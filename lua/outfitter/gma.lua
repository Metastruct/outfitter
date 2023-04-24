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

	meta.gma_version = gma:ReadByte() -- TODO: GMA version
	if (meta.gma_version or math.huge) > 3 then
		return nil,'Unsupported gma version: '..(meta.gma_version or -1)
	end
	meta.steamid = {gma:ReadULong(),gma:ReadULong()} -- TODO: steamid
	meta.timestamp = {gma:ReadULong(),gma:ReadULong()} -- TODO: timestamp
	if meta.gma_version > 1 then
		meta.required_content = {}
		for i=1,2 ^ 14 do
			if i==2^14-1 then
				return nil,"corrupted file"
			end
			str = gma:ReadString()
			if str=="" then break end
			if not str then
				return nil,'corrupted file'
			end
			table.insert(meta.required_content,str)
		end
	end

	meta.name = gma:ReadString()
	meta.description = util.JSONToTable(gma:ReadString())
	meta.author = gma:ReadString()
	meta.addon_version = gma:ReadULong() -- TODO: addon version
	if not meta.addon_version then
		return nil,'corrupted file'
	end

	for n = 1, 2 ^ 14 do
		if n == 2 ^ 14 - 1 then return nil, 'too many files' end
		
		-- filenum, can ignore
		local filenum= gma:ReadULong()
		if filenum == 0 then break end
		if filenum~=n then
			return nil,'corrupted filenum'
		end
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
	--meta.unknown = gma:Read(4)

	--for k, v in pairs(meta.files) do
	--	print(string.NiceSize(v.size), v.filename)
	--end

	return meta
end

local function verify_files(meta,collect)
	if collect then
		collect(true)
	end
	for _, file_meta in pairs(meta.files) do
		local fd = file_meta.fd or meta.fd
		fd:Seek(file_meta.offset)

		local data = fd:Read(file_meta.size)
		if not data or #data ~= file_meta.size then
			return nil,'read failed'
		end
		
		if file_meta.crc and file_meta.crc~=0 and tostring(util.CRC(data))~=tostring(file_meta.crc) then return false,file_meta end
		
		if collect then
			local datalen = #data
			data = nil
			collect(datalen)
		end
	end
	return meta
end

