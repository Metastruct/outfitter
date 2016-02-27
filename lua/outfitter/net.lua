local Tag='outfitter' 
local NTag = 'OF'

module(Tag,package.seeall)


--TODO: hex encoding at least
function EncodeOW(o,w)
	return w..','..o
end

function DecodeOW(str)
	local w,o = str:match'^(%d-),(.*)$'
	w = tonumber(w)
	return o,w
end

function SetNeworked(o,w,pl)
	if CLIENT then pl = LocalPlayer() end
	local dat = EncodeOW(o,w)
	pl:SetNetData(NTag,dat)
end


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

function SanityCheckNData(mdl,wsid)
	
	if not mdl then return false end
	if not wsid then return false end
	if mdl=="" or #mdl>2048*2 then return false end
	if mdl:find("  ",1,true) or mdl:find("..",1,true) or mdl:find("\t",1,true) or mdl:find("\n",1,true) then return false end
	if wsid<=0 then return false end
end

function NetData(pl,k,val)
	if k~=NTag then return end
	if not isstring(val) and val~=nil then return false end
	if #val>2048*2 or #val==0 then return false end
	
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

local function findpl(uid)
	for _,pl in next,player.GetAll() do 
		if pl:UserID()==uid then
			return pl
		end
	end
end	

if CLIENT then
	function NetData(plid,k,val)
		if k~=NTag then return end
		--local t = player.GetNetVarsTable()[plid]
		--assert(t)
		dbg(plid,k,val)
		--t.outfitter_mdl,t.outfitter_wsid = DecodeOW(val)
		local pl = findpl(plid)
		if pl then OnPlayerVisible(pl) end
	end
	
	function OnPlayerVisible(pl)
		
		-- check for changed outfit data
		local new = pl:GetNetData(NTag)
		local old = pl.outfitter_nvar

		if new~=old then
			pl.outfitter_nvar = new
			
			local mdl,wsid
			if new then
				mdl,wsid = DecodeOW(new)
			end
			
			OnChangeOutfit(pl,mdl,wsid)
		end
		
	end

	hook.Add("NetworkEntityCreated",Tag,function(pl) 
		if not pl:IsPlayer() then return end 
		OnPlayerVisible(pl) 
	end)

	hook.Add("NotifyShouldTransmit",Tag,function(pl,inpvs)
		if pl:IsPlayer() then
			OnPlayerPVS(pl,inpvs)
		end
	end)
	
	-- I want to tell others about my outfit
	function BroadcastOutfit(mdl,wsid)
		assert(wsid and tonumber(wsid))
		LocalPlayer():SetNetData(Tag,EncodeOW(mdl:gsub("%.mdl$",""),wsid))
	end	
	
end

hook.Add("NetData",Tag,function(...) return NetData(...) end)