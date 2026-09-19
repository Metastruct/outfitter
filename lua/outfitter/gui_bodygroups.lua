local Tag = 'outfitter'

-- lua_openscript_cl srv/outfitter/lua/outfitter/ui.lua;lua_openscript_cl srv/outfitter/lua/outfitter/gui.lua;outfitter_open

module(Tag, package.seeall)



local RADIO_FONT = "BudgetLabel"

local CCHECKED = Color(111, 255, 111, 255)
local CSTROKE  = Color(200, 200, 200, 255)
local CBGON    = Color(55, 55, 55, 255)
local CBGSEL   = Color(70, 100, 70, 255)

local function text_height(s, width)
	surface.SetFont(RADIO_FONT)
	local _, fh = surface.GetTextSize("Ay")
	if fh <= 0 then fh = 13 end
	if width <= 10 then width = 100 end
	local lines = 0
	for _, para in ipairs(string.Explode("\n", s or "")) do
		local lw, count = 0, 1
		local first = true
		for _, word in ipairs(string.Explode(" ", para)) do
			local ww = surface.GetTextSize(word)
			local sp = surface.GetTextSize(" ")
			if not first and lw + ww + sp > width then
				count = count + 1
				lw = ww
			else
				lw = lw + ww + sp
			end
			first = false
		end
		lines = lines + count
	end
	return lines * fh
end

local PANEL = {}
function PANEL:Init()
	self.checked = false
	self:SetCursor("hand")
	self:SetTall(20)
	self.lbl = vgui.Create("DLabel", self, "radio label")
	self.lbl:Dock(FILL)
	self.lbl:DockMargin(18, 1, 4, 1)
	self.lbl:SetFont(RADIO_FONT)
	self.lbl:SetWrap(true)
end

function PANEL:SetDescription(s)
	self.d = s or ""
	self.lbl:SetText(self.d)
	self:SetTooltip(self.d)
end

function PANEL:SetChecked(checked)
	self.checked = checked
end

function PANEL:OnMousePressed(mc)
	if mc ~= MOUSE_LEFT then return end
	surface.PlaySound("ui/buttonclick.wav")
	self:GetParent():SetChecked(self.n)
end

function PANEL:PerformLayout(w, h)
	self.lbl:SetSize(w, h)
end

function PANEL:Paint(w, h)
	draw.RoundedBox(3, 0, 0, w, h, self.checked and CBGSEL or CBGON)
	if self.checked then
		surface.SetDrawColor(CCHECKED)
		surface.DrawRect(2, 2, 8, 8)
	end
end
local radiobtn = vgui.RegisterTable(PANEL, "EditablePanel")





local PANEL = {}
function PANEL:Init()
	self.radios = self.radios or {}
end

function PANEL:OnSelected(n, pnl)
end

function PANEL:SetText(t)
	if not self.header then
		self.header = vgui.Create("DLabel", self, "group header")
		self.header:Dock(TOP)
		self.header:DockMargin(2, 4, 2, 2)
		self.header:SetFont(RADIO_FONT)
		self.header:SetWrap(true)
		self.header:SetAutoStretchVertical(true)
	end
	self.header:SetText(t)
	self:InvalidateLayout()
end

function PANEL:AddOption(description, letter)
	self.n = (self.n or 0) + 1
	local n = self.n

	local pnl = vgui.CreateFromTable(radiobtn, self, 'radiolist')
	pnl.n = n
	pnl:SetDescription(description == "" and "disable" or description)
	pnl:Dock(TOP)
	pnl:DockMargin(2, 1, 2, 1)

	self.radios = self.radios or {}
	self.radios[n] = pnl
	return n, pnl
end

function PANEL:SetChecked(n)
	for k, v in next, self.radios do
		v:SetChecked(k == n)
	end
	self:OnSelected(n)
end

function PANEL:PerformLayout(w, h)
	local t = 0
	if IsValid(self.header) then
		self.header:SetWide(w)
		t = t + self.header:GetTall() + 6
	end
	for k, v in next, self.radios do
		v:SetTall(math.max(20, text_height(v.d, w) + 4))
		t = t + v:GetTall() + 2
	end
	self:SetTall(t)
end

vgui.Register('OFRadioBatton', PANEL, "EditablePanel")

local PrettyName = function(name)
	name = name and name:gsub("%.smd$", "") or ""
	name = name:gsub("([a-z0-9])([A-Z])([a-z])",
		function(q, a, b)
			return q .. ' ' .. a:lower() .. b
		end)
	name = name:gsub("[_%.%-]", " ")
	name = name:gsub("(%s)%s*", "%1")
	return name
end






local PANEL = {}
function PANEL:Init()
end

function PANEL:Think()
end

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

function PANEL:OnSelected(part, n)
	part.n = n
	self:UpdateBG()
end

