local Tag = 'outfitter'
module(Tag, package.seeall)

---@class OutfitterData
---@field mdl string Model path (e.g. "models/player/kleiner.mdl")
---@field download_path string|false Workshop ID, HTTP URL, or false if no download source
---@field skin number|nil Skin index
---@field bodygroups table|nil Bodygroup overrides (e.g. {HeadAttachment = 0, Backpack = 2})
---@field dependency_manifest table|nil Dependency manifest {version = 1, dependencies = {"wsid1", "wsid2"}}

local api = rawget(_M,'api') or {}

---Returns the currently applied outfit, or nil if no outfit is set.
---@return OutfitterData|nil
function api.get_current()
	local pl = LocalPlayer()
	if not pl or not pl:IsValid() then return nil end
	local mdl, download_path, skin, bodygroups, dependency_manifest = pl:OutfitInfo()
	if not mdl then return nil end
	return {
		mdl = mdl,
		download_path = download_path,
		skin = skin,
		bodygroups = bodygroups,
		dependency_manifest = dependency_manifest
	}
end

---Clears the current outfit and resets to the default player model.
function api.clear()
	RemoveOutfit()
end

---Applies an outfit from a data table.
---Also broadcasts the outfit to the server if a valid download_path is present.
---@param data OutfitterData
---@return boolean ok Whether the application was started successfully
---@return string|nil err Error reason on failure
function api.apply(data)
	if not data or not data.mdl then return false, "no_model" end

	local pl = LocalPlayer()
	if not pl or not pl:IsValid() then return false, "no_player" end

	local download_path = data.download_path
	if download_path == nil then download_path = false end

	OnChangeOutfit(pl, data.mdl, download_path, data.skin, data.bodygroups, data.dependency_manifest)

	local encoded = EncodeOutfitterPayload(data.mdl, download_path, data.dependency_manifest)
	if encoded then
		NetworkOutfit(data.mdl, download_path, data.dependency_manifest)
	end

	return true
end

do
    local blocklist_key = Tag .. '_model_blocklist'
    local function save_blocklist(t)
        util.SetPData("0", blocklist_key, json.encode(t))
    end
    local function load_blocklist()
        local s = util.GetPData("0", blocklist_key, false)
        if not s or s == "" or s == "nil" then return {} end
        local ok, t = pcall(json.decode, s)
        if not ok or not t then return {} end
        return t
    end
    local blocklist = load_blocklist()

    function api.block(mdl)
        if not mdl then return end
        blocklist[mdl] = true
        save_blocklist(blocklist)
        for _, ply in ipairs(player.GetAll()) do
            if ply.outfitter_mdl == mdl then
                ply:EnforceModel(false)
            end
        end
    end

    function api.unblock(mdl)
        if not mdl then return end
        blocklist[mdl] = nil
        save_blocklist(blocklist)
        for _, ply in ipairs(player.GetAll()) do
            local data = api.get_player_networked_data(ply)
            if data and data.mdl == mdl then
                ply.outfitter_nvar = nil
                OnPlayerVisible(ply)
            end
        end
    end

    function api.is_blocked(mdl)
        if not mdl then return false end
        return blocklist[mdl] == true
    end

    function api.get_blocklist()
        return blocklist
    end
end

---Returns the decoded networked outfit data for any player, or nil.
---@param ply Player
---@return OutfitterData|nil
function api.get_player_networked_data(ply)
    if not IsValid(ply) then return end
    local encoded = ply:GetNetData(NTag)
    if not encoded then return end
    local mdl, download_path, dependency_manifest = DecodeOutfitterPayload(encoded)
    if not mdl then return end
    return {
        mdl = mdl,
        download_path = download_path,
        dependency_manifest = dependency_manifest
    }
end

---Returns a human-readable description of why a player's outfit is not visible,
---along with the outfit data it relates to.
---@param ply Player
---@return string|nil status
---@return OutfitterData|nil data
function api.describe_outfit_error(ply)
    if not IsValid(ply) then return nil end

    local last = ply.outfitter_last_error
    local data = api.get_player_networked_data(ply)

    if last then
        local reason = ExplainErrorCode(last.error, last.download_path)
        return reason, { mdl = last.mdl, download_path = last.download_path }
    end

    if data then
        if api.is_blocked(data.mdl) then
            return "Hidden by your outfit blocklist", data
        end
        if ply.enforce_model == data.mdl then
            return nil
        end
        return "Unknown error", data
    end

    return nil
end

---Temporarily unblocks a player's outfit (session-only) and retries downloading/applying it.
---Clears the workshop fetch failure cache so a previously-blocked item is fetched again.
---@param ply Player
---@return boolean ok
---@return string|nil err
function api.retry_outfit(ply)
    if not IsValid(ply) then return false, "no_player" end

    local data = api.get_player_networked_data(ply)
    local mdl = data and data.mdl
    local download_path = data and data.download_path
    if not mdl then
        local cur = ply:OutfitInfo()
        if cur then mdl, download_path = cur end
    end
    if not mdl then return false, "no_outfit" end

    if api.is_blocked(mdl) then
        api.unblock(mdl)
    end

    if download_path and tonumber(download_path) then
        TemporarilyAllowWS(download_path)
        ResetWS(download_path)
    end

    ply.outfitter_last_error = nil
    ply.outfitter_nvar = nil
    OnPlayerVisible(ply)

    return true
