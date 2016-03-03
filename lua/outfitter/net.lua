local Tag='outfitter' 
local NTag = 'OF'

module(Tag,package.seeall)

--function SetNeworked(o,w,pl)
--	if CLIENT then pl = LocalPlayer() end
--	local dat = EncodeOW(o,w)
--	pl:SetNetData(NTag,dat)
--end

if CLIENT then
	
	function NetData(plid,k,val)
		if k~=NTag then return end
		--local t = player.GetNetVarsTable()[plid]
		--assert(t)
		--t.outfitter_mdl,t.outfitter_wsid = DecodeOW(val)
		local pl = findpl(plid)
		dbg("NetData",pl or plid,k,"<-",val)
		if pl then OnPlayerVisible(pl) end
	end
		
	function OnPlayerVisible(pl)
		
		-- check for changed outfit data
		local new = pl:GetNetData(NTag)
		local old = pl.outfitter_nvar
		if new~=old then
			
			local me = LocalPlayer()
			
			if pl~=me then
				if not IsEnabled() then
					pl.outfitter_nvar = nil
					dbgn(2,"OnPlayerVisible","IsEnabled",pl)
					return
				end
			end
			
			pl.outfitter_nvar = new
			
			--if old == true then return end
			
			local mdl,wsid
			if new then
				mdl,wsid = DecodeOW(new)
			end
			
			dbgn(2,"OnPlayerVisible",pl==me and "SKIP" or pl,mdl or "UNSET?",wsid)
			
			if pl==me then
				dbg("OnPlayerVisible","SKIP","LocalPlayer")
				return
			end
			
			OnChangeOutfit(pl,mdl,wsid)
		end
		
	end


	hook.Add("NetworkEntityCreated",Tag,function(ent) 
		if ent:IsPlayer() then
			OnPlayerVisible(ent)
		elseif ent:GetClass() == "class C_HL2MPRagdoll" then
			local owner = ent:GetRagdollOwner()
			if owner:IsValid() then
				OnDeathRagdollCreated(ent,owner)
				return 
			end
		end
	end)

	local function OnPlayerPVS(pl,inpvs)
		if inpvs==false then return end
		OnPlayerInPVS(pl)
	end
	
	hook.Add("NotifyShouldTransmit",Tag,function(pl,inpvs)
		if pl:IsPlayer() then
			OnPlayerPVS(pl,inpvs)
		end
	end)
	
	-- I want to tell others about my outfit
	function NetworkOutfit(mdl,wsid)
		assert(not wsid or tonumber(wsid),('ASSERT: mdl=%q wsid=%q'):format(tostring(mdl),tostring(wsid)))
		
		if not mdl then mdl=nil wsid=nil end
		
		local encoded = mdl and EncodeOW(mdl and mdl:gsub("%.mdl$",""),wsid)
		dbg("NetworkOutfit",mdl,wsid,('%q'):format(tostring(encoded)))
		if not encoded then encoded=nil end
		
		LocalPlayer():SetNetData(NTag,encoded)
		
	end

end

hook.Add("NetData",Tag,function(...) return NetData(...) end)