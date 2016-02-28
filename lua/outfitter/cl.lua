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
	pl:EnforceModel(mdl)
	pl.outfitter_mdl = mdl
	pl.outfitter_wsid = wsid
end
function OnChangeOutfit(pl,mdl,wsid)
	dbg("OnChangeOutfit",pl,mdl=="false" and "unset" or ('%q'):format(tostring(mdl)),wsid==false and "" or ('%q'):format(tostring(wsid)))

	assert((mdl and wsid) or (not mdl and not wsid))
	assert(mdl~="")
	assert(wsid~=0)
	assert(wsid~=0)
	
	mdl = mdl and mdl:gsub("%.mdl$","")
	

	if not mdl then
		RESET(pl)
		return true
	end
	
	return DoChangeOutfit(pl,mdl..'.mdl',wsid)
end

function DoChangeOutfit(...)
	if co.make(...) then return end
	local pl,mdl,wsid = ...
	
	dbg("DoChangeOutfit",...)
	
	local exists = HasMDL(mdl)
	
	if exists then
		SET(pl,mdl,wsid)
		return true
	end
		
	if not NeedWS(wsid) then 
		dbg("DoChangeOutfit","NeedWS failed, continuing",...) 
		-- return -- it doesnt hurt to recheck
	end

	if not HasMDL(mdl) then
		dbg("DoChangeOutfit","FAIL",...)
		RESET(pl)
		return false,"hasmdl"
	end
	
	SET(pl,mdl,wsid)
	
	return true
	
end

function BroadcastMyOutfit(mdl,wsid)
		local mdl = mdl or LocalPlayer().outfitter_mdl 
		local wsid = wsid or LocalPlayer().outfitter_wsid
		dbg("BroadcastMyOutfit",mdl,wsid)
		
		NetworkOutfit(mdl,wsid)
		
		return mdl,wsid
		
end