local Tag='outfitter' 

module(Tag,package.seeall)

local Player = FindMetaTable"Player"

outfitter_enabled = CreateClientConVar("outfitter_enabled","1",true,true)


--TODO
outfitter_failsafe = CreateClientConVar("outfitter_failsafe","0",true)
--TODO
outfitter_maxsize = CreateClientConVar("outfitter_maxsize","5",true)


function ReserveGMA(path)
	net.reserve(path)
end



local enforce_models = {}
function Think()
	for pl,count in next,enforce_models do
		if pl:IsValid() and count>0 then
			
			enforce_models[pl] = count - 1
			
			pl:SetModel(pl.enforce_model)
			
		else
			enforce_models[pl] = nil
		end
	end
end

hook.Add("Think",Tag,Think)


function StartEnforcing(pl)
	enforce_models[pl] = 3
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

function NotifyShouldTransmit(pl,should)
	if pl:IsPlayer() and should then
		if pl.enforce_model then
			pl.original_model = pl:GetModel()
			StartEnforcing(pl)
		end
	end
end

hook.Add("NotifyShouldTransmit",Tag,NotifyShouldTransmit)


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
	MountWS(wsid,function(paths)
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

-- workshop mounting coroutine 

local mounting = {}

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
	mounting[wsid] = false
	ErrorNoHalt("MountWS("..tostring(wsid)..") failed: "..tostring(reason or ":s").."\n")
end

function coMountWS(wsid)
	local isdbg = isdbg()
	
	local dat = mounting[wsid]
	
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
	mounting[wsid] = dat
	
	local cb = co.newcb()
	steamworks.FileInfo(wsid,cb)
	local result = co.waitcb(cb)
	
	if isdbg then dbg("steamworks.FileInfo",wsid,"->",result) end
	
	if not result or not result.fileid then
		cantmount(wsid,"fileinfo")
		return SYNC(dat,false)
	end
	
	co.wait(.3)
	
	local TIME = isdbg and SysTime()
	local path = steamworks_Download( result.fileid, true )
	if isdbg then dbg("Download",wsid,"to",path,"took",SysTime()-TIME) end
	
	-- might return instantly :s
	
	assert(path~=true)
	
	if not path then
		cantmount(wsid,"download")
		return SYNC(dat,false)
	end
	
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
	
	mounting[wsid] = true
	res[wsid] = files or {}
	return SYNC(dat,files or {})

end

function MountWS(wsid,cb)
	if co.make(wsid,cb) then return end
	cb(coMountWS(wsid))
end

--          l outfitter.MountWS(111412589,PrintTable)