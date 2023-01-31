local Tag = 'outfitter'
module(Tag .. '.gma', package.seeall)

-- Reads binary strings
local function readInt(file_meta, count)
	local bits = file_meta:Read(count)

	local bytes = {string.byte(bits, 1, count)}

	local var = 0

	for pos = 0, count - 1 do
		local mult = 256 ^ pos
		var = var + bytes[pos + 1] * mult
	end

	if var > 2147483647 then return var - 4294967296 end

	return var
end

local function parse(gma)
	if gma:Read(4) ~= "GMAD" then return nil, 'invalid header' end

	local meta = {
		files = {},
		fd = gma
	}

	meta.gma_version = gma:Read(1):byte() -- TODO: GMA version
	meta.steamid = gma:Read(8) -- TODO: steamid
	meta.timestamp = gma:Read(8) -- TODO: timestamp
	meta.requested_content = gma:ReadString() or "" -- TODO: required content
	meta.name = gma:ReadString()
	meta.description = util.JSONToTable(gma:ReadString())
	meta.author = gma:ReadString()
	meta.addon_version = gma:Read(4) -- TODO: addon version

	for n = 1, 2 ^ 14 do
		if n == 2 ^ 14 - 1 then return nil, 'too many files' end
		if gma:ReadLong() == 0 then break end
		local filename = gma:ReadString()
		local file_meta = {}
		file_meta.filename = filename
		file_meta.size = gma:ReadULong()
		if gma:ReadULong() ~= 0 then return nil, "file too large" end
		file_meta.crc = gma:ReadULong()
		--file_meta.fd = gma
		file_meta.ext = string.GetExtensionFromFilename(filename)
		if file_meta.size <= 0 then return nil, 'invalid filesize' end
		if file_meta.size >= (2 ^ 30) - 1 then return nil, 'invalid filesize' end
		table.insert(meta.files, file_meta)
	end

	for _, file_meta in pairs(meta.files) do
		file_meta.offset = gma:Tell()
		gma:Skip(file_meta.size)
	end
	--for k, v in pairs(meta.files) do
	--	print(string.NiceSize(v.size), v.filename)
	--end

	return meta
end

local function build(meta, gma, collect)
	gma:Write"GMAD" -- GMA Ident 
	gma:Write(string.char(meta.gma_version)) -- GMA version
	gma:Write(meta.steamid) -- SteamID
	gma:Write(meta.timestamp) -- Timestamp
	assert(meta.requested_content == "", "TODO")
	gma:Write(meta.requested_content .. '\0') -- Required content
	gma:Write((meta.name or "") .. '\0') -- Name
	gma:Write(util.TableToJSON(meta.description) .. '\0') -- Description
	gma:Write((meta.author or "") .. '\0') -- Author
	gma:Write(meta.addon_version) -- Addon version
	local idx = 0

	if collect then
		collect(true)
	end

	for i, file_meta in pairs(meta.files) do
		idx = idx + 1
		gma:WriteLong(idx) -- file number
		assert(idx == i)
		gma:Write(file_meta.filename .. "\0") -- filename 
		assert(file_meta.size < 2 ^ 30)
		gma:WriteULong(file_meta.size) -- file size 1
		gma:WriteULong(0) -- file size 2
		gma:WriteLong(file_meta.crc or 0)
	end

	gma:WriteLong(0) -- file number 0 (ends listing)

	for _, file_meta in pairs(meta.files) do
		local fd = file_meta.fd or meta.fd
		fd:Seek(file_meta.offset)
		local data = fd:Read(file_meta.size)
		gma:Write(data)

		if collect then
			local datalen = #data
			data = nil
			collect(datalen)
		end
	end

	if collect then
		collect(false)
	end

	return gma:Tell()
end

local function strip_lua(meta)
	for i, file_meta in pairs(meta.files) do
		if file_meta.ext:lower() == "lua" then
			table.remove(meta.files, i)
		end
	end

	return meta
end

local function skip_if_no_lua(meta)
	for i, file_meta in pairs(meta.files) do
		if file_meta.ext:lower() == "lua" then return end
	end

	meta.ret = true
	meta.no_lua = true

	return true
end

-- Writes in_fd|parsed_gma_metadata to out_fd while applying a list of transforming processors to it
--  - processors: { function(gma_metadata) gma_metadata.name="name changed" return gma_metadata end, ... }
--  - collect (optional): garbage collection callback (cannot be async if using DownloadUGC)
local function process(in_fd, out_fd, processors, collect)
	local meta, err, err2

	if istable(in_fd) then
		meta = in_fd
	else
		meta, err, err2 = parse(in_fd)
		if not meta then return meta, err end
	end

	meta.eof = in_fd:EndOfFile()

	for _, process in pairs(processors) do
		local meta_new, err, err2 = process(meta)
		if not meta_new then return nil, err, err2 end
		if meta_new == true then break end
		meta = meta_new
	end

	if meta.error then return nil, meta.error, meta end
	if meta.ret then return meta end
	meta.write_size = assert(build(meta, out_fd, collect))

	return meta
end

file.CreateDir("cache")
file.CreateDir("cache/workshop")
function rebuild_nolua_cache_purge(cb)
    local files = file.Find("cache/workshop/*.nolua.gma.dat","DATA")
    for k,v in pairs(files or {}) do
        local path = ("cache/workshop/%s"):format(v)
        if not cb or cb(path)~=true then
            file.Delete(path,'DATA')
        end
    end
end


local uid = 0

-- always_overwrite: overwrite if existing, used for high security
-- return: 
--  - true: no lua found
--  - mount_path (string), new_file  (string): path for MountGMA and whether or not file is just written or likely already mounted
local function rebuild_nolua(in_fd, id, always_overwrite, collect)
	if not id then
		uid = uid + 1
		id = os.date("%y-%m-%d_%H_%M_%S") .. '-' .. uid
		--TODO: crc?
	end

	local write_path = ("cache/workshop/%s.nolua.gma.dat"):format(id)
	local mount_path = ("data/cache/workshop/%s.nolua.gma.dat"):format(id)
	local new_file = false
	local out_fd = file.Open(write_path, 'wb', 'DATA')

	if not out_fd then
		if always_overwrite then return nil, 'not writable' end

		if file.Size(write_path, 'DATA') > 10 then
			-- likely already mounted!
			return mount_path, new_file
		else
			return nil, 'not writable'
		end
	end

	--TODO: verify! local meta, err = process(in_fd, out_fd, {skip_if_no_lua,strip_lua})
	local meta, err = process(in_fd, out_fd, {strip_lua}, collect)

	out_fd:Close()

	if meta.no_lua then
		file.Delete(write_path)

		return true
	end

	if not meta then return nil, err end
	new_file = true

	return mount_path, new_file
end

_M.build = build
_M.parse = parse
_M.process = process
_M.rebuild_nolua = rebuild_nolua

local TEST = false

if TEST then
	local process = process
	local workshop_id = "1135026995"

	steamworks.DownloadUGC(workshop_id, function(path, gma_fd)
		print(path)
		local out_fd = file.Open("test_nolua.dat", 'wb', 'DATA')

		print("process", process(gma_fd, out_fd, {strip_lua}))

		gma_fd:Seek(0)

		print("rebuild_nolua", rebuild_nolua(gma_fd, workshop_id, false, function(sz)
			if sz == true then
				print("collect start")
			end

			local _ = isnumber(sz) and sz > 1000 * 900 and print(string.NiceSize(sz))
		end))

		out_fd:Seek(0)
		out_fd:Close()
	end)
end
