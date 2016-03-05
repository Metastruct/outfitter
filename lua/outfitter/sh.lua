local Tag='outfitter' 

module(Tag,package.seeall)


function HasMDL(mdl)
	mdl = mdl:gsub("%.mdl$","")
	return file.Exists(mdl..'.mdl','GAME')
end

net.Receive(Tag,function(...) OnReceive(...) end)

local cache = {}
function FlushCache()
	cache = {}
end

function FileExistsCached(fpath)
	local ret = cache[fpath]
	if ret == nil then
		ret = HasMDL(fpath)
		cache[fpath] = ret
	end
	return ret
end

function SanityCheckNData(mdl,wsid)
	
	if not mdl then return false end
	if not wsid then return false end
	if mdl=="" or #mdl>2048*2 then return false end
	if mdl:find("  ",1,true) or mdl:find("..",1,true) or mdl:find("\t",1,true) or mdl:find("\n",1,true) then return false end
	if wsid<=0 then return false end
	
	return nil
	
end


function findpl(uid)
	for _,pl in next,player.GetAll() do 
		if pl:UserID()==uid then
			return pl
		end
	end
end	


--TODO: hex encoding at least
function EncodeOW(o,w)
	return w and o and (w..','..(o:gsub("%.mdl$",""))) or nil
end

function DecodeOW(str)
	if not str then return end
	local w,o = str:match'^(%d-),(.*)$'
	w = tonumber(w)
	if o then o=o..'.mdl' end
	return o,w
end

-- parse model from file
function CanPlayerModel(f,sz)
	local mdl,err,err2 = mdlinspect.Open(f)
	if not mdl then
		return nil,err,err2
	end
	
	if mdl.version<44 or mdl.version>49 then
		return false,"version"
	end
	
	local ok ,err = mdl:ParseHeader()
	if not ok then 
		return false,err or "hdr" 
	end

	if not mdl.bone_count or mdl.bone_count<=2 then
		return false,"nobones"
	end
	
	if sz then
		local valid,err = mdl:Validate(sz)
		if not valid then 
			dbg("CanPlayerModel",f,"validate error",err)
			return false,"valid" 
		end
	end
	
	--print(mdl,mdl.bodypart_count,mdl.skinreference_count)
	
	local found = false
	local imdls = mdl:IncludedModels()
	
	if mdl.bonecontroller_count ~= mdl.bone_count then
		--dbg("bonecontroller_count differs?!",mdl.bonecontroller_count,mdl.bone_count)
	end
	
	local attachments = mdl:Attachments()
	if not attachments or not next(attachments) then
		return false,"noattachments"
	end
	--PrintTable("ASD",mdl:BoneNames())
	local found
	for k,v in next,attachments do
		local name = v[1]
		--print(name)
		if name=="eyes" or name=="anim_attachment_head" or name=="mouth" or name=="anim_attachment_RH" or name=="anim_attachment_LH" then found=true break end
	end
	if not found then
		--PrintTable(mdl:Attachments())
		return false,"attachments" 
	end
	
	local found 
	for k,v in next,imdls do
		v=v[2]
		if v and v:find("_arms_",1,true) then
			return false,"arms"
		end
		
		if v and not v:find"%.mdl$" then
			return false,"badinclude",v
		end
		
		--if v 
		--	and v:find"%.mdl$" 
		--	and ( 
		--		v:find("anim",1,true) 
		--		or v:find('/m_',1,true) 
		--		or v:find('/f_',1,true) 
		--		or v:find('/cs_',1,true) ) 
		--then
		--	found = true
		--	break
		--end
	end
	--if not found then 
	--	return false,"includemdls" 
	--end
	
	--TODO: Bones are named all over the place
	
	--local bname = mdl:BoneNames() [1]
	--if not bname or (	not bname:lower():find("pelvis",1,true) 
	--					and bname~="Root"  
	--					and bname~="pelvis"  
	--					and bname~="hip"  
	--					and bname~="root") 
	--then
	--	return false,"bones",bname
	--end
	
	return true
end

--[[
local fp ="models/player/"
local flist = file.Find(fp..'*.mdl','GAME')
-- flist = {'matress.mdl'}

for _,fn in next,flist do

	local fpath = fp..fn
	local f = file.Open(fpath,'rb','GAME')
	print(('%50s'):format(fn),CanPlayerModel(f))
	f:Close()
	
end--]]


