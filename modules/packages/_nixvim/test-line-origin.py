#!/usr/bin/env python3
"""Run the real line-origin popup against throwaway Jujutsu and Git repositories."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent


def marker_free(parent):
    parent = parent.resolve()
    return parent.is_dir() and os.access(parent, os.W_OK) and not any(
        (ancestor / marker).exists()
        for ancestor in (parent, *parent.parents)
        for marker in ('.jj', '.git')
    )


def tree_hashes(root):
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(root.rglob('*')) if p.is_file()}


def main():
    editor = os.environ.get('NVIM') or shutil.which('nvim')
    jj = shutil.which('jj')
    git = shutil.which('git')
    if not (editor and jj and git):
        raise SystemExit('Neovim (or NVIM), jj and git are required')
    candidates = [os.environ.get('XDG_RUNTIME_DIR'), '/dev/shm', tempfile.gettempdir(), Path.home()]
    base = next((Path(path) for path in candidates if path and marker_free(Path(path))), None)
    if base is None:
        raise SystemExit('No writable temporary directory outside a repository marker')
    with tempfile.TemporaryDirectory(prefix='seele-line-origin-', dir=base) as temp:
        root = Path(temp)
        home = root / 'home'
        home.mkdir()
        (root / 'jj.toml').write_text('[ui]\npaginate = "auto"\ncolor = "always"\n')
        clean = {k: v for k, v in os.environ.items() if not k.startswith(('GIT_', 'JJ_'))}
        common = dict(clean, HOME=str(home), XDG_CONFIG_HOME=str(root / 'config'),
                      XDG_STATE_HOME=str(root / 'state'), XDG_DATA_HOME=str(root / 'data'),
                      XDG_CACHE_HOME=str(root / 'cache'), JJ_CONFIG=str(root / 'jj.toml'),
                      GIT_CONFIG_GLOBAL=str(root / 'gitconfig'), GIT_CONFIG_NOSYSTEM='1',
                      PAGER='false', GIT_PAGER='false')
        # A hostile user configuration: pagers and colour must not leak into parsing.
        (root / 'gitconfig').write_text('[color]\n\tui = always\n[core]\n\tpager = false\n'
                                        '[log]\n\tshowSignature = true\n')
        alice = dict(JJ_USER='Alice Example', JJ_EMAIL='alice@example.com',
                     JJ_TIMESTAMP='2024-01-02T03:04:05+01:00',
                     GIT_AUTHOR_NAME='Alice Example', GIT_AUTHOR_EMAIL='alice@example.com',
                     GIT_AUTHOR_DATE='2024-01-02T03:04:05+01:00',
                     GIT_COMMITTER_NAME='Alice Example', GIT_COMMITTER_EMAIL='alice@example.com',
                     GIT_COMMITTER_DATE='2024-01-02T03:04:05+01:00')
        bob = dict(JJ_USER='Bob Builder', JJ_EMAIL='bob@example.com',
                   JJ_TIMESTAMP='2024-03-04T05:06:07-05:00',
                   GIT_AUTHOR_NAME='Bob Builder', GIT_AUTHOR_EMAIL='bob@example.com',
                   GIT_AUTHOR_DATE='2024-03-04T05:06:07-05:00',
                   GIT_COMMITTER_NAME='Bob Builder', GIT_COMMITTER_EMAIL='bob@example.com',
                   GIT_COMMITTER_DATE='2024-03-04T05:06:07-05:00')

        def run(argv, cwd, who):
            return subprocess.run(argv, cwd=cwd, env=dict(common, **who), check=True,
                                  capture_output=True, text=True).stdout

        # Jujutsu: two described changes and a working-copy change, then a save
        # jj has not recorded yet, so the popup must not snapshot to see it.
        jjrepo = root / 'jj repo'
        jjrepo.mkdir()
        run([jj, 'git', 'init', '--quiet'], jjrepo, alice)
        story = jjrepo / 'story.txt'
        story.write_text('alpha\nbeta\ngamma\ndelta\n')
        run([jj, 'describe', '--quiet', '-m', 'Add story\n\nWhy: the first draft.'], jjrepo, alice)
        run([jj, 'new', '--quiet'], jjrepo, bob)
        story.write_text('alpha\nBETA\ngamma\ndelta\n')
        run([jj, 'describe', '--quiet', '-m', 'Rewrite beta\n\nBeta needed a capital.'], jjrepo, bob)
        run([jj, 'new', '--quiet'], jjrepo, alice)
        story.write_text('alpha\nBETA\ngamma\ndelta\nepsilon\n')
        run([jj, 'describe', '--quiet', '-m', 'Work in progress'], jjrepo, alice)
        story.write_text('alpha\nBETA\ngamma\ndelta\nepsilon\nzeta\n')

        def jj_ids(rev):
            out = run([jj, '--ignore-working-copy', '--no-pager', '--color', 'never', 'log', '--no-graph',
                       '-r', rev, '-T', 'change_id ++ " " ++ change_id.shortest(8) ++ " "'
                       ' ++ commit_id ++ " " ++ commit_id.shortest(8)'], jjrepo, alice)
            change, change_short, commit, commit_short = out.split()
            return dict(change=change, short=change_short + ' ' + commit_short, commit=commit)

        def operations():
            return run([jj, '--ignore-working-copy', 'op', 'log', '--no-graph', '-T', 'id ++ "\\n"'],
                       jjrepo, alice)

        # A Jujutsu repository without a colocated Git directory.
        native = root / 'native jj'
        native.mkdir()
        run([jj, 'git', 'init', '--quiet', '--no-colocate'], native, bob)
        assert not (native / '.git').exists()
        (native / 'solo.txt').write_text('only line\n')
        run([jj, 'describe', '--quiet', '-m', 'Solo'], native, bob)
        native_short = run([jj, '--ignore-working-copy', '--color', 'never', 'log', '--no-graph', '-r', '@', '-T',
                            'change_id.shortest(8) ++ " " ++ commit_id.shortest(8)'], native, bob)

        # Git: two commits and a saved but uncommitted line.
        gitrepo = root / 'git repo'
        gitrepo.mkdir()
        run([git, 'init', '--quiet'], gitrepo, alice)
        notes = gitrepo / 'notes.txt'
        notes.write_text('one\ntwo\nthree\n')
        run([git, 'add', 'notes.txt'], gitrepo, alice)
        run([git, 'commit', '--quiet', '-m', 'Add notes\n\nBecause lists help.'], gitrepo, alice)
        notes.write_text('one\nTWO\nthree\n')
        run([git, 'commit', '--quiet', '-am', 'Shout two\n\nTwo deserves it.'], gitrepo, bob)
        notes.write_text('one\nTWO\nthree\nfour\n')
        (gitrepo / 'untracked.txt').write_text('loose\n')

        def git_ids(rev):
            full, short = run([git, 'log', '-1', '--format=%H %h', rev], gitrepo, alice).split()
            return dict(change=full, short=short, commit=full)

        outside = root / 'outside'
        outside.mkdir()
        (outside / 'plain.txt').write_text('no history here\n')
        expect = {
            'jj': {'add': jj_ids('@--'), 'rewrite': jj_ids('@-'), 'wc': jj_ids('@'),
                   'story': str(story), 'root': str(jjrepo)},
            'git': {'add': git_ids('HEAD~'), 'shout': git_ids('HEAD'),
                    'notes': str(notes), 'untracked': str(gitrepo / 'untracked.txt'), 'root': str(gitrepo)},
            'native': {'file': str(native / 'solo.txt'), 'short': native_short},
            'outside': str(outside / 'plain.txt'),
            'unsaved': str(outside / 'never-saved.txt'),
        }
        (root / 'expect.json').write_text(json.dumps(expect))
        before_operations = operations()
        before_git = tree_hashes(gitrepo / '.git')
        before_colocated = tree_hashes(jjrepo / '.git')
        before_story = story.read_bytes()

        script = root / 'test.lua'
        script.write_text(LUA)
        env = dict(common, TEST_EXPECT=str(root / 'expect.json'),
                   TEST_MODULE=str(HERE / 'line-origin.lua'))
        result = subprocess.run([editor, '--headless', '-u', 'NONE', '-i', 'NONE', '-n', '-l', str(script)],
                                cwd=root, env=env, capture_output=True, text=True, timeout=120)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        print(result.stdout, end='')
        assert operations() == before_operations, 'Annotating recorded a jj operation'
        assert tree_hashes(gitrepo / '.git') == before_git, 'Annotating changed the Git directory'
        assert tree_hashes(jjrepo / '.git') == before_colocated, 'Annotating changed the colocated Git directory'
        assert story.read_bytes() == before_story, 'Annotating changed the saved file'
        print('Line origin: jj and Git popups, ranges, unsaved lines, parents, actions and argv checks passed')


LUA = r'''
local api = vim.api
local expect = vim.json.decode(io.open(vim.env.TEST_EXPECT):read("*a"))
local function eq(a, b, message)
  assert(vim.deep_equal(a, b), (message or "") .. "\n" .. vim.inspect(a) .. "\n~=\n" .. vim.inspect(b))
end
local messages, calls, finished = {}, {}, 0
vim.notify = function(message, level) messages[#messages + 1] = { message, level } end
local real_system = vim.system
vim.system = function(argv, opts, on_exit)
  calls[#calls + 1] = { argv = vim.deepcopy(argv), cwd = opts.cwd, env = opts.env, stdin = opts.stdin }
  return real_system(argv, opts, function(result)
    on_exit(result)
    -- Queued behind the module's own scheduled continuation, which may start
    -- the next process first.
    vim.schedule(function() finished = finished + 1 end)
  end)
end
vim.g.mapleader = " "
vim.o.columns, vim.o.lines = 120, 40
local module = dofile(vim.env.TEST_MODULE)
module.setup()

local function keys(text)
  api.nvim_feedkeys(api.nvim_replace_termcodes(text, true, false, true), "x", false)
end
local function floats()
  local found = {}
  for _, win in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_get_config(win).relative ~= "" then found[#found + 1] = win end
  end
  return found
end
local function idle()
  assert(vim.wait(10000, function() return finished == #calls end, 10), "processes did not finish")
end
local function popup()
  idle()
  assert(vim.bo.filetype == "seele-line-origin", "no popup: " .. vim.inspect(messages[#messages]))
  local config = api.nvim_win_get_config(0)
  return api.nvim_buf_get_lines(0, 0, -1, false), config.title[1][1], config.footer[1][1]
end
local function message()
  idle()
  return messages[#messages][1]
end
local function edit(path)
  vim.cmd.edit({ args = { path }, bang = true })
end
local RULE = {}
local function check(lines, wanted)
  eq(#lines, #wanted, table.concat(lines, "\n"))
  for i, pattern in ipairs(wanted) do
    if pattern == RULE then
      assert(lines[i] ~= "" and lines[i]:gsub("─", "") == "", ("line %d %q is not a rule"):format(i, lines[i]))
    elseif type(pattern) == "table" then
      assert(lines[i]:match(pattern[1]), ("line %d %q !~ %q"):format(i, lines[i], pattern[1]))
    else
      eq(lines[i], pattern, "line " .. i)
    end
  end
end
local function date(day) return { "^%d+ [a-z]+s? ago · " .. vim.pesc(day) .. "$" } end

-- Jujutsu ------------------------------------------------------------------
local J = expect.jj
edit(J.story)
local source_win, source_buf = api.nvim_get_current_win(), api.nvim_get_current_buf()
api.nvim_buf_set_lines(0, 0, 1, false, { "ALPHA, unsaved" })
api.nvim_win_set_cursor(0, { 2, 0 })
keys(" b")
local lines, title, footer = popup()
eq(title, " Line 2 ")
eq(footer, " y copy id  ⏎/d diff  p parent  q close ")
check(lines, {
  J.rewrite.short .. "  Bob Builder <bob@example.com>",
  date("2024-03-04 05:06 -05:00"),
  "",
  "Rewrite beta",
  "",
  "Beta needed a capital.",
})
-- The short id is highlighted as jj does: unique prefix and dimmed rest.
local marks = api.nvim_buf_get_extmarks(0, -1, { 0, 0 }, { 0, -1 }, { details = true })
eq(marks[1][4].hl_group, "SeeleLineOriginChange")
eq(marks[1][3], 0)
-- Exact argv: no shell, no pager, no colour, and no working-copy snapshot.
eq(calls[1].argv, { "jj", "--no-pager", "--color", "never", "--ignore-working-copy", "file", "annotate",
  "-r", "@", "-T", 'commit.commit_id() ++ " " ++ original_line_number ++ " " ++ content', "--", "story.txt" })
eq(calls[1].cwd, J.root)
eq(vim.list_slice(calls[2].argv, 1, 7), { "jj", "--no-pager", "--color", "never", "--ignore-working-copy",
  "log", "--no-graph" })
eq(calls[2].argv[9], J.rewrite.commit)

-- y copies the stable change id.
keys("y")
eq(vim.fn.getreg('"'), J.rewrite.change)
assert(message():find("Copied " .. J.rewrite.change, 1, true))

-- p steps to the version the change replaced.
keys("p")
lines, title = popup()
eq(title, " Before " .. J.rewrite.short:sub(1, 8) .. " · line 2 ")
check(lines, {
  J.add.short .. "  Alice Example <alice@example.com>",
  date("2024-01-02 03:04 +01:00"),
  "replaced by " .. J.rewrite.short:sub(1, 8),
  "",
  "Add story",
  "",
  "Why: the first draft.",
})
eq(calls[#calls - 2].argv, { "jj", "--no-pager", "--color", "never", "--ignore-working-copy", "file", "annotate",
  "-r", J.add.commit, "-T", 'commit.commit_id() ++ " " ++ original_line_number ++ " " ++ content', "--", "story.txt" })
eq(calls[#calls - 1].argv, { "jj", "--no-pager", "--color", "never", "--ignore-working-copy", "file", "show",
  "-r", J.rewrite.commit, "-T", "", "--", 'root-file:"story.txt"' })
-- The first change has nothing before it.
local count = #messages
keys("p")
idle()
eq(#messages, count + 1)
assert(messages[#messages][1]:find("introduced this file", 1, true), messages[#messages][1])

-- Escape closes and returns focus.
keys("<Esc>")
eq(api.nvim_get_current_win(), source_win)
eq(#floats(), 0)

-- A visual range groups lines by change, in order, and marks unsaved and
-- not-yet-recorded lines instead of guessing.
keys("ggVG b")
lines, title = popup()
eq(title, " Lines 1–6 ")
-- Rules span the popup.
eq(vim.fn.strdisplaywidth(lines[4]), api.nvim_win_get_width(0))
check(lines, {
  "Not saved yet",
  "Changed in this buffer since the last save; no change records it yet.",
  "Line 1",
  RULE,
  J.rewrite.short .. "  Bob Builder <bob@example.com>",
  date("2024-03-04 05:06 -05:00"),
  "Line 2",
  "",
  "Rewrite beta",
  "",
  "Beta needed a capital.",
  RULE,
  J.add.short .. "  Alice Example <alice@example.com>",
  date("2024-01-02 03:04 +01:00"),
  "Lines 3–4",
  "",
  "Add story",
  "",
  "Why: the first draft.",
  RULE,
  J.wc.short .. "  Alice Example <alice@example.com>",
  date("2024-01-02 03:04 +01:00"),
  "Lines 5–6 · working-copy change · includes saved lines jj has not recorded yet",
  "",
  "Work in progress",
})
-- Actions follow the section under the cursor; unsaved lines have no id.
api.nvim_win_set_cursor(0, { 2, 0 })
keys("y")
assert(message():find("not recorded", 1, true))
eq(vim.fn.getreg('"'), J.rewrite.change)
api.nvim_win_set_cursor(0, { 21, 0 })
keys("y")
eq(vim.fn.getreg('"'), J.wc.change)

-- d opens the change's diff read-only, at this file.
api.nvim_win_set_cursor(0, { 14, 0 })
keys("d")
idle()
eq(api.nvim_buf_get_name(0), "line-origin://" .. J.add.short:sub(1, 8))
eq({ vim.bo.modifiable, vim.bo.readonly, vim.bo.buftype, vim.bo.filetype }, { false, true, "nofile", "diff" })
local diff = api.nvim_buf_get_lines(0, 0, -1, false)
assert(table.concat(diff, "\n"):find("Add story", 1, true))
eq(diff[api.nvim_win_get_cursor(0)[1]], "diff --git a/story.txt b/story.txt")
assert(not table.concat(diff, "\n"):find("\27", 1, true), "colour escape leaked into the diff")
eq(calls[#calls].argv, { "jj", "--no-pager", "--color", "never", "--ignore-working-copy", "--config",
  "ui.show-cryptographic-signatures=false", "show", "--git", "-r", J.add.commit })
keys("q")
eq(api.nvim_get_current_buf(), source_buf)

-- Stale results are discarded: an edit while annotating, then a second request.
api.nvim_win_set_cursor(0, { 3, 0 })
count = #messages
module.show()
api.nvim_buf_set_lines(0, 2, 3, false, { "gamma, edited while annotating" })
idle()
eq(#floats(), 0)
eq(#messages, count)
vim.cmd("silent undo")
module.show(2, 2)
module.show(4, 4)
lines, title = popup()
eq(title, " Line 4 ")
eq(#floats(), 1)
eq(lines[1], J.add.short .. "  Alice Example <alice@example.com>")
keys("q")

-- A Jujutsu repository without colocated Git reads the same way.
edit(expect.native.file)
keys(" b")
lines = popup()
eq(lines[1], expect.native.short .. "  Bob Builder <bob@example.com>")
eq(lines[3], "working-copy change")
eq(calls[#calls].cwd, vim.fs.dirname(expect.native.file))
keys("q")

-- Theme switches clear highlights; the links come back with the colorscheme.
vim.cmd("highlight clear")
vim.api.nvim_exec_autocmds("ColorScheme", {})
eq(api.nvim_get_hl(0, { name = "SeeleLineOriginChange" }).link, "Special")
eq(api.nvim_get_hl(0, { name = "SeeleLineOriginUnsaved" }).link, "DiagnosticWarn")

-- Git ----------------------------------------------------------------------
local G = expect.git
edit(G.notes)
api.nvim_buf_set_lines(0, 0, 1, false, { "ONE, unsaved" })
keys("ggVG b")
lines, title = popup()
eq(title, " Lines 1–4 ")
check(lines, {
  "Not saved yet",
  "Changed in this buffer since the last save; no change records it yet.",
  "Line 1",
  RULE,
  G.shout.short .. "  Bob Builder <bob@example.com>",
  date("2024-03-04 05:06 -05:00"),
  "Line 2",
  "",
  "Shout two",
  "",
  "Two deserves it.",
  RULE,
  G.add.short .. "  Alice Example <alice@example.com>",
  date("2024-01-02 03:04 +01:00"),
  "Line 3",
  "",
  "Add notes",
  "",
  "Because lists help.",
  RULE,
  "Not committed yet",
  "Saved, but no Git commit contains it yet.",
  "Line 4",
})
local blame
for _, call in ipairs(calls) do
  if call.argv[1] == "git" and vim.tbl_contains(call.argv, "blame") then blame = blame or call end
end
eq(blame.argv, { "git", "--no-pager", "-c", "color.ui=never", "-c", "log.showSignature=false",
  "-c", "core.quotePath=false", "blame", "--porcelain", "--contents", "-", "--", "notes.txt" })
eq(blame.env, { GIT_OPTIONAL_LOCKS = "0", GIT_TERMINAL_PROMPT = "0" })
eq(blame.stdin, "one\nTWO\nthree\nfour\n")
api.nvim_win_set_cursor(0, { 5, 0 })
keys("y")
eq(vim.fn.getreg('"'), G.shout.change)
keys("p")
lines, title = popup()
eq(title, " Before " .. G.shout.short .. " · line 2 ")
check(lines, {
  G.add.short .. "  Alice Example <alice@example.com>",
  date("2024-01-02 03:04 +01:00"),
  "replaced by " .. G.shout.short,
  "",
  "Add notes",
  "",
  "Because lists help.",
})
keys("p")
assert(message():find("introduced this file", 1, true))
keys("d")
idle()
eq(vim.bo.filetype, "git")
diff = api.nvim_buf_get_lines(0, 0, -1, false)
eq(diff[1], "commit " .. G.add.commit)
eq(diff[api.nvim_win_get_cursor(0)[1]], "diff --git a/notes.txt b/notes.txt")
keys("q")

-- Refusals say plainly what is missing.
edit(G.notes)
local disk = io.open(G.notes, "rb"):read("*a")
local file = io.open(G.notes, "wb"); file:write("changed elsewhere\n" .. disk); file:close()
keys(" b")
eq(message(), "The file changed on disk since it was loaded; reload it first")
file = io.open(G.notes, "wb"); file:write(disk); file:close()
edit(G.untracked)
keys(" b")
eq(message(), "untracked.txt is not tracked by Git")
edit(expect.outside)
keys(" b")
eq(message(), "This file is not in a Jujutsu or Git repository")
edit(expect.unsaved)
keys(" b")
eq(message(), "This file has not been saved yet, so no change contains it")
vim.cmd.enew()
keys(" b")
eq(message(), "Name and save this file before asking where its lines came from")

-- Every process was an argv list for jj or git: nothing went through a shell.
for _, call in ipairs(calls) do
  assert(type(call.argv) == "table", "command is not an argv list")
  assert(call.argv[1] == "jj" or call.argv[1] == "git", call.argv[1])
  for _, arg in ipairs(call.argv) do assert(type(arg) == "string") end
  assert(vim.tbl_contains(call.argv, "--no-pager"))
end
vim.cmd("qa!")
'''

if __name__ == '__main__':
    main()