local function build(meta, gma, collect, no_crc)
	local pos=0
	local function add(n)
		pos=pos+n
		--assert(pos==gma:Tell())
		return pos
	end
	gma:Write"GMAD" -- GMA Ident 
	add(4)
	gma:Write(string.char(meta.gma_version)) -- GMA version
	add(1)
	gma:WriteULong(meta.steamid[1]) -- SteamID
	gma:WriteULong(meta.steamid[2]) -- SteamID
	add(8)
	gma:WriteULong(meta.timestamp[1]) -- Timestamp
	gma:WriteULong(meta.timestamp[2]) -- Timestamp
	add(8)
	if meta.gma_version>1 then
		--TODO: dummy
		gma:Write('\0') -- Required content
		add(1)
	end
	local name = (meta.name or "") .. '\0'
	gma:Write(name) -- Name
	add(#name)
	local desc = (meta.description and util.TableToJSON(meta.description) or '{"type":"model","tags":["fun"],"description":"description"}') .. '\0'
	gma:Write(desc) -- Description
	add(#desc)
	local author = (meta.author or "") .. '\0'
	gma:Write(author) -- Author
	add(#author)
	gma:WriteULong(meta.addon_version) -- Addon version
	add(4)
	local idx = 0

	if collect then
		collect(true)
	end

	for i, file_meta in pairs(meta.files) do
		idx = idx + 1
	
		gma:WriteLong(idx) -- file number
		add(4)
		assert(idx == i)
	
		gma:Write(file_meta.filename .. "\0") -- filename 
		add(#file_meta.filename+1)

		assert(file_meta.size < 2 ^ 30)
	
		gma:WriteULong(file_meta.size) -- file size 1
		gma:WriteULong(0) -- file size 2
		add(8)
	
		gma:WriteULong(file_meta.crc or 0)
		add(4)
	end

	gma:WriteLong(0) -- file number 0 (ends listing)
	add(4)

	for _, file_meta in pairs(meta.files) do
		local fd = file_meta.fd or meta.fd
		fd:Seek(file_meta.offset)
		local data = fd:Read(file_meta.size)
		if not data or #data ~= file_meta.size then
			return nil,'read failed'
		end
		
		if no_crc ~= true and file_meta.crc and file_meta.crc~=0 and tostring(util.CRC(data))~=tostring(file_meta.crc) then return nil,"file corrupted" end
		file_meta.offset = gma:Tell()
		gma:Write(data)
		add(#data)

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
	local meta, meta_new, ret, err, err2

	if istable(in_fd) then
		meta = in_fd
	else
		meta, err, err2 = parse(in_fd)
		if not meta then return nil, err end
	end

	meta.eof = in_fd:EndOfFile()

	for _, processor in pairs(processors) do
		meta_new, err, err2 = processor(meta)
		if not meta_new then return nil, err, err2 end
		if meta_new == true then break end
		meta = meta_new
	end

	if meta.error then return nil, meta.error, meta end
	if meta.ret then return meta end
	
	ret,err = build(meta, out_fd, collect)
	
	if not ret then
		return nil,err
	end	

	meta.write_size = ret

	return meta
end

file.CreateDir("cache")
file.CreateDir("cache/workshop")
local function rebuild_nolua_cache_purge(cb)
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
			-- likely already mounted!f
			return mount_path, new_file
		else
			return nil, 'not writable'
		end
	end

	--TODO:  {skip_if_no_lua,strip_lua}
	local ok, meta, err = xpcall(process,debug.traceback,in_fd, out_fd, {strip_lua}, collect)
	if not ok then 
		err=meta
		meta=nil
	end

	out_fd:Close()

	if not meta then 
		file.Delete(write_path)
		return nil,err
	end

	if meta.no_lua then
		-- TODO: add support back, for now we want to copy every file even if they have no lua in outfitter

		--dbgn(6,"no lua, deleting",write_path)
		--file.Delete(write_path)
		--return true
	end

	new_file = true

	return mount_path, new_file
end

_M.build = build
_M.parse = parse
_M.process = process
_M.rebuild_nolua = rebuild_nolua
_M.rebuild_nolua_cache_purge = rebuild_nolua_cache_purge

local TEST = false

if TEST then
	local process = process
	print("\n")for _,workshop_id in pairs{2570101454,1135026995} do
		
		steamworks.DownloadUGC(workshop_id, function(path, gma_fd)
			print("\n\n=========",workshop_id,"==========")--local out_fd = file.Open("test_nolua.dat", 'wb', 'DATA')

			--print("process", process(gma_fd, out_fd, {strip_lua}))
			local parsed = _M.parse(gma_fd)			
			assert(verify_files(parsed))
			local q=table.Copy(parsed)
			q.files=nil
			print("=======parsed=========\n")
			PrintTable(q)
			print("================\n")


			print("DownloadUGC pre-parse",parsed,parsed.eof,not gma_fd:EndOfFile() and "NOT END OF FILE!!!!!!!!" or "",-(gma_fd:Tell()-gma_fd:Size())) 
			print(("%q"):format(gma_fd:Read(4)))
			gma_fd:Seek(0)
			local output_id = nil -- we want a new file every time
			local nolua_path,err = _M.rebuild_nolua(gma_fd, output_id, true, function(sz)
				if sz == true then
					--print("collect start")
				end

				--local _ = isnumber(sz) and sz > 1000 * 900 and print(string.NiceSize(sz))
			end)
			print("rebuild_nolua:",path,err)
			
			--out_fd:Seek(0)
			--out_fd:Close()

			print("gma.parse",nolua_path)
			local testfd = file.Open(nolua_path,'rb','MOD')
			print("result=")
			local parsed = _M.parse(testfd)
			assert(verify_files(parsed))
			parsed.files=nil
			print("========postparsed========\n")
			PrintTable(parsed)
			print("================\n")

			print("EOF",testfd:EndOfFile())
			testfd:Seek(0)
			local parser = gmaparse.Parser(testfd)
			parser:ParseHeader()
			print("========gmaparse========\n")
			PrintTable(parser)
			print("================\n")
			for i=1,1234 do
				local fd,err = parser:EnumFiles()
				if fd==false then
				break
				end
			end
			testfd:Close()

		end)
	end
end
