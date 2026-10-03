#!/usr/bin/env python3
"""Spell check real prose buffers in a real Neovim with isolated state.

Usage:
  test-spell.py SPELL_DIR JJDESCRIPTION_PARSER JJDESCRIPTION_QUERIES

SPELL_DIR holds the built de.utf-8.spl and .sug, as german-spell.nix installs them.
The parser and its base highlights.scm are nvim-treesitter's jjdescription
grammar, the pair the packaged configuration runs with; Neovim bundles the
markdown parser itself. NVIM selects the editor (default: nvim). Nothing from
the user's configuration or data directories is read or written.
"""

import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent


def lua_string(value):
    return "[==[" + str(value) + "]==]"


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    spell_dir, parser, queries = (Path(arg).resolve() for arg in sys.argv[1:])
    editor = os.environ.get("NVIM", "nvim")
    if shutil.which(editor) is None:
        raise SystemExit(f"{editor} is required")

    with tempfile.TemporaryDirectory(prefix="seele-spell-test-") as root:
        root = Path(root)
        # A runtime directory laid out the way nixvim's extraFiles and grammar
        # plugins lay theirs out.
        runtime = root / "runtime"
        (runtime / "spell").mkdir(parents=True)
        for name in ("de.utf-8.spl", "de.utf-8.sug"):
            shutil.copy(spell_dir / name, runtime / "spell")
        (runtime / "parser").mkdir()
        shutil.copy(parser, runtime / "parser" / "jjdescription.so")
        (runtime / "queries" / "jjdescription").mkdir(parents=True)
        shutil.copy(queries, runtime / "queries" / "jjdescription" / "highlights.scm")
        after = runtime / "after" / "queries" / "jjdescription"
        after.mkdir(parents=True)
        shutil.copy(HERE / "jjdescription-spell.scm", after / "highlights.scm")
        before = sorted(p.relative_to(runtime) for p in runtime.rglob("*"))

        env = {key: value for key, value in os.environ.items() if not key.startswith("XDG_")}
        for name in ("CONFIG", "DATA", "STATE", "CACHE"):
            env[f"XDG_{name}_HOME"] = str(root / name.lower())
        env["HOME"] = str(root / "home")

        init = root / "init.lua"
        init.write_text(f"""
vim.opt.runtimepath:prepend({lua_string(runtime)})
vim.opt.runtimepath:append({lua_string(runtime / "after")})
vim.g.missing = {{}}
vim.api.nvim_create_autocmd("SpellFileMissing", {{
  callback = function(args) table.insert(vim.g.missing, args.match) end,
}})
-- nixvim's treesitter.highlight.enable starts a highlighter on every buffer
-- whose language has a parser; plain syntax covers the rest.
vim.api.nvim_create_autocmd("FileType", {{
  callback = function(args) pcall(vim.treesitter.start, args.buf) end,
}})
dofile({lua_string(HERE / "spell.lua")}).setup()
""")

        files = root / "files"
        files.mkdir()
        (files / "note.md").write_text(
            "# Einkaufsliste\n\n"
            "Teh house has a Kaffeetasse and a Wochenmarkt.\n"
            "Die Straße ist lang, aber die Strase nicht.\n"
            "Run `nixfmt --chek` from <https://exampel.org> and [[Wikilnk]].\n"
            "The colour is nice, die Strasse auch.\n"
        )
        (files / "editor.jjdescription").write_text(
            "feat(nixvim): Chek prose in descriptons\n\n"
            "The bodi is prose too.\n\n"
            "JJ: This commment is mine\n"
            "JJ: Change ID: qkxkwtqq\n"
            "JJ: This commit contains the following changes:\n"
            "JJ:     M modules/packages/_nixvim/spel.lua\n"
        )
        (files / "COMMIT_EDITMSG").write_text(
            "Fix teh typo\n\n"
            "# Plese enter the commit mesage for your changes.\n"
        )
        (files / "code.lua").write_text("-- teh comment\nlocal wrd = 1\n")

        count = 0

        def run(body):
            nonlocal count
            count += 1
            script = root / "check.lua"
            script.write_text(f"""
local function bad(strict)
  -- Walk the buffer with ]s/]S so syntax and Treesitter decide what is prose,
  -- exactly as they do for the highlighting the user sees. A headless editor
  -- never redraws, so parse first as a screen update would. Every fixture
  -- starts with a correct word, since ]s only finds words after the cursor.
  local parser = vim.treesitter.get_parser(0, nil, {{ error = false }})
  if parser then parser:parse(true) end
  vim.o.wrapscan = false
  vim.api.nvim_win_set_cursor(0, {{1, 0}})
  -- With nothing left to find, ]s leaves the cursor where it was.
  local found, last = {{}}, "1:0"
  while true do
    local ok = pcall(vim.cmd, "normal! " .. (strict and "]S" or "]s"))
    local pos = vim.api.nvim_win_get_cursor(0)
    local key = pos[1] .. ":" .. pos[2]
    if not ok or key == last then break end
    last = key
    table.insert(found, vim.fn.spellbadword()[1])
  end
  return found
end
local function open(name)
  vim.cmd.edit(vim.fn.fnameescape({lua_string(files)} .. "/" .. name))
end
local function eq(actual, expected, what)
  if not vim.deep_equal(actual, expected) then
    error(what .. ": expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual))
  end
end
local ok, err = pcall(function()
{body}
end)
if not ok then
  io.stderr:write(tostring(err) .. "\\n")
  vim.cmd("cquit 1")
end
eq(vim.g.missing, {{}}, "spell files Neovim wanted to download")
vim.cmd("qa!")
""")
            result = subprocess.run(
                [editor, "--headless", "-i", "NONE", "-n", "-u", str(init), "-S", str(script)],
                env=env, capture_output=True, text=True, timeout=60)
            if result.returncode:
                raise AssertionError(result.stdout + result.stderr)

        # Both languages resolve from the runtime path, with regions.
        run("""
eq(vim.opt.spelllang:get(), {"en_us", "de_de"}, "spelllang")
eq(vim.fn.spellbadword("Straße Häuser Kaffeetasse house"), {"", ""}, "known words")
eq(vim.fn.spellbadword("Strase"), {"Strase", "bad"}, "German typo")
eq(vim.fn.spellbadword("Strasse"), {"Strasse", "local"}, "Swiss spelling")
eq(vim.fn.spellbadword("colour"), {"colour", "local"}, "British spelling")
assert(vim.list_contains(vim.fn.spellsuggest("Strase", 5), "Straße"), "German suggestion")
""")

        # Markdown: prose is checked; code, URLs and wikilinks are not.
        run("""
open("note.md")
eq(vim.bo.filetype, "markdown", "filetype")
assert(vim.wo.spell, "markdown spell")
assert(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()], "markdown highlighter")
eq(bad(true), {"Teh", "Strase"}, "markdown mistakes")
eq(bad(false), {"Teh", "Strase", "colour", "Strasse"}, "markdown mistakes and regional words")
""")

        # A Jujutsu description: subject and body are prose, the generated
        # lines and a conventional prefix are not.
        run("""
open("editor.jjdescription")
eq(vim.bo.filetype, "jjdescription", "filetype")
assert(vim.wo.spell, "jjdescription spell")
assert(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()], "jjdescription highlighter")
eq(bad(true), {"Chek", "descriptons", "bodi", "commment"}, "description mistakes")
""")

        # Git's commit template keeps its comment lines out of the check.
        run("""
open("COMMIT_EDITMSG")
eq(vim.bo.filetype, "gitcommit", "filetype")
assert(vim.wo.spell, "gitcommit spell")
eq(bad(true), {"teh"}, "commit message mistakes")
""")

        # Source code is not prose, and leaving it does not leak into it.
        run("""
open("note.md")
open("code.lua")
eq(vim.bo.filetype, "lua", "filetype")
assert(not vim.wo.spell, "code must not be spell checked")
""")

        # zg teaches a word into private data, which a later session reads.
        (files / "words.txt").write_text("Seele runs Hyprland.\n")
        run("""
open("words.txt")
eq(bad(true), {"Hyprland"}, "unknown word")
vim.cmd("normal! zg")
eq(bad(true), {}, "after zg")
""")
        personal = root / "data" / "nvim" / "spell" / "personal.utf-8.add"
        assert personal.read_text() == "Hyprland\n", personal.read_text()
        assert personal.parent.stat().st_mode & 0o777 == 0o700
        run("""
open("words.txt")
eq(bad(true), {}, "taught word in a new session")
""")
        after_files = sorted(p.relative_to(runtime) for p in runtime.rglob("*"))
        assert after_files == before, f"runtime path was written: {after_files}"

    print(f"Passed {count} Neovim sessions.")


if __name__ == "__main__":
    main()
