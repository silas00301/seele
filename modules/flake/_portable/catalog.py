"""Render the portable-app declarations without building the applications."""

import argparse
import json
from pathlib import Path
import sys


def main():
    manifest_path = Path(sys.argv[1])
    parser = argparse.ArgumentParser(
        prog="seele-portable-apps",
        description="Discover Seele's configured portable applications.",
        epilog="Run an application with: nix run github:silas00301/seele#COMMAND",
    )
    parser.add_argument("command", nargs="?", help="show the features and platforms for one command")
    parser.add_argument("--all-systems", action="store_true", help="include applications for other platforms")
    parser.add_argument("--json", action="store_true", help="emit machine-readable application metadata")
    args = parser.parse_args(sys.argv[2:])
    manifest = json.loads(manifest_path.read_text())
    system = manifest["system"]
    applications = sorted(manifest["applications"], key=lambda app: app["name"])
    if not args.all_systems:
        applications = [app for app in applications if system in app["systems"]]
    if args.command:
        applications = [app for app in applications if app["name"] == args.command]
        if not applications:
            parser.error(f"no portable command {args.command!r} in this selection; try --all-systems")
    if args.json:
        print(json.dumps(applications, indent=2, ensure_ascii=False))
    elif args.command:
        app = applications[0]
        print(f"{app['name']} (executable: {app['binary']})")
        print(f"Features: {', '.join(app['modules'])}")
        print(f"Platforms: {', '.join(app['systems'])}")
        print(f"Run: nix run github:silas00301/seele#{app['name']}")
    else:
        selection = "all platforms" if args.all_systems else system
        print(f"Seele portable applications — {selection}\n")
        rows = [(app["name"], app["binary"], ", ".join(app["modules"])) for app in applications]
        headings = ("COMMAND", "EXECUTABLE", "INCLUDED FEATURES")
        widths = [max(len(row[i]) for row in [headings, *rows]) for i in range(2)]
        for row in [headings, *rows]:
            print(f"{row[0]:<{widths[0]}}  {row[1]:<{widths[1]}}  {row[2]}")
        print("\nRun: nix run github:silas00301/seele#COMMAND")
        print("Inspect a command: nix run github:silas00301/seele#portable-apps -- COMMAND")


if __name__ == "__main__":
    main()
