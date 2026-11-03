local Tag = 'outfitter'

-- lua_openscript_cl srv/outfitter/lua/outfitter/ui.lua;lua_openscript_cl srv/outfitter/lua/outfitter/gui.lua;outfitter_open

module(Tag, package.seeall)

local ROW_HEIGHT = 24
local ROW_SPACING = 2
local ROW_LABEL_WIDTH = 110

local PrettyName = function(name)
	name = name and name:gsub("%.smd$", "") or ""
	name = name:gsub("([a-z0-9])([A-Z])([a-z])",
		function(q, a, b)
			return q .. ' ' .. a:lower() .. b
		end)
	name = name:gsub("[_%.%-]", " ")
	name = name:gsub("(%s)%s*", "%1")
	return name:sub(1, 1):upper() .. name:sub(2)
end

local function SkinName(skins, id)
	for slot, texture in ipairs(skins[id]) do
		local default_texture = skins[1][slot]
		if id == 1 or (default_texture and default_texture[1] ~= texture[1]) then
			local name = PrettyName(texture[1]:match("[^/\\]+$") or texture[1])
			if name ~= "" then return name end
		end
	end
	return language.GetPhrase("outfitter_skin_n"):format(id)
end

local PANEL = {}

function PANEL:Clear()
	for k, v in next, self:GetChildren() do v:Remove() end
end

function PANEL:Refresh()
	self:Clear()
	dbg("self.model")
	local a = mdlinspect.Open(self.model)
	a:ParseHeader()
	local parts = a:BodyPartsEx()
	self.parts = parts

	self.skins = a:ParseSkins()

	self:CreatePanels()
	self:InvalidateLayout()
end

function PANEL:UpdateBG()
	local t = {}
	for k, v in next, self.parts do
		if v.n then
			t[#t + 1] = ("%s=%s"):format(v.name, v.n)
		end
	end

	RunConsoleCommand("outfitter_bodygroups_set", table.concat(t, ","))
end

function PANEL:AddRow(text, tooltip)
	local row = self:Add("EditablePanel")
	row:Dock(TOP)
	row:DockMargin(0, 0, 0, ROW_SPACING)
	row:SetTall(ROW_HEIGHT)
	row:SetTooltip(tooltip or text)

	local label = row:Add("DLabel")
	label:Dock(LEFT)
	label:SetWide(ROW_LABEL_WIDTH)
	label:SetDark(true)
	label:SetText(text)

	local combo = row:Add("DComboBox")
	combo:Dock(FILL)
	combo:SetSortItems(false)

	self.row_count = self.row_count + 1
	return combo
end

function PANEL:CreatePanels()
	self.row_count = 0

	local pl = LocalPlayer()
	local on_model = pl:GetModel() == self.model
	local body_data = pl:GetBodyGroupData()

	local skin_count = #self.skins
	if skin_count > 1 then
		local current = on_model and math.Clamp(pl:GetSkin(), 0, skin_count - 1) or 0
		local combo = self:AddRow(language.GetPhrase("skin"), "#outfitter_skin_tip")
		combo:SetEnabled(on_model)
		for id = 1, skin_count do
			combo:AddChoice(SkinName(self.skins, id), id - 1, id - 1 == current)
		end
		combo.OnSelect = function(_, _, _, skin)
			RunConsoleCommand("outfitter_skin_set", tostring(skin))
		end
	end

	for k, part in next, self.parts do
		if #part.models < 2 then
			part.n = nil
			continue
		end

		local value = 0
		if on_model then
			value = body_data and math.floor(body_data / part.base) % #part.models or pl:GetBodygroup(k - 1)
		end
		part.n = math.Clamp(value, 0, #part.models - 1)

		local name = PrettyName(part.name)
		local combo = self:AddRow(name)
		combo:SetEnabled(on_model)
		for i, partmdl in ipairs(part.models) do
			local model_name = PrettyName(partmdl.name)
			if model_name == "" then
				model_name = language.GetPhrase("outfitter_bg_none")
			end
			combo:AddChoice(model_name, i - 1, i - 1 == part.n)
		end
		combo.OnSelect = function(_, _, _, n)
			part.n = n
			self:UpdateBG()
		end
	end

	if self.row_count == 0 then
		local empty = self:Add("DLabel")
		empty:Dock(TOP)
		empty:SetDark(true)
		empty:SetWrap(true)
		empty:SetAutoStretchVertical(true)
		empty:SetText("#outfitter_bg_empty")
	end

	self:SetTall(math.max(self.row_count * (ROW_HEIGHT + ROW_SPACING), ROW_HEIGHT * 2))
end

function PANEL:SetModel(mdl)
	self.model = mdl
	if not mdl then return end
	self:Refresh()
end

bodygroups_factor = vgui.RegisterTable(PANEL, "EditablePanel")
