#!/usr/bin/env python3
"""Allowlist tests for the Dependabot Nix repair helper."""

from __future__ import annotations

import base64
import importlib.util
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

os.environ.pop("COPILOT_GITHUB_TOKEN", None)

_SPEC = importlib.util.spec_from_file_location(
    "dependabot_nix_repair",
    Path(__file__).with_name("dependabot_nix_repair.py"),
)
repair = importlib.util.module_from_spec(_SPEC)
assert _SPEC.loader is not None
_SPEC.loader.exec_module(repair)


def _git(repo: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo), *args], text=True
    ).strip()


def _init() -> tuple[tempfile.TemporaryDirectory[str], Path, str]:
    temporary = tempfile.TemporaryDirectory(prefix="dependabot-nix-repair-")
    repo = Path(temporary.name)
    subprocess.run(["git", "init", "-b", "main"], cwd=repo, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.email", "test@example.invalid"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.name", "Repair Test"], cwd=repo, check=True)
    (repo / "flake.nix").write_text("{ outputs = _: {}; }\n", encoding="utf-8")
    (repo / "modules").mkdir()
    (repo / "modules" / "example.nix").write_text("1\n", encoding="utf-8")
    subprocess.run(["git", "add", "flake.nix", "modules/example.nix"], cwd=repo, check=True)
    subprocess.run(["git", "commit", "-m", "init"], cwd=repo, check=True, capture_output=True)
    return temporary, repo, _git(repo, "rev-parse", "HEAD")


