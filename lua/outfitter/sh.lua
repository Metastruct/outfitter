local Tag='outfitter' 

module(Tag,package.seeall)

local outfitter_sv_distance = CreateConVar("outfitter_sv_distance", "0", { FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY } )
function ServerSuggestDistance()
	return outfitter_sv_distance:GetBool()
end

function HasMDL(mdl)
	mdl = mdl:gsub("%.mdl$","")
	return file.Exists(mdl..'.mdl','GAME')
end

net.Receive(Tag,function(...) if this.OnReceive then OnReceive(...) end end)


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
function MDLIsPlayermodel(f,sz)
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
			dbg("MDLIsPlayermodel",f,"validate error",err)
			return false,"valid" 
		end
	end
	
	--print(mdl,mdl.bodypart_count,mdl.skinreference_count)
	
	local found = false
	local imdls = mdl:IncludedModels()
	
	if mdl.bonecontroller_count ~= mdl.bone_count then
		--dbg("bonecontroller_count differs?!",mdl.bonecontroller_count,mdl.bone_count)
	end
	
	local found
	local found_anm
	for k,v in next,imdls do
		v=v[2]
		if v and v:find("_arms_",1,true) then
			return false,"arms"
		end
		
		if v and not v:find"%.mdl$" then
			return false,"badinclude",v
		end
		if v=="models/m_anm.mdl" then
			found_anm = true
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
	
	local attachments = mdl:Attachments()
	if not attachments or not next(attachments) then
		if not found_anm then
			--PrintTable(mdl:Attachments())
			return false,"noattachments" 
		else
			dbg("MDLIsPlayermodel",mdl.name,"no attachments but included")
		end
	else
		--PrintTable("ASD",mdl:BoneNames())
		local found
		for k,v in next,attachments do
			local name = v[1]
			--print(name)
			if name=="eyes" or name=="anim_attachment_head" or name=="mouth" or name=="anim_attachment_RH" or name=="anim_attachment_LH" then found=true break end
		end
		if not found then
			if not found_anm then
				--PrintTable(mdl:Attachments())
				return false,"attachments" 
			else
				dbg("MDLIsPlayermodel",mdl.name,"no attachments but included")
			end
		end
		
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
	print(('%50s'):format(fn),MDLIsPlayermodel(f))
	f:Close()
	
end--]]

local t = {"","","",""}
local function GenID(_1,_2,_3,_4,_5)
	if not _1 then return end
	t[1] = _1
	t[2] = tostring(_2)
	t[3] = tostring(_3)
	t[4] = tostring(_4)
	assert(not _5)
	return table.concat(t,"|")
end

local Player = FindMetaTable"Player"
function Player.OutfitHash(pl)
	return pl.outfitter_latest
end
function Player.OutfitUpdateHash(pl)
	local hash = GenID(pl:OutfitInfo())
	pl.outfitter_latest = hash
	return hash
end
function Player.OutfitCheckHash(pl,nhash)
	local cur = pl:OutfitHash()
	cur = cur or false
	nhash = nhash or false
	return cur==nhash
end

function Player.OutfitInfo(pl)
	
	return 	pl.outfitter_mdl,
			pl.outfitter_wsid,
			pl.outfitter_skin,
			pl.outfitter_bodygroups
			
end
function Player.OutfitSetInfo(pl,mdl,wsid,skin,bodygroups)
	
	pl.outfitter_mdl = mdl
	pl.outfitter_wsid = wsid
	pl.outfitter_skin = skin
	pl.outfitter_bodygroups = bodygroups
	pl:OutfitUpdateHash()

end

--- Crashing code detector thingy
--TODO: Stack, blacklist of files

local CFPATH = "outfitter_crash.dat"
local f
local function getfile()
	if not f then
		f = file.Open(CFPATH, 'wb','DATA')
	end
	return f
end

local function closefile()
	if f then
		f:Close()
	end

	f = nil
end

function CRITICAL(iscritical,dat)

	getfile()
	if not f then return end
	
	f:Seek(0)
	if iscritical then
		f:Write(tostring(iscritical)..':'..tostring(dat)..'\0')
	else
		f:Write'\0'
	end
	
	f:Flush()
end

OnInitialize(function()
	local dat = file.Read(CFPATH,'DATA')
	if not dat then return end
	file.Delete(CFPATH,'DATA')
	local fc = dat:sub(1,1)
	if fc=="" or fc=='\0' then return end
	dat = dat:match '^([^%z]+)'
	if not dat then return end
	ErrorNoHalt("[Outfitter] CRASH: ".. ('%q'):format(tostring(dat)) ..'\n')
end)
