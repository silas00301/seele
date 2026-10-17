"""Check generated Stylix presets against the real runtime and launcher contract.

Usage: python3 tests/theme-presets.py /path/to/seele-theme /path/to/catalog.json
The flake check supplies its actual generated catalog and theme files. A
registered theme folder's entry names its document; the shell and the terminal
then take that document's own roles, not a projection of its Base16 palette,
and its own wallpaper when it names one. The catalog carries the host's
wallpaper mapping (modules/features/themes/wallpaper.nix), and each theme
publishes the image it chooses for every output and the outputs that differ;
without a mapping that is its own image or the configured wallpaper.
"""
import json
import configparser
from pathlib import Path
import subprocess
import sys
import tempfile
import tomllib

binary = str(Path(sys.argv[1]).resolve())
catalog = json.loads(Path(sys.argv[2]).read_text())
mapping = catalog.get("wallpapers", {})


def wallpaper(theme, own, output=None):
    """The image a theme shows on an output, in wallpaper.nix's order."""
    light = theme["mode"] == "light"
    mapped = mapping.get("themes", {}).get(theme["id"], {})
    place = mapping.get("outputs", {}).get(output, {}) if output else {}
    mode = "light" if light else "dark"
    for image in (mapped.get("outputs", {}).get(output) if output else None, mapped.get("image"), own,
                  place.get(mode), place.get("image"), mapping.get(mode)):
        if image:
            return image
    return catalog["wallpaper"]


def outputs(theme, own):
    named = set(mapping.get("outputs", {})) | set(mapping.get("themes", {}).get(theme["id"], {}).get("outputs", {}))
    everywhere = wallpaper(theme, own)
    return {output: wallpaper(theme, own, output) for output in sorted(named) if wallpaper(theme, own, output) != everywhere}


with tempfile.TemporaryDirectory(prefix="seele-stylix-") as directory:
    root = Path(directory)
    config = root / "config/seele-theme"
    config.mkdir(parents=True)
    catalog["commands"] = {}
    (config / "catalog.json").write_text(json.dumps(catalog))
    env = {"HOME": str(root), "XDG_CONFIG_HOME": str(config.parent), "XDG_STATE_HOME": str(root / "state")}
    def run(*args):
        result = subprocess.run([binary, *args], env=env, capture_output=True, text=True, timeout=15)
        assert result.returncode == 0, (args, result.stdout, result.stderr)
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
        document = json.loads(Path(theme["document"]).read_text()) if "document" in theme else None
        if document is None:
            assert selected["base"] == launcher["colors"]["core"]["background"]
            assert selected["accent"] == launcher["colors"]["core"]["accent"]
        else:
            for key, value in document.items():
                assert selected[key] == value, (theme["id"], key)
        own = (document or {}).get("wallpaper")
        assert selected["wallpaper"] == wallpaper(theme, own), (theme["id"], selected["wallpaper"])
        assert selected.get("wallpaperOutputs", {}) == outputs(theme, own), (theme["id"], selected.get("wallpaperOutputs"))
        assert (state / "current/vicinae.toml").read_bytes() == Path(theme["vicinaeTheme"]).read_bytes()
        ghostty = (state / "current/ghostty").read_text()
        assert "background = " + (document or {}).get("base", theme["palette"]["base00"]) in ghostty
        assets = {
            "gtkCss": "gtk.css",
            "gtkSourceView": "gtksourceview.xml",
            "zenChrome": "zen-chrome.css",
            "zenContent": "zen-content.css",
            "spicetify": "spicetify.ini",
            "kvantumConfig": "kvantum.kvconfig",
            "kvantumSvg": "kvantum.svg",
            "kdeColors": "kde.colors",
        }
        for key, filename in assets.items():
            published = (state / "current" / filename).read_bytes()
            source = Path(theme["assets"][key]).read_bytes()
            if key == "zenChrome":
                assert published.startswith(source)
                assert b"#urlbar-input::placeholder" in published
            else:
                assert published == source
        assert theme["palette"]["base00"] in (state / "current/gtk.css").read_text()
        assert theme["palette"]["base0D"] in (state / "current/zen-chrome.css").read_text()
        spicetify = configparser.ConfigParser()
        spicetify.read(state / "current/spicetify.ini")
        assert spicetify["base"]["main"].lower() == theme["palette"]["base00"].removeprefix("#").lower()
        assert "*background: " + theme["palette"]["base00"] in (state / "current/Xresources").read_text()
        assert len(list(state.glob(".theme-*"))) == 1
    folders = sum("document" in theme for theme in catalog["themes"])
    print(f"{len(entries)} generated presets, {folders} of them theme folders, passed palette, mode, publication, wallpaper mapping and launcher parity checks")
