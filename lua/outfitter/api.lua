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
    end

    function api.unblock(mdl)
        if not mdl then return end
        blocklist[mdl] = nil
        save_blocklist(blocklist)
    end

    function api.is_blocked(mdl)
        if not mdl then return false end
        return blocklist[mdl] == true
    end

    function api.get_blocklist()
        return blocklist
    end
end

hook.Add("CanOutfit", Tag, function(pl, mdl, download_info)
    if api.is_blocked(mdl) then return false end
end)

_M.api = api
