if SERVER then
    AddCSLuaFile()
    return
end

local TAG = "OutfitterDependencyMounter"
local STATUS_COMMAND = "outfitter_dependency_mounter_status"
local MAX_DEPENDENCY_DEPTH = 4

hook.Remove("PreOutfitApply", TAG)
if concommand.Remove then
    concommand.Remove(STATUS_COMMAND)
end

local status = {}
local waiting = {}
local mounted = {}

local function log(text, is_error)
    MsgC(
        is_error and Color(255, 135, 135) or Color(120, 200, 255),
        "[Outfitter Dependency Mounter] ",
        Color(255, 255, 255),
        tostring(text) .. "\n"
    )
end

local function merge_ids(target, seen, values)
    for _, value in ipairs(values or {}) do
        local id = tostring(value or ""):match("^%d+$")
        if id and #id >= 5 and not seen[id] then
            seen[id] = true
            target[#target + 1] = id
        end
    end
end

local function dependency_ids(children)
    local ids = {}
    local seen = {}

    for key, value in pairs(children or {}) do
        local candidate = value

        if istable(candidate) then
            candidate = candidate.publishedfileid or candidate.fileid or candidate.id
        elseif isbool(candidate) then
            candidate = key
        end

        merge_ids(ids, seen, { candidate })
    end

    return ids
end

local function fetch_info(id, callback)
    if not steamworks or not isfunction(steamworks.FileInfo) then
        callback(nil)
        return
    end

    steamworks.FileInfo(id, function(info)
        callback(istable(info) and info or nil)
    end)
end

local function required_items_from_html(body)
    local ids = {}
    local seen = {}
    local start_pos = body:find('id="RequiredItems"', 1, true)
    if not start_pos then return ids end

    local end_pos = body:find("<!-- created by -->", start_pos, true)
    local section = body:sub(start_pos, end_pos or math.min(#body, start_pos + 150000))

    for id in section:gmatch("workshop/filedetails/%?id=(%d+)") do
        merge_ids(ids, seen, { id })
    end

    for id in section:gmatch("sharedfiles/filedetails/%?id=(%d+)") do
        merge_ids(ids, seen, { id })
    end

    return ids
end

local function fetch_dependencies(id, callback)
    fetch_info(id, function(info)
        local ids = {}
        local seen = {}
        merge_ids(ids, seen, dependency_ids(info and info.children))

        if not isfunction(HTTP) then
            callback(ids)
            return
        end

        HTTP({
            method = "GET",
            url = "https://steamcommunity.com/sharedfiles/filedetails/?id=" .. id,
            headers = {
                ["Cookie"] = "wants_mature_content_item_" .. id .. "=1; birthtime=0; lastagecheckage=1-January-1970",
            },
            success = function(code, body)
                if code == 200 and isstring(body) then
                    merge_ids(ids, seen, required_items_from_html(body))
                end
                callback(ids)
            end,
            failed = function()
                callback(ids)
            end,
        })
    end)
end

local function mount_item(id, callback)
    if mounted[id] then
        callback(true)
        return
    end

    if not outfitter or
        not isfunction(outfitter.FetchWS) or
        not isfunction(outfitter.MountWS) then
        callback(false, "Outfitter is not ready")
        return
    end

    outfitter.FetchWS(id, function(path, err, err2)
        if not path then
            callback(false, tostring(err or err2 or "download failed"))
            return
        end

        local ok, mount_error = outfitter.MountWS(path)
        if not ok then
            callback(false, tostring(mount_error or "mount failed"))
            return
        end

        mounted[id] = true
        callback(true)
    end)
end

local function run_series(items, worker, callback)
    local index = 0

    local function next_item(ok, err)
        if ok == false then
            callback(false, err)
            return
        end

        index = index + 1
        local item = items[index]
        if not item then
            callback(true)
            return
        end

        worker(item, next_item)
    end

    next_item(true)
end

local function resolve_item(id, depth, lineage, callback)
    if mounted[id] or lineage[id] then
        callback(true)
        return
    end

    if depth > MAX_DEPENDENCY_DEPTH then
        callback(false, "dependency nesting is too deep")
        return
    end

    local next_lineage = table.Copy(lineage)
    next_lineage[id] = true

    fetch_dependencies(id, function(children)
        run_series(children, function(child, child_done)
            resolve_item(child, depth + 1, next_lineage, child_done)
        end, function(ok, err)
            if not ok then
                callback(false, err)
                return
            end

            mount_item(id, callback)
        end)
    end)
end

local function reapply_waiting_outfits(root)
    local outfits = waiting[root] or {}
    waiting[root] = nil

    for ply, outfit in pairs(outfits) do
        if IsValid(ply) and isfunction(ply.SetWantOutfit) then
            timer.Simple(0, function()
                if IsValid(ply) and isfunction(ply.SetWantOutfit) then
                    ply:SetWantOutfit(outfit.model, outfit.download, outfit.skin, outfit.bodygroups)
                end
            end)
        end
    end
end

local function finish_root(root, ok, err)
    status[root] = ok and "ready" or "failed"

    if ok then
        log("Mounted required addons for Workshop " .. root)
    else
        log("Could not mount every required addon for Workshop " .. root .. ": " .. tostring(err), true)
    end

    reapply_waiting_outfits(root)
end

local function begin_root(root)
    status[root] = "loading"

    fetch_dependencies(root, function(children)
        if #children == 0 then
            finish_root(root, true)
            return
        end

        log("Workshop " .. root .. " requires: " .. table.concat(children, ", "))

        run_series(children, function(child, done)
            resolve_item(child, 1, { [root] = true }, done)
        end, function(ok, err)
            finish_root(root, ok, err)
        end)
    end)
end

hook.Add("PreOutfitApply", TAG, function(ply, model, download_info)
    local root = tostring(download_info or ""):match("^%d+$")
    if not root then return end

    local root_status = status[root]
    if root_status == "ready" or root_status == "failed" then return end

    waiting[root] = waiting[root] or setmetatable({}, { __mode = "k" })
    waiting[root][ply] = {
        model = model,
        download = download_info,
        skin = ply.outfitter_skin,
        bodygroups = ply.outfitter_bodygroups,
    }

    if root_status ~= "loading" then
        begin_root(root)
    end

    return false
end)

concommand.Add(STATUS_COMMAND, function()
    local roots = {}
    for id, value in pairs(status) do
        roots[#roots + 1] = id .. "=" .. value
    end
    table.sort(roots)

    local mounted_ids = {}
    for id in pairs(mounted) do
        mounted_ids[#mounted_ids + 1] = id
    end
    table.sort(mounted_ids)

    log("roots: " .. (#roots > 0 and table.concat(roots, ", ") or "none"))
    log("mounted dependencies: " .. (#mounted_ids > 0 and table.concat(mounted_ids, ", ") or "none"))
end)

log("Installed. Outfitter Workshop dependencies will be mounted before outfits are applied.")
