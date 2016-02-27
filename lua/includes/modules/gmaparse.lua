local Tag='gmaparse' 

module(Tag,package.seeall)

local GMA = {}
local _M = {__index = GMA,__tostring=function(self) return "GMAD Parser" end}
function Parser(f)
	if isstring(f) then
		f = file.Open(f,'rb','GAME')
	end	
	
	
	local hdr = f:Read(4)
	if hdr~='GMAD' then
		return nil,"notgma"
	end
	
	local version = string.byte(f:Read(1))
	
	if version>3 then
		return nil,'newformat'
	end
	
	local T = {file = f, _iOffset=0,version = version}
	
	return setmetatable(T,_M)
	
end

function GMA:IsValid()
	return self.file and self:ParseHeader() and true or false
end

function GMA:GetFile()
	return self.file
end

function GMA:Close()
	local f = self.file
	f:Close()
	self.file = false
end

function GMA:_ParseFail(reason)
	self.parsed_header = false
	self.parse_error = reason or "?"
	self.error = "Parsing failed: "..tostring(reason)
	return nil,reason
end

function GMA:GetError()
	return self.error
end

function GMA:ParseHeader()
	if self.parsed_header~=nil then 
		return self.parsed_header
	end
	self.parsed_header = false
	
	local f = self.file
	local res = self
	
	local sid = f:Read(8) -- TODO
	res.steamid = sid
	
	local ts = f:Read(8) -- TODO
	res.timestamp = ts

	local strcontent = {}
	if self.version>1 then
		for i=1,1024 do
			local s = f:ReadString(128)
			if not s or s=="" then break end
			strcontent[#strcontent+1]=s
		end	
	end
	res.strcontent = strcontent
	
	-- TODO
	local name		= f:ReadString()
	local desc		= f:ReadString() -- TODO json
	local author	= f:ReadString()

	res.name,res.desc,res.author = name,desc,author
	
	-- TODO: unused?
	local addonver = f:Read(4)
	res.addonver = addonver
	
	res.file_enum = f:Tell()
	
	return true
	
end


local entry = {}
GMA.tmp_entry = entry

function GMA:EnumFiles(reset)
	local f = self.file
	
	if reset then
		self.parsed_filelist = false
		self._iOffset = 0
		f:Seek(res.file_enum)
	end
	assert(not self.parsed_filelist)
	
	local readtype = f:Read(4) -- uint
	
	if readtype==nil then error"offset failure" end
	
	if readtype=="\0\0\0\0" then
		self.fileblock = f:Tell()
		self.parsed_filelist = true
		return false
	else
		entry.readtype = from_u_int(readtype,true)
	end
	
	entry.Name		= f:ReadString(64) or ""
	
	entry.Size		= from_u_int(f:Read(4) or "\0",true) -- long long
	
	assert(f:Read(4)=='\0\0\0\0')
	
	if entry.Size>1024*1024*256 then 
		return self:_ParseFail'bigsize'
	end
	entry.CRC		= from_u_int(f:Read(4) or "\0",true) -- unsigned int
	
	entry.Offset	= self._iOffset
	self._iOffset = self._iOffset + entry.Size
		
	return entry
	
end

function GMA:SeekToFileOffset(offset)
	
	assert(self.parsed_filelist)
	
	if istable(offset) then
		offset = offset.Offset
	end
	
	local f = self.file
	local off = self.fileblock + offset
	
	if off>f:Size() then print("offset too big",off-f:Size()) return false end
	
	f:Seek(off)
	return f:Tell()==off
	
end

function GMA:ReadEntry(entry,fast)
	local offset = entry.Offset
	local size = entry.Size
	
	local seekok = self:SeekToFileOffset(offset)
	if not seekok then return nil,"seekfail" end
	
	local data = self.file:Read(size)
	if not data then return nil,"nodata" end
	if #data~=size then return nil,"eof" end
	if not fast and tostring(util.CRC(data))~=tostring(entry.CRC) then return nil,"crc" end
	
	return data
	
end

--[[ -- test
local fp ="cache/workshop/"
local fn = '391042736548413304.cache'

local fpath = fp..fn
local f = file.Open(fpath,'rb','MOD')

local gma,err = Parser(f)
if not gma then print("Parser init fail",err) return end

local ok ,err = gma:ParseHeader()
if not ok then print("header parse failed",err) return end

local mdls = {}
for i=1,8192 do
	local entry = gma:EnumFiles()
	if not entry then break end
	if entry.Name:find'%.mdl$' then
		mdls[#mdls+1] = table.Copy(entry)
	end
end

for k,entry in next,mdls do
	print("Entry: '"..entry.Name.."'",string.NiceSize(entry.Size))
	local dat,err = gma:ReadEntry(entry)
	if not dat then print("","fail",err) continue end
	print("Data: ",#dat,('%q'):format(dat:sub(1,10)))
end
print("GMAERR",gma:GetError())
PrintTable(gma)
PrintTable(gma.tmp_entry)
gma:Close()

	
--]]