local Tag = 'outfitter'
local NTag = 'OF'

-- lua_openscript_cl srv/outfitter/lua/outfitter/ui.lua;lua_openscript_cl srv/outfitter/lua/outfitter/gui.lua;outfitter_open

module(Tag, package.seeall)
local NOUI = OUTFITTER_NO_UI

local outfitter_gui_focusdim = CreateClientConVar("outfitter_gui_focusdim", "0", true, false, "#outfitter_gui_focusdim")
local vgui = GetVGUI()

-- GUIWantChangeModel
local PANEL = {}

local matUp = Material "icon16/arrow_up.png"

function PANEL:Init()
	local txt = vgui.Create('DLabel', self, 'msg')
	txt:Dock(TOP)
	txt:SetText "#outfitter_urlmsg"
	txt:SetTextColor(Color(0, 0, 0, 255))
	local b = vgui.Create('DButton', self.top, 'choose button')

	self.chooseb = b
	b:Dock(RIGHT)
	b:SetIcon("icon16/accept.png")
	b:SetText "#select_character"
	b:SizeToContents()

	b:SetWidth(math.min(b:GetSize(), 256) + 32)
	b:SetEnabled(false)
	b:SetZPos(100)
	b:SetCookieName("ofchoosewsbutn")
	b.hideusehint = b:GetCookie("hideusehint")
	b:NoClipping(false)
	b.PaintOver = function(b, w, h)
		if b:IsEnabled() then
			DisableClipping(true)

			surface.SetDrawColor(30, 255, 0, 30)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(66, 255, 22, 255 * .5 + 255 * .3 * (math.sin(RealTime() * 7) > 0.3 and 1 or -1))
			surface.SetDrawColor(66, 255, 22, 255 * .5 + 255 * .3 * (math.sin(RealTime() * 7) > 0.3 and 1 or -1))

			surface.DrawOutlinedRect(-1, -1, w + 2, h + 2)
			surface.DrawOutlinedRect(0, 0, w, h)


			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(matUp)
			local sz = 32
			surface.DrawTexturedRect(w * .5 - sz * .5, h - 2 + math.sin(RealTime() * 7) * 4, sz, sz)

			DisableClipping(false)
		end
	end

	b.DoClick = function(b, mc)
		b.hideusehint = true
		b:SetCookie("hideusehint", '1')
		self:WSChoose()
	end
	self:GetBrowser():AddFunction("gmod", "wssubscribe", function() self:WSChoose() end)
end

function PANEL:WSChoose()
	self:Hide()
	if self.chosen_id then
		surface.PlaySound "npc/vort/claw_swing1.wav"
		UIChoseWorkshop(self.chosen_id, self.returntoui, true)
	end
end

function PANEL:LoadedURL(url, title)
	self.BaseClass.LoadedURL(self, url, title)
	if not url or url == "" then return end

	-- sharedfiles/filedetails/?id=422403917&searchtext=playermodel

	local id = UrlToWorkshopID(url)
	self.chooseb:SetEnabled(id and true or false)
	self.chosen_id = tonumber(id)
	--print(id)
end

function PANEL:InjectScripts(browser)
	--dbg("Injecting browser code",browser or "NOBROWSER")
	browser:QueueJavascript [[
		
			function SubscribeItem() {
				gmod.wssubscribe();
			};
			
			setTimeout(function() {
				function SubscribeItem() {
					gmod.wssubscribe();
				};
			
				var sub = document.getElementById("SubscribeItemOptionAdd");
				if (sub) {
					sub.innerText = "Select";
				};
			}, 0);
			
		]]
end

function PANEL:Show(str, returntoui)
	self.returntoui = returntoui

	local dourl = not self.already_loaded
	self.already_loaded = true

	local url =
	'http://steamcommunity.com/workshop/browse/?appid=4000&searchtext=playermodel&childpublishedfileid=0&browsesort=trend&section=readytouseitems&requiredtags%5B%5D=Model'
	if str then
		str = str and tostring(str)
		str = str and #str > 0 and str
		if str then
			str = string.urlencode and string.urlencode(str) or str
			url = 'http://steamcommunity.com/workshop/browse/?appid=4000&searchtext=playermodel+' ..
			str .. '&childpublishedfileid=0&browsesort=trend&section=readytouseitems&requiredtags%5B%5D=Model'
		end
	end

	if dourl then
		self:OpenURL(url)
	end
	self.BaseClass.Show(self)
end

function PANEL:CheckEntryURLChange()
	if self.chooseb:IsEnabled() then return end
	local txt = self.entry and self.entry:GetValue()
	if not txt then return end
	if txt ~= self.lasttextobserved then
		self.lasttextobserved = txt
		local id = UrlToWorkshopID(txt)
		--print("checked entry, found",id,"from",txt)
		self.chooseb:SetEnabled(id and true or false)
		self.chosen_id = tonumber(id)
	end
end

function PANEL:Think()
	self.BaseClass.Think(self)
	self:CheckEntryURLChange()
end

vgui.Register(Tag, PANEL, 'custombrowser')

m_vModelDlg = NULL
function GUIWantChangeModel(str, returntoui)
	if not ValidPanel(m_vModelDlg) then
		local d = vgui.Create(Tag, nil, Tag)
		m_vModelDlg = d
	end

	m_vModelDlg:Show(str, returntoui)

	return m_vModelDlg
end

