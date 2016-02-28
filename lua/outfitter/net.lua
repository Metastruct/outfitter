local Tag='outfitter' 
local NTag = 'OF'

module(Tag,package.seeall)

function SetNeworked(o,w,pl)
	if CLIENT then pl = LocalPlayer() end
	local dat = EncodeOW(o,w)
	pl:SetNetData(NTag,dat)
end

if CLIENT then
	
	function NetData(plid,k,val)
		if k~=NTag then return end
		--local t = player.GetNetVarsTable()[plid]
		--assert(t)
		--t.outfitter_mdl,t.outfitter_wsid = DecodeOW(val)
		local pl = findpl(plid)
		dbg("NET",pl or plid,k,"<-",val)
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