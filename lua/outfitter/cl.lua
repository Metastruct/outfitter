local Tag='outfitter' 
local NTag = 'OF'

module(Tag,package.seeall)

	
-- Incoming new outfit
-- We dont' know if model or wsid exist
local function RESET(pl)
	pl:EnforceModel(false)
	pl.outfitter_mdl = nil
	pl.outfitter_wsid = nil
end
local function SET(pl,mdl,wsid)
	
	if mdl and not IsEnabled() then return end
	
	local ret = pl:EnforceModel(mdl)
	pl.outfitter_mdl = mdl
	pl.outfitter_wsid = wsid
	if not ret then
		dbge("SET FAIL?",ret,mdl,wsid)
	end
	UIOnEnforce(pl)
	return ret
end

function DisableEverything()
	dbg("DisableEverything")
	for _,pl in next,player.GetAll() do
		if pl.outfitter_nvar then
			pl.outfitter_nvar = nil
			
			-- force instant disable
			pl.latest_want = nil 
			OnChangeOutfit(pl,nil,nil)
			
		end
	end
end

function EnableEverything()
	dbg("EnableEverything")
	for _,pl in next,player.GetAll() do
		OnPlayerVisible(pl)
	end
end

function OnChangeOutfit(pl,mdl,wsid)
	dbg("OnChangeOutfit",pl,mdl=="false" and "unset" or ('%q'):format(tostring(mdl)),wsid==false and "" or ('%q'):format(tostring(wsid)))
	
	assert(pl and pl:IsValid())
	pl:GetModel()
	assert((mdl and wsid) or (not mdl and not wsid))
	assert(mdl~="")
	assert(wsid~=0)
	assert(wsid~=0)
	
	mdl = mdl and mdl:gsub("%.mdl$","")
	
	co(coDoChangeOutfit,pl,mdl..'.mdl',wsid)
	
	return 
end

function coDoChangeOutfit_FIN(pl,mdl,wsid)
	
	local mdl2 = pl.latest_want
	local want_changed = (mdl ~= mdl2)
	pl.latest_want = false
	
	if want_changed then
		local wsid2 = pl.latest_want_wsid
		dbg("ChangeOutfit","WANT CHANGED",mdl,wsid,"->",mdl2,wsid2)
		return coDoChangeOutfit(pl,mdl2,wsid2)
	end
	
end

function PlStillWant(pl,mdl)
	return mdl == pl.latest_want
end
-- DoChangeOutfit: NO callback. NOT to be called from coroutine.
function coDoChangeOutfit(pl,mdl,wsid)
	
	local prev_want = pl.latest_want

	dbg("DoChangeOutfit","BEGIN",pl,mdl,wsid,prev_want)
	
	pl.latest_want = mdl
	pl.latest_want_wsid = wsid
	
	if prev_want then
		dbg("DoChangeOutfit","already in progress",pl,mdl,wsid,prev_want)
		coDoChangeOutfit_FIN(pl,mdl,wsid)
		return false,"changing"
	end
	
	if not mdl then
		RESET(pl)
		coDoChangeOutfit_FIN(pl,mdl,wsid)
		return true
	end
	
	local exists = HasMDL(mdl)
	
	if exists then
		local ok = SET(pl,mdl,wsid)
		if not ok then
			dbg("DoChangeOutfit","setfail")
		end
		coDoChangeOutfit_FIN(pl,mdl,wsid)
		return true
	end
	
	
	local ok, err = NeedWS(wsid,pl,mdl)
	if not ok then 
		dbg("DoChangeOutfit","NeedWS failed",err,"continuing...",pl,mdl,wsid) 
		-- return -- it doesnt hurt to recheck
	end
	
	
	-- -------------- TIME PASSES HERE ---------------
	
	
	--TODO: check player is not asking for another outfit already 
	-- Only one can be running at a time for a player
	
	if not pl:IsValid() then 
		dbg("Player vanished!!!",pl)
		-- Useless: coDoChangeOutfit_FIN(pl,mdl,wsid)
		return false,"noplayer"
	end

	if not HasMDL(mdl) then
		dbg("DoChangeOutfit","HASMDL",pl,mdl,wsid)
		RESET(pl)
		coDoChangeOutfit_FIN(pl,mdl,wsid)
		return false,"mdl"
	end
	
	local want = PlStillWant(pl,mdl)
	if not want then
		dbg("DoChangeOutfit","OBSOLETE",pl,mdl,wsid)
		coDoChangeOutfit_FIN(pl,mdl,wsid)
		return false,"obsolete"
	end
	
	SET(pl,mdl,wsid)
	
	return true
	
end

function RemoveOutfit()
	NetworkOutfit()
	OnChangeOutfit(LocalPlayer())
end

function BroadcastMyOutfit(mdl,wsid)
		local mdl = mdl or LocalPlayer().outfitter_mdl 
		local wsid = wsid or LocalPlayer().outfitter_wsid
		dbg("BroadcastMyOutfit",mdl,wsid)
		
		NetworkOutfit(mdl,wsid)
		
		return mdl,wsid
		
end