function GUIReviewDependencies(graph, dependency_manifest, cb)
	local text_color = Color(20, 20, 20)
	local unavailable_color = Color(125, 35, 35)
	local status_ok_color = Color(20, 95, 35)
	local status_error_color = Color(135, 25, 25)

	local function paint_frame(_, w, h)
		surface.SetDrawColor(238, 238, 238, 255)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(210, 210, 210, 255)
		surface.DrawRect(0, 0, w, 24)
		surface.SetDrawColor(70, 70, 70, 255)
		surface.DrawOutlinedRect(0, 0, w, h)
	end

	local function set_check_text_color(check, color)
		check:SetTextColor(color)
		if check.Label then check.Label:SetTextColor(color) end
	end

	local frame = vgui.Create('DFrame', nil, 'dependency selector')
	frame:SetDeleteOnClose(true)
	frame:SetTitle("Outfitter dependencies")
	frame:SetIcon('icon16/bricks.png')
	frame:SetSize(math.min(ScrW() - 64, 720), math.min(ScrH() - 64, 560))
	frame.Paint = paint_frame
	frame:Center()
	frame:MakePopup()

	local selected = {}
	local normalized = NormalizeDependencyManifest(dependency_manifest)
	if normalized then
		for _, id in next, normalized.dependencies do
			if graph.nodes[id] and not graph.nodes[id].error and id ~= graph.root then
				selected[id] = true
			end
		end
	else
		for _, id in next, graph.order do
			if not graph.nodes[id].error then
				selected[id] = true
			end
		end
	end

	local finished
	local function finish(manifest)
		if finished then return end
		finished = true
		cb(manifest)
		frame:Remove()
	end

	frame.OnClose = function()
		finish(false)
	end

	local info = frame:Add("DLabel")
	info:Dock(TOP)
	info:DockMargin(8, 8, 8, 4)
	info:SetWrap(true)
	info:SetAutoStretchVertical(true)
	info:SetTextColor(text_color)
	info:SetText("#outfitter_depinfo")

	local status = frame:Add("DLabel")
	status:Dock(BOTTOM)
	status:DockMargin(8, 4, 8, 4)
	status:SetTall(22)

	local buttons = frame:Add("EditablePanel")
	buttons:Dock(BOTTOM)
	buttons:DockMargin(8, 4, 8, 8)
	buttons:SetTall(28)

	local cancel = buttons:Add("DButton")
	cancel:Dock(LEFT)
	cancel:SetWide(80)
	cancel:SetText("#dialog.cancel")
	cancel:SetImage("icon16/cancel.png")
	cancel.DoClick = function()
		finish(false)
	end

	local none = buttons:Add("DButton")
	none:Dock(RIGHT)
	none:SetWide(190)
	none:SetText("#outfitter_depcontwo")
	none:SetImage("icon16/delete.png")
	none.DoClick = function()
		finish(MakeDependencyManifest())
	end

	local accept = buttons:Add("DButton")
	accept:Dock(RIGHT)
	accept:DockMargin(0, 0, 4, 0)
	accept:SetWide(190)
	accept:SetImage("icon16/accept.png")

	local scroll = frame:Add("DScrollPanel")
	scroll:Dock(FILL)
	scroll:DockMargin(8, 4, 8, 4)

	local list = scroll:Add("DListLayout")
	list:Dock(TOP)

	local function selected_manifest()
		local dependencies = {}
		for _, id in next, graph.order do
			if selected[id] then
				dependencies[#dependencies + 1] = id
			end
		end

		return MakeDependencyManifest(dependencies)
	end

	local function selected_size()
		local root = graph.nodes[graph.root]
		local size = root and root.size or 0
		local dependency_size = 0
		local count = 0
		for id in next, selected do
			if selected[id] then
				local node = graph.nodes[id]
				local node_size = node and node.size or 0
				dependency_size = dependency_size + node_size
				size = size + node_size
				count = count + 1
			end
		end
		return size, dependency_size, count
	end

	local function refresh()
		local size, dependency_size, count = selected_size()
		local maxsize = OutfitMaxSize()
		local oversize = maxsize > 0.1 and size > maxsize

		status:SetText(("%d selected, %s dependencies, %s with outfit, %s limit"):format(count,
			string.NiceSize(dependency_size), string.NiceSize(size),
			maxsize > 0.1 and string.NiceSize(maxsize) or "no"))
		status:SetTextColor(oversize and status_error_color or status_ok_color)
		accept:SetText(oversize and "Increase limit and accept" or "Use selected dependencies")
	end

	local seen = {}
	local function add_dependency(id, depth)
		if seen[id] then return end
		seen[id] = true

		local node = graph.nodes[id]
		if not node or id == graph.root then return end

		local row = list:Add("EditablePanel")
		row:SetTall(28)

		local open = row:Add("DButton")
		open:Dock(RIGHT)
		open:SetWide(34)
		open:SetText("")
		open:SetImage("icon16/world.png")
		open:SetTooltip("#outfitter_openws")
		open.DoClick = function()
			gui.OpenURL("https://steamcommunity.com/sharedfiles/filedetails/?id=" .. id)
		end

		local check = row:Add("DCheckBoxLabel")
		check:Dock(FILL)
		check:DockMargin(math.max(0, depth - 1) * 16, 2, 4, 2)
		local text = ("%s [%s] (%s)"):format(node.title or "Unknown workshop item", id, string.NiceSize(node.size))
		if node.error then
			text = text .. " - unavailable: " .. node.error
		end
		check:SetText(text)
		check:SetTooltip(node.error and ("Unavailable: " .. node.error) or ("Workshop " .. id))
		check:SetChecked(selected[id] and true or false)
		check:SetEnabled(not node.error)
		set_check_text_color(check, node.error and unavailable_color or text_color)
		check.OnChange = function(_, value)
			selected[id] = value and true or nil
			refresh()
		end

		for _, child in next, node.children do
			add_dependency(child, depth + 1)
		end
	end

	for _, child in next, graph.nodes[graph.root].children do
		add_dependency(child, 1)
	end

	accept.DoClick = function()
		local size = selected_size()
		local maxsize = OutfitMaxSize()
		if maxsize > 0.1 and size > maxsize then
			outfitter_maxsize:SetInt(math.ceil(size / 1000 / 1000))
		end
		finish(selected_manifest())
	end

	refresh()
end

-- GUIOpen



local PANEL = {}
function PANEL:Init()
	local functions = self:Add('DPanel', 'settings')
	functions:Dock(LEFT)
	functions:SetWidth(300)
	functions:SetHeight(300)
	functions:DockMargin(4, 1, 24, 0)
	functions:SetPaintBackground(false)

	--functions:EnableVerticalScrollbar()

	local function Add(itm, b)
		local c = vgui.Create(itm, functions, b)
		--settingslist:AddItem(c)
		c:Dock(BOTTOM)
		return c
	end

	do
		local b = functions:Add('DButton', 'choose button')
		self.btn_choose = b

		b:Dock(TOP)
		b:SetText("#open_workshop")
		b:SetTooltip [[#outfitter_choosemdl]]

		b.DoClick = function()
			GUIWantChangeModel(nil, true)

			self:GetParent():Hide()
		end
		b:DockMargin(0, 4, 1, 8)
		b:SetImage 'icon16/folder_user.png'
		b.PaintOver = function(b, w, h)
			if not next(self.mdllist:GetLines()) then
				b:NoClipping(false)
				surface.SetDrawColor(140, 255, 140, 255 * .5 + 255 * .3 * math.sin(RealTime() * 4))

				surface.DrawOutlinedRect(-1, -1, w + 2, h + 2)
				surface.DrawOutlinedRect(0, 0, w, h)
				b:NoClipping(true)
			end
		end
	end
	do
		local b = functions:Add('DTextEntry', 'url input')
		self.input_mdlsource = b

		b:Dock(TOP)
		b:SetText("")
		b:SetPlaceholderText("https://steamcommunity.com/sharedfiles/filedetails/?id=1234")

		b.OnEnter = function()
			local url = b:GetValue():Trim()
			if url == "puze" then
				url = "https://g2cf.metastruct.net/delme/puze.gma"
			end
			local wsid = UrlToWorkshopID(url, true)
			dbg("GUI", "UrlToWorkshopID", url, wsid)
			if wsid then
				surface.PlaySound "npc/vort/claw_swing1.wav"
				UIChoseWorkshop(wsid, true, true)
				self:GetParent():Hide()
			else
				if IsHTTPURL(url) then
					if AllowedHTTPURL(url) then
						self:GetParent():Hide()
						UIChoseHTTPGMA(url, true)
					else
						chat.AddText("#outfitter_warnlist")
						surface.PlaySound "common/warning.wav"
					end
				else
					dbg("Not HTTP URL", url)
					surface.PlaySound "common/warning.wav"
				end
			end
		end
		b:DockMargin(0, 4, 1, 8)
	end

	local l = functions:Add("DLabel", 'chosen')
	self.lbl_chosen = l
	l:Dock(TOP)
	l:DockMargin(1, 1, 1, 1)
	l:SetWrap(true)
	l:SetTooltip [[#outfitter_ws_title]]
	l:SetText("#outfitter_choose_ws")
	l:SetTall(44)
	l:SetFont "BudgetLabel"
	l:SetTextColor(Color(255, 255, 255, 255))

	local dependencies = functions:Add("DButton", 'dependencies')
	self.btn_dependencies = dependencies
	dependencies:Dock(TOP)
	dependencies:DockMargin(0, 1, 1, 4)
	dependencies:SetText("#outfitter_deps")
	dependencies:SetImage("icon16/bricks.png")
	dependencies:SetTooltip("#outfitter_review_deps")
	dependencies:SetVisible(false)
	dependencies.DoClick = function()
		local wsid = UIGetWSID()
		if not wsid then return end

		co(function()
			local dependency_manifest, err = coUIReviewDependencies(wsid, UIGetDependencyManifest())
			if dependency_manifest == false then return end
			if not dependency_manifest then
				return UIError("Dependency review failed: " .. tostring(err))
			end

			UIApplyDependencyManifest(dependency_manifest)
			GUIRefresh()
		end)
	end



	local mdllist = functions:Add("DListView", 'modelname')
	mdllist:SetMultiSelect(false)
	mdllist:AddColumn("#gameui_playermodel")
	self.mdllist = mdllist
	mdllist:SetTooltip [[#outfitter_choose_of]]
	mdllist:DockMargin(0, 5, 0, 0)
	mdllist:Dock(FILL)
	mdllist:SetTall(128)
	mdllist.OnRowSelected = function(mdllist, n, itm)
		local ret = GUIChooseMDL(n)
		if not ret then
			surface.PlaySound "common/warning.wav"
		end
		self.btn_bg:Refresh()
	end
	--TODO : OnRowRightClick
	function mdllist.PerformLayout(mdllist)
		DListView.PerformLayout(mdllist)
		self.btn_bg:InvalidateLayout()
	end

	mdllist.PaintOver = function(b, w, h)
		if next(mdllist:GetLines()) and not mdllist:GetSelectedLine() then
			mdllist:NoClipping(false)
			surface.SetDrawColor(255, 66, 22, 255 * .5 + 255 * .3 * math.sin(RealTime() * 4))

			surface.DrawOutlinedRect(-1, -1, w + 1, h + 1)
			surface.DrawOutlinedRect(0, 0, w, h)
			mdllist:NoClipping(true)
		end
	end

	local sheet = self:Add("DPropertySheet")
	self.sheet = sheet
	sheet:Dock(FILL)

	local mdlhistpanel = self:Add("EditablePanel")
	self.mdlhistpanel = mdlhistpanel
	sheet:AddSheet("#servers_history", mdlhistpanel, "icon16/user.png")
	local settingspnl = self:Add("DScrollPanel")
	self.settingspnl = settingspnl
	sheet:AddSheet("#spawnmenu.utilities.settings", settingspnl, "icon16/cog.png")
	local blocklistPanel = self:Add("EditablePanel")
	self.blocklistPanel = blocklistPanel
	sheet:AddSheet("#Blocklist", blocklistPanel, "icon16/stop.png")
	local infopanel = self:Add("EditablePanel")
	self.infopanel = infopanel
	infopanel.Think = function()
		infopanel.Think = function() end

		local p = vgui.CreateFromTable(about_factory, infopanel)
		self.aboutpnl = p
		--print"create about"
		infopanel.aboutpnl = p
		p:Dock(FILL)
	end
	infopanel:Dock(FILL)
	sheet:AddSheet("#information", infopanel, "icon16/information.png")

	local function AddS(itm, b)
		local c = vgui.Create(itm, settingspnl, b)
		--settingslist:AddItem(c)
		c:Dock(TOP)
		return c
	end




	----------------------------------------------------


	blocklistPanel:DockPadding(2, 1, 2, 1)


	local txt = blocklistPanel:Add('DLabel', 'infomsg')
	txt:Dock(TOP)
	txt:SetText "#outfitter_titlebl"
	txt:SetWrap(true)
	txt:SetTextColor(Color(0, 0, 0, 255))



	local check = blocklistPanel:Add("DCheckBoxLabel", 'nsfwtoggle')
	check:SetConVar("nsfw")
	check:SetText("#outfitter_allownsfw")
	check:SizeToContents()
	check:SetTooltip [[#outfitter_allownsfwtip]]
	check:DockMargin(1, 0, 1, 1)
	check:Dock(TOP)

	local TextEntry = blocklistPanel:Add("DTextEntry", "blocklist")
	TextEntry:SetSize(100, 200)
	TextEntry:Dock(FILL)
	TextEntry:SetValue(table.concat(GetTitleBlocklist(), "\n"))
	TextEntry:SetMultiline(true)
	TextEntry:SetVerticalScrollbarEnabled(true)
	TextEntry:SetAllowNonAsciiCharacters(true)
	TextEntry:SetEditable(true)
	TextEntry:SetTooltip "#outfitter_title_blacklist"
	TextEntry:SetPlaceholderText "#outfitter_title_blacklist"
	function TextEntry.OnLoseFocus()
		SetTitleBlocklist(TextEntry:GetValue())
		TextEntry:SetValue(table.concat(GetTitleBlocklist(), "\n"))
	end
	----------------------------------------------------

	mdlhistpanel:DockPadding(2, 1, 2, 1)

	local function hr()
		local b = AddS('EditablePanel')
		b:SetTall(2)
		b:DockMargin(1, 24, 1, 2)
		b.Paint = function(b, w, h)
			surface.SetDrawColor(240, 240, 240, 200)
			surface.DrawRect(0, 0, w, h)
		end
		local hr_line1 = b
	end

	local scroll = mdlhistpanel:Add("DScrollPanel", 'mdlhistscroll')
	scroll:Dock(FILL)
	local mdlhist = scroll:Add("DIconLayout", 'mdlhist')
	mdlhist:DockMargin(4, 4, 4, 4)
	--mdlhist:SetMultiSelect( false )
	--mdlhist:AddColumn( "#name" )
	--mdlhist:AddColumn( "#gameui_playermodel" )
	self.mdlhist = mdlhist


	mdlhist:Dock(FILL)
	mdlhist.OnRowSelected = function(mdlhist, n, itm)
		local dat = GUIGetHistory()[n]
		if not dat then return end
		if not self:WantOutfitMDL(unpack(dat)) then
			surface.PlaySound "common/warning.wav"
		end
	end

	function mdlhist:Clear()
		local chld = self:GetChildren()
		for k, v in pairs(chld) do
			v:Remove()
		end
	end

	local b = mdlhistpanel:Add('DButton', 'choose button')
	self.btn_clearhist = b

	b:Dock(BOTTOM)

	b:SetText("#gameui_clearbutton")
	b.DoClick = function()
		GUIClearHistory()
	end
	b:DockMargin(0, 5, 0, 0)
	b:SetImage 'icon16/bin.png'



	local check = AddS("DCheckBoxLabel")
	check:SetConVar(Tag .. "_enabled")
	check:SetText("#gameui_enabled")
	check:SizeToContents()
	check:SetTooltip [[#outfitter_on_tip]]
	check:DockMargin(1, 0, 1, 1)
	local btn_en = check

	local check = AddS("DCheckBoxLabel")
	check:SetConVar(Tag .. "_friendsonly")
	check:SetText("#outfitter_friendsonly")
	check:SetTooltip [[#outfitter_friendsonlytip]]
	check:SizeToContents()

	check:DockMargin(1, 4, 1, 1)
	local d_5 = check

	hr()

	local slider = AddS("DNumSlider")
	slider:SetText("#outfitter_dldistance")
	slider:SizeToContents()
	slider:DockPadding(0, 16, 0, 0)
	slider.Label:Dock(TOP)
	slider.Label:DockMargin(0, -16, 0, 0)
	slider:SetTooltip [[#outfitter_dldistancetip]]

	slider:DockMargin(1, 12, 1, 1)
	slider:SetMin(0)
	slider:SetMax(5000)
	slider:SetDecimals(0)
	slider:SetConVar(Tag .. '_distance')
	local sld_dist = slider

	local c = AddS("DComboBox")
	c:SetSize(100, 20)
	c:SetTooltip [[#outfitter_distmode]]
	--c.SetValue = function(c,val)
	--	local setv = val==0 and 2 or val==1 and 3 or 1
	--	dbgn(2,"ChooseDistanceModeCtrl",val,'->',setv)
	--	c:ChooseOptionID(setv)
	--end
	local distance_mode
	c.OnSelect = function(c, val)
		distance_mode = distance_mode or GetConVar(Tag .. '_distance_mode')
		local choose = val == 1 and -1 or val == 2 and 0 or 1
		dbgn(2, "ChooseDistanceMode", val, '->', choose)
		distance_mode:SetInt(choose)
	end
	c:AddChoice("#outfitter_def", '-1')
	c:AddChoice("#outfitter_seo", '0')
	c:AddChoice("#outfitter_noo", '1')

	c:SetConVar(Tag .. '_distance_mode')
	local d_4 = c
	c:DockMargin(0, 12, 0, 0)


	hr()

	local slider = AddS("DNumSlider")
	slider:SetText("#outfitter_maxdlsize")
	slider:SizeToContents()
	slider:DockPadding(0, 16, 0, 0)
	slider.Label:Dock(TOP)
	slider.Label:DockMargin(0, -16, 0, 0)

	slider:SetTooltip [[#outfitter_maxdlsizetip]]

	slider:DockMargin(1, 4, 1, 1)
	slider:SetMin(0)
	slider:SetMax(256)
	slider:SetDecimals(0)
	slider:SetConVar(Tag .. '_maxsize')
	local sld_dl = slider

	local check = AddS("DCheckBoxLabel")
	check:SetConVar(Tag .. "_allow_dependencies")
	check:SetText("#outfitter_allow_wsdeps")
	check:SizeToContents()
	check:SetTooltip [[#outfitter_allow_wsdepstip]]
	check:DockMargin(1, 12, 1, 1)

	--TODO
	--local check = functions:Add( "DCheckBoxLabel" )
	-- 	check:SetConVar(Tag.."_ask")
	--	check:SetText( "Ask mode")
	--	check:SizeToContents()
	--	check:Dock(TOP)
	--	check:DockMargin(1,4,1,1)


	hr()

	local check = AddS("DCheckBoxLabel")
	check:SetConVar(Tag .. "_hands")
	check:SetText("#outfitter_guesschands")
	check:SetTooltip [[#outfitter_guesschandstip]]
	check:SizeToContents()

	check:DockMargin(1, 4, 1, 1)
	local d_6 = check

	local check = AddS("DCheckBoxLabel")
	check:SetConVar(Tag .. "_sounds")
	check:SetText("#outfitter_uisfx=")
	check:SetTooltip [[#outfitter_uisfxtip]]
	check:SizeToContents()

	check:DockMargin(1, 4, 1, 1)
	local d_7 = check

	local check = AddS("DCheckBoxLabel")
	check:SetConVar(Tag .. "_gui_focusdim")
	check:SetText("#outfitter_dimgui")
	check:SetTooltip [[#outfitter_dimguitip]]
	check:SizeToContents()
	check:DockMargin(1, 4, 1, 1)

	hr()
	local check = AddS("DCheckBoxLabel")
	check:SetConVar(Tag .. "_allow_http_test")
	check:SetText("#outfitter_outsidews")
	check:SetTooltip [[#outfitter_outsidewstip]]
	check:SizeToContents()

	check:DockMargin(1, 4, 1, 1)




	local check = AddS("DCheckBoxLabel")
	check:SetConVar(Tag .. "_allow_unsafe_http")
	check:SetText("#outfitter_untrustedurl")
	check:SetTooltip [[#outfitter_untrustedurltip]]
	check:SizeToContents()

	check:DockMargin(1, 4, 1, 1)

	hr()

	local debug = AddS("DCheckBoxLabel")
	debug:SetConVar(Tag .. "_dbg")
	debug:SetText("#debug")
	debug:SetTooltip [[#outfitter_debugtip]]
	debug:SizeToContents()

	debug:DockMargin(1, 14, 1, 1)
	local d_3 = debug

	local check = AddS("DCheckBoxLabel")
	check:SetConVar(Tag .. "_unsafe")
	check:SetText("#outfitter_unsafe")
	check:SizeToContents()

	check:SetTooltip [[#outfitter_removesafetychecks]]
	check:DockMargin(1, 4, 1, 1)
	local d_1 = check
	local check = AddS("DCheckBoxLabel")
	check:SetConVar(Tag .. "_failsafe")
	check:SetText("#outfitter_failsafe")
	check:SizeToContents()
	check:SetTooltip [[#outfitter_failsafetip]]

	check:DockMargin(1, 4, 1, 1)
	local d_2 = check

	local check = AddS("DCheckBoxLabel")
	check:SetConVar(Tag .. "_use_autoblacklist")
	check:SetText("#outfitter_autoblock")
	check:SizeToContents()
	check:SetTooltip [[#outfitter_autoblocktip]]
	check:DockMargin(1, 4, 1, 1)
	local d_2 = check

	hr()
	local check = AddS("DCheckBoxLabel")
	check:SetConVar(Tag .. "_animfix_oldmethod")
	check:SetText("#outfitter_legacy")
	check:SizeToContents()
	check:SetTooltip [[#outfitter_legacytip]]

	check:DockMargin(1, 4, 1, 1)

	local check = AddS("DCheckBoxLabel")
	check:SetConVar(Tag .. "_download_notifications")
	check:SetText("#outfitter_dlnotif")
	check:SizeToContents()
	check:SetTooltip [[#outfitter_dlnotiftip]]

	check:DockMargin(1, 4, 1, 1)

	local check = AddS("DCheckBoxLabel")
	check:SetConVar(Tag .. "_info_hud")
	check:SetText("#outfitter_ofitinfocontext")
	check:SizeToContents()
	check:SetTooltip [[#outfitter_ofitinfocontexttip]]

	check:DockMargin(1, 4, 1, 1)

	local check = AddS("DButton")
	check:SetText("#outfitter_clrmdlblacklist")
	check:DockMargin(1, 4, 1, 1)
	check.DoClick = function()
		RunConsoleCommand "outfitter_blacklist_clear"
	end
	check:SetImage 'icon16/tag_blue_delete.png'

	local check = AddS("DButton")
	check:SetText("#outfitter_fixfullupdate")
	check:DockMargin(1, 4, 1, 1)
	check.DoClick = function()
		Fullupdate()
	end
	check:SetImage 'icon16/transmit_error.png'

	local check = AddS("DButton")
	check:SetText("FIX: Local player animations")
	check:DockMargin(1, 4, 1, 1)
	check.DoClick = function()
		FixLocalPlayerAnimations(true)
	end
	check:SetImage 'icon16/transmit_error.png'

	local b = Add('DButton', 'thirdperson')
	b:SetText("#tool.camera.name")
	b:SetTooltip [[#outfitter_thirdptip]]

	b.DoClick = function() ToggleThirdperson() end
	b:DockMargin(16, 2, 16, 1)
	b:SetImage 'icon16/find.png'



	--local b = Add('EditablePanel')
	--b:SetTall(1)
	--b:DockMargin(-4,24,-4,1)
	--b.Paint = function(b,w,h)
	--	surface.SetDrawColor(240,240,240,200)
	--	surface.DrawRect(0,0,w,h)
	--end
	--local hr_line1 = b

	--------------------------------------------------



	-- second layer
	local cont = functions:Add('EditablePanel', 'container')
	cont:SetTall(24)
	cont:Dock(BOTTOM)

	local b = vgui.Create('DButton', mdllist, 'Bodygroups button')
	function b.Refresh(b)
		-- poor man's pcall
		co(function()
			b.mdl = false
			b:SetEnabled2(false)
			dbg("Bodygroup", "BTN", "Refresh")

			local l = UIGetMDLList()
			if not l then return end
			local chosen = UIGetChosenMDL()
			if not chosen then return false end
			local mdl = l[chosen]
			if not mdl then return false end
			if not file.Exists(mdl.Name, 'workshop') and not file.Exists(mdl.Name, 'GAME') then return false end
			local a = mdlinspect.Open(mdl.Name)
			a:ParseHeader()
			local parts = a:BodyPartsEx()
			local ok
			for k, v in next, parts do
				if v.nummodels > 1 then
					ok = true
					break
				end
			end
			if not ok then return end

			b:SetEnabled2(true)
			b.mdl = mdl
		end)
	end

	self.btn_bg = b
	b:Dock(NODOCK)
	b:SetText("")
	b:SetSize(24, 24)
	b:SetTooltip [[#GameUI_Modify]]
	b.DoClick = function()
		if not LocalPlayer():GetNetData(NTag) then
			local menu = DermaMenu()
			menu:AddOption("#gameui_submit", function()
				GUIBroadcastMyOutfit()
			end):SetIcon('icon16/transmit.png')
			menu:AddOption("#gameui_cancel", function() end):SetIcon('icon16/cancel.png')
			menu:AddOption("Edit anyway", function()
				GUIOpenBodyGroupOverlay(self)
			end):SetIcon('icon16/accept.png')
			menu:Open()
		else
			GUIOpenBodyGroupOverlay(self)
		end
	end
	b:SetImage 'icon16/group_edit.png'
	b.PerformLayout = function(b, w, h)
		DButton.PerformLayout(b, w, h)

		local w2 = b:GetParent():GetCanvas():GetWide()

		local _, y = b:GetParent():GetSize()
		b:SetPos(w2 - w - 1, y - h - 1)
	end
	function b.SetEnabled2(b, v)
		b:SetDisabled(not v)
		b._set_enabled = v
	end

	--b.PaintOver= function(b,w,h)
	--	if b._set_enabled then
	--		if UIGetChosenMDL() and UIGetMDLList() and LocalPlayer().latest_want~=UIGetMDLList()[UIGetChosenMDL()] then
	--			surface.SetDrawColor(55,240,55,40+25*math.sin(RealTime()*7)^2)
	--			surface.DrawRect(1,1,w-2,h-2)
	--		end
	--	end
	--end

	local b = cont:Add('DButton', 'Autowear button')
	self.btn_autowear = b
	b:SetTooltip [[#outfitter_autoweartip]]
	b:SetText("#makepersistent")
	b:Dock(FILL)
	b:SizeToContents()
	b.DoClick = function()
		local m = DermaMenu()
		m:AddOption("#makepersistent", function()
			SetAutowear()
		end):SetIcon 'icon16/vcard_edit.png'
		m:AddOption("#vgui_htmlreload", function()
			if co.make() then return end
			coDoAutowear()
		end):SetIcon 'icon16/transmit_go.png'
		m:Open()
	end
	b:SetImage 'icon16/disk.png'


	--------------------------------------------------


	local cont = functions:Add('EditablePanel', 'container')
	cont:SetTall(32)
	cont:Dock(BOTTOM)

	local b = cont:Add('DButton', 'Send button')
	self.btn_send = b
	b:Dock(LEFT)
	b:SetText("#gameui_submit")
	b:SetTooltip [[#outfitter_broadcastof]]
	b.DoClick = function()
		GUIBroadcastMyOutfit()
		b._set_enabled = false
		self:GetParent():Hide()
	end
	b:SetImage 'icon16/transmit.png'
	b.PerformLayout = function(b, w, h)
		DButton.PerformLayout(b, w, h)
		b:SetWide(b:GetParent():GetWide() * .5)
	end
	self.btnSendOutfit = b
	function b.SetEnabled2(b, v)
		b:SetDisabled(not v)
		b._set_enabled = v
	end

	b.PaintOver = function(b, w, h)
		if b._set_enabled then
			if UIGetChosenMDL() and UIGetMDLList() and LocalPlayer().latest_want ~= UIGetMDLList()[UIGetChosenMDL()] then
				surface.SetDrawColor(55, 240, 55, 40 + 25 * math.sin(RealTime() * 7) ^ 2)
				surface.DrawRect(1, 1, w - 2, h - 2)
			end
		end
	end



	local b = cont:Add('DButton', 'Clear button')
	self.btn_clear = b
	b:SetTooltip [[#outfitter_remoutfit]]
	b:SetText("#gameui_cancel")
	b:Dock(FILL)
	b:SizeToContents()
	b.DoClick = function()
		UICancelAll()
		self:DoRefresh(trychoose_mdl)
		--self:GetParent():Hide()
	end
	b:SetImage 'icon16/cancel.png'



	local div = self:Add "DHorizontalDivider"
	div:Dock(FILL)

	functions:Dock(NODOCK)
	sheet:Dock(NODOCK)
	div:SetCookieName(Tag)
	div:SetLeft(functions)
	div:SetRight(sheet)
	div:SetDividerWidth(4) --set the divider width. DEF: 8
	div:SetLeftMin(150)   --set the minimun width of left side
	div:SetRightMin(0)
	div:SetLeftWidth(300)

	--------------------------------------------------
end

gui_readytosend = false
local wanting = false
local want_wsid
local want_mdl
function PANEL:WantOutfitMDL(wsid, mdl, title)
	dbg("WantOutfitMDL", wanting and "ALREADY WANTING" or "", wsid, mdl, title)
	if wanting and want_wsid == wsid then
		want_mdl = mdl
	end

	if wanting then return false end
	want_wsid = wsid
	want_mdl = mdl

	local worker = co(function()
		if wanting then return end
		wanting = true
		self:GetParent():Hide()
		dbg("WantOutfitMDL", wanting and "ALREADY WANTING" or "", wsid, mdl, title)
		local ok, err = xpcall(UIChoseWorkshop, debug.traceback, wsid, false, true)
		if not ok then
			ErrorNoHalt(err .. '\n')
			wanting = false
			return
		end
		GUIOpen(nil, want_mdl)
		wanting = false
	end)

	return worker
end

function PANEL:WSChoose()
	self:Hide()
	if self.chosen_id then
		surface.PlaySound "npc/vort/claw_swing1.wav"
		UIChoseWorkshop(self.chosen_id, false, true)
	end
end

function GUIBroadcastMyOutfit()
	local mdl, wsid = UIBroadcastMyOutfit()
	if mdl and wsid then
		co(function()
			local self = GUIPanel()
			--if self and self.lbl_chosen:IsValid() then
			--	self.lbl_chosen:SetText( "Loading info..." )
			--end



			local info = co_steamworks_FileInfo(wsid)
			local title = info.title
			local self = GUIPanel()
			--if self and self.lbl_chosen:IsValid() then
			--	self.lbl_chosen:SetText( title or "" )
			--end
			if not title then return end
			GUIAddHistory(wsid, title, mdl)
		end)
	end
end

local want_n
local choosing
function GUIChooseMDL(n)
	dbg("GUIChooseMDL", n, choosing and "already choosing, changing" or "", want_n)
	want_n = n

	if choosing then return false end
	local mdllist = UIGetMDLList()
	local mdl = mdllist and mdllist[n]
	if not mdl then return false end

	co(function()
		if choosing then return end
		choosing = true
		UIChangeModelToID(n)
		if n ~= want_n and want_n then
			dbg("CHANGE WANT OT", want_n)
			UIChangeModelToID(want_n, true)
		end
		dbg("GUIChooseMDL", "FINISH", n)
		want_n = nil
		choosing = false
		GUICheckTransmit()
	end)
	return mdl
end

function GUIClearHistory()
	GUIDelHistory(-1)
end

local function SAVE(t)
	local s = json.encode(t)
	util.SetPData("0", Tag, s)
end

local function LOAD()
	local s = util.GetPData("0", Tag, false)
	if not s or s == "" or s == "nil" then return {} end
	local t = json.decode(s)
	return t or {}
end

local hist
function GUIAddHistory(wsid, title, mdl)
	if not title or not mdl or not wsid then return end
	if not hist then
		GUIGetHistory()
	end
	for k, v in next, hist do
		local wsid2, mdl2 = v[1], v[2]
		if wsid2 == wsid and mdl2 == mdl then return end
	end

	local t = { wsid, mdl, title }
	table.insert(hist, t)
	SAVE(hist)

	GUIRefresh()

	return t
end

function GUIGetHistory()
	if not hist then hist = LOAD() end
	return hist
end

function GUIDelHistory(n)
	if n < 0 then table.Empty(hist) end
	local ret = table.remove(hist, n)
	SAVE(hist)

	GUIRefresh()

	return ret
end

function GUICheckTransmit()
	local gui = GUIPanel()
	if not gui then return end
	local self = gui.content
	if not self then return end

	local cansend = UIGetChosenMDL() and UIGetDownloadInfoX() and UIGetMDLList()
	self.btnSendOutfit:SetEnabled2(cansend)
	self.btn_bg:Refresh()
	self:RefreshDependencyButton()
end

function PANEL:RefreshDependencyButton()
	local button = self.btn_dependencies
	if not button then return end

	local wsid = UIGetWSID()
	local visible = tonumber(wsid) ~= nil and ShouldMountChildren()
	self.dependency_button_request = (self.dependency_button_request or 0) + 1

	button:SetVisible(visible)
	button:SetEnabled(false)

	if not visible then return end

	if not UIGetChosenMDL() then
		button:SetTooltip("Choose a model before reviewing dependencies")
		return
	end

	button:SetTooltip("Checking workshop dependencies...")

	local request = self.dependency_button_request
	co(function()
		local graph, err = coResolveWSDependencies(wsid)
		if not self:IsValid() or not button:IsValid() then return end
		if request ~= self.dependency_button_request or wsid ~= UIGetWSID() then return end

		local has_dependencies = graph and graph.count > 0
		button:SetEnabled(has_dependencies)
		button:SetTooltip(has_dependencies and "Review the dependencies sent with this outfit" or
			(graph and "This workshop outfit does not declare dependencies" or
				("Could not read dependencies: " .. tostring(err))))
	end)
end

function PANEL:DoRefresh(trychoose_mdl)
	dbg("doRefresh", trychoose_mdl)
	self.mdllist:Clear()
	self.btn_bg:Refresh()
	self.mdlhist:Clear()

	self.lbl_chosen:SetText("#outfitter_slctwsaddon")

	local wsid = UIGetWSID()

	co(function()
		self.lbl_chosen:SetText("-")

		if wsid and tonumber(wsid) then
			self.lbl_chosen:SetText("#outfitter_loadinginfo")
			local info = co_steamworks_FileInfo(wsid)
			if not self:IsValid() then return end
			if not self.lbl_chosen:IsValid() then return end

			if wsid ~= UIGetWSID() then
				return
			end
			if not info or not info.title then
				self.lbl_chosen:SetText("-")
			else
				local str = ("%s (%s)"):format(info.title, string.NiceSize(info.size or 0))
				self.lbl_chosen:SetText(str)
			end
		elseif wsid and wsid:find("http") then -- it's a gma download
			local ok, body, len, hdrs, code = co_head(wsid)
			if ok then
				self.lbl_chosen:SetText("#outfitter_badgma")
			else
				local size = hdrs and hdrs["Content-Length"] and tonumber(hdrs["Content-Length"])
				self.lbl_chosen:SetText(("GMA HEAD OK (%s)"):format(size and string.NiceSize(size) or "Size Unknown!"))
			end
		end
	end)


	local tm = UITriedMounting()
	local mdllist = UIGetMDLList()

	GUICheckTransmit()


	-- model list
	local chosen
	for k, dat in next, mdllist or {} do
		if trychoose_mdl and trychoose_mdl == dat.Name then
			chosen = true
		end
		local pnl = self.mdllist:AddLine(dat.Name and MDLToUI(dat.Name) or "???")

		if chosen and chosen == true then
			chosen = pnl
		end
	end

	local extra = UIGetMDLListExtra()
	if extra and extra.discards then
		for k, dat in next, extra.discards or {} do
			local pnl = self.mdllist:AddLine(dat.Name and MDLToUI(dat.Name) or "???")
			pnl:SetTooltip(dat.error_player or dat.error_vvd or "INVALID MODEL")
			local Paint = pnl.Paint or function() end
			pnl.Paint = function(pnl, w, h)
				local r = Paint(pnl, w, h)
				surface.SetDrawColor(240, 30, 30, 120)
				surface.DrawRect(0, 0, w, h)
				return r
			end
		end
	end

	for _, v in next, GUIGetHistory() do
		local wsid, mdl, title = unpack(v)


		local pnl = self.mdlhist:Add('DOWorkshopIcon')
		pnl:SetAddon({ wsid = wsid, title = MDLToUI(mdl) })
		self.mdlhist:Layout()
		pnl:SetTooltip(title .. '\n' .. mdl)
		pnl._OnMousePressed = pnl.OnMousePressed
		pnl.OnMousePressed = function(pnl, mc)
			if mc == MOUSE_RIGHT then
				local m = DermaMenu()
				m:AddOption("#open_workshop", function()
					gui.OpenURL(("https://steamcommunity.com/workshop/filedetails/?id=%d"):format(wsid))
				end):SetIcon 'icon16/world.png'
				m:AddOption("#gameui_delete", function()
					for n, vv in next, GUIGetHistory() do
						if vv == v then
							GUIDelHistory(n)
							return
						end
					end
				end):SetIcon 'icon16/bin.png'
				m:Open()
				return
			elseif mc == MOUSE_LEFT then
				if not self:WantOutfitMDL(unpack(v)) then
					surface.PlaySound "common/warning.wav"
				end
			end
		end
	end

	if chosen then
		if chosen ~= true then
			dbg("SelectItem", "AUTO", chosen, trychoose_mdl)

			self.mdllist:SelectItem(chosen)
		else
			dbg("Choose missing", trychoose_mdl)
		end
	end

	self.btn_bg:Refresh()
end

local factory = vgui.RegisterTable(PANEL, 'EditablePanel')









-- main panel

local PANEL = {}
function PANEL:Init()
	local pnl = vgui.CreateFromTable(factory, self)
	self.content = pnl
	pnl:Dock(FILL)

	local t = os.date "*t"
	self.m_bPaintHat = t.month == 12 and t.day <= 25

	self:SetCookieName "ofp"
	self:SetTitle "#outfitter_maintitle"
	self:SetMinHeight(290)
	self:SetMinWidth(312)
	self:SetPos(32, 32)
	self:SetDeleteOnClose(false)
	self.btnMinim:SetEnabled(true)
	self.btnMaxim:SetEnabled(true)
	local had_max = self:GetCookie("pmax", "") == '1'

	if had_max then
		self:SetSize(640, 400)
	else
		self:SetSize(313, 293)
	end

	self.btnMaxim.DoClick = function()
		self:SetSize(640, 400)
		self:SetCookie("pmax", '1')
		had_max = true
		self:CenterVertical()
	end

	self:CenterVertical()

	if not had_max then
		self.btnMaxim.PaintOver = function(b, w, h)
			if had_max then return end
			b:NoClipping(false)
			surface.SetDrawColor(255, 66, 22, 255 * .5 + 255 * .3 * math.sin(RealTime() * 4))

			surface.DrawOutlinedRect(-1, -1, w + 1, h + 1)
			surface.DrawOutlinedRect(0, 0, w, h)
			b:NoClipping(true)
		end
	end
	self.btnMinim.DoClick = function()
		self:SetSize(313, 293)
		self:CenterVertical()
	end
	self:SetDraggable(true)
	self:SetSizable(true)

	local title = self.lblTitle
	if title then
		self:SetIcon 'icon16/user.png'
		--local img = vgui.Create('DImage',title)
		--img:SetImage("icon16/user.png")
		--img:Dock(LEFT)
		--img.PerformLayout = function()
		--	img:SetWide(img:GetTall())
		--	title:SetTextInset(img:GetTall() + 5,0)
		--end

		local check = self:Add("DCheckBoxLabel")
		check:SetConVar(Tag .. "_enabled")
		check:SetText("#gameui_enabled")
		check:SizeToContents()
		check:SetTooltip [[#outfitter_on_tip]]
		self.btnCheck = check
	end
	local OnMouseReleased = self.OnMouseReleased
	self.OnMouseReleased = function(...)
		self.OnMouseReleasedHook(...)
		return OnMouseReleased(...)
	end
	local Think = self.Think
	self.Think = function(...)
		Think(...)

		local hovered = self:IsHovered() or self:IsChildHovered()

		if hovered and not self.hadhover then
			self.hadhover = true
		end

		local hasf = not outfitter_gui_focusdim:GetBool() or (hovered or not self.hadhover) or self.Dragging or
		self.Sizing
		if hasf ~= self.hierfocused then
			self.hierfocused = hasf
			if hasf then
				self.fadeouttime = nil
				self:SetAlpha(255)
			else
				self.fadeouttime = RealTime()
			end
		end
		if self.fadeouttime then
			local f = (RealTime() - self.fadeouttime) / 0.15
			f = 1 - f
			f = f > 1 and 1 or f < 0 and 0 or f
			self:SetAlpha(f * 200 + 55)
		end

		local x, y = self:CursorPos()
		if x > 0 and x < 20 and y > 0 and y < 20 then
			self:SetCursor("hand")
		end
	end
end

function PANEL:OnMouseReleasedHook(mc)
	local x, y = self:CursorPos()
	if x < 0 or x > 20 then return end
	if y < 0 or y > 20 then return end


	if mc == MOUSE_LEFT then
		GUIAbout()
		return
	end

	local menu = DermaMenu()

	if UIGetChosenMDL() and UIGetMDLList() and LocalPlayer().latest_want ~= UIGetMDLList()[UIGetChosenMDL()] then
		menu:AddOption("#gameui_submit", function() GUIBroadcastMyOutfit() end):SetImage 'icon16/transmit.png'
	end

	--menu:AddLine()

	menu:AddOption("About", function() GUIAbout() end):SetImage 'icon16/information.png'
	menu:AddOption("Close", function() self:Hide() end):SetImage 'icon16/door_out.png'
	menu:Open()
end

function PANEL:PerformLayout(w, h)
	DFrame.PerformLayout(self, w, h)
	self.btnMinim:SetEnabled(w > (self:GetMinWidth() + 5) or h > (5 + self:GetMinHeight()))

	local check = self.btnCheck
	local cw, ch = 0, 0
	if check then
		cw, ch = check:GetSize()
	end

	local b = self.btnMinim or self.btnMaxim
	if b and b:IsValid() then
		local bw, bh = b:GetWide(), b:GetTall()
		local bx, by = b:GetPos()
		if check then
			check:SetPos(bx - cw - 4, by + bh * .5 - ch * .5 + 1)
			check:SetVisible(w > 256)
		end
	end
end

function PANEL:Hide()
	self:SetVisible(false)
	--hook.Run("OnContextMenuClose")
	self:OnClose()
end

function PANEL:OnClose()
	self.want_thirdperson = InThirdperson()
	ToggleThirdperson(false)
end

function PANEL:Show(_, trychoose_mdl)
	--if not self:IsVisible() then
	surface.PlaySound "garrysmod/ui_return.wav"
	--end
	self:SetVisible(true)
	self:MakePopup()
	self:DoRefresh(trychoose_mdl)
	if self.want_thirdperson then
		ToggleThirdperson(true)
	end
end

function PANEL:DoRefresh(trychoose_mdl)
	if not self:IsVisible() then return end

	self.content:DoRefresh(trychoose_mdl)
end

local factory = vgui.RegisterTable(PANEL, 'DFrame')

if this.m_vGUIDlg and ValidPanel(this.m_vGUIDlg) then
	m_vGUIDlg:Remove()
end


function GUIPanel()
	return ValidPanel(m_vGUIDlg) and m_vGUIDlg
end

function GUIRefresh()
	local gui = GUIPanel()
	if gui then gui:DoRefresh() end
end

local prev = rawget(_M, 'm_vGUIDlg')
if ValidPanel(prev) then prev:Remove() end
m_vGUIDlg = NULL
local alerted
function GUIOpen(_, trychoose_mdl)
	if not ValidPanel(m_vGUIDlg) then
		local d = vgui.CreateFromTable(factory, nil, Tag .. '_GUI')
		m_vGUIDlg = d
	end


	m_vGUIDlg:Show(nil, trychoose_mdl)

	if Derma_Message and not alerted and game.SinglePlayer() then
		alerted = true
		Derma_Message("#outfitter_dermaalertmsg", '#outfitter_warning')
	end

	return m_vGUIDlg
end

if NOUI then return end
concommand.Add(Tag .. '_open', function()
	GUIOpen()
end, nil, "Open the outfit selection GUI")
--RunConsoleCommand(Tag..'_open')




-- button --



local icon = "icon64/outfitter.png"
icon = file.Exists("materials/" .. icon, 'GAME') and icon or "icon64/playermodel.png"

list.Set("DesktopWindows", Tag, {
	title     = "Outfitter",
	icon      = icon,
	width     = 1,
	height    = 1,
	onewindow = false,
	init      = function(icon, window)
		window:GetParent():Close()
		window:Remove()
		GUIOpen()
	end
})
