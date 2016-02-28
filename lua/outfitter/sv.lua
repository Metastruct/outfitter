local Tag='outfitter' 

module(Tag,package.seeall)

util.AddNetworkString(Tag) 



function NetRateLimit(self,k)
	local nextt = self.outfitter_next or 0
	local now = RealTime()
	if nextt < now then
		nextt = now + (pl.outfitter_limiter or 15)
		return false,nextt
	end
	return true,nextt-now
end

function RateLimitMessage(pl,ratelimit)
	if ratelimit then
		pl:ChatPrint"you need to wait more before sending a new outfit"
	end
	return ratelimit
end


function NetData(pl,k,val)
	if k~=NTag then return end
	dbg("NetData",pl)
	
	if not isstring(val) and val~=nil then
		dbg(pl,"val",type(val))
		return false 
	end
	if #val>2048*2 or #val==0 then 
		dbg("NET","badval",#val,pl)
		return false 
	end
	
	local mdl,wsid 
	if val then
		mdl,wsid = DecodeOW(val)
	end
	pl.outfitter_mdl = mdl
	pl.outfitter_wsid = wsid
	
	if not val then return true end
		
	local ret = SanityCheckNData(mdl,wsid)
	
	if ret~=nil then 
		dbg(pl,"sanity check fail",tostring(val):sub(1,256))
		return ret
	end
	
	return RateLimitMessage(pl,NetRateLimit(pl,k))
	
end
