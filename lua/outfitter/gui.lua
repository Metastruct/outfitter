local Tag = 'outfitter'
local NTag = 'OF'

-- lua_openscript_cl srv/outfitter/lua/outfitter/ui.lua;lua_openscript_cl srv/outfitter/lua/outfitter/gui.lua;outfitter_open

module(Tag, package.seeall)
local NOUI = OUTFITTER_NO_UI

local outfitter_gui_focusdim = CreateClientConVar("outfitter_gui_focusdim", "0", true, false, "Dim GUI when mouse leaves window")
local outfitter_debug_cefcheck = CreateClientConVar("outfitter_debug_cefcheck", "1", true, false, "Check if the CEF/H.264 codec is installed; if not, open pasted URLs in the Steam overlay instead of mounting them")

local cef_codec_checked
local cef_codec_available
local cef_callbacks

local function CEFCodecCheckFinish()
	if not cef_callbacks then return end
	local cbs = cef_callbacks
	cef_callbacks = nil
	for _, cb in ipairs(cbs) do
		cb(cef_codec_available)
	end
end

local function RunCEFCodecCheck()
	if not (BRANCH == "x86-64" or system.IsWindows()) then
		cef_codec_available = false
		CEFCodecCheckFinish()
		return
	end

	local panel = vgui.Create("DHTML", nil, "outfitter_cef_codec_check")
	panel:SetSize(32, 32)
	panel:SetKeyboardInputEnabled(false)
	panel:SetMouseInputEnabled(false)
	panel.Paint = function() return true end

	panel.RemoveWhileHidden = function()
		if not IsValid(panel) then return end
		panel:SetVisible(false)
		panel:Remove()
	end

	local timeout_timer = "outfitter_cef_codec_check_timeout"
	timer.Create(timeout_timer, 8, 1, function()
		if cef_codec_available == nil then
			cef_codec_available = false
			panel:RemoveWhileHidden()
			CEFCodecCheckFinish()
		end
	end)

	panel:SetHTML("")

	panel.OnDocumentReady = function()
		if cef_codec_available ~= nil then
			panel:RemoveWhileHidden()
			return
		end
		panel:AddFunction("gmod", "getCodecStatus", function(codecStatus)
			if cef_codec_available ~= nil then return end
			timer.Remove(timeout_timer)
			cef_codec_available = tobool(codecStatus)
			panel:RemoveWhileHidden()
			CEFCodecCheckFinish()
		end)
		panel:QueueJavascript([[gmod.getCodecStatus(document.createElement("video").canPlayType('video/mp4; codecs="avc1.42E01E, mp4a.40.2"') == "probably")]])
	end
end

