local Tag='outfitter' 
local NTag = 'OF'

module(Tag,package.seeall)

	
-- Incoming new outfit
-- We dont' know if model or wsid exist
local function RESET(pl)
	pl:EnforceModel(false)
	pl.outfitter_mdl = nil
	pl.outfitter_wsid = nil
	
	hook.Run("OutfitApply",pl)
	
end
local function SET(pl)
	
	local mdl,wsid = pl:OutfitInfo()
	
	if mdl and not IsEnabled() then return end
	if DidCrash('setmdl',mdl) then dbge("EnforceModel","CRASH",mdl,wsid) end
	CRITICAL("setmdl",mdl)
	local ret = pl:EnforceModel(mdl)
	CRITICAL(false)
	
	pl.outfitter_mdl = mdl
	pl.outfitter_wsid = wsid
	if not ret then
		dbge("SET FAIL?",ret,mdl,wsid)
	end
	UIOnEnforce(pl)
	
	hook.Run("OutfitApply",pl,mdl,wsid)
	
	return ret
end

function DisableEverything()
	dbg("DisableEverything")
	for _,pl in next,player.GetAll() do
		if pl.outfitter_nvar then
			pl.outfitter_nvar = nil
			
			--TODO: Add instant skip to unset
			pl:SetWantOutfit(false)
			
		end
	end
end

function RefreshPlayers()
	for _,pl in next,player.GetAll() do
		OnPlayerVisible(pl)
	end
end

function EnableEverything()
	dbg("EnableEverything")
	RefreshPlayers()
end


local Player = FindMetaTable"Player"

------- player outfit changing --------

function Player.SetWantOutfit(pl,mdl,wsid,skin,bodygroups)
	dbg("SetWantOutfit",pl,not mdl and "unset" or ('%q'):format(tostring(mdl)),not wsid and "-" or ('%q'):format(tostring(wsid)))
	
	assert(pl and pl:IsValid())
	pl:GetModel()
	assert((mdl and wsid) or (not mdl and not wsid))
	assert(mdl~="")
	assert(wsid~=0)
	assert(wsid~=0)
	
	mdl = mdl and (mdl:gsub("%.mdl$","")..'.mdl') or false
	
	pl:OutfitSetInfo(mdl,wsid,skin,bodygroups)

	local thread = pl.outfitter_co_thread
	
	assert(thread~=true)
	
	local status = thread and coroutine.status(thread)
	
	if status and status ~= "dead" then
		return
	end
	
	local status = pl.outfitter_changing
	if status then
		dbge("ChangeOutfitThread","was already changing?",pl)
	end
	
	pl.outfitter_co_thread = true
	pl.outfitter_co_thread = co(ChangeOutfitThread,pl)
end

function OnChangeOutfit(pl,...)
	
	pl:SetWantOutfit(...)
	
end

function ChangeOutfitThread(pl)
	
	pl.outfitter_changing = true
	
	co.waittick() -- detach, need to check player validity after this
	
	for i=1,8192 do
		
		if i>1 then
			co.sleep(1)
		end
		
		local ok,err = co.wait_player(pl)
		if not ok then dbg("ChangeOutfitThread","ABORT",pl,"VANISH",err) return end
		
		local hash  = pl:OutfitHash()
		local ret,err = ChangeOutfitThreadWorker(pl,hash)
			
		local ok,err = co.wait_player(pl) -- Check for player validity
		if not ok then 
			dbg("ChangeOutfitThread","ABORT",pl,"VANISH",err)
			return
		end
		
		if not ret then
			dbg("ChangeOutfit",pl,"RETERR",err or "???")
		end
		
		local newhash = pl:OutfitHash()
		if pl:OutfitCheckHash(hash) then
			if i>1 then
				dbge("ChangeOutfitThread","finished changing after",i,"iterations",pl)
				
			end
			break
		end
	end
	pl.outfitter_changing = false
	
end

local function HBAD(pl,hash)
	local ok = pl:OutfitCheckHash(hash)
	return not ok
end
-- DoChangeOutfit: NO callback. NOT to be called from coroutine.

--TODO: change to iterative to fix shit
function ChangeOutfitThreadWorker(pl,hash)
	
	
	
	assert(pl:OutfitCheckHash(hash))
	assert(not HBAD(pl,hash))
	
	local mdl,wsid,skin,bodygroups = pl:OutfitInfo()
	mdl = mdl or false

	dbg("ChangeOutfit","BEGIN",pl,mdl or "unset",wsid)
	
	-- 1. Check whether we just want to reset
	if not mdl then RESET(pl) return true end
	
	-- 2. If model exists then just apply it
	local exists = HasMDL(mdl)
	if exists then
		
		local ret = hook.Run("CanOutfit",pl,pl:OutfitInfo())
		if ret == false then 
			return false,"canoutfit" 
		end
		
		if HBAD(pl,hash) then return false,"outdated" end
		
		local ok,err = SET(pl,mdl,wsid,skin,bodygroups)
		if not ok then
			dbge("DoChangeOutfit","setfail but was existing?",err)
		end
		
		return true
	end
	
	------------ TIME PASSES ONLY HERE -------------
	local ok, err = NeedWS(wsid,pl,mdl)
	if not ok then 
		dbg("DoChangeOutfit","NeedWS failed",err,"continuing...",pl,mdl,wsid)
	end
	
	local ok,err = co.wait_player(pl) -- so check for player validity
	if not ok then 
		dbg("ChangeOutfit","ABORT",pl,"VANISH",err)
		return false,"noplayer"
	end
	------------------------------------------------
	
	-- 3. Time passed, we may need to abort if some new outfit is waiting
	if HBAD(pl,hash) then return false,"outdated" end
	
	-- 4. if model doesnt exist then screw it
	if not HasMDL(mdl) then
		dbg("DoChangeOutfit","HASMDL",pl,mdl,wsid)
		RESET(pl)
		return false,"mdl"
	end
	
	-- 5. Check CanOutfit
	local ret = hook.Run("CanOutfit",pl,pl:OutfitInfo())
	if ret == false then 
		return false,"canoutfit" 
	end
	
	-- 6. The hook may have changed our outfit
	if HBAD(pl,hash) then return false,"outdated" end
	
	-- 7. Actually set the outfit!
	SET(pl,mdl,wsid,skin,bodygroups)
	
	dbg("ChangeOutfit","FINISHED",pl,mdl or "unset",wsid)
	
	return true
end

function RemoveOutfit()
	NetworkOutfit()
	OnChangeOutfit(LocalPlayer())
end

function BroadcastMyOutfit(a)
	assert(not a)
	local mdl,wsid,s,bg = LocalPlayer():OutfitInfo()
	dbg("BroadcastMyOutfit",mdl,wsid,s,bg)
	
	NetworkOutfit(mdl,wsid)
	
	return mdl,wsid
	
end

