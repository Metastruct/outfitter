local Tag='outfitter' 
local NTag = 'OF'


module(Tag,package.seeall)

util.AddNetworkString(Tag) 

function RateLimitMessage(pl,rem)
	local msg = "[Outfitter] you need to wait before sending a new outfit ("..rem.." seconds remaining)"
	pl:ChatPrint(msg)
end

local ent
function PrecacheModel(mdl)

	local loaded = util.IsModelLoaded(mdl)
	if loaded then return end
	
	dbg("ADDING TO LIST",('%q'):format(mdl))
	
	if StringTable then
		StringTable("modelprecache"):AddString(true,mdl)
		return
	end
	
	if not ent or not ent:IsValid() then
		ent = ents.Create'base_entity'
		if not ent or not ent:IsValid() then return end
		
		ent:SetNoDraw(true)
		ent:Spawn()
		ent:SetNoDraw(true)
		
	end
	
	ent:SetModel(mdl)
	
end

function NetData(pl,k,val)
	if k~=NTag then return end
	dbg("NetData","receiving outfit from",pl)
	
	if not isstring(val) and val~=nil then
		dbg(pl,"val",type(val))
		return false 
	end
	
	local mdl,wsid 
	if val then
		
		if #val>2048*2 or #val==0 then 
			dbg("NetData","badval",#val,pl)
			return false 
		end
		
		mdl,wsid = DecodeOW(val)
		
	end
	
	local ret = hook.Run("CanOutfit",pl,mdl,wsid)
	if ret == false then return false end
	
	pl:OutfitSetInfo(mdl,wsid)
	
	dbg("NetData",pl,"outfit",mdl,wsid)
	
	if not val then return true end
		
	local ret = SanityCheckNData(mdl,wsid)
	
	if ret~=nil then 
		dbg("NetData",pl,"sanity check fail",tostring(val):sub(1,256))
		return ret
	end
	
	assert(mdl)
	
	local should,remaining = pl:NetDataShouldLimit(NTag,util.IsModelLoaded(mdl) and 3 or 10)
	
	if should then
		RateLimitMessage(pl,remaining)
		dbg("NetData",pl,"ratelimiting",string.NiceTime(remaining))
		return -- TODO
	end
	
	PrecacheModel(mdl)
	
	return true
end