function CheckCEFCodec(cb)
	if cef_codec_available ~= nil then
		if cb then cb(cef_codec_available) end
		return
	end
	if cb then
		cef_callbacks = cef_callbacks or {}
		cef_callbacks[#cef_callbacks + 1] = cb
	end
	if not cef_codec_checked then
		cef_codec_checked = true
		RunCEFCodecCheck()
	end
end

hook.Add("PreRender", Tag, function()
	hook.Remove("PreRender", Tag)
	CheckCEFCodec()
end)

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



local HISTORY_ICON_SIZE = 72

local PANEL = {}

function PANEL:CreateOutfitPage(page)
	page:DockPadding(8, 8, 8, 8)

	local status_row = page:Add('EditablePanel')
	status_row:Dock(TOP)
	status_row:SetTall(24)

	local clear = status_row:Add('DButton')
	self.btn_clear = clear
	clear:Dock(RIGHT)
	clear:SetWide(130)
	clear:SetText("#outfitter_remove")
	clear:SetTooltip("#outfitter_remoutfit")
	clear:SetImage('icon16/cancel.png')
	clear.DoClick = function()
		UICancelAll()
		self:DoRefresh()
	end

	local status = status_row:Add('DLabel')
	self.lbl_status = status
	status:Dock(FILL)
	status:SetFont("DermaDefaultBold")
	status:SetDark(true)

	local source_row = page:Add('EditablePanel')
	source_row:Dock(TOP)
	source_row:DockMargin(0, 8, 0, 0)
	source_row:SetTall(24)

	local choose = source_row:Add('DButton')
	self.btn_choose = choose
	choose:Dock(LEFT)
	choose:SetWide(150)
	choose:SetText("#outfitter_browse")
	choose:SetTooltip("#outfitter_choosemdl")
	choose:SetImage('icon16/folder_user.png')
	choose.DoClick = function()
		self:GetParent():Hide()
		GUIWantChangeModel(nil, true)
	end

	local url_entry = source_row:Add('DTextEntry')
	self.input_mdlsource = url_entry
	url_entry:Dock(FILL)
	url_entry:DockMargin(6, 0, 0, 0)
	url_entry:SetPlaceholderText("#outfitter_url_placeholder")

	local function SubmitURL(url, hidegui)
		if url == "puze" then
			url = "https://g2cf.metastruct.net/delme/puze.gma"
		end
		local wsid = UrlToWorkshopID(url, true)
		dbg("GUI", "UrlToWorkshopID", url, wsid)
		if wsid then
			surface.PlaySound "npc/vort/claw_swing1.wav"
			UIChoseWorkshop(wsid, true, true)
			hidegui()
		else
			if IsHTTPURL(url) then
				if AllowedHTTPURL(url) then
					hidegui()
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

	url_entry.OnEnter = function()
		local url = url_entry:GetValue():Trim()
		local hidegui = function() self:GetParent():Hide() end
		local submit = function()
			SubmitURL(url, hidegui)
		end
		if UrlToWorkshopID(url, true) then
			return submit()
		end
		if not outfitter_debug_cefcheck:GetBool() then
			return submit()
		end
		CheckCEFCodec(function(codec_ok)
			if codec_ok then
				submit()
			else
				dbg("CEF codec not installed, opening URL in Steam overlay", url)
				gui.OpenURL(url, true)
			end
		end)
	end

	local history = page:Add('EditablePanel')
	self.history_row = history
	history:Dock(TOP)
	history:DockMargin(0, 8, 0, 0)
	history:SetTall(HISTORY_ICON_SIZE + 26)

	local history_header = history:Add('EditablePanel')
	history_header:Dock(TOP)
	history_header:DockMargin(0, 0, 0, 4)
	history_header:SetTall(22)

	local clear_history = history_header:Add('DButton')
	self.btn_clearhist = clear_history
	clear_history:Dock(RIGHT)
	clear_history:SetWide(70)
	clear_history:SetText("#gameui_clearbutton")
	clear_history:SetImage('icon16/bin.png')
	clear_history.DoClick = function()
		GUIClearHistory()
	end

	local history_label = history_header:Add('DLabel')
	history_label:Dock(FILL)
	history_label:SetFont("DermaDefaultBold")
	history_label:SetDark(true)
	history_label:SetText("#outfitter_recent")

	local mdlhist = history:Add('DHorizontalScroller')
	self.mdlhist = mdlhist
	mdlhist:Dock(FILL)
	mdlhist:SetOverlap(-4)

	local actions = page:Add('EditablePanel')
	actions:Dock(BOTTOM)
	actions:DockMargin(0, 4, 0, 0)
	actions:SetTall(28)

	local send = actions:Add('DButton')
	self.btnSendOutfit = send
	send:Dock(LEFT)
	send:SetWide(150)
	send:SetText("#outfitter_apply")
	send:SetTooltip("#outfitter_broadcastof")
	send:SetImage('icon16/transmit.png')
	send.DoClick = function()
		GUIBroadcastMyOutfit()
	end

	local thirdperson = actions:Add('DCheckBoxLabel')
	self.chk_thirdperson = thirdperson
	thirdperson:Dock(LEFT)
	thirdperson:DockMargin(12, 6, 0, 6)
	thirdperson:SetText("#outfitter_thirdperson")
	thirdperson:SetTooltip("#outfitter_thirdptip")
	thirdperson:SetDark(true)
	thirdperson:SizeToContents()
	thirdperson.OnChange = function(_, value)
		ToggleThirdperson(value and true or false)
	end

	local autowear = actions:Add('DCheckBoxLabel')
	self.chk_autowear = autowear
	autowear:Dock(LEFT)
	autowear:DockMargin(12, 6, 0, 6)
	autowear:SetText("#outfitter_wearonjoin")
	autowear:SetTooltip("#outfitter_autoweartip")
	autowear:SetDark(true)
	autowear:SizeToContents()
	autowear.OnChange = function(_, value)
		if value then
			SetAutowear()
		else
			ClearAutowear()
		end
		self:RefreshStatus()
	end

	local load_saved = actions:Add('DButton')
	self.btn_loadsaved = load_saved
	load_saved:Dock(RIGHT)
	load_saved:SetWide(130)
	load_saved:SetText("#outfitter_loadsaved")
	load_saved:SetImage('icon16/transmit_go.png')
	load_saved.DoClick = function()
		co(coDoAutowear)
	end

	local hint = page:Add('DLabel')
	self.lbl_hint = hint
	hint:Dock(BOTTOM)
	hint:DockMargin(0, 6, 0, 0)
	hint:SetTall(20)
	hint:SetDark(true)

	local chosen_row = page:Add('EditablePanel')
	chosen_row:Dock(TOP)
	chosen_row:DockMargin(0, 8, 0, 4)
	chosen_row:SetTall(24)

	local dependencies = chosen_row:Add('DButton')
	self.btn_dependencies = dependencies
	dependencies:Dock(RIGHT)
	dependencies:SetWide(130)
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

	local chosen = chosen_row:Add('DLabel')
	self.lbl_chosen = chosen
	chosen:Dock(FILL)
	chosen:SetTooltip("#outfitter_ws_title")
	chosen:SetDark(true)
	chosen:SetText("")

	local mdllist = vgui.Create('DListView', page)
	self.mdllist = mdllist
	mdllist:SetMultiSelect(false)
	mdllist:AddColumn("#gameui_playermodel")
	mdllist:SetTooltip("#outfitter_choose_of")
	mdllist.OnRowSelected = function(_, n)
		if not GUIChooseMDL(n) then
			surface.PlaySound "common/warning.wav"
		end
	end

	local customize = vgui.Create('DPanel', page)
	customize:DockPadding(6, 6, 6, 6)

	local customize_label = customize:Add('DLabel')
	customize_label:Dock(TOP)
	customize_label:SetFont("DermaDefaultBold")
	customize_label:SetDark(true)
	customize_label:SetText("#outfitter_bodygroups")

	local customize_scroll = customize:Add('DScrollPanel')
	self.bg_scroll = customize_scroll
	customize_scroll:Dock(FILL)
	customize_scroll:DockMargin(0, 4, 0, 0)

	self.bg_edit_disabled = customize_scroll:Add('DLabel')
	self.bg_edit_disabled:Dock(TOP)
	self.bg_edit_disabled:SetText("#outfitter_submitfirst")
	self.bg_edit_disabled:SetDark(true)
	self.bg_edit_disabled:SetWrap(true)
	self.bg_edit_disabled:SetAutoStretchVertical(true)

	self.bg_edit = vgui.CreateFromTable(bodygroups_factor, customize_scroll, 'bodygroups editor')
	self.bg_edit:Dock(TOP)

	local div = page:Add('DHorizontalDivider')
	div:Dock(FILL)
	div:SetCookieName(Tag .. '_outfit')
	div:SetLeft(mdllist)
	div:SetRight(customize)
	div:SetDividerWidth(6)
	div:SetLeftMin(200)
	div:SetRightMin(160)
	div:SetLeftWidth(380)
end

function PANEL:CreateSettingsPage(page)
	page:DockPadding(4, 4, 4, 4)

	local categories = page:Add('DCategoryList')
	categories:Dock(FILL)

	local function Form(name, expanded)
		local form = vgui.Create('DForm')
		form:SetName(name)
		form:SetExpanded(expanded)
		categories:AddItem(form)
		return form
	end

	local function Check(form, text, convar, tooltip)
		local check = form:CheckBox(text, convar)
		if tooltip then check:SetTooltip(tooltip) end
		return check
	end

	local function Slider(form, text, convar, max, tooltip)
		local slider = form:NumSlider(text, convar, 0, max, 0)
		slider:SetTooltip(tooltip)
		return slider
	end

	local function FixButton(form, text, image, callback)
		local button = form:Button(text)
		button:SetImage(image)
		button.DoClick = callback
		return button
	end

	local general = Form("#outfitter_set_general", true)
	Check(general, "#outfitter_show_outfits", Tag .. "_enabled", "#outfitter_on_tip")
	Check(general, "#outfitter_friendsonly", Tag .. "_friendsonly", "#outfitter_friendsonlytip")
	Check(general, "#outfitter_guesschands", Tag .. "_hands", "#outfitter_guesschandstip")
	Check(general, "#outfitter_uisfx", Tag .. "_sounds", "#outfitter_uisfxtip")
	Check(general, "#outfitter_dimgui", Tag .. "_gui_focusdim", "#outfitter_dimguitip")
	Check(general, "#outfitter_ofitinfocontext", Tag .. "_info_hud", "#outfitter_ofitinfocontexttip")

	local downloads = Form("#outfitter_set_downloads", true)
	Slider(downloads, "#outfitter_maxdlsize", Tag .. "_maxsize", 256, "#outfitter_maxdlsizetip")
	Check(downloads, "#outfitter_allow_wsdeps", Tag .. "_allow_dependencies", "#outfitter_allow_wsdepstip")
	Slider(downloads, "#outfitter_dldistance", Tag .. "_distance", 5000, "#outfitter_dldistancetip")

	local distance_mode
	local combo = downloads:ComboBox("#outfitter_distmode_label", Tag .. "_distance_mode")
	combo:SetTooltip("#outfitter_distmode")
	combo.OnSelect = function(_, val)
		distance_mode = distance_mode or GetConVar(Tag .. '_distance_mode')
		local choose = val == 1 and -1 or val == 2 and 0 or 1
		dbgn(2, "ChooseDistanceMode", val, '->', choose)
		distance_mode:SetInt(choose)
	end
	combo:AddChoice("#outfitter_def", '-1')
	combo:AddChoice("#outfitter_sao", '0')
	combo:AddChoice("#outfitter_noo", '1')

	Check(downloads, "#outfitter_dlnotif", Tag .. "_download_notifications", "#outfitter_dlnotiftip")

	local links = Form("#outfitter_set_links", false)
	Check(links, "#outfitter_outsidews", Tag .. "_allow_http_test", "#outfitter_outsidewstip")
	Check(links, "#outfitter_untrustedurl", Tag .. "_allow_unsafe_http", "#outfitter_untrustedurltip")

	local troubleshooting = Form("#outfitter_set_troubleshooting", false)
	FixButton(troubleshooting, "#outfitter_fixlplyanim", 'icon16/transmit_error.png', function()
		FixLocalPlayerAnimations(true)
	end)
	FixButton(troubleshooting, "#outfitter_fixfullupdate", 'icon16/transmit_error.png', function()
		Fullupdate()
	end)
	FixButton(troubleshooting, "#outfitter_clrmdlblacklist", 'icon16/tag_blue_delete.png', function()
		RunConsoleCommand "outfitter_blacklist_clear"
	end)
	Check(troubleshooting, "#outfitter_autoblock", Tag .. "_use_autoblacklist", "#outfitter_autoblocktip")
	Check(troubleshooting, "#outfitter_failsafe", Tag .. "_failsafe", "#outfitter_failsafetip")
	Check(troubleshooting, "#outfitter_legacy", Tag .. "_animfix_oldmethod", "#outfitter_legacytip")
	Check(troubleshooting, "#debug", Tag .. "_dbg", "#outfitter_debugtip")
	Check(troubleshooting, "#outfitter_unsafe", Tag .. "_unsafe", "#outfitter_removesafetychecks")
end

function PANEL:CreateBlocklistPage(page)
	page:DockPadding(8, 8, 8, 8)

	local txt = page:Add('DLabel', 'infomsg')
	txt:Dock(TOP)
	txt:SetText "#outfitter_titlebl"
	txt:SetDark(true)

	local check = page:Add("DCheckBoxLabel", 'nsfwtoggle')
	check:SetConVar("nsfw")
	check:SetText("#outfitter_allownsfw")
	check:SizeToContents()
	check:SetTooltip [[#outfitter_allownsfwtip]]
	check:SetDark(true)
	check:DockMargin(0, 2, 0, 6)
	check:Dock(TOP)

	local TextEntry = page:Add("DTextEntry", "blocklist")
	self.blocklist_entry = TextEntry
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
end

function PANEL:SaveBlocklist()
	local entry = self.blocklist_entry
	if not IsValid(entry) then return end

	local value = entry:GetValue()
	if value ~= table.concat(GetTitleBlocklist(), "\n") then
		SetTitleBlocklist(value)
	end
end

function PANEL:CreateSettingsSheet(frame)
	local sheet = frame:Add("DPropertySheet")
	sheet:Dock(FILL)

	local settings_page = frame:Add("DPanel")
	self:CreateSettingsPage(settings_page)
	sheet:AddSheet("#outfitter_tab_preferences", settings_page, "icon16/wrench.png")

	local blocklist_page = frame:Add("DPanel")
	self:CreateBlocklistPage(blocklist_page)
	sheet:AddSheet("#outfitter_tab_blocklist", blocklist_page, "icon16/stop.png")

	local infopanel = frame:Add("EditablePanel")
	infopanel.Think = function()
		infopanel.Think = function() end

		local p = vgui.CreateFromTable(about_factory, infopanel)
		p:Dock(FILL)
	end
	infopanel:Dock(FILL)
	sheet:AddSheet("#information", infopanel, "icon16/information.png")

	return sheet
end

function PANEL:Init()
	local outfit_page = self:Add("DPanel")
	outfit_page:Dock(FILL)
	self:CreateOutfitPage(outfit_page)
end

function PANEL:RefreshBGE()
	local data = api and api.get_player_networked_data(LocalPlayer())
	local mdllist = UIGetMDLList()
	local chosen = UIGetChosenMDL()
	local chosen_dat = mdllist and chosen and mdllist[chosen]
	local mdl = chosen_dat and chosen_dat.Name or data and data.mdl
	if mdl and (file.Exists(mdl, 'workshop') or file.Exists(mdl, 'GAME')) then
		self.bg_edit_disabled:SetVisible(false)
		self.bg_edit:SetVisible(true)
		if self.bg_edit.model ~= mdl or #self.bg_edit:GetChildren() == 0 then
			local ok, err = pcall(self.bg_edit.SetModel, self.bg_edit, mdl)
			if not ok then
				dbgelvl(3, err)
				self.bg_edit:Clear()
				self.bg_edit:SetVisible(false)
				self.bg_edit_disabled:SetVisible(true)
			end
		end
	else
		self.bg_edit:SetVisible(false)
		self.bg_edit:Clear()
		self.bg_edit_disabled:SetVisible(true)
	end
	self.bg_scroll:InvalidateLayout()
end

local function ManifestKey(manifest)
	local normalized = NormalizeDependencyManifest(manifest)
	if not normalized or #normalized.dependencies == 0 then return "" end
	return DependencyManifestID(normalized)
end

function PANEL:RefreshStatus()
	local pl = LocalPlayer()
	local networked = api and api.get_player_networked_data(pl)
	local worn_mdl = networked and networked.mdl
	local current = api and api.get_current()
	local current_mdl = current and current.mdl

	if current_mdl and current_mdl ~= worn_mdl then
		self.lbl_status:SetText(language.GetPhrase("outfitter_status_preview"):format(MDLToUI(current_mdl)))
	elseif worn_mdl then
		self.lbl_status:SetText(language.GetPhrase("outfitter_status_worn"):format(MDLToUI(worn_mdl)))
	else
		self.lbl_status:SetText("#outfitter_status_none")
	end

	local mdllist = UIGetMDLList()
	local chosen = UIGetChosenMDL()
	local chosen_dat = mdllist and chosen and mdllist[chosen]
	local chosen_name = chosen_dat and chosen_dat.Name

	local dependency_manifest = ShouldMountChildren() and UIGetDependencyManifest() or nil
	local applied = chosen_name and chosen_name == worn_mdl and
		ManifestKey(dependency_manifest) == ManifestKey(networked.dependency_manifest)

	if not mdllist then
		self.lbl_hint:SetText("#outfitter_hint_browse")
	elseif not chosen_name then
		self.lbl_hint:SetText("#outfitter_hint_pick")
	elseif applied then
		self.lbl_hint:SetText("#outfitter_hint_applied")
	else
		self.lbl_hint:SetText("#outfitter_hint_apply")
	end

	self.btn_clear:SetEnabled((worn_mdl or current_mdl or mdllist) and true or false)
	self.btnSendOutfit:SetEnabled((chosen_name and UIGetDownloadInfoX() and not applied) and true or false)

	self.chk_thirdperson:SetChecked(InThirdperson() and true or false)

	local saved = GetAutowear()
	local saved_current = saved and current and saved.mdl == current.mdl and tostring(saved.wsid) == tostring(current.download_path)
	self.chk_autowear:SetChecked(saved_current and true or false)
	self.chk_autowear:SetEnabled((current or saved_current) and true or false)
	self.btn_loadsaved:SetVisible((saved and not saved_current) and true or false)
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
		GUIRebuildBGE()
		GUICheckTransmit()
	end)
	return mdl
end

function GUIRebuildBGE()
	local gui = GUIPanel()
	if not gui then return end

	gui.content.bg_edit.model = nil
	gui.content:RefreshBGE()
end

hook.Add("OutfitApply", Tag .. '_bge', function(pl, mdl)
	if pl == LocalPlayer() and mdl then
		GUIRebuildBGE()
	end
end)

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
		if tostring(wsid2) == tostring(wsid) and mdl2 == mdl then
			table.remove(hist, k)
			break
		end
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

	self:RefreshStatus()
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
		button:SetTooltip("#outfitter_depscho")
		return
	end

	button:SetTooltip("#outfitter_depscheck")

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
	self:RefreshBGE()
	self.mdlhist:Clear()

	self.lbl_chosen:SetText("")

	local wsid = UIGetWSID()

	co(function()
		if wsid and tonumber(wsid) then
			self.lbl_chosen:SetText("#outfitter_loadinginfo")
			local info = co_steamworks_FileInfo(wsid)
			if not self:IsValid() then return end
			if not self.lbl_chosen:IsValid() then return end

			if wsid ~= UIGetWSID() then
				return
			end
			if not info or not info.title then
				self.lbl_chosen:SetText("")
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


	local mdllist = UIGetMDLList()

	GUICheckTransmit()


	-- model list
	local chosen
	local current = UIGetChosenMDL()
	for k, dat in next, mdllist or {} do
		if trychoose_mdl and trychoose_mdl == dat.Name then
			chosen = true
		end
		local pnl = self.mdllist:AddLine(dat.Name and MDLToUI(dat.Name) or "???")

		if chosen and chosen == true then
			chosen = pnl
		end

		if k == current then
			pnl:SetSelected(true)
		end
	end

	local extra = UIGetMDLListExtra()
	if extra and extra.discards then
		for k, dat in next, extra.discards or {} do
			local name = dat.Name and MDLToUI(dat.Name) or "???"
			local pnl = self.mdllist:AddLine(language.GetPhrase("outfitter_invalidmodel"):format(name))
			pnl:SetTooltip(dat.error_player or dat.error_vvd or "INVALID MODEL")
		end
	end

	local history = GUIGetHistory()
	self.history_row:SetVisible(#history > 0)
	self.history_row:GetParent():InvalidateLayout()

	for i = #history, 1, -1 do
		local v = history[i]
		local wsid, mdl, title = unpack(v)


		local pnl = vgui.Create('DOWorkshopIcon')
		pnl:SetAddon({ wsid = wsid, title = MDLToUI(mdl) })
		pnl:SetWide(HISTORY_ICON_SIZE)
		self.mdlhist:AddPanel(pnl)
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
end

function PANEL:Think()
	if not self.bg_edit then return end
	local pl = LocalPlayer()
	local new = pl and pl:GetNetData(NTag)
	if new ~= self._bge_lastnvar then
		self._bge_lastnvar = new
		self:RefreshBGE()
		self:RefreshStatus()
	end
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
	self:SetIcon 'icon16/user.png'
	self:SetMinHeight(420)
	self:SetMinWidth(560)
	self:SetSize(math.min(ScrW() - 64, 720), math.min(ScrH() - 64, 600))
	self:SetPos(32, 32)
	self:CenterVertical()
	self:SetDeleteOnClose(false)
	self:SetDraggable(true)
	self:SetSizable(true)
	self.btnMinim:SetVisible(false)
	self.btnMaxim:SetVisible(false)

	local settings = self:Add("DImageButton")
	self.btnSettings = settings
	settings:SetImage('icon16/cog.png')
	settings:SetSize(16, 16)
	settings:SetTooltip("#spawnmenu.utilities.settings")
	settings.DoClick = function()
		self:ToggleSettings()
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
	end
end

function PANEL:PerformLayout(w, h)
	DFrame.PerformLayout(self, w, h)

	local settings = self.btnSettings
	local close = self.btnClose
	if settings and close and close:IsValid() then
		local bx, by = close:GetPos()
		local sw, sh = settings:GetSize()
		settings:SetPos(bx - sw - 8, by + close:GetTall() * .5 - sh * .5)
	end
end

function PANEL:CloseSettings()
	if IsValid(self.settings) then
		self.settings:Remove()
	end
end

function PANEL:ToggleSettings()
	if IsValid(self.settings) then
		self:CloseSettings()
		return
	end

	local frame = vgui.Create('DFrame')
	self.settings = frame
	frame:SetTitle("#spawnmenu.utilities.settings")
	frame:SetIcon('icon16/cog.png')
	frame:SetSize(math.min(ScrW() - 64, 560), math.min(ScrH() - 64, 600))
	frame.btnMinim:SetVisible(false)
	frame.btnMaxim:SetVisible(false)

	local x, y = self:GetPos()
	local right = x + self:GetWide() + 8
	if right + frame:GetWide() <= ScrW() then
		frame:SetPos(right, y)
	else
		frame:Center()
	end
	frame:MakePopup()

	local content = self.content
	frame.OnRemove = function()
		if IsValid(content) then
			content:SaveBlocklist()
		end
	end

	content:CreateSettingsSheet(frame)
end

function PANEL:OnRemove()
	self:CloseSettings()
end

function PANEL:Hide()
	self:SetVisible(false)
	--hook.Run("OnContextMenuClose")
	self:OnClose()
end

function PANEL:OnClose()
	self:CloseSettings()
	self.want_thirdperson = InThirdperson()
	ToggleThirdperson(false)
end

function PANEL:Show(_, trychoose_mdl)
	--if not self:IsVisible() then
	surface.PlaySound "garrysmod/ui_return.wav"
	--end
	self:SetVisible(true)
	self:MakePopup()
	if self.want_thirdperson then
		ToggleThirdperson(true)
	end
	self:DoRefresh(trychoose_mdl)
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
