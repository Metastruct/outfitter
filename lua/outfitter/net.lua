local Tag='outfitter'
local NTag = 'OF'

module(Tag,package.seeall)

hook.Add("NetData",Tag,function(...) return NetData(...) end)

function SHNetworkOutfit(pl,mdl,wsid)
	assert(not wsid or tonumber(wsid),('ASSERT: mdl=%q wsid=%q'):format(tostring(mdl),tostring(wsid)))
	
	if not mdl then mdl=nil wsid=nil end
	
	local encoded = mdl and EncodeOW(mdl and mdl:gsub("%.mdl$",""),wsid)
	dbg("NetworkOutfit",pl,mdl,wsid,('%q'):format(tostring(encoded)))
	if not encoded then encoded=nil end
	
	pl:SetNetData(NTag,encoded)

end

if CLIENT then
	function CyclePlayerModel(pl)
		dbgn(2,"CyclePlayerModel()")
		assert(not pl or pl==LocalPlayer())
		net.Start(Tag)
		net.SendToServer()
	end
end

if SERVER then return end

function NetData(plid,k,val)
	if k~=NTag then return end

	local pl = findpl(plid)
	dbg("NetData",pl or plid,k,"<-",val)
	if not pl then 
		dbgn(11,"Skip netdata callback for",plid)
		return
	end

	OnPlayerVisible(pl,net.IsPlayerVarsBurst())
	
end
	
function OnPlayerVisible(pl,initial_sendings)
	
	-- check for changed outfit data
	local new = pl:GetNetData(NTag)
	local old = pl.outfitter_nvar
	
	if new==old then
		return
	end
	
	pl.outfitter_nvar_burst = initial_sendings
	
	local me = LocalPlayer()
	if pl==me then
		timer.Simple(1,function()
			--CyclePlayerModel(pl)
		end)
	end
	-- local player is special snowflake
	if pl~=me and new then
		
		if not IsEnabled() then
			pl.outfitter_nvar = nil
			dbgn(2,"OnPlayerVisible","IsEnabled",pl)
			return
		end
		
		if VisibleFilter(me,pl) then
			dbgn(2,"OnPlayerVisible","VisibleFiltering",pl)
			return
		end
			
		if IsHighPerf() then
			dbgn(2,"OnPlayerVisible","high perf blocking")
			return
		end
		
	end
	
	--if old == true then return end
	
	local mdl,wsid
	if new then
		mdl,wsid = DecodeOW(new)
	
		local ret = hook.Run("CanOutfit",pl,mdl,wsid)
		if ret == false then return end
		if ret ~= true then
			if not IsFriendly(pl) then
				dbgn(3,"OnPlayerVisible","unfriendly",pl)
				return
			end
		end
		
	end
	
	pl.outfitter_nvar = new
	
	hook.Run("CouldOutfit",pl,mdl,wsid)
	
	dbgn(2,"OnPlayerVisible",pl==me and "SKIP" or pl,mdl or "UNSET?",wsid)
	
	if pl==me then
		dbg("OnPlayerVisible","SKIP","LocalPlayer")
		return
	end
	
	OnChangeOutfit(pl,mdl,wsid)
	
	
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
function NetworkOutfit(...)
	return SHNetworkOutfit(LocalPlayer(),...)
end
