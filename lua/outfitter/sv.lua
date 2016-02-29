local Tag='outfitter' 
local NTag = 'OF'

setfenv(1,_G)

module(Tag,package.seeall)

util.AddNetworkString(Tag) 



function NetRateLimit(pl,k)
	local nextt = pl.outfitter_next or 0
	local now = RealTime()
	if nextt < now then
		nextt = now + (pl.outfitter_limiter or 15)
		return true,nextt
	end
	return false,nextt-now
end

function RateLimitMessage(pl,passok)
	if not passok then
		pl:ChatPrint"[Outfitter] you need to wait more before sending a new outfit"
	end
	return passok
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
	
	pl.outfitter_mdl = mdl
	pl.outfitter_wsid = wsid
	
	dbg("NetData",pl,"outfit",mdl,wsid)
	
	if not val then return true end
		
	local ret = SanityCheckNData(mdl,wsid)
	
	if ret~=nil then 
		dbg("NetData",pl,"sanity check fail",tostring(val):sub(1,256))
		return ret
	end
	
	local ret = RateLimitMessage(pl,NetRateLimit(pl,k))
	if ret~=true then
		dbg("NetData",pl,"ratelimiting")
		--return -- TODO
	end
	
	local loaded = util.IsModelLoaded(mdl)
	if not loaded and StringTable then
		dbg("adding to stringtable",mdl)
		StringTable("modelprecache"):AddString(true,mdl)
	end

	
	return true
end
