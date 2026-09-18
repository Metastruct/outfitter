local Tag = 'outfitter'
local NTag = 'OF'
local NTagSkin = 'OFSkin'

module(Tag, package.seeall)
_M.NTagSkin = NTagSkin
_M.NTag = NTag

hook.Add("NetData", Tag, function(...) return NetData(...) end)

function SHNetworkOutfit(pl, mdl, download_info, dependency_manifest)
	--assert(not download_info or tonumber(download_info),('NetworkOutfit INVALID: mdl=%q download_info=%q'):format(tostring(mdl),tostring(download_info)))

	if not mdl then
		mdl = nil
		download_info = nil
		dependency_manifest = nil
	end

	local encoded, err = mdl and EncodeOutfitterPayload(mdl, download_info, dependency_manifest)
	dbg("NetworkOutfit", pl, mdl, download_info, DependencyManifestID(dependency_manifest), ('%q'):format(tostring(encoded)), err)
	if not encoded then encoded = nil end

	pl:SetNetData(NTag, encoded)
end

if CLIENT then
	function CyclePlayerModel(pl)
		dbgn(2, "CyclePlayerModel()")
		assert(not pl or pl == LocalPlayer())
		net.Start(Tag)
		net.SendToServer()
	end
end

if SERVER then
	return
end

function NetData(plid, k, val)
	if k ~= NTag then return end

	local pl = findpl(plid)
	dbg("NetData", pl or plid, k, "<-", val)
	if not pl then
		dbgn(11, "Skip netdata callback for", plid)
		return
	end

	OnPlayerVisible(pl, net.IsPlayerVarsBurst())
end

-- Repeatedly called on all visible players and sometimes invisible players due to dormant player state updates
function OnPlayerVisible(pl, initial_sendings)
	-- check for changed outfit data
	local new = pl:GetNetData(NTag)
	local old = pl.outfitter_nvar

	if new == old then
		return
	end

	pl.outfitter_nvar_burst = initial_sendings

	local me = LocalPlayer()
	if pl == me then
		timer.Simple(1, function()
			--CyclePlayerModel(pl)
		end)
	end

	-- local player is special snowflake due to engine
	if pl ~= me and new then
		if not IsEnabled() then
			pl.outfitter_nvar = nil
			dbgn(2, "OnPlayerVisible", "IsEnabled", pl)
			return
		end

		if VisibleFilter(me, pl) then
			dbgn(2, "OnPlayerVisible", "VisibleFiltering", pl)
			return
		end

		if IsHighPerf() then
			dbgn(2, "OnPlayerVisible", "high perf blocking")
			return
		end
	end

	--if old == true then return end

	local mdl, download_info, dependency_manifest
	if new then
		mdl, download_info, dependency_manifest = DecodeOutfitterPayload(new)

		local ret = hook.Run("CanOutfit", pl, mdl, download_info)
		if ret == false then return end
		if ret ~= true then
			if not IsFriendly(pl) then
				dbgn(3, "OnPlayerVisible", "unfriendly", pl)
				return
			end
		end
	end

	pl.outfitter_nvar = new

	hook.Run("CouldOutfit", pl, mdl, download_info)

	dbgn(2, "OnPlayerVisible", pl == me and "SKIP" or pl, mdl or "UNSET?", download_info)

	if pl == me then
		dbg("OnPlayerVisible", "SKIP", "LocalPlayer")
		return
	end

	OnChangeOutfit(pl, mdl, download_info, nil, nil, dependency_manifest)
end

hook.Add("NetworkEntityCreated", Tag, function(ent)
	if ent:IsPlayer() then
		OnPlayerVisible(ent)
	elseif ent:GetClass() == "class C_HL2MPRagdoll" then
		local owner = ent:GetRagdollOwner()
		if IsValid(owner) then
			OnDeathRagdollCreated(ent, owner)
			return
		end
	end
end)

local function OnPlayerPVS(pl, inpvs)
	if inpvs == false then return end
	OnPlayerInPVS(pl)
end

hook.Add("NotifyShouldTransmit", Tag, function(pl, inpvs)
	if pl:IsPlayer() then
		OnPlayerPVS(pl, inpvs)
	end
end)

-- I want to tell others about my outfit
function NetworkOutfit(...)
	return SHNetworkOutfit(LocalPlayer(), ...)
end

function RequestSkin(n)
	--TODO: don't overwrite client's preferences
	RunConsoleCommand("cl_playerskin", tostring(n or 1))

	net.Start(NTagSkin)
	net.WriteUInt(n or 1, 10)
	net.SendToServer()
end

local NTagDebug = 'OFDebug'
_M.NTagDebug = NTagDebug

-- Copy LocalPlayer's current outfit (model, download source, skin and bodygroups)
-- onto another player. The server does the actual applying and validates admin.
function SendDebugOutfitToBot(bot)
	if not IsValid(bot) then return false, "no target" end
	if not bot:IsBot() then return false, "not a bot" end

	local me = LocalPlayer()
	local mdl, download_info, skin, bodygroups, dep_manifest = me:OutfitInfo()
	if not mdl then return false, "no outfit" end

	local bg = {}
	for k, v in pairs(bodygroups or {}) do
		bg[#bg + 1] = ("%s=%d"):format(k, v)
	end

	dbg("SendDebugOutfitToBot", bot, mdl, download_info, "skin", skin, "bodygroups", table.concat(bg, ","))

	net.Start(NTagDebug)
	net.WriteEntity(bot)
	net.WriteString(mdl)
	net.WriteString(download_info and tostring(download_info) or "")
	net.WriteString(json.encode(dep_manifest or {}))
	net.WriteUInt(skin or 1, 10)
	net.WriteString(table.concat(bg, ","))
	net.SendToServer()

	return true
end

concommand.Add("outfitter_debug_setbot_outfit", function(pl, cmd, args)
	local me = LocalPlayer()
	if not IsValid(me) then return end

	local developer = GetConVar("developer")
	if not developer or not developer:GetBool() or not me:IsAdmin() then
		chat.AddText("[Outfitter] Requires developer 1 and admin")
		return
	end

	local bot
	local arg = tonumber(args[1])
	if arg then
		bot = Entity(arg)
	else
		local tr = me:GetEyeTrace()
		if tr and tr.Hit and tr.HitNonWorld and IsValid(tr.Entity) then
			bot = tr.Entity
		end
	end
	if not IsValid(bot) or not bot:IsBot() then
		chat.AddText("[Outfitter] Aim at a bot or pass its Entity index")
		return
	end

	local ok, err = SendDebugOutfitToBot(bot)
	if ok then
		chat.AddText("[Outfitter] Copied your outfit to " .. bot:Nick() .. " (" .. bot:EntIndex() .. ")")
	else
		chat.AddText("[Outfitter] " .. tostring(err))
	end
end, nil, "Copy your outfit (model, skin, bodygroups) to the bot you're aiming at (developer 1 + admin)")