end

hook.Add("CanOutfit", Tag, function(pl, mdl, download_info)
    if api.is_blocked(mdl) then return false end
end)

_M.api = api

if CLIENT then
    local T = language.GetPhrase

    properties.Add("outfitter", {
        MenuLabel = "#outfitter",
        Order = 22,
        MenuIcon = "icon16/user_go.png",
        PrependSpacer = true,

        Filter = function(self, ent, ply)
            if not IsValid(ent) then return false end
            if not ent:IsPlayer() then return false end
            if not IsEnabled() then return false end
            if not CanPlayerMenu() then return false end
            local mdl = ent:OutfitInfo()
            if mdl then return true end
            if api.get_player_networked_data(ent) then return true end
            return false
        end,

        MenuOpen = function(self, option, ent, tr)
            if not IsValid(ent) then return end
            local submenu = option:AddSubMenu()
            submenu:AddOption("Open Outfitter", function()
                GUIOpen()
            end):SetImage("icon16/application_view_list.png")
            local mdl, download_path = ent:OutfitInfo()

            if not mdl then
                local netdata = api.get_player_networked_data(ent)
                if netdata then
                    local reason, last
                    if ent.outfitter_last_error then
                        last = ent.outfitter_last_error
                        reason = ExplainErrorCode(last.error, last.download_path) or last.error or "Unknown error"
                    elseif api.is_blocked(netdata.mdl) then
                        reason = "Hidden by your outfit blocklist"
                    else
                        reason = "Unknown error"
                    end

                    submenu:AddOption(reason, function() end):SetImage("icon16/exclamation.png")

                    if api.is_blocked(netdata.mdl) then
                        submenu:AddOption("Unblock Outfit", function()
                            api.unblock(netdata.mdl)
                        end):SetImage("icon16/status_online.png")
                    end

                    submenu:AddOption("Temporarily Unblock & Retry", function()
                        api.retry_outfit(ent)
                    end):SetImage("icon16/arrow_refresh.png")

                    submenu:AddOption("Copy model path", function()
                        SetClipboardText(netdata.mdl)
                    end):SetImage("icon16/page_white_copy.png")

                    if netdata.download_path and tonumber(netdata.download_path) then
                        submenu:AddOption("Open Outfit Workshop Page", function()
                            gui.OpenURL("https://steamcommunity.com/workshop/filedetails/?id=" .. netdata.download_path)
                        end):SetImage("icon16/picture.png")
                    end
                    return
                end
            end

            if mdl then
                if api.is_blocked(mdl) then
                    submenu:AddOption("Unblock Outfit", function()
                        api.unblock(mdl)
                    end):SetImage("icon16/status_online.png")
                else
                    submenu:AddOption("Block Outfit", function()
                        api.block(mdl)
                    end):SetImage("icon16/status_offline.png")
                end
                local failed = ent.outfitter_last_error
                    or (download_path and _load_info_history[download_path] and _load_info_history[download_path].state == "error")
                if failed then
                    submenu:AddOption("Temporarily Unblock & Retry", function()
                        api.retry_outfit(ent)
                    end):SetImage("icon16/arrow_refresh.png")
                end
                submenu:AddOption("Copy model path", function()
                    SetClipboardText(mdl)
                end):SetImage("icon16/page_white_copy.png")
            end

            if download_path and tonumber(download_path) then
                submenu:AddOption("Open Outfit Workshop Page", function()
                    gui.OpenURL("https://steamcommunity.com/workshop/filedetails/?id=" .. download_path)
                end):SetImage("icon16/picture.png")
            end

            local developer = GetConVar("developer")
            local me = LocalPlayer()
            if IsValid(me) and me:IsAdmin() and developer and developer:GetBool() then
                local debugmenu = submenu:AddSubMenu("Debug", function() end, "icon16/wrench.png")
                debugmenu:AddOption("Copy my outfit to this bot", function()
                    local ok, err = SendDebugOutfitToBot(ent)
                    if not ok then
                        chat.AddText("[Outfitter] " .. tostring(err or "failed"))
                    end
                end)
                debugmenu:AddOption("Clear this bot's outfit", function()
                    local ok, err = SendDebugClearOutfit(ent)
                    if not ok then
                        chat.AddText("[Outfitter] " .. tostring(err or "failed"))
                    end
                end)
                debugmenu:AddOption("Dump outfit info", function()
                    local mdl, download_path, skin, bodygroups, dependency_manifest = ent:OutfitInfo()
                    PrintTable({
                        mdl = mdl,
                        download_path = download_path,
                        skin = skin,
                        bodygroups = bodygroups,
                        dependency_manifest = dependency_manifest
                    })
                end)
            end
        end,

        Action = function(self, ent)
            GUIOpen()
        end
    })
end
