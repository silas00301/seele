-- Show where lines came from. Reads history and the saved file; never records,
-- snapshots or rewrites anything, and never runs a command through a shell.
local M = {}
local api, uv = vim.api, vim.uv

local title = "Line origin"
local timeout = 15000
local annotate_limit = 8 * 1024 * 1024
local metadata_limit = 1024 * 1024
local show_limit = 4 * 1024 * 1024
local file_limit = 2 * 1024 * 1024
local line_limit = 20000
local section_limit = 50
local null_commit = string.rep("0", 40)
local hint = " y copy id  ⏎/d diff  p parent  q close "
local namespace = api.nvim_create_namespace("seele_line_origin")
-- Every request, action and popup takes a number; a result for an older number is stale.
local generation = 0
local popup

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.WARN, { title = title })
end

local function highlights()
  -- Links into the active colorscheme survive every preset the theme switcher applies.
  for name, link in pairs({
    SeeleLineOriginChange = "Special",
    SeeleLineOriginCommit = "Identifier",
    SeeleLineOriginRest = "Comment",
    SeeleLineOriginAuthor = "Title",
    SeeleLineOriginDate = "Comment",
    SeeleLineOriginSubject = "Title",
    SeeleLineOriginNote = "DiagnosticHint",
    SeeleLineOriginUnsaved = "DiagnosticWarn",
    SeeleLineOriginRule = "FloatBorder",
  }) do
    api.nvim_set_hl(0, name, { link = link, default = true })
  end
end

-- Processes ----------------------------------------------------------------

local function first_error(stderr)
  for line in (stderr or ""):gmatch("[^\r\n]+") do
    line = line:gsub("%c", ""):gsub("^%s*[Ee]rror:%s*", ""):gsub("^fatal:%s*", "")
    if line ~= "" then return line end
  end
end

