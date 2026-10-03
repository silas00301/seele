--- @since 26.9.1
-- Pack the hovered or selected entries into a new archive in the current
-- directory. The extension typed into the prompt chooses the format. 7-Zip is
-- the store path Nix substitutes below, never whatever PATH resolves.

local SEVENZIP = "@sevenzip@"

-- Extension, 7-Zip container type, and the compressor a tarball goes through.
local FORMATS = {
	{ ".tar.gz", "tar", "gzip" },
	{ ".tgz", "tar", "gzip" },
	{ ".tar.xz", "tar", "xz" },
	{ ".txz", "tar", "xz" },
	{ ".tar.bz2", "tar", "bzip2" },
	{ ".tbz2", "tar", "bzip2" },
	{ ".tar", "tar" },
	{ ".zip", "zip" },
	{ ".7z", "7z" },
}

local function format_of(name)
	local lower = name:lower()
	for _, f in ipairs(FORMATS) do
		if #name > #f[1] and lower:sub(-#f[1]) == f[1] then
			return f
		end
	end
end

local function fail(task, message)
	ya.notify { title = "Pack", content = message, level = "error", timeout = 8 }
	if task then
		task:fail(message)
	end
end

local targets = ya.sync(function()
	local tab, urls = cx.active, {}
	for _, file in pairs(tab.selected) do
		urls[#urls + 1] = file.url
	end
	if #urls == 0 and tab.current.hovered then
		urls[1] = tab.current.hovered.url
	end

	local paths = {}
	for i, url in ipairs(urls) do
		if url.spec.is_virtual then
			return nil, nil
		end
		paths[i] = tostring(url.path)
	end
	return paths, tostring(tab.current.cwd.path)
end)

-- 7-Zip stores each entry relative to its working directory, so it runs from
-- the closest directory holding every entry.
local function common_parent(urls)
	local base = urls[1].parent
	while base do
		local holds = true
		for _, url in ipairs(urls) do
			holds = holds and url:starts_with(base)
		end
		if holds then
			return base
		end
		base = base.parent
	end
end

local function run(cwd, args)
	local output, err = Command(SEVENZIP):arg(args):cwd(tostring(cwd)):output()
	if not output then
		return "could not start 7-Zip: " .. tostring(err)
	elseif not output.status.success then
		local detail = output.stderr:gsub("[%c%s]+", " "):match("^ ?(.-) ?$"):sub(1, 400)
		return string.format("7-Zip exited with %s. %s", output.status.code or "a signal", detail)
	end
end

local function pack(dir, base, entries, name, format)
	local tmp, err = fs.unique("dir", dir:join(".tmp_pack"))
	if not tmp then
		return nil, "could not create a working directory: " .. tostring(err)
	end

	-- `-spd` keeps `*` and `?` in names literal, `--` ends switches and
	-- @listfile parsing, and `-snl` stores links as links instead of
	-- following them out of the selection. The working directory is left out
	-- for when the archive is made inside a folder that is being packed.
	local inner = format[3] and name:sub(1, #name - #format[1]) .. ".tar" or name
	local args = { "a", "-t" .. format[2], "-snl", "-spd", "-bso0", "-bsp0" }
	local own = tmp:strip_prefix(base)
	if own then
		args[#args + 1] = "-x!" .. tostring(own)
	end
	args[#args + 1] = "--"
	args[#args + 1] = tostring(tmp:join(inner))
	for _, entry in ipairs(entries) do
		args[#args + 1] = entry
	end

	err = run(base, args)
	if not err and format[3] then
		err = run(tmp, { "a", "-t" .. format[3], "-bso0", "-bsp0", "--", name, inner })
	end

	-- `fs.unique` creates the name before returning it, so the rename can only
	-- ever replace that empty placeholder, never a file someone else made.
	local dest, moved
	if not err then
		dest, err = fs.unique("file", dir:join(name))
	end
	if dest then
		moved, err = fs.rename(tmp:join(name), dest)
		if not moved then
			fs.remove("file", dest)
			dest = nil
		end
	end

	fs.remove("dir_all", tmp)
	return dest, err and tostring(err)
end

return {
	entry = function()
		ya.emit("escape", { visual = true })

		local paths, cwd = targets()
		if not paths then
			return fail(nil, "Packing needs local files")
		elseif #paths == 0 then
			return
		end

		local urls = {}
		for i, path in ipairs(paths) do
			urls[i] = Url(path)
		end
		local dir, base = Url(cwd), common_parent(urls)
		if not base then
			return fail(nil, "There is nothing above / to pack into")
		end

		local entries = {}
		for i, url in ipairs(urls) do
			entries[i] = tostring(url:strip_prefix(base))
		end

		local value = (#urls == 1 and urls[1].name or base.name or "archive") .. ".zip"
		local title = "Pack into:"
		local name, format
		while true do
			local input, event = ya.input { title = title, value = value, pos = { "top-center", y = 3, w = 60 } }
			if event ~= 1 then
				return
			end

			value, format = input, format_of(input)
			if input:find("/", 1, true) then
				title = "A name, not a path:"
			elseif not format then
				title = "Use .zip, .7z, .tar, .tar.gz, .tar.xz or .tar.bz2:"
			elseif fs.cha(dir:join(input), false) then
				title = "Already exists, pick another name:"
			else
				name = input
				break
			end
		end

		ya.emit("escape", { select = true })
		local task = ya.task("custom", { track = true }):name("Pack " .. name):spawn()
		if not task:acquire() then
			return
		end

		local dest, err = pack(dir, base, entries, name, format)
		if dest then
			task:succeed { dest }
		else
			fail(task, string.format('Could not pack "%s": %s', name, err))
		end
	end,
}
