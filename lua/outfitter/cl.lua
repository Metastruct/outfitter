local Tag='outfitter' 
local NTag = 'OF'

module(Tag,package.seeall)

local SAVE =false  --TODO

local Player = FindMetaTable"Player"

--TODO: Make outfitter mount all after enabling?
outfitter_enabled = CreateClientConVar("outfitter_enabled","1",SAVE,true)


--TODO
outfitter_failsafe = CreateClientConVar("outfitter_failsafe","0",SAVE)
--TODO
outfitter_maxsize = CreateClientConVar("outfitter_maxsize","5",SAVE)


function ReserveGMA(path)
	net.reserve(path)
end

local function Enforce(pl)
	pl:SetModel(pl.enforce_model)
end

local enforce_models = {}
function Think()
	for pl,count in next,enforce_models do
		if pl:IsValid() and count>0 then
			
			enforce_models[pl] = count - 1
			
			Enforce(pl)
			
		else
			enforce_models[pl] = nil
		end
	end
end

hook.Add("Think",Tag,Think)


function StartEnforcing(pl)
	enforce_models[pl] = 3
	Enforce(pl)
end

function Player.EnforceModel(pl,mdl,nocheck)
	if not nocheck then
		local exists = file.Exists(mdl,'GAME')
		if not exists then return end
	end
	if not pl.enforce_model then
		pl.original_model = pl:GetModel()
	end
	
	StartEnforcing(pl)
	
	pl.enforce_model = mdl
	
end

function Player.GetEnforceModel(pl,mdl)
	enforce_models[pl] = 3
	pl.enforce_model = mdl
end

function OnPlayerInPVS(pl)
	if pl.enforce_model then
		pl.original_model = pl:GetModel()
		StartEnforcing(pl)
	end
end

-- networked new outfit
function OnChangeOutfit(pl,mdl,wsid)
	assert((mdl and wsid) or (not mdl and not wsid))
	assert(mdl~="")
	assert(wsid~=0)
	assert(wsid~=0)
	
	if not mdl then
		if pl.original_model then
			pl:SetModel(pl.original_model)
		end
		
		pl.enforce_model = nil
		pl.outfitter_mdl = nil
		pl.outfitter_wsid = nil
	end
	--DoOutfitMount
	pl.outfitter_mdl,pl.outfitter_wsid = mdl,wsid
	
end





function OnMessage(len)
	local pl = net.ReadPlayer or net.ReadEntity
	pl = pl()
	
	if not pl:IsValid() then return end
	
	local mdl = net.ReadString()
	local wsid = net.ReadString() -- TODO: length?
	
	DoOutfitMount(pl,mdl..'.mdl',wsid)
	
end

function DoOutfitMount(pl,mdl,wsid)
	
	local exists = HasMDL(mdl)
	
	if exists then
		return pl:EnforceModel(mdl,true)
	end
	FetchWS(wsid,function(paths)
		if not paths then return end
		local found
		for k,v in next,paths do
			if v== mdl then
				found = true
				break
			end
		end
		found = found or HasMDL(mdl)
		if not found then 
			dbge("DoOutfitMount",mdl,"missing from",wsid,"but was to be mounted" )
		end
	end)
end

-- workshop fetching coroutine 

local fetching = {}

local res = {}

local function SYNC(cbs,ret)
	for k,cb in next,cbs do
		cb(ret)
		co.waittick()
	end
	return ret
end

local function steamworks_Download( fileid, uncomp )
	local instant
	local path
	local cb = co.newcb()
	local function cb2(...)
		if instant==nil then
			path = ...
			instant = true
			return 
		end
		return cb(...)
	end
	steamworks.Download( fileid, uncomp, cb2 )
	instant = false
	if instant==nil then
		path = co.waitcb(cb)
	end
	return path
end


local function cantmount(wsid,reason)
	fetching[wsid] = false
	ErrorNoHalt("FetchWS("..tostring(wsid)..") failed: "..tostring(reason or ":s").."\n")
end

function coFetchWS(wsid)
	local isdbg = isdbg()
	
	local dat = fetching[wsid]
	
	if dat then
		if dat==true then 
			--return res[wsid] or true
		elseif istable(dat) then
			local cb = co.newcb()
			dat[#dat+1] = cb
			return co.waitcb()
		elseif dat==false then
			return false
		end
	end
	
	dat = {}
	fetching[wsid] = dat
	
	local cb = co.newcb()
	steamworks.FileInfo(wsid,cb)
	local fileinfo = co.waitcb(cb)
	
	if isdbg then dbg("steamworks.FileInfo",wsid,"->",fileinfo) end
	
	if not fileinfo or not fileinfo.fileid then
		cantmount(wsid,"fileinfo")
		return SYNC(dat,false)
	end
	
	local maxsz = outfitter_maxsize:GetFloat()
	
	if maxsz>0.000001 and (fileinfo.size or 0) > maxsz*1024*1024 then
		cantmount(wsid,"too big")
		return SYNC(dat,false)
	end
		
	co.wait(.3)
	
	local TIME = isdbg and SysTime()
	local path = steamworks_Download( fileinfo.fileid, true )
	if isdbg then dbg("Download",wsid,"to",path,"took",SysTime()-TIME) end

	-- might return instantly :s
	
	assert(path~=true)
	
	if not path then
		cantmount(wsid,"download")
		return SYNC(dat,false)
	end
	
	local res = path
	fetching[wsid] = true
	res[wsid] = res
	
	return SYNC(dat,res)

end

function FetchWS(wsid,cb)
	if co.make(wsid,cb) then return end
	cb(coFetchWS(wsid))
end

function MountWS( path )
	
	if co.make(path) then return end
	
	co.wait(.3)
	
	--TODO: HUDPaint notification of mounting
	
	local TIME = isdbg and SysTime()
	local ok, files = game.MountGMA( path )
	if isdbg then dbg("MountGMA",wsid,path,"took",SysTime()-TIME) end

	if not ok then
		cantmount(wsid,"mountgma")
		return SYNC(dat,false)
	end
	
	co.wait(.5)
	
end

--          l outfitter.FetchWS(111412589,PrintTable)