-- Runs argv directly with bounded stdout and a deadline; `done` receives either
-- the bytes or a message describing the failure.
local function run(argv, opts, done)
  local chunks, size, overflow = {}, 0, false
  local errors, error_size = {}, 0
  local process
  local ok, started = pcall(vim.system, argv, {
    cwd = opts.cwd,
    env = opts.env,
    stdin = opts.stdin or false,
    text = false,
    timeout = timeout,
    stdout = function(_, data)
      if not data or overflow then return end
      size = size + #data
      if size > opts.limit then
        overflow = true
        if process then process:kill(15) end
        return
      end
      chunks[#chunks + 1] = data
    end,
    stderr = function(_, data)
      if data and error_size < 8192 then
        errors[#errors + 1], error_size = data, error_size + #data
      end
    end,
  }, function(result)
    vim.schedule(function()
      local stdout, stderr = table.concat(chunks), table.concat(errors)
      if overflow then
        done(nil, argv[1] .. " output exceeded its size limit", stdout)
      elseif result.code == 124 then
        done(nil, argv[1] .. " timed out after " .. timeout / 1000 .. " s")
      elseif result.code ~= 0 or result.signal ~= 0 then
        done(nil, first_error(stderr) or (argv[1] .. " failed with status " .. result.code))
      else
        done(stdout)
      end
    end)
  end)
  if ok then
    process = started
  else
    vim.schedule(function() done(nil, "Cannot start " .. argv[1] .. ": " .. tostring(started)) end)
  end
end

-- Line mapping --------------------------------------------------------------

local function split(bytes)
  if bytes == "" then return {} end
  if bytes:sub(-1) == "\n" then bytes = bytes:sub(1, -2) end
  return vim.split(bytes, "\n", { plain = true })
end

local function joined(lines)
  local normalized = {}
  for i, line in ipairs(lines) do normalized[i] = (line:gsub("\r$", "")) end
  return #normalized == 0 and "" or table.concat(normalized, "\n") .. "\n"
end

-- For every line of `new`, the unchanged line of `old` it came from, or nil.
local function line_map(old, new)
  local hunks = vim.diff(joined(old), joined(new), { result_type = "indices", algorithm = "histogram" })
  local map, o, n = {}, 1, 1
  for _, hunk in ipairs(hunks) do
    local old_start, old_count, new_start, new_count = hunk[1], hunk[2], hunk[3], hunk[4]
    local last_unchanged = new_count == 0 and new_start or new_start - 1
    while n <= last_unchanged do
      map[n], n, o = o, n + 1, o + 1
    end
    n = n + new_count
    o = (old_count == 0 and old_start or old_start - 1) + 1 + old_count
  end
  while n <= #new do
    map[n], n, o = o, n + 1, o + 1
  end
  return map, hunks
end

-- Where a line of `new` stood in `old`: the line it replaced or the one it follows.
local function anchor(map, hunks, line)
  if map[line] then return map[line], "unchanged" end
  for _, hunk in ipairs(hunks) do
    local old_start, old_count, new_start, new_count = hunk[1], hunk[2], hunk[3], hunk[4]
    if new_count > 0 and line >= new_start and line < new_start + new_count then
      if old_count > 0 then return old_start + math.min(line - new_start, old_count - 1), "replaced" end
      if old_start == 0 then return 1, "before" end
      return old_start, "after"
    end
  end
end

-- Files and repositories ----------------------------------------------------

local function read_file(path)
  local stat = uv.fs_stat(path)
  if not stat then return nil end
  if stat.type ~= "file" then return nil, "This path is not a regular file" end
  if stat.size > file_limit then return nil, "The saved file exceeds the 2 MiB annotation limit" end
  local fd, err = uv.fs_open(path, uv.constants.O_RDONLY + uv.constants.O_NONBLOCK, 0)
  if not fd then return nil, "Cannot read the saved file: " .. tostring(err) end
  local chunks, size = {}, 0
  while size <= file_limit do
    local chunk = uv.fs_read(fd, math.min(65536, file_limit + 1 - size), size)
    if not chunk or #chunk == 0 then break end
    chunks[#chunks + 1], size = chunk, size + #chunk
  end
  uv.fs_close(fd)
  if size > file_limit then return nil, "The saved file exceeds the 2 MiB annotation limit" end
  return table.concat(chunks)
end

-- The nearest marker wins; Jujutsu is preferred at a colocated root.
local function repository(directory)
  while directory do
    local jj = uv.fs_stat(directory .. "/.jj")
    local git = uv.fs_stat(directory .. "/.git")
    local has_git = git and (git.type == "directory" or git.type == "file")
    if jj and jj.type == "directory" then return directory, "jj", has_git end
    if has_git then return directory, "git", false end
    local parent = vim.fs.dirname(directory)
    if parent == directory then break end
    directory = parent
  end
end

local function jj_literal(text)
  return '"' .. text:gsub('[%c"\\]', function(c) return ("\\x%02x"):format(c:byte()) end) .. '"'
end

-- Backends ------------------------------------------------------------------
-- annotate(rev, path, stdin) gives { entries = { {id, line, path} }, lines = {...} };
-- rev nil means the working copy as it was last recorded (jj) or the saved bytes (git).

local jj, git = {}, {}

-- --ignore-working-copy: a read action must not snapshot, which would write a
-- new working-copy commit and operation and could auto-track files.
local function jj_argv(...)
  return { "jj", "--no-pager", "--color", "never", "--ignore-working-copy", ... }
end

function jj.annotate(ctx, rev, path, done)
  local argv = jj_argv("file", "annotate", "-r", rev or "@",
    "-T", 'commit.commit_id() ++ " " ++ original_line_number ++ " " ++ content', "--", path)
  run(argv, { cwd = ctx.root, limit = annotate_limit }, function(stdout, err)
    if not stdout then
      if err and err:find("No such path", 1, true) then err = "missing" end
      return done(nil, err)
    end
    local result = { entries = {}, lines = {} }
    for _, record in ipairs(split(stdout)) do
      local id, line, content = record:match("^(%x+) (%d+) (.*)$")
      if not id then return done(nil, "Unexpected jj file annotate output") end
      result.entries[#result.entries + 1] = { id = id, line = tonumber(line), path = path }
      result.lines[#result.lines + 1] = content
    end
    done(result)
  end)
end

local jj_metadata_template = table.concat({
  '"[" ++ json(commit_id)',
  "json(change_id)",
  "json(change_id.shortest(8).prefix())",
  "json(change_id.shortest(8).rest())",
  "json(commit_id.shortest(8).prefix())",
  "json(commit_id.shortest(8).rest())",
  "json(author.name())",
  "json(author.email())",
  'json(author.timestamp().format("%s %z"))',
  "json(description)",
  "json(parents.map(|p| p.commit_id()))",
  "json(current_working_copy)",
  'json(root) ++ "]\\n"',
}, ' ++ "," ++ ')

function jj.metadata(ctx, ids, done)
  local revset = table.concat(ids, " | ")
  run(jj_argv("log", "--no-graph", "-r", revset, "-T", jj_metadata_template),
    { cwd = ctx.root, limit = metadata_limit }, function(stdout, err)
      if not stdout then return done(nil, err) end
      local result = {}
      for _, record in ipairs(split(stdout)) do
        local ok, v = pcall(vim.json.decode, record)
        if not ok or type(v) ~= "table" or #v ~= 13 then return done(nil, "Unexpected jj log output") end
        result[v[1]] = {
          id = v[1], copy = v[2], label = { { v[3], "SeeleLineOriginChange" }, { v[4], "SeeleLineOriginRest" },
            { " " }, { v[5], "SeeleLineOriginCommit" }, { v[6], "SeeleLineOriginRest" } },
          short = v[3] .. v[4], author = v[7], email = v[8], date = v[9], description = v[10],
          parent = v[11][1], working_copy = v[12], root = v[13],
        }
        if v[12] then result["@"] = result[v[1]] end
      end
      done(result)
    end)
end

function jj.file(ctx, rev, path, done)
  run(jj_argv("file", "show", "-r", rev, "-T", "", "--", "root-file:" .. jj_literal(path)),
    { cwd = ctx.root, limit = file_limit + 1 }, done)
end

function jj.parent(meta)
  if meta.parent and meta.parent ~= null_commit then return meta.parent end
end

function jj.show(ctx, meta, done)
  run(jj_argv("--config", "ui.show-cryptographic-signatures=false", "show", "--git", "-r", meta.id),
    { cwd = ctx.root, limit = show_limit }, done)
end

-- Optional locks off: git may otherwise refresh the index during a read.
local git_env = { GIT_OPTIONAL_LOCKS = "0", GIT_TERMINAL_PROMPT = "0" }

local function git_argv(...)
  return { "git", "--no-pager", "-c", "color.ui=never", "-c", "log.showSignature=false",
    "-c", "core.quotePath=false", ... }
end

function git.annotate(ctx, rev, path, done, stdin)
  local argv = rev and git_argv("blame", "--porcelain", rev, "--", path)
    or git_argv("blame", "--porcelain", "--contents", "-", "--", path)
  run(argv, { cwd = ctx.root, limit = annotate_limit, env = git_env, stdin = stdin },
    function(stdout, err)
      if not stdout then
        if err and err:find("no such path", 1, true) then err = "missing" end
        return done(nil, err)
      end
      local result, commits, current = { entries = {}, lines = {} }, {}, nil
      for _, record in ipairs(split(stdout)) do
        if record:sub(1, 1) == "\t" then
          if not current then return done(nil, "Unexpected git blame output") end
          local info = commits[current.id]
          current.path = info.filename or path
          result.entries[#result.entries + 1] = current
          result.lines[#result.lines + 1] = record:sub(2)
          current = nil
        else
          local id, line = record:match("^(%x+) (%d+) %d+")
          if id and (#id == 40 or #id == 64) then
            current = { id = id, line = tonumber(line) }
            commits[id] = commits[id] or {}
          elseif current then
            local key, value = record:match("^(%S+) ?(.*)$")
            if key == "filename" then
              commits[current.id].filename = value
            elseif key == "previous" then
              local previous, previous_path = value:match("^(%x+) (.*)$")
              commits[current.id].previous = { id = previous, path = previous_path }
            end
          end
        end
      end
      for _, entry in ipairs(result.entries) do
        entry.previous = commits[entry.id].previous
        if entry.id:match("^0+$") then entry.id = "uncommitted" end
      end
      done(result)
    end)
end

function git.metadata(ctx, ids, done)
  local argv = git_argv("log", "--no-walk=unsorted", "-z", "--date=raw",
    "--format=%H%x1f%h%x1f%aN%x1f%aE%x1f%ad%x1f%P%x1f%B")
  vim.list_extend(argv, ids)
  argv[#argv + 1] = "--"
  run(argv, { cwd = ctx.root, limit = metadata_limit, env = git_env }, function(stdout, err)
    if not stdout then return done(nil, err) end
    local result = {}
    for record in stdout:gmatch("[^%z]+") do
      local fields = vim.split((record:gsub("^\n", "")), "\31", { plain = true })
      if #fields < 7 then return done(nil, "Unexpected git log output") end
      local body = table.concat(fields, "\31", 7)
      result[fields[1]] = {
        id = fields[1], copy = fields[1], label = { { fields[2], "SeeleLineOriginCommit" } },
        short = fields[2], author = fields[3], email = fields[4], date = fields[5], description = body,
        parent = vim.split(fields[6], " ", { trimempty = true })[1],
      }
    end
    done(result)
  end)
end

function git.file(ctx, rev, path, done)
  run(git_argv("cat-file", "blob", rev .. ":" .. path), { cwd = ctx.root, limit = file_limit + 1, env = git_env }, done)
end

function git.parent(_, entry)
  return entry.previous and entry.previous.id, entry.previous and entry.previous.path
end

function git.show(ctx, meta, done)
  run(git_argv("show", "--no-ext-diff", "--no-color", meta.id, "--"),
    { cwd = ctx.root, limit = show_limit, env = git_env }, done)
end

-- Presentation --------------------------------------------------------------

local function ago(epoch)
  local seconds = os.time() - epoch
  if seconds < 0 then return "in the future" end
  for _, unit in ipairs({ { "year", 31536000 }, { "month", 2592000 }, { "week", 604800 },
    { "day", 86400 }, { "hour", 3600 }, { "minute", 60 } }) do
    local count = math.floor(seconds / unit[2])
    if count >= 1 then return ("%d %s%s ago"):format(count, unit[1], count == 1 and "" or "s") end
  end
  return "just now"
end

local function dates(raw)
  local epoch, sign, hours, minutes = (raw or ""):match("^(%-?%d+) ([+-])(%d%d)(%d%d)$")
  if not epoch then return "unknown date" end
  local offset = (tonumber(hours) * 3600 + tonumber(minutes) * 60) * (sign == "-" and -1 or 1)
  return ("%s · %s %s%s:%s"):format(ago(tonumber(epoch)),
    os.date("!%Y-%m-%d %H:%M", tonumber(epoch) + offset), sign, hours, minutes)
end

local function ranges(lines)
  local parts, i = {}, 1
  while i <= #lines do
    local j = i
    while j < #lines and lines[j + 1] == lines[j] + 1 do j = j + 1 end
    parts[#parts + 1] = i == j and tostring(lines[i]) or (lines[i] .. "–" .. lines[j])
    i = j + 1
  end
  return (#lines == 1 and "Line " or "Lines ") .. table.concat(parts, ", ")
end

local function clean(text)
  -- Keep tabs; strip controls that could forge or hide interface text.
  return (text:gsub("[%z\1-\8\11-\31\127]", ""))
end

-- Renders sections into rows of { text, highlight } segments.
local function render(sections, show_lines, width)
  local rows, starts = {}, {}
  local function add(segments) rows[#rows + 1] = segments end
  for index, section in ipairs(sections) do
    if index > 1 then add({ { string.rep("─", width), "SeeleLineOriginRule" } }) end
    starts[index] = #rows
    if section.kind == "unsaved" then
      add({ { "Not saved yet", "SeeleLineOriginUnsaved" } })
      add({ { "Changed in this buffer since the last save; no change records it yet.", "SeeleLineOriginNote" } })
      if show_lines then add({ { ranges(section.lines), "SeeleLineOriginDate" } }) end
    elseif section.kind == "uncommitted" then
      add({ { "Not committed yet", "SeeleLineOriginUnsaved" } })
      add({ { "Saved, but no Git commit contains it yet.", "SeeleLineOriginNote" } })
      if show_lines then add({ { ranges(section.lines), "SeeleLineOriginDate" } }) end
    else
      local meta = section.meta
      local header = vim.deepcopy(meta.label)
      if meta.author ~= "" then
        header[#header + 1] = { "  " .. clean(meta.author), "SeeleLineOriginAuthor" }
        if meta.email ~= "" then header[#header + 1] = { " <" .. clean(meta.email) .. ">", "SeeleLineOriginDate" } end
      end
      add(header)
      add({ { meta.root and "Root of the repository" or dates(meta.date), "SeeleLineOriginDate" } })
      local notes = {}
      if show_lines then notes[#notes + 1] = ranges(section.lines) end
      if meta.working_copy then notes[#notes + 1] = "working-copy change" end
      if section.unrecorded then notes[#notes + 1] = "includes saved lines jj has not recorded yet" end
      if section.note then notes[#notes + 1] = section.note end
      if #notes > 0 then add({ { table.concat(notes, " · "), "SeeleLineOriginNote" } }) end
      add({ { "" } })
      local description = clean((meta.description or ""):gsub("%s+$", ""))
      if description == "" then
        add({ { "(no description set)", "SeeleLineOriginDate" } })
      else
        for i, line in ipairs(vim.split(description, "\n", { plain = true })) do
          add({ { line, i == 1 and "SeeleLineOriginSubject" or nil } })
        end
      end
    end
  end
  return rows, starts
end

local function close()
  local old = popup
  popup = nil
  if old and api.nvim_win_is_valid(old.win) then
    pcall(api.nvim_win_close, old.win, true)
    if api.nvim_win_is_valid(old.origin) then api.nvim_set_current_win(old.origin) end
  end
end

local function fill(state, sections, window_title, show_lines)
  local columns = math.max(20, vim.o.columns - 4)
  local width = vim.fn.strdisplaywidth(hint)
  local rows, starts = render(sections, show_lines, 1)
  for _, row in ipairs(rows) do
    local text = ""
    for _, segment in ipairs(row) do text = text .. segment[1] end
    width = math.max(width, vim.fn.strdisplaywidth(text))
  end
  width = math.min(width, 80, columns)
  rows, starts = render(sections, show_lines, width)
  local lines = {}
  for i, row in ipairs(rows) do
    local text = ""
    for _, segment in ipairs(row) do text = text .. segment[1] end
    lines[i] = text
  end
  vim.bo[state.buf].modifiable = true
  api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  api.nvim_buf_clear_namespace(state.buf, namespace, 0, -1)
  for i, row in ipairs(rows) do
    local col = 0
    for _, segment in ipairs(row) do
      if segment[2] and #segment[1] > 0 then
        api.nvim_buf_set_extmark(state.buf, namespace, i - 1, col,
          { end_col = col + #segment[1], hl_group = segment[2] })
      end
      col = col + #segment[1]
    end
  end
  state.sections, state.starts, state.width = sections, starts, width
  state.title = " " .. window_title .. " "
  return width
end

local function place(state)
  local max_height = math.max(3, vim.o.lines - vim.o.cmdheight - 4)
  local config = { width = state.width, height = 1, title = state.title, title_pos = "left",
    footer = hint, footer_pos = "right" }
  local border = vim.o.winborder
  if border == "" or border == "none" then config.border = "rounded" end
  local position = api.nvim_win_is_valid(state.origin)
    and vim.fn.screenpos(state.origin, state.line, 1) or { row = 0 }
  if position.row > 0 then
    config.relative, config.win, config.bufpos = "win", state.origin, { state.line - 1, 0 }
    state.below = vim.o.lines - vim.o.cmdheight - position.row - 3
    state.above = position.row - 3
  else
    config.relative, config.row, config.col = "editor", 1, math.floor((vim.o.columns - state.width) / 2)
  end
  if state.win and api.nvim_win_is_valid(state.win) then
    api.nvim_win_set_config(state.win, config)
  else
    config.style = "minimal"
    state.win = api.nvim_open_win(state.buf, true, config)
    vim.wo[state.win].wrap = true
    vim.wo[state.win].linebreak = true
    vim.wo[state.win].cursorline = false
  end
  local height = math.min(api.nvim_win_text_height(state.win, {}).all, max_height)
  if config.relative == "win" then
    if height > state.below and state.above > state.below then
      config.anchor, config.row, config.col = "SW", 0, 0
      height = math.min(height, math.max(state.above, 1))
    else
      config.anchor, config.row, config.col = "NW", 1, 0
      height = math.min(height, math.max(state.below, 1))
    end
  end
  config.height = height
  api.nvim_win_set_config(state.win, config)
  api.nvim_win_set_cursor(state.win, { 1, 0 })
end

local function section_at_cursor(state)
  local row = api.nvim_win_get_cursor(state.win)[1] - 1
  local found = state.sections[1]
  for index, start in ipairs(state.starts) do
    if row >= start then found = state.sections[index] end
  end
  return found
end

local function recorded(section)
  if section.kind == "commit" then return section end
  notify("These lines are not recorded in any change yet", vim.log.levels.INFO)
end

local function copy(state)
  local section = recorded(section_at_cursor(state))
  if not section then return end
  local id = section.meta.copy
  vim.fn.setreg('"', id, "v")
  local message = "Copied " .. id
  if vim.fn.has("clipboard") == 1 then
    if pcall(vim.fn.setreg, "+", id, "v") then
      message = message .. " to the unnamed register and clipboard"
    else
      message = message .. " to the unnamed register; clipboard provider failed"
    end
  else
    message = message .. " to the unnamed register"
  end
  notify(message, vim.log.levels.INFO)
end

local function diff(state)
  local section = recorded(section_at_cursor(state))
  if not section then return end
  local ctx, meta = state.ctx, section.meta
  generation = generation + 1
  local token = generation
  close()
  ctx.backend.show(ctx, meta, function(stdout, err, partial)
    if token ~= generation then return end
    if not stdout and not partial then return notify(err) end
    local lines = split(stdout or partial)
    if not stdout then lines[#lines + 1] = "[output truncated at " .. show_limit / 1048576 .. " MiB]" end
    local buf = api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].undolevels = -1
    vim.bo[buf].modeline = false
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = true
    vim.bo[buf].modified = false
    local name = "line-origin://" .. meta.short
    local existing = vim.fn.bufnr("^" .. name .. "$")
    if existing > 0 then api.nvim_buf_delete(existing, { force = true }) end
    api.nvim_buf_set_name(buf, name)
    vim.cmd("tab sbuffer " .. buf)
    vim.bo[buf].filetype = ctx.kind == "git" and "git" or "diff"
    vim.keymap.set("n", "q", function() api.nvim_buf_delete(buf, { force = true }) end,
      { buffer = buf, desc = "Close change diff" })
    local target = "diff --git a/" .. section.path .. " "
    for i, line in ipairs(lines) do
      if line:sub(1, #target) == target then
        api.nvim_win_set_cursor(0, { i, 0 })
        break
      end
    end
  end)
end

local function parent(state)
  local section = recorded(section_at_cursor(state))
  if not section then return end
  local ctx, meta = state.ctx, section.meta
  if not section.origin then
    return notify("jj has not recorded this line yet, so it has no earlier version", vim.log.levels.INFO)
  end
  local rev, path = ctx.backend.parent(meta, section.origin)
  path = path or section.origin.path
  if not rev then
    return notify(meta.short .. " introduced this file; there is no earlier version", vim.log.levels.INFO)
  end
  generation = generation + 1
  local token = generation
  local function live() return token == generation and popup == state and api.nvim_win_is_valid(state.win) end
  ctx.backend.annotate(ctx, rev, path, function(before, err)
    if not live() then return end
    if not before then
      if err == "missing" then
        return notify(path .. " did not exist before " .. meta.short, vim.log.levels.INFO)
      end
      return notify(err)
    end
    ctx.backend.file(ctx, meta.id, section.origin.path, function(bytes, file_err)
      if not live() then return end
      if not bytes then return notify(file_err) end
      local map, hunks = line_map(before.lines, split(bytes))
      local line, relation = anchor(map, hunks, section.origin.line)
      if not line or not before.entries[line] then
        return notify("The file was empty before " .. meta.short, vim.log.levels.INFO)
      end
      local entry = before.entries[line]
      ctx.backend.metadata(ctx, { entry.id }, function(found, meta_err)
        if not live() then return end
        if not found or not found[entry.id] then return notify(meta_err or "Missing change metadata") end
        local note = ({
          replaced = "replaced by " .. meta.short,
          after = "line " .. section.origin.line .. " of " .. meta.short .. " was inserted after it",
          before = "line " .. section.origin.line .. " of " .. meta.short .. " was inserted before it",
        })[relation]
        fill(state, { {
          kind = "commit", meta = found[entry.id], lines = { line }, path = entry.path,
          origin = entry, note = note,
        } }, ("Before %s · line %d"):format(meta.short, line), false)
        place(state)
      end)
    end)
  end)
end

local function open(ctx, sections, window_title, show_lines)
  close()
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].undolevels = -1
  vim.bo[buf].modeline = false
  vim.bo[buf].filetype = "seele-line-origin"
  local state = { ctx = ctx, buf = buf, origin = ctx.win, line = ctx.first }
  fill(state, sections, window_title, show_lines)
  place(state)
  popup = state
  for _, binding in ipairs({
    { "y", copy, "Copy change id" },
    { "<CR>", diff, "Open change diff" },
    { "d", diff, "Open change diff" },
    { "p", parent, "Show the line's previous version" },
    { "q", close, "Close line origin" },
    { "<Esc>", close, "Close line origin" },
  }) do
    local action = binding[2]
    vim.keymap.set("n", binding[1], function() action(state) end, { buffer = buf, nowait = true, desc = binding[3] })
  end
  api.nvim_create_autocmd({ "WinLeave", "BufLeave" }, {
    buffer = buf,
    once = true,
    callback = function() vim.schedule(function() if popup == state then close() end end) end,
  })
end

-- Requests ------------------------------------------------------------------

local function present(ctx, ids, unsaved, unrecorded)
  local wanted, seen = {}, {}
  for line = ctx.first, ctx.last do
    local id = ids[line]
    if id and id ~= "uncommitted" and not seen[id] then
      seen[id] = true
      wanted[#wanted + 1] = id
    end
  end
  local function build(metadata)
    if not ctx.current() then return end
    local sections, by_key = {}, {}
    for line = ctx.first, ctx.last do
      local key, kind, meta = ids[line], "commit", nil
      if unsaved[line] then
        key, kind = "unsaved", "unsaved"
      elseif key == "uncommitted" then
        kind = "uncommitted"
      else
        meta = metadata[key]
        if not meta then return notify("Missing change metadata for line " .. line) end
        key = meta.id
      end
      local section = by_key[key]
      if not section then
        section = { kind = kind, meta = meta, lines = {}, path = ctx.relative }
        by_key[key] = section
        sections[#sections + 1] = section
      end
      section.lines[#section.lines + 1] = line
      if unrecorded[line] then
        section.unrecorded = true
      elseif not section.origin and ctx.origins[line] then
        section.origin = ctx.origins[line]
      end
    end
    local omitted = #sections - section_limit
    if omitted > 0 then
      sections = vim.list_slice(sections, 1, section_limit)
      notify(("Showing the first %d changes; %d more are in the selection"):format(section_limit, omitted),
        vim.log.levels.INFO)
    end
    local window_title = ctx.first == ctx.last and ("Line " .. ctx.first)
      or ("Lines %d–%d"):format(ctx.first, ctx.last)
    open(ctx, sections, window_title, ctx.first ~= ctx.last)
  end
  if #wanted == 0 then return build({}) end
  ctx.backend.metadata(ctx, wanted, function(metadata, err)
    if not ctx.current() then return end
    if not metadata then return notify(err) end
    build(metadata)
  end)
end

local function request(first, last)
  generation = generation + 1
  local token = generation
  close()
  local buf, win = api.nvim_get_current_buf(), api.nvim_get_current_win()
  if vim.bo[buf].buftype ~= "" then return notify("This buffer is not a file") end
  local name = api.nvim_buf_get_name(buf)
  if name == "" then return notify("Name and save this file before asking where its lines came from") end
  local path = uv.fs_realpath(name)
  if not path then return notify("This file has not been saved yet, so no change contains it") end
  local root, kind, colocated = repository(vim.fs.dirname(path))
  if not root then return notify("This file is not in a Jujutsu or Git repository") end
  if kind == "jj" and vim.fn.executable("jj") == 0 then
    if not colocated then return notify("jj is not installed, so this Jujutsu repository cannot be read") end
    kind = "git"
  end
  if kind == "git" and vim.fn.executable("git") == 0 then
    return notify("git is not installed, so this Git repository cannot be read")
  end
  local count = api.nvim_buf_line_count(buf)
  if count > line_limit or api.nvim_buf_get_offset(buf, count) > file_limit then
    return notify("This buffer exceeds the 2 MiB or 20000 line annotation limit")
  end
  local saved, err = read_file(path)
  if not saved then return notify(err or "This file has not been saved yet, so no change contains it") end
  local saved_lines = split(saved)
  -- Compare the buffer with the saved bytes decoded the way the buffer decoded them.
  local decoded = saved:gsub("^\239\187\191", "")
  local encoding = vim.bo[buf].fileencoding
  if encoding ~= "" and encoding ~= "utf-8" then
    local converted = vim.fn.iconv(decoded, encoding, "utf-8")
    if converted ~= "" or decoded == "" then decoded = converted end
  end
  local saved_text = split(decoded)
  local saved_for = line_map(saved_text, api.nvim_buf_get_lines(buf, 0, -1, false))
  if not vim.bo[buf].modified then
    -- Unmodified text that differs from the disk is older than the save, not newer.
    local stale = #saved_text ~= count
    for line = 1, count do stale = stale or saved_for[line] == nil end
    if stale then return notify("The file changed on disk since it was loaded; reload it first") end
  end
  first, last = math.max(1, math.min(first, last)), math.min(count, math.max(first, last))
  local tick = api.nvim_buf_get_changedtick(buf)
  local relative = path:sub(#root + (root == "/" and 1 or 2))
  local ctx = {
    kind = kind, backend = kind == "jj" and jj or git, root = root, relative = relative,
    buf = buf, win = win, first = first, last = last, origins = {},
  }
  ctx.current = function()
    return token == generation and api.nvim_buf_is_valid(buf) and api.nvim_buf_get_changedtick(buf) == tick
  end
  local function annotated(result, annotate_err)
    if not ctx.current() then return end
    if not result then
      if annotate_err == "missing" then
        return notify(kind == "jj"
          and (relative .. " is not in jj's last recorded working copy (new or untracked)")
          or (relative .. " is not tracked by Git"), vim.log.levels.INFO)
      end
      return notify(annotate_err)
    end
    -- jj annotates its last record of the working copy; git annotates the saved bytes.
    local recorded_for = kind == "jj" and line_map(result.lines, saved_lines) or nil
    local ids, unsaved, unrecorded = {}, {}, {}
    for line = first, last do
      local saved_line = saved_for[line]
      if not saved_line then
        unsaved[line] = true
      else
        local index = recorded_for and recorded_for[saved_line] or (not recorded_for and saved_line)
        local entry = index and result.entries[index]
        if entry then
          ids[line] = entry.id
          ctx.origins[line] = entry
        else
          -- Saved after jj last recorded the working copy: jj gives such lines
          -- to the working-copy change when it next snapshots.
          ids[line], unrecorded[line] = "@", true
        end
      end
    end
    present(ctx, ids, unsaved, unrecorded)
  end
  if kind == "jj" then
    jj.annotate(ctx, nil, relative, annotated)
  else
    git.annotate(ctx, nil, relative, annotated, saved)
  end
end

function M.show(first, last)
  local line = api.nvim_win_get_cursor(0)[1]
  request(first or line, last or first or line)
end

function M.setup()
  highlights()
  api.nvim_create_autocmd("ColorScheme", {
    group = api.nvim_create_augroup("SeeleLineOrigin", { clear = true }),
    callback = highlights,
  })
  api.nvim_create_user_command("LineOrigin", function(args)
    M.show(args.line1, args.line2)
  end, { range = true, desc = "Show which change last touched these lines, and why" })
  vim.keymap.set("n", "<leader>b", function() M.show() end, { desc = "Show line origin" })
  vim.keymap.set("x", "<leader>b", ":LineOrigin<CR>", { silent = true, desc = "Show line origins" })
end

return M
