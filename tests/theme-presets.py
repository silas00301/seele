"""Check generated Stylix presets against the real runtime and launcher contract.

Usage: python3 tests/theme-presets.py /path/to/seele-theme /path/to/catalog.json
The flake check supplies its actual generated catalog and theme files.
"""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import tomllib

binary = str(Path(sys.argv[1]).resolve())
catalog = json.loads(Path(sys.argv[2]).read_text())
with tempfile.TemporaryDirectory(prefix="seele-stylix-") as directory:
    root = Path(directory)
    config = root / "config/seele-theme"
    config.mkdir(parents=True)
    catalog["commands"] = {}
    (config / "catalog.json").write_text(json.dumps(catalog))
    env = {"HOME": str(root), "XDG_CONFIG_HOME": str(config.parent), "XDG_STATE_HOME": str(root / "state")}
    def run(*args):
        result = subprocess.run([binary, *args], env=env, capture_output=True, text=True, timeout=15, check=True)
        return json.loads(result.stdout)
    entries = run("list")["themes"]
    assert len(entries) == len(catalog["themes"])
    assert {theme["mode"] for theme in entries} == {"light", "dark"}
    assert not (root / "state").exists(), "Listing cannot publish a theme"
    for theme in catalog["themes"]:
        run("set", theme["id"])
        state = root / "state/seele-theme"
        selected = json.loads((state / "selection.json").read_text())
        assert selected["palette"] == theme["palette"]
        assert selected["mode"] == theme["mode"]
        assert selected["id"] == theme["id"]
        launcher = tomllib.loads((state / "current/vicinae.toml").read_text())
        assert launcher["meta"]["variant"] == theme["mode"]
        assert launcher["colors"]["core"]["background"] == theme["palette"]["base00"]
        assert launcher["colors"]["core"]["foreground"] == theme["palette"]["base05"]
        assert launcher["colors"]["core"]["accent"] == theme["palette"]["base0D"]
        assert selected["base"] == launcher["colors"]["core"]["background"]
        assert selected["accent"] == launcher["colors"]["core"]["accent"]
        assert (state / "current/vicinae.toml").read_bytes() == Path(theme["vicinaeTheme"]).read_bytes()
        ghostty = (state / "current/ghostty").read_text()
        assert "background = " + theme["palette"]["base00"] in ghostty
        assert len(list(state.glob(".theme-*"))) == 1
    print(f"{len(entries)} generated presets passed palette, mode, publication and launcher parity checks")
