#!/usr/bin/env python3
"""Allowlist for Dependabot Nix repairs.

Ordinary regular ``*.nix`` files only. The publish job re-validates this
payload and never evaluates Nix. Symlinks, non-regular files, hidden paths,
locks, and submodule gitlinks are rejected.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import stat
import subprocess
import sys
from pathlib import Path

MAX_FILES = 200
MAX_FILE_BYTES = 1_048_576
HEADLINE = "fix(nix): repair dependency update"

_SEGMENT = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._+-]*$")
_SHA = re.compile(r"^[0-9a-f]{40}$")
_PR = re.compile(r"^[1-9][0-9]{0,8}$")
_REPO = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
_FORBIDDEN_BRANCHES = frozenset({"HEAD", "main", "master"})
_BLOB_MODES = frozenset({b"100644", b"100755"})


class RepairRejected(Exception):
    """The candidate repair is outside the publish allowlist."""


def validate_repository(repository: str) -> str:
    if not isinstance(repository, str) or not _REPO.fullmatch(repository):
        raise RepairRejected("Repository name is not usable.")
    return repository


def validate_sha(value: str) -> str:
    if not isinstance(value, str) or not _SHA.fullmatch(value):
        raise RepairRejected("Commit id is not a full SHA-1.")
    return value


def validate_pr_number(value: str) -> str:
    if not isinstance(value, str) or not _PR.fullmatch(value):
        raise RepairRejected("Pull request number must be a positive integer.")
    return value


def validate_relpath(path: str) -> str:
    if not isinstance(path, str) or not path.endswith(".nix"):
        raise RepairRejected("Repair includes files outside ordinary Nix sources.")
    if "\\" in path or path.startswith("/"):
        raise RepairRejected("Repair includes files outside ordinary Nix sources.")
    parts = path.split("/")
    if any(not _SEGMENT.fullmatch(part) for part in parts):
        raise RepairRejected("Repair includes files outside ordinary Nix sources.")
    return path


def validate_branch(name: str) -> str:
    if not isinstance(name, str) or name in _FORBIDDEN_BRANCHES:
        raise RepairRejected("Refusing to publish onto that branch.")
    parts = name.split("/")
    if any(not _SEGMENT.fullmatch(part) for part in parts):
        raise RepairRejected("Refusing to publish onto that branch.")
    return name


def reject_copilot_token_on_publish() -> None:
    if os.environ.get("COPILOT_GITHUB_TOKEN"):
        raise RepairRejected("Publish must not receive the Copilot token.")


def assess_pull_request(pull_request: dict, repository: str) -> tuple[str, str]:
    repository = validate_repository(repository)
    if not isinstance(pull_request, dict):
        raise RepairRejected("Pull request metadata is unusable.")
    user = pull_request.get("user") or {}
    if not isinstance(user, dict) or user.get("login") != "dependabot[bot]":
        raise RepairRejected("Repair publishes only Dependabot pull requests.")
    if pull_request.get("state") != "open":
        raise RepairRejected("Repair refuses a pull request that is not open.")
    head = pull_request.get("head") or {}
    base = pull_request.get("base") or {}
    if not isinstance(head, dict) or not isinstance(base, dict):
        raise RepairRejected("Pull request metadata is unusable.")
    head_repo = head.get("repo") or {}
    base_repo = base.get("repo") or {}
    if not isinstance(head_repo, dict) or head_repo.get("full_name") != repository:
        raise RepairRejected("Repair refuses a fork pull request.")
    if not isinstance(base_repo, dict) or base_repo.get("full_name") != repository:
        raise RepairRejected("Repair refuses a pull request from another repository.")
    sha = validate_sha(head.get("sha"))
    branch = validate_branch(head.get("ref"))
    return sha, branch


def normalize_payload(
    payload: dict,
    *,
    max_bytes: int = MAX_FILE_BYTES,
    max_files: int = MAX_FILES,
) -> dict:
    if not isinstance(payload, dict):
        raise RepairRejected("Repair payload is malformed.")
    base_sha = validate_sha(payload.get("base_sha"))
    additions = payload.get("additions")
    deletions = payload.get("deletions")
    if not isinstance(additions, list) or not isinstance(deletions, list):
        raise RepairRejected("Repair payload is malformed.")
    if len(additions) + len(deletions) > max_files:
        raise RepairRejected("Repair touches too many files.")
    if not additions and not deletions:
        raise RepairRejected("Copilot did not produce a repair.")
    seen: set[str] = set()
    normalized_additions = []
    for item in additions:
        if not isinstance(item, dict):
            raise RepairRejected("Repair payload is malformed.")
        path = validate_relpath(item.get("path"))
        contents = item.get("contents")
        if not isinstance(contents, str):
            raise RepairRejected("Repair payload is malformed.")
        if path in seen:
            raise RepairRejected("Repair repeats a path.")
        seen.add(path)
        try:
            raw = base64.b64decode(contents, validate=True)
        except (ValueError, TypeError) as error:
            raise RepairRejected("Repair contents are not valid base64.") from error
        if len(raw) > max_bytes:
            raise RepairRejected("Repair file is too large.")
        normalized_additions.append(
            {"path": path, "contents": base64.b64encode(raw).decode("ascii")}
        )
    normalized_deletions = []
    for path in deletions:
        path = validate_relpath(path)
        if path in seen:
            raise RepairRejected("Repair repeats a path.")
        seen.add(path)
        normalized_deletions.append(path)
    normalized_additions.sort(key=lambda item: item["path"])
    normalized_deletions.sort()
    return {
        "base_sha": base_sha,
        "additions": normalized_additions,
        "deletions": normalized_deletions,
    }


def graphql_body(payload: dict, repository: str, branch: str, expected_sha: str) -> dict:
    payload = normalize_payload(payload)
    repository = validate_repository(repository)
    branch = validate_branch(branch)
    expected_sha = validate_sha(expected_sha)
    if payload["base_sha"] != expected_sha:
        raise RepairRejected("Pull request head moved after verification.")
    return {
        "query": (
            "mutation($input: CreateCommitOnBranchInput!) { "
            "createCommitOnBranch(input: $input) { "
            "commit { oid signature { isValid } } } }"
        ),
        "variables": {
            "input": {
                "branch": {
                    "repositoryNameWithOwner": repository,
                    "branchName": branch,
                },
                "expectedHeadOid": expected_sha,
                "message": {"headline": HEADLINE},
                "fileChanges": {
                    "additions": payload["additions"],
                    "deletions": [{"path": path} for path in payload["deletions"]],
                },
            }
        },
    }


def _git(repo: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        check=check,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def _nul_split(blob: bytes) -> list[bytes]:
    parts = blob.split(b"\0")
    if parts and parts[-1] == b"":
        parts.pop()
    return parts


def _ensure_head(repo: Path, head: str) -> None:
    head = validate_sha(head)
    current = _git(repo, "rev-parse", "--verify", "HEAD").stdout.decode().strip()
    if current != head:
        raise RepairRejected("Checkout does not match the reviewed commit.")


def _reject_staged(repo: Path) -> None:
    staged = _git(repo, "diff", "--cached", "--quiet", check=False)
    if staged.returncode == 1:
        raise RepairRejected("Unexpected Git staging.")
    if staged.returncode != 0:
        raise RepairRejected(staged.stderr.decode(errors="replace").strip() or "Git index check failed.")


def _walk(repo: Path, relative: str, *, create: bool) -> Path:
    validate_relpath(relative)
    current = repo
    parts = relative.split("/")
    for part in parts[:-1]:
        current = current / part
        if current.is_symlink():
            raise RepairRejected("Repair includes files outside ordinary Nix sources.")
        if current.exists():
            if not current.is_dir():
                raise RepairRejected("Repair includes files outside ordinary Nix sources.")
        elif create:
            current.mkdir(mode=0o755)
        else:
            raise RepairRejected("Repair includes files outside ordinary Nix sources.")
    leaf = current / parts[-1]
    if leaf.is_symlink():
        raise RepairRejected("Repair includes files outside ordinary Nix sources.")
    return leaf


def _read_regular(repo: Path, relative: str, max_bytes: int) -> bytes:
    leaf = _walk(repo, relative, create=False)
    if not leaf.exists() or not stat.S_ISREG(leaf.lstat().st_mode):
        raise RepairRejected("Repair includes files outside ordinary Nix sources.")
    if leaf.lstat().st_mode & 0o111:
        raise RepairRejected("Repair includes files outside ordinary Nix sources.")
    fd = os.open(leaf, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        data = os.read(fd, max_bytes + 1)
    finally:
        os.close(fd)
    if len(data) > max_bytes:
        raise RepairRejected("Repair file is too large.")
    return data


def _head_blob_mode(repo: Path, relative: str) -> None:
    listed = _git(repo, "ls-tree", "-z", "HEAD", "--", relative).stdout
    entry = listed.split(b"\0", 1)[0]
    if not entry:
        raise RepairRejected("Repair includes files outside ordinary Nix sources.")
    metadata, name = entry.split(b"\t", 1)
    mode, kind, _oid = metadata.split()
    if name.decode("utf-8") != relative or kind != b"blob" or mode not in _BLOB_MODES:
        raise RepairRejected("Repair includes files outside ordinary Nix sources.")


def _parse_name_status(blob: bytes) -> list[tuple[str, str]]:
    parts = _nul_split(blob)
    if len(parts) % 2:
        raise RepairRejected("Unexpected git status output.")
    entries = []
    for index in range(0, len(parts), 2):
        try:
            status = parts[index].decode("ascii")
            path = parts[index + 1].decode("utf-8")
        except UnicodeError as error:
            raise RepairRejected("Repair includes files outside ordinary Nix sources.") from error
        entries.append((status, path))
    return entries


def collect_repair(
    repo: Path,
    head: str,
    *,
    max_bytes: int = MAX_FILE_BYTES,
    max_files: int = MAX_FILES,
) -> dict:
    repo = repo.resolve()
    _ensure_head(repo, head)
    _reject_staged(repo)
    changes = _parse_name_status(
        _git(repo, "diff", "--name-status", "--no-renames", "-z", "HEAD").stdout
    )
    untracked = []
    for raw in _nul_split(_git(repo, "ls-files", "--others", "--exclude-standard", "-z").stdout):
        try:
            untracked.append(raw.decode("utf-8"))
        except UnicodeError as error:
            raise RepairRejected("Repair includes files outside ordinary Nix sources.") from error
    additions = []
    deletions = []
    seen: set[str] = set()
    for status, path in changes:
        if status not in {"A", "M", "D"} or path in seen:
            raise RepairRejected("Repair includes files outside ordinary Nix sources.")
        seen.add(path)
        validate_relpath(path)
        if status == "D":
            _head_blob_mode(repo, path)
            leaf = repo / path
            if leaf.exists() or leaf.is_symlink():
                raise RepairRejected("Repair includes files outside ordinary Nix sources.")
            deletions.append(path)
            continue
        if status == "M":
            _head_blob_mode(repo, path)
        additions.append(
            {
                "path": path,
                "contents": base64.b64encode(_read_regular(repo, path, max_bytes)).decode("ascii"),
            }
        )
    for path in untracked:
        if path in seen:
            raise RepairRejected("Repair includes files outside ordinary Nix sources.")
        seen.add(path)
        validate_relpath(path)
        additions.append(
            {
                "path": path,
                "contents": base64.b64encode(_read_regular(repo, path, max_bytes)).decode("ascii"),
            }
        )
    return normalize_payload(
        {"base_sha": head, "additions": additions, "deletions": deletions},
        max_bytes=max_bytes,
        max_files=max_files,
    )


def _stage_exact(repo: Path, paths: list[str]) -> None:
    _git(repo, "add", "--", *paths)
    staged = [
        part.decode("utf-8")
        for part in _nul_split(_git(repo, "diff", "--cached", "--name-only", "--no-renames", "-z").stdout)
    ]
    if sorted(staged) != sorted(paths):
        raise RepairRejected("Staging did not match the repair.")
    if _nul_split(_git(repo, "diff", "--name-only", "-z").stdout):
        raise RepairRejected("Repair includes files outside ordinary Nix sources.")
    if _nul_split(_git(repo, "ls-files", "--others", "--exclude-standard", "-z").stdout):
        raise RepairRejected("Repair includes files outside ordinary Nix sources.")


def apply_repair(repo: Path, payload: dict, head: str, *, stage: bool = False) -> dict:
    repo = repo.resolve()
    payload = normalize_payload(payload)
    _ensure_head(repo, head)
    if payload["base_sha"] != head:
        raise RepairRejected("Repair does not match the checked out commit.")
    _reject_staged(repo)
    for path in payload["deletions"]:
        leaf = _walk(repo, path, create=False)
        if not leaf.exists():
            continue
        if not stat.S_ISREG(leaf.lstat().st_mode):
            raise RepairRejected("Repair includes files outside ordinary Nix sources.")
        os.unlink(leaf)
    for item in payload["additions"]:
        raw = base64.b64decode(item["contents"], validate=True)
        leaf = _walk(repo, item["path"], create=True)
        if leaf.exists() and not stat.S_ISREG(leaf.lstat().st_mode):
            raise RepairRejected("Repair includes files outside ordinary Nix sources.")
        fd = os.open(
            leaf,
            os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW | os.O_CLOEXEC,
            0o644,
        )
        try:
            os.write(fd, raw)
            os.fchmod(fd, 0o644)
        finally:
            os.close(fd)
    paths = [item["path"] for item in payload["additions"]] + payload["deletions"]
    if stage:
        _stage_exact(repo, paths)
    return payload


def _github_json(path: str) -> dict:
    raw = subprocess.check_output(["gh", "api", path])
    value = json.loads(raw)
    if not isinstance(value, dict):
        raise RepairRejected("GitHub returned unexpected metadata.")
    return value


def _github_graphql(body: dict) -> str:
    raw = subprocess.check_output(
        ["gh", "api", "graphql", "--input", "-"],
        input=json.dumps(body).encode(),
    )
    response = json.loads(raw)
    if response.get("errors"):
        messages = []
        for item in response["errors"]:
            if isinstance(item, dict) and isinstance(item.get("message"), str):
                messages.append(item["message"][:300])
        detail = "; ".join(messages) if messages else "request failed"
        raise RepairRejected(f"GitHub refused the repair commit: {detail}")
    try:
        commit = response["data"]["createCommitOnBranch"]["commit"]
        oid = commit["oid"]
        valid = bool((commit.get("signature") or {}).get("isValid"))
    except (KeyError, TypeError) as error:
        raise RepairRejected("GitHub refused the repair commit.") from error
    if not valid or not isinstance(oid, str) or not _SHA.fullmatch(oid):
        raise RepairRejected("GitHub did not verify the repair signature.")
    print(f"Published signed repair {oid}")
    return oid


def resolve_pull_request(number: str) -> str:
    repository = validate_repository(os.environ["GITHUB_REPOSITORY"])
    number = validate_pr_number(number)
    pull_request = _github_json(f"repos/{repository}/pulls/{number}")
    sha, _branch = assess_pull_request(pull_request, repository)
    output = os.environ.get("GITHUB_OUTPUT")
    if not output:
        raise RepairRejected("GITHUB_OUTPUT is not set.")
    with open(output, "a", encoding="utf-8") as handle:
        handle.write(f"head_sha={sha}\n")
    print(sha)
    return sha


def publish_repair(payload_path: Path, number: str) -> str:
    reject_copilot_token_on_publish()
    repository = validate_repository(os.environ["GITHUB_REPOSITORY"])
    number = validate_pr_number(number)
    payload = normalize_payload(json.loads(payload_path.read_text(encoding="utf-8")))
    pull_request = _github_json(f"repos/{repository}/pulls/{number}")
    sha, branch = assess_pull_request(pull_request, repository)
    body = graphql_body(payload, repository, branch, sha)
    return _github_graphql(body)


def _command_collect(args: argparse.Namespace) -> None:
    payload = collect_repair(Path(args.repo), args.head)
    destination = Path(args.output)
    destination.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def _command_apply(args: argparse.Namespace) -> None:
    payload = json.loads(Path(args.input).read_text(encoding="utf-8"))
    apply_repair(Path(args.repo), payload, args.head, stage=args.stage)


def _command_resolve(args: argparse.Namespace) -> None:
    resolve_pull_request(args.pull_request)


def _command_publish(args: argparse.Namespace) -> None:
    publish_repair(Path(args.input), args.pull_request)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Allowlisted Dependabot Nix repair helper.")
    parser.add_argument("--repo", default=".", help="Git checkout to read or modify.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    collect = subparsers.add_parser("collect")
    collect.add_argument("--head", required=True)
    collect.add_argument("--output", required=True)
    collect.set_defaults(func=_command_collect)

    apply = subparsers.add_parser("apply")
    apply.add_argument("--head", required=True)
    apply.add_argument("--input", required=True)
    apply.add_argument("--stage", action="store_true")
    apply.set_defaults(func=_command_apply)

    resolve = subparsers.add_parser("resolve")
    resolve.add_argument("--pull-request", required=True)
    resolve.set_defaults(func=_command_resolve)

    publish = subparsers.add_parser("publish")
    publish.add_argument("--input", required=True)
    publish.add_argument("--pull-request", required=True)
    publish.set_defaults(func=_command_publish)

    args = parser.parse_args(argv)
    try:
        args.func(args)
    except RepairRejected as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