class AllowlistTests(unittest.TestCase):
    def test_collect_modify_add_and_delete(self) -> None:
        temporary, repo, head = _init()
        self.addCleanup(temporary.cleanup)
        (repo / "modules" / "example.nix").write_text("2\n", encoding="utf-8")
        (repo / "modules" / "fresh.nix").write_text("fresh\n", encoding="utf-8")
        (repo / "flake.nix").unlink()
        payload = repair.collect_repair(repo, head)
        self.assertEqual(payload["base_sha"], head)
        self.assertEqual(payload["deletions"], ["flake.nix"])
        paths = [item["path"] for item in payload["additions"]]
        self.assertEqual(paths, ["modules/example.nix", "modules/fresh.nix"])
        (repo / "flake.nix").write_text("{ outputs = _: {}; }\n", encoding="utf-8")
        (repo / "modules" / "example.nix").write_text("1\n", encoding="utf-8")
        (repo / "modules" / "fresh.nix").unlink()
        repair.apply_repair(repo, payload, head, stage=True)
        self.assertFalse((repo / "flake.nix").exists())
        self.assertEqual((repo / "modules" / "example.nix").read_text(encoding="utf-8"), "2\n")
        self.assertEqual((repo / "modules" / "fresh.nix").read_text(encoding="utf-8"), "fresh\n")
        self.assertEqual(stat.S_IMODE((repo / "modules" / "fresh.nix").stat().st_mode), 0o644)
        staged = _git(repo, "diff", "--cached", "--name-only").splitlines()
        self.assertEqual(sorted(staged), ["flake.nix", "modules/example.nix", "modules/fresh.nix"])

    def test_rejects_lock_symlink_hidden_and_executable(self) -> None:
        temporary, repo, head = _init()
        self.addCleanup(temporary.cleanup)
        (repo / "flake.lock").write_text("{}\n", encoding="utf-8")
        with self.assertRaises(repair.RepairRejected):
            repair.collect_repair(repo, head)
        (repo / "flake.lock").unlink()
        hidden = repo / ".github" / "workflows"
        hidden.mkdir(parents=True)
        (hidden / "evil.nix").write_text("x\n", encoding="utf-8")
        with self.assertRaises(repair.RepairRejected):
            repair.collect_repair(repo, head)
        (hidden / "evil.nix").unlink()
        link = repo / "modules" / "link.nix"
        link.symlink_to("example.nix")
        with self.assertRaises(repair.RepairRejected):
            repair.collect_repair(repo, head)
        link.unlink()
        target = repo / "modules" / "example.nix"
        target.chmod(0o755)
        with self.assertRaises(repair.RepairRejected):
            repair.collect_repair(repo, head)

    def test_rejects_staged_escape_and_oversize_payloads(self) -> None:
        temporary, repo, head = _init()
        self.addCleanup(temporary.cleanup)
        (repo / "modules" / "example.nix").write_text("staged\n", encoding="utf-8")
        subprocess.run(["git", "add", "modules/example.nix"], cwd=repo, check=True)
        with self.assertRaisesRegex(repair.RepairRejected, "staging"):
            repair.collect_repair(repo, head)
        with self.assertRaises(repair.RepairRejected):
            repair.normalize_payload(
                {
                    "base_sha": head,
                    "additions": [{"path": "../outside.nix", "contents": base64.b64encode(b"x").decode()}],
                    "deletions": [],
                }
            )
        with self.assertRaises(repair.RepairRejected):
            repair.normalize_payload(
                {
                    "base_sha": head,
                    "additions": [
                        {"path": "modules/example.nix", "contents": base64.b64encode(b"abcdef").decode()}
                    ],
                    "deletions": [],
                },
                max_bytes=4,
            )
        with self.assertRaises(repair.RepairRejected):
            repair.normalize_payload({"base_sha": head, "additions": [], "deletions": []})
        with self.assertRaises(repair.RepairRejected):
            repair.collect_repair(repo, "a" * 40)

    def test_apply_refuses_symlink_destination(self) -> None:
        temporary, repo, head = _init()
        self.addCleanup(temporary.cleanup)
        leaf = repo / "modules" / "example.nix"
        leaf.unlink()
        leaf.symlink_to("missing")
        payload = {
            "base_sha": head,
            "additions": [
                {"path": "modules/example.nix", "contents": base64.b64encode(b"safe\n").decode()}
            ],
            "deletions": [],
        }
        with self.assertRaises(repair.RepairRejected):
            repair.apply_repair(repo, payload, head)
        self.assertTrue(leaf.is_symlink())

    def test_pull_request_and_publish_rules(self) -> None:
        repository = "silas00301/seele"
        sha = "a" * 40
        accepted = {
            "state": "open",
            "user": {"login": "dependabot[bot]"},
            "head": {"sha": sha, "ref": "dependabot/nix/nixpkgs-1", "repo": {"full_name": repository}},
            "base": {"repo": {"full_name": repository}},
        }
        self.assertEqual(repair.assess_pull_request(accepted, repository), (sha, "dependabot/nix/nixpkgs-1"))
        forked = {
            **accepted,
            "head": {"sha": sha, "ref": "dependabot/nix/nixpkgs-1", "repo": {"full_name": "other/seele"}},
        }
        with self.assertRaisesRegex(repair.RepairRejected, "fork"):
            repair.assess_pull_request(forked, repository)
        closed = {**accepted, "state": "closed"}
        with self.assertRaises(repair.RepairRejected):
            repair.assess_pull_request(closed, repository)
        human = {**accepted, "user": {"login": "silash"}}
        with self.assertRaises(repair.RepairRejected):
            repair.assess_pull_request(human, repository)
        with self.assertRaises(repair.RepairRejected):
            repair.validate_branch("main")
        payload = repair.normalize_payload(
            {
                "base_sha": sha,
                "additions": [{"path": "modules/example.nix", "contents": base64.b64encode(b"1\n").decode()}],
                "deletions": ["flake.nix"],
            }
        )
        body = repair.graphql_body(payload, repository, "dependabot/nix/nixpkgs-1", sha)
        changes = body["variables"]["input"]["fileChanges"]
        self.assertEqual(changes["additions"][0]["path"], "modules/example.nix")
        self.assertEqual(changes["deletions"], [{"path": "flake.nix"}])
        self.assertEqual(body["variables"]["input"]["expectedHeadOid"], sha)
        self.assertEqual(body["variables"]["input"]["message"]["headline"], repair.HEADLINE)
        with self.assertRaises(repair.RepairRejected):
            repair.graphql_body(payload, repository, "main", sha)
        previous = os.environ.get("COPILOT_GITHUB_TOKEN")
        os.environ["COPILOT_GITHUB_TOKEN"] = "present"
        try:
            with self.assertRaisesRegex(repair.RepairRejected, "Copilot"):
                repair.reject_copilot_token_on_publish()
        finally:
            if previous is None:
                os.environ.pop("COPILOT_GITHUB_TOKEN", None)
            else:
                os.environ["COPILOT_GITHUB_TOKEN"] = previous


if __name__ == "__main__":
    unittest.main()
