if SERVER then
	AddCSLuaFile()
end


local File = FindMetaTable"File"

local visit_folders
visit_folders = function(init_path,scope,cb)
	scope = scope or 'GAME'
	
	local stack = {
		init_path,
	}
	
	-- "models/player"
	
	-- "models/player/fld1"
	-- "models/player/fld2"
	
	-- "models/player/fld1/asd"
	-- "models/player/fld1/qwe"
	-- "models/player/fld2"
	
	while stack[1] do
		local entry = stack[1]
		table.remove(stack,1)
		
		local fi,fo = file.Find(entry..'/*.*',scope)
		local ret = cb(entry..'/',fi,fo)
		if ret == nil then
			for k,v in next,fo do
				table.insert(stack,1,entry..'/'..v)
			end
		elseif ret == false then return end
	end
	
end


file.RecurseFolders = visit_folders

local tmp = {}
function File.ReadString(f,n,ch)
	n = n or 256
	ch = ch or '\0'
	local startpos = f:Tell()
	local offset = 0
	local tmpn = 0
	local sz = f:Size()
	
	--TODO: Use n and sz instead
	for i=1,1048576 do
--	while true do
		if f:Tell()>=sz then return nil,"eof" end
		local str = f:Read(n)
		--if not str then return nil,"eof","wtf" end
		local pos = str:find(ch,1,true)
		if pos then
			--offset = offset + pos
			
			--reset position
			f:Seek(startpos+offset+pos)
			
			tmp[tmpn + 1] = str:sub(1,pos - 1)
			return table.concat(tmp,'',1,tmpn+1)
		else
			tmpn = tmpn + 1
			tmp[tmpn] = str
			offset = offset + n
		end
	end
	return nil,"not found"
end