function PANEL:CreatePanels()
	-- skin
	local r = self:Add("OFRadioBatton")
	r.OnSelected = function(r, setskin_id)
		RunConsoleCommand("outfitter_skin_set", tostring(setskin_id))
		LocalPlayer().outfitter_skin = setskin_id
	end

	r:SetText("#skin")
	r:Dock(TOP)
	r:SizeToContents()

	for id, skindata in pairs(self.skins) do
		r:AddOption(skindata[1][1], tostring(id - 1))
	end

	r:SetChecked(LocalPlayer().outfitter_skin or 1)

	local divider = self:Add("EditablePanel")
	divider:SetSize(1, 16)
	divider:Dock(TOP)
	-- bodygroups
	local activeBodyGroups = LocalPlayer().outfitter_bodygroups or {}

	for k, part in next, self.parts do
		if #part.models < 2 then continue end

		local r = self:Add("OFRadioBatton")
		r.OnSelected = function(r, n) self:OnSelected(part, n - 1) end

		r:SetText(PrettyName(part.name))
		r:Dock(TOP)

		local n = 0
		for k, partmdl in next, part.models do
			local name = PrettyName(partmdl.name)
			if name ~= "" then
				n = n + 1
			end
			local n, pnl = r:AddOption(name == "" and "disable" or name, name == "" and "" or n)
		end

		r:SetChecked((activeBodyGroups[part.name] or 0) + 1)
	end
end

function PANEL:SetModel(mdl)
	self.model = mdl
	if not mdl then return end
	self:Refresh()
end

function PANEL:PerformLayout()
	self:SizeToChildren(false, true)
end

bodygroups_factor = vgui.RegisterTable(PANEL, "EditablePanel")



function GUIOpenBodyGroupOverlay(owner, mdl)
	if not mdl then
		local l = UIGetMDLList()
		if not l then return end
		--print(l)
		local chosen = UIGetChosenMDL()
		if not chosen then return false end
		--print(chosen)
		mdl = l[chosen]
		if not mdl then return false end
		mdl = mdl.Name

		if not mdl then return false end
		if not file.Exists(mdl, 'workshop') and not file.Exists(mdl, 'GAME') then return false end
	end

	dbg("GUIOpenBodyGroupOverlay", mdl)

	local frame = vgui.Create('DFrame', nil, 'bodygroups selector')
	frame:SetDraggable(false)
	frame:SetSizable(false)
	frame:SetScreenLock(true)
	frame:SetDeleteOnClose(true)
	frame:SetTitle("Bodygroup and skin selector")
	frame:ShowCloseButton(false)
	frame:SetIcon('icon16/group_edit.png')
	frame.pnlOwner = owner
	frame:MakePopup()
	frame:RequestFocus()
	function frame:Think()
		if not self.fframe then
			self.fframe = true
			return
		end

		if not self:IsActive() then
			print "noactive"
			self:Remove()
			return
		end
		if self.pnlOwner and (not self.pnlOwner:IsValid() or not self.pnlOwner:IsVisible()) then
			self:Remove()
			print "noparent"
			return
		end
		local x, y = self:GetPos()

		local w, h = self:GetSize()
		local sw, sh = ScrW(), ScrH()
		local nx, ny = (x + w) > sw and (sw - w) or x,
			(y + h) > sh and (sh - h) or y
		if x ~= nx or y ~= ny then
			self:SetPos(nx, ny)
		end
	end

	local W, H = 250, 400 -- TODO: Autoscale GUI
	frame:SetSize(W, H)
	frame:SetPos(gui.MousePos())
	timer.Simple(60, function()
		if IsValid(frame) then frame:Remove() end
	end)

	local orig_mdl = LocalPlayer().original_model or LocalPlayer():GetModel()
	local info = util.GetModelInfo(orig_mdl)
	local skinCount = info and info.SkinCount or 0
	if skinCount < 2 then
		local warn = vgui.Create('DLabel', frame)
		warn:Dock(TOP)
		warn:DockMargin(4, 4, 4, 0)
		warn:SetWrap(true)
		warn:SetAutoStretchVertical(true)
		warn:SetTextColor(Color(226, 85, 85))
		warn:SetFont("BudgetLabel")
		local msg =
		"Changing skin might not work due to a GMod bug (need serverside playermodel with two or more skins)."
		if _G.pac then msg = msg .. '\n NOTE: PAC entity part prevents changing skin, change in PAC instead.' end
		warn:SetText(msg)
	end

	local scrollpanel = vgui.Create('DScrollPanel', frame)
	scrollpanel:Dock(FILL)

	local bodygrouper = vgui.CreateFromTable(bodygroups_factor, scrollpanel)
	bodygrouper:Dock(TOP)
	bodygrouper:SetModel(mdl)
	return true
end

--GUIOpenBodyGroupOverlay()
