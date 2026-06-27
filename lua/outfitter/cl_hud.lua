local Tag = 'outfitter'
module(Tag, package.seeall)

local outfitter_info_hud = CreateClientConVar("outfitter_info_hud", "1", true, false, "Show outfit info in HUD when context menu is open")

local FONT = "TargetID"
local FONT_SM = "TargetIDSmall"

local function ResolveTitle(download_path)
    if not download_path then return end
    local info = _load_info_history[download_path]
    if info and info.title then return info.title end
    if tonumber(download_path) then
        local cached = _ws_cache and _ws_cache[download_path]
        if cached and istable(cached) then
            local fileinfo = cached[1]
            if istable(fileinfo) and isstring(fileinfo.title) then
                return fileinfo.title
            end
        end
    end
end

local function ResolveSizeStr(download_path)
    if not download_path then return end
    if tonumber(download_path) then
        local cached = _ws_cache and _ws_cache[download_path]
        if cached and istable(cached) then
            local fileinfo = cached[1]
            if istable(fileinfo) and fileinfo.size then
                return string.NiceSize(fileinfo.size)
            end
        end
    end
end

hook.Add("HUDPaintBackground", Tag, function()
    if not outfitter_info_hud:GetBool() then return end
    if not input.IsKeyDown(KEY_C) then return end
    if not IsEnabled() then return end

    local ply = LocalPlayer()
    if not ply then return end

    local tr = ply:GetEyeTrace()
    if not tr or not tr.Hit or not tr.HitNonWorld then return end
    local ent = tr.Entity
    if not IsValid(ent) or not ent:IsPlayer() then return end

    local mdl, download_path = ent:OutfitInfo()

    local status
    local status_color
    local title
    local size_str

    if mdl then
        local info = download_path and _load_info_history[download_path]
        if info then
            if info.state == "error" then
                status = "Failed: " .. (info.error or "unknown")
                status_color = Color(255, 120, 120)
            elseif info.state == "loading" then
                status = "Loading..."
                status_color = Color(255, 255, 120)
            else
                status = "Ready"
                status_color = Color(120, 255, 120)
            end
        elseif ent.outfitter_changing then
            status = "Loading..."
            status_color = Color(255, 255, 120)
        elseif not HasMDL(mdl) then
            status = "Pending..."
            status_color = Color(200, 200, 120)
        else
            status = "Ready"
            status_color = Color(120, 255, 120)
        end
        title = ResolveTitle(download_path)
        size_str = ResolveSizeStr(download_path)
    else
        if api.get_player_networked_data(ent) then
            status = "Unknown error"
            status_color = Color(255, 120, 120)
            mdl = "?"
        else
            local last = ent.outfitter_last_error
            if last then
                status = "Failed: " .. (last.error or "unknown")
                status_color = Color(255, 120, 120)
                mdl = last.mdl or "?"
                title = ResolveTitle(last.download_path)
            else
                return
            end
        end
    end

    local mouse_x, mouse_y = input.GetCursorPos()
    if (mouse_x == 0 and mouse_y == 0) or not vgui.CursorVisible() then
        mouse_x, mouse_y = ScrW() / 2, ScrH() / 2
    end

    local lines = {}
    if title then
        lines[#lines + 1] = {text = title, color = Color(200, 200, 255), font = FONT}
    end
    lines[#lines + 1] = {text = mdl, color = Color(255, 255, 255), font = FONT_SM}
    if status ~= "Ready" then
        lines[#lines + 1] = {text = status, color = status_color, font = FONT_SM}
    end
    if size_str then
        lines[#lines + 1] = {text = size_str, color = Color(180, 180, 180), font = FONT_SM}
    end

    local total_w = 0
    local total_h = 0
    for _, l in ipairs(lines) do
        surface.SetFont(l.font)
        l.w, l.h = surface.GetTextSize(l.text)
        if l.w > total_w then total_w = l.w end
        total_h = total_h + l.h + 2
    end
    total_h = total_h + 6
    total_w = total_w + 16

    local right_x = mouse_x - 24
    local x0 = right_x - total_w
    local y = mouse_y + 30

    surface.SetDrawColor(0, 0, 0, 180)
    surface.DrawRect(x0, y - 4, total_w, total_h)
    surface.SetDrawColor(90, 90, 90, 200)
    surface.DrawOutlinedRect(x0, y - 4, total_w, total_h)

    for _, l in ipairs(lines) do
        surface.SetFont(l.font)
        draw.SimpleText(l.text, l.font, right_x - l.w, y, l.color)
        y = y + l.h + 2
    end
end)
