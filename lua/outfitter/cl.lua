local Tag='outfitter'
local NTag = 'OF'

module(Tag,package.seeall)
	
	
-- Incoming new outfit
-- We dont' know if model or download_info exist
local function RESET(pl)
	pl:EnforceModel(false)
	pl.outfitter_mdl = nil
	pl.outfitter_download_info = nil
	
	hook.Run("OutfitApply",pl,"","")
	
end
local function SET(pl)
	
	local mdl,download_info = pl:OutfitInfo()
	
	if mdl and not IsEnabled() then return false,"disabled" end
	if hook.Run("PreOutfitApply",pl,mdl,download_info)==false then return false,"hook" end
	
	if DidCrash('setmdl',mdl) then
		dbge("EnforceModel","CRASH",mdl,download_info)
		return false,"crash"
	end
	
	CRITICAL("setmdl",mdl)
	local ret = pl:EnforceModel(mdl)
	CRITICAL(false)
	
	pl.outfitter_mdl = mdl
	pl.outfitter_download_info = download_info
	if not ret then
		dbge("SET FAIL?",ret,mdl,download_info)
	end
	UIOnEnforce(pl)
	
	hook.Run("OutfitApply",pl,mdl,download_info)
	
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

function Player.SetWantOutfit(pl,mdl,download_info,skin,bodygroups)
	dbg("SetWantOutfit",pl,not mdl and "unset" or ('%q'):format(tostring(mdl)),not download_info and "-" or ('%q'):format(tostring(download_info)))
	
	assert(pl and pl:IsValid())
	pl:GetModel()
	assert((mdl and download_info~=nil) or (not mdl and download_info==nil))
	assert(mdl~="")
	assert(tonumber(download_info)~=0)
	
	mdl = mdl or false
	
	pl:OutfitSetInfo(mdl,download_info,skin,bodygroups)

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
		assert(i<8000,"loop fuckup")
		
		if i>1 then
			co.sleep(.5)
		end
		
		local ok,err = co.wait_player(pl)
		if not ok then dbg("ChangeOutfitThread","ABORT",pl,"VANISH",err) return end
		
		local hash  = pl:OutfitHash()
		local ret,err = ChangeOutfitThreadWorker(pl,hash)
			
		local ok,err2 = co.wait_player(pl) -- Check for player validity
		if not ok then
			dbg("ChangeOutfitThread","ABORT",pl,"VANISH",err2)
			return
		end
		
		if not ret then
			dbg("ChangeOutfit",pl,"ChangeOutfitThreadWorker ERROR:",err or "???")
		end
		
		local newhash = pl:OutfitHash()
		if pl:OutfitCheckHash(hash) then
			if i>1 then
				dbgn(3,"ChangeOutfitThread","finished changing after",i,"iterations",pl)
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
	
	local mdl,download_info,skin,bodygroups = pl:OutfitInfo()
	mdl = mdl or false

	dbg("ChangeOutfit","BEGIN",pl,mdl or "unset",download_info)
	
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
		
		local ok,err = SET(pl,mdl,download_info,skin,bodygroups)
		if not ok and IsEnabled() then
			dbge("DoChangeOutfit","Setting model failed, but file.Existed",err,mdl)
		end
		
		return true
	end
	
	------------ TIME PASSES ONLY HERE -------------
	local ok, err = AcquireAssets(download_info,pl,mdl)
	if not ok then
		dbg("DoChangeOutfit","NeedWS failed",err,"continuing...",pl,mdl,download_info)
		if err == 'oversize' then
			coUIOversizeMsg(pl,download_info)				
		end
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
		dbg("DoChangeOutfit","HasMDL()=false",pl,mdl,download_info)
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
	SET(pl,mdl,download_info,skin,bodygroups)
	
	dbg("ChangeOutfit","FINISHED",pl,mdl or "unset",download_info)
	
	return true
end

function AcquireAssets(download_info,pl,mdl)
	if download_info and tonumber(download_info) then
		return NeedWS(download_info,pl,mdl)
	end
	if IsHTTPURL(download_info) then
		if AllowedHTTPURL(download_info) then
			return NeedHTTPGMA(download_info,pl,mdl)
		else
			return nil,'URL not allowed: '..tostring(download_info)
		end
	end	
	return nil,'invalid download_info'
end

function RemoveOutfit()
	NetworkOutfit()
	OnChangeOutfit(LocalPlayer())
end

function BroadcastMyOutfit(a)
	assert(not a)
	local mdl,download_info,s,bg = LocalPlayer():OutfitInfo()
	dbg("BroadcastMyOutfit",mdl,download_info,s,bg)
	
	NetworkOutfit(mdl,download_info)
	
	return mdl,download_info
	
end

hook.Add("PlayerSlowThink",Tag,function(pl)
	if pl:InPVS() then
		OnPlayerVisible(pl)
	end
end)