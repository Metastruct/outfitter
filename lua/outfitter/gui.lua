local Tag='outfitter'

-- lua_openscript_cl srv/outfitter/lua/outfitter/ui.lua;lua_openscript_cl srv/outfitter/lua/outfitter/gui.lua;outfitter_open

module(Tag,package.seeall)
local NOUI=OUTFITTER_NO_UI

local outfitter_gui_focusdim = CreateClientConVar("outfitter_gui_focusdim","0",true)
local vgui = GetVGUI()

-- GUIWantChangeModel
	local PANEL = {}
	
	local matUp = Material"icon16/arrow_up.png"
	
	function PANEL:Init()
		local txt = vgui.Create('DLabel',self,'msg')
		txt:Dock(TOP)
		txt:SetText"If the browser does not change URL please paste the URL yourself in the browser bar from your web browser."
		txt:SetTextColor(Color(0,0,0,255))
		local b = vgui.Create('DButton',self.top,'choose button')
			
			self.chooseb = b
			b:Dock(RIGHT)
			b:SetIcon("icon16/accept.png")
			b:SetText"#select_character"
			b:SizeToContents()
			
			b:SetWidth(math.min(b:GetSize(),256)+32)
			b:SetEnabled(false)
			b:SetZPos(100)
			b:SetCookieName("ofchoosewsbutn")
			b.hideusehint = b:GetCookie("hideusehint")
			b:NoClipping(false)
			b.PaintOver = function(b,w,h)

				if b:IsEnabled() then
					DisableClipping(true)
					
					surface.SetDrawColor(30,255,0,30)
					surface.DrawRect(0,0,w,h)
					surface.SetDrawColor(66,255,22,255*.5 + 255*.3 * (math.sin(RealTime()*7)>0.3 and 1 or -1))
					surface.SetDrawColor(66,255,22,255*.5 + 255*.3 * (math.sin(RealTime()*7)>0.3 and 1 or -1))

					surface.DrawOutlinedRect(-1,-1,w+2,h+2)
					surface.DrawOutlinedRect(0,0,w,h)
					
					
					surface.SetDrawColor(255,255,255,255)
					surface.SetMaterial(matUp)
					local sz = 32
					surface.DrawTexturedRect(w*.5-sz*.5,h-2+math.sin(RealTime()*7)*4,sz,sz)
					
					DisableClipping(false)
				end
			end
		
			b.DoClick=function(b,mc)
				b.hideusehint=true
				b:SetCookie("hideusehint",'1')
				self:WSChoose()
			end
			self:GetBrowser():AddFunction( "gmod", "wssubscribe", function() self:WSChoose() end )
			
	end

	function PANEL:WSChoose()
		self:Hide()
		if self.chosen_id then
			surface.PlaySound"npc/vort/claw_swing1.wav"
			UIChoseWorkshop(self.chosen_id,self.returntoui)
		end
	end
	function PANEL:LoadedURL(url,title)
		self.BaseClass.LoadedURL(self,url,title)
		if not url or url=="" then return end
		
		-- sharedfiles/filedetails/?id=422403917&searchtext=playermodel

		local id = UrlToWorkshopID(url)
		self.chooseb:SetEnabled(id and true or false)
		self.chosen_id = tonumber(id)
		--print(id)
	end
	
	function PANEL:InjectScripts(browser)
		--dbg("Injecting browser code",browser or "NOBROWSER")
		browser:QueueJavascript[[
		
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
	function PANEL:Show(str,returntoui)
		
		self.returntoui = returntoui
		
		local dourl = not self.already_loaded
		self.already_loaded = true
		
		local url = 'http://steamcommunity.com/workshop/browse/?appid=4000&searchtext=playermodel&childpublishedfileid=0&browsesort=trend&section=readytouseitems&requiredtags%5B%5D=Model'
		if str then
			str = str and tostring(str)
			str = str and #str>0 and str
			if str then
				str = string.urlencode and string.urlencode(str) or str
				url = 'http://steamcommunity.com/workshop/browse/?appid=4000&searchtext=playermodel+'..str..'&childpublishedfileid=0&browsesort=trend&section=readytouseitems&requiredtags%5B%5D=Model'
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
		if txt~=self.lasttextobserved then
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
	vgui.Register(Tag,PANEL,'custombrowser')

	m_vModelDlg = NULL
	function GUIWantChangeModel(str,returntoui)
		
		if not ValidPanel(m_vModelDlg) then
			local d = vgui.Create(Tag,nil,Tag)
			m_vModelDlg = d
		end
		
		m_vModelDlg:Show(str,returntoui)
		
		return m_vModelDlg
	end

	
	
	

	
	
	
	
	
	
	
	
	
-- GUIOpen



local PANEL = {}
function PANEL:Init()
	
	local functions = self:Add('DPanel','settings')
	functions:Dock(LEFT)
	functions:SetWidth(300)
	functions:SetHeight(300)
	functions:DockMargin(4,1,24,0)
	functions:SetPaintBackground(false)
	
	--functions:EnableVerticalScrollbar()

	local function Add(itm,b)
		local c= vgui.Create(itm,functions,b)
		--settingslist:AddItem(c)
		c:Dock(BOTTOM)
		return c
	end
	
	do
		local b = functions:Add('DButton','choose button')
			self.btn_choose = b

			b:Dock(TOP)
			b:SetText("#open_workshop")
			b:SetTooltip[[Choose a workshop addon which contains an outfit]]

			b.DoClick= function()
				
				GUIWantChangeModel(nil,true)
				
				self:GetParent():Hide()
			end
			b:DockMargin(0,4,1,8)
			b:SetImage'icon16/folder_user.png'
			b.PaintOver = function(b,w,h)
				if not next(self.mdllist:GetLines()) then
					b:NoClipping(false)
					surface.SetDrawColor(140,255,140,255*.5 + 255*.3 * math.sin(RealTime()*4))

					surface.DrawOutlinedRect(-1,-1,w+2,h+2)
					surface.DrawOutlinedRect(0,0,w,h)
					b:NoClipping(true)
				end
			end
	end
	do
		local b = functions:Add('DTextEntry','url input')
			self.input_mdlsource = b

			b:Dock(TOP)
			b:SetText("")
			b:SetPlaceholderText("https://steamcommunity.com/sharedfiles/filedetails/?id=1234")

			b.OnEnter= function()
				
				local url = b:GetValue():Trim()
				if url =="puze" then 
					url="https://g2cf.metastruct.net/delme/puze.gma"
				end
				local wsid = UrlToWorkshopID(url,true)
				dbg("GUI","UrlToWorkshopID",url,wsid)
				if wsid then

					surface.PlaySound"npc/vort/claw_swing1.wav"
					UIChoseWorkshop(wsid,true)
					self:GetParent():Hide()
				else
					if IsHTTPURL(url) then
						if AllowedHTTPURL(url) then
							self:GetParent():Hide()
							UIChoseHTTPGMA(url,true)
						else
							chat.AddText("This HTTP URL is not in allowlist")					
							surface.PlaySound"common/warning.wav"
						end
					else
						dbg("Not HTTP URL",url)
						surface.PlaySound"common/warning.wav"
					end
				end
			end
			b:DockMargin(0,4,1,8)
	end

	local l = functions:Add( "DLabel",'chosen' )
		self.lbl_chosen = l
		l:Dock(TOP)
		l:DockMargin(1,1,1,1)
		l:SetWrap(true)
		l:SetTooltip[[Title of the chosen workshop addon]]
		l:SetText("1. Choose a workshop addon")
		l:SetTall(44)
		l:SetFont"BudgetLabel"
		l:SetTextColor(Color(255,255,255,255))
		
		
	
	local mdllist = functions:Add( "DListView",'modelname' )
		mdllist:SetMultiSelect( false )
		mdllist:AddColumn( "#gameui_playermodel" )
		self.mdllist = mdllist
		mdllist:SetTooltip[[Click one of the models on this list to choose as your outfit]]
		mdllist:DockMargin(0,5,0,0)
		mdllist:Dock(FILL)
		mdllist:SetTall(128)
		mdllist.OnRowSelected = function(mdllist,n,itm)
			local ret = GUIChooseMDL(n)
			if not ret then
				surface.PlaySound"common/warning.wav"
			end
			self.btn_bg:Refresh()
		end
		--TODO : OnRowRightClick
		function mdllist.PerformLayout(mdllist)
			DListView.PerformLayout(mdllist)
			self.btn_bg:InvalidateLayout()
		end
		mdllist.PaintOver = function(b,w,h)
			if next(mdllist:GetLines()) and not mdllist:GetSelectedLine() then
				mdllist:NoClipping(false)
				surface.SetDrawColor(255,66,22,255*.5 + 255*.3 * math.sin(RealTime()*4))

				surface.DrawOutlinedRect(-1,-1,w+1,h+1)
				surface.DrawOutlinedRect(0,0,w,h)
				mdllist:NoClipping(true)
			end
		end
		
	local sheet = self:Add( "DPropertySheet" )
		self.sheet = sheet
		sheet:Dock( FILL )
		
	local mdlhistpanel = self:Add( "EditablePanel" )
		self.mdlhistpanel=mdlhistpanel
		sheet:AddSheet( "#servers_history", mdlhistpanel, "icon16/user.png" )
	local settingspnl = self:Add( "DScrollPanel" )
		self.settingspnl=settingspnl
		sheet:AddSheet( "#spawnmenu.utilities.settings", settingspnl, "icon16/cog.png" )
	local blocklistPanel = self:Add( "EditablePanel" )
		self.blocklistPanel=blocklistPanel
		sheet:AddSheet( "#Blocklist", blocklistPanel, "icon16/stop.png" )
	local infopanel = self:Add( "EditablePanel" )
		self.infopanel=infopanel
		infopanel.Think=function()
			infopanel.Think=function() end
			
			local p = vgui.CreateFromTable(about_factory,infopanel)
			self.aboutpnl = p
			--print"create about"
			infopanel.aboutpnl = p
			p:Dock(FILL)
		end
		infopanel:Dock(FILL)
		sheet:AddSheet( "#information", infopanel, "icon16/information.png" )
		
		local function AddS(itm,b)
			
			local c= vgui.Create(itm,settingspnl,b)
			--settingslist:AddItem(c)
			c:Dock(TOP)
			return c
		end
		
		
	
	
	----------------------------------------------------


	blocklistPanel:DockPadding( 2,1,2,1 )


	local txt = blocklistPanel:Add('DLabel','infomsg')
	txt:Dock(TOP)
	txt:SetText"Title blocklist"
	txt:SetWrap(true)
	txt:SetTextColor(Color(0,0,0,255))


	
	local check = blocklistPanel:Add( "DCheckBoxLabel",'nsfwtoggle' )
	 	check:SetConVar("nsfw")
		check:SetText( "Allow NSFW")
		check:SizeToContents()
		check:SetTooltip[[Allow NSFW content in title]]
		check:DockMargin(1,0,1,1)
		check:Dock(TOP)

	local TextEntry = blocklistPanel:Add("DTextEntry", "blocklist" )
	TextEntry:SetSize(100,200)
	TextEntry:Dock( FILL )
	TextEntry:SetValue(table.concat(GetTitleBlocklist(),"\n"))
	TextEntry:SetMultiline(true)
	TextEntry:SetVerticalScrollbarEnabled(true)
	TextEntry:SetAllowNonAsciiCharacters(true)
	TextEntry:SetEditable(true)
	TextEntry:SetTooltip"Add a banned sentence per line.\n An outfit's title matching any of the sentences will be blocked."
	TextEntry:SetPlaceholderText"Add a banned sentence per line.\n An outfit's title matching any of the sentences will be blocked."
	function TextEntry.OnLoseFocus()
		SetTitleBlocklist(TextEntry:GetValue())
		TextEntry:SetValue(table.concat(GetTitleBlocklist(),"\n"))
	end
	----------------------------------------------------

	mdlhistpanel:DockPadding( 2,1,2,1 )

	local function hr()
		local b = AddS('EditablePanel')
		b:SetTall(2)
		b:DockMargin(1,24,1,2)
		b.Paint = function(b,w,h)
			surface.SetDrawColor(240,240,240,200)
			surface.DrawRect(0,0,w,h)
		end
		local hr_line1 = b
	end

	local scroll = mdlhistpanel:Add( "DScrollPanel",'mdlhistscroll' )
	scroll:Dock(FILL)
	local mdlhist = scroll:Add( "DIconLayout",'mdlhist' )
		mdlhist:DockMargin(4,4,4,4)
		--mdlhist:SetMultiSelect( false )
		--mdlhist:AddColumn( "#name" )
		--mdlhist:AddColumn( "#gameui_playermodel" )
		self.mdlhist = mdlhist
	
		
		mdlhist:Dock(FILL)
		mdlhist.OnRowSelected = function(mdlhist,n,itm)
			local dat = GUIGetHistory()[n]
			if not dat then return end
			if not self:WantOutfitMDL(unpack(dat)) then
				surface.PlaySound"common/warning.wav"
			end
		end

		function mdlhist:Clear()
			local chld = self:GetChildren()
			for k, v in pairs( chld ) do
				v:Remove()
			end
		end
		
	local b = mdlhistpanel:Add('DButton','choose button')
		self.btn_clearhist = b
		
		b:Dock(BOTTOM)
		
		b:SetText("#gameui_clearbutton")
		b.DoClick= function()
			GUIClearHistory()
		end
		b:DockMargin(0,5,0,0)
		b:SetImage'icon16/bin.png'
	
	
	
	local check = AddS( "DCheckBoxLabel" )
	 	check:SetConVar(Tag.."_enabled")
		check:SetText( "#gameui_enabled")
		check:SizeToContents()
		check:SetTooltip[[Toggle this if someone's outfit got blocked or should be showing]]
		check:DockMargin(1,0,1,1)
		local btn_en = check
		
	local check = AddS( "DCheckBoxLabel" )
		check:SetConVar(Tag.."_friendsonly")
		check:SetText( "Load only outfits of friends")
		check:SetTooltip[[When non friend wears an outfit it gets blocked]]
		check:SizeToContents()

		check:DockMargin(1,4,1,1)
	local d_5 = check

	hr()

	local slider = AddS( "DNumSlider" )
		slider:SetText( "Outfit download distance" )
		slider:SizeToContents()
		slider:DockPadding(0,16,0,0)
		slider.Label:Dock(TOP)
		slider.Label:DockMargin(0,-16,0,0)
		slider:SetTooltip[[How near does a player have to be for an outfit to download]]

		slider:DockMargin(1,12,1,1)
		slider:SetMin( 0 )
		slider:SetMax( 5000 )
		slider:SetDecimals( 0 )
		slider:SetConVar( Tag..'_distance' )
		local sld_dist = slider
			
	local c = AddS( "DComboBox" )
	c:SetSize( 100, 20 )
	c:SetTooltip[[Distance mode: start downloading outfits when you get near a player]]
	--c.SetValue = function(c,val)
	--	local setv = val==0 and 2 or val==1 and 3 or 1 
	--	dbgn(2,"ChooseDistanceModeCtrl",val,'->',setv)
	--	c:ChooseOptionID(setv)
	--end
	local distance_mode
	c.OnSelect = function(c,val)
		distance_mode=distance_mode or GetConVar(Tag..'_distance_mode')
		local choose = val==1 and -1 or val==2 and 0 or 1
		dbgn(2,"ChooseDistanceMode", val, '->', choose )
		distance_mode:SetInt(choose)
	end
	c:AddChoice( "Default Mode", '-1' )
	c:AddChoice( "See All Outfits", '0' )
	c:AddChoice( "Nearby Outfits Only", '1' )
	
	c:SetConVar(Tag..'_distance_mode')
	local d_4 = c
	c:DockMargin(0,12,0,0)
	
	
	hr()

	local slider = AddS( "DNumSlider" )
		slider:SetText( "Maximum download size (in MB)" )
		slider:SizeToContents()
		slider:DockPadding(0,16,0,0)
		slider.Label:Dock(TOP)
		slider.Label:DockMargin(0,-16,0,0)
		
		slider:SetTooltip[[This is how big an outfit you can receive without it being blocked]]

		slider:DockMargin(1,4,1,1)
		slider:SetMin( 0 )
		slider:SetMax( 256 )
		slider:SetDecimals( 0 )
		slider:SetConVar( Tag..'_maxsize' )
		local sld_dl = slider
	--TODO
	--local check = functions:Add( "DCheckBoxLabel" )
	-- 	check:SetConVar(Tag.."_ask")
	--	check:SetText( "Ask mode")
	--	check:SizeToContents()
	--	check:Dock(TOP)
	--	check:DockMargin(1,4,1,1)
	
	
	hr()

	local check = AddS( "DCheckBoxLabel" )
	 	check:SetConVar(Tag.."_hands")
		check:SetText( "Use hands")
		check:SetTooltip[[Should we guess hands for the playermodels]]
		check:SizeToContents() 

		check:DockMargin(1,4,1,1)
	local d_6 = check
	
	local check = AddS( "DCheckBoxLabel" )
	 	check:SetConVar(Tag.."_sounds")
		check:SetText( "UI sounds")
		check:SetTooltip[[Should we play informational sounds]]
		check:SizeToContents() 

		check:DockMargin(1,4,1,1)
	local d_7 = check
	
	local check = AddS( "DCheckBoxLabel" )
	 	check:SetConVar(Tag.."_gui_focusdim")
		check:SetText( "Dim GUI")
		check:SetTooltip[[When mouse leaves the UI should we dim it?]]
		check:SizeToContents()
		check:DockMargin(1,4,1,1)
		
	hr()
	local check = AddS( "DCheckBoxLabel" )
		check:SetConVar(Tag.."_allow_http_test")
		check:SetText( "Allow outfits from outside workshop")
		check:SetTooltip[[Allow HTTP downloads from outside workshop. Unsafe potentially!!!]]
		check:SizeToContents()

		check:DockMargin(1,4,1,1)




	local check = AddS( "DCheckBoxLabel" )
		check:SetConVar(Tag.."_allow_unsafe_http")
		check:SetText( "Load outfits from untrusted URLs (UNSAFE, may leak IP!!!)")
		check:SetTooltip[[Outfitter by default does not allow HTTP downloads from everywhere, but can be set to allow them for local testing]]
		check:SizeToContents()

		check:DockMargin(1,4,1,1)

	hr()

	local debug = AddS( "DCheckBoxLabel" )
	 	debug:SetConVar(Tag.."_dbg")
		debug:SetText( "#debug")
		debug:SetTooltip[[Print debug stuff to console. Enable this if something is wrong and in the bugreport give the log output.]]
		debug:SizeToContents()
 
		debug:DockMargin(1,14,1,1)
		local d_3 = debug

	local check = AddS( "DCheckBoxLabel" )
	 	check:SetConVar(Tag.."_unsafe")
		check:SetText( "Unsafe")
		check:SizeToContents()

		check:SetTooltip[[Remove some outfit checks (for yourself only). This should not be needed ever.]]
		check:DockMargin(1,4,1,1)
		local d_1 = check
	local check = AddS( "DCheckBoxLabel" )
	 	check:SetConVar(Tag.."_failsafe")
		check:SetText( "Failsafe")
		check:SizeToContents()
		check:SetTooltip[[This gets ticked if you were detected to crash right after applying outfit.]]

		check:DockMargin(1,4,1,1)
		local d_2 = check
		
	local check = AddS( "DCheckBoxLabel" )
	 	check:SetConVar(Tag.."_use_autoblacklist")
		check:SetText( "Autoblacklist")
		check:SizeToContents()
		check:SetTooltip[[Blacklists outfits that crashed you automatically]]
		check:DockMargin(1,4,1,1)
		local d_2 = check
	hr()
	local check = AddS( "DCheckBoxLabel" )
	 	check:SetConVar(Tag.."_animfix_oldmethod")
		check:SetText( "Legacy: Use fullupdate for local player animations")
		check:SizeToContents()
		check:SetTooltip[[Previously we needed a fullupdate to fix animations. Now a different technique is used.]]

		check:DockMargin(1,4,1,1)
		
	local check = AddS( "DCheckBoxLabel" )
		check:SetConVar(Tag.."_download_notifications")
		check:SetText( "Legacy: Show downloading notifications")
		check:SizeToContents()
		check:SetTooltip[[Show downloading notifications when downloading models from the workshop]]

		check:DockMargin(1,4,1,1)

	local check = AddS( "DButton" )
	 	check:SetText( "FIX: Clear models blacklist") 
		check:DockMargin(1,4,1,1)
		check.DoClick=function()
			RunConsoleCommand"outfitter_blacklist_clear"
		end
		check:SetImage'icon16/tag_blue_delete.png'
		
	local check = AddS( "DButton" )
	 	check:SetText( "FIX: Fullupdate") 
		check:DockMargin(1,4,1,1)
		check.DoClick=function()
			Fullupdate()
		end
		check:SetImage'icon16/transmit_error.png'
		
	local check = AddS( "DButton" )
	 	check:SetText( "FIX: Local player animations") 
		check:DockMargin(1,4,1,1)
		check.DoClick=function()
			FixLocalPlayerAnimations(true)
		end
		check:SetImage'icon16/transmit_error.png'
		
	local b = Add('DButton','thirdperson')
		b:SetText("#tool.camera.name")
		b:SetTooltip[[Enables/disable thirdperson (if one is installed)]]

		b.DoClick=function() ToggleThirdperson() end
		b:DockMargin(16,2,16,1)
		b:SetImage'icon16/find.png'
	
	
	
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
	local cont = functions:Add('EditablePanel','container')
	cont:SetTall(24)
	cont:Dock(BOTTOM)
		
	local b = vgui.Create('DButton',mdllist,'Bodygroups button')
		function b.Refresh(b)
			-- poor man's pcall
			co(function()
				b.mdl = false
				b:SetEnabled2(false)
				dbg("Bodygroup","BTN","Refresh")
				
				local l = UIGetMDLList()
				if not l then return end
				local chosen = UIGetChosenMDL()
				if not chosen then return false end
				local mdl = l[chosen]
				if not mdl then return false end
				if not file.Exists(mdl.Name,'workshop') and not file.Exists(mdl.Name,'GAME') then return false end
				local a = mdlinspect.Open(mdl.Name)
				a:ParseHeader()
				local parts = a:BodyPartsEx()
				local ok 
				for k,v in next,parts do
					if v.nummodels>1 then
						ok=true
						break
					end
				end
				if not ok then return end
				
				b:SetEnabled2(true)
				b.mdl = mdl
			end)
		end
		
		
		self.btn_bg= b
		b:Dock(NODOCK)
		b:SetText("")
		b:SetSize(24,24)
		b:SetTooltip[[#GameUI_Modify]]
		b.DoClick= function()
			GUIOpenBodyGroupOverlay(self) --, b.mdl.Name)
		end
		b:SetImage'icon16/group_edit.png'
		b.PerformLayout=function(b,w,h)
			DButton.PerformLayout(b,w,h)
			
			local w2 = b:GetParent():GetCanvas():GetWide()
			
			local _,y = b:GetParent():GetSize()
			b:SetPos(w2-w-1,y-h-1)
		end
		function b.SetEnabled2(b,v)
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
	
	local b = cont:Add('DButton','Autowear button')
		self.btn_autowear = b
		b:SetTooltip[[Automatically wear this outfit on servers]]
		b:SetText("#makepersistent")
		b:Dock(FILL)
		b:SizeToContents()
		b.DoClick = function()
			local m = DermaMenu()
				m:AddOption("#makepersistent",function()
					SetAutowear()
				end):SetIcon'icon16/vcard_edit.png'
				m:AddOption("#vgui_htmlreload",function()
					if co.make() then return end
					coDoAutowear()
				end):SetIcon'icon16/transmit_go.png'
			m:Open()
		end
		b:SetImage'icon16/disk.png'
	
	
	--------------------------------------------------

	
	local cont = functions:Add('EditablePanel','container')
	cont:SetTall(32)
	cont:Dock(BOTTOM)
	
	local b = cont:Add('DButton','Send button')
		self.btn_send= b
		b:Dock(LEFT)
		b:SetText("#gameui_submit")
		b:SetTooltip[[This broadcasts the outfit you have chosen to the whole server]]
		b.DoClick= function()
			GUIBroadcastMyOutfit()
			b._set_enabled  = false
			self:GetParent():Hide()
		end
		b:SetImage'icon16/transmit.png'
		b.PerformLayout=function(b,w,h)
			DButton.PerformLayout(b,w,h)
			b:SetWide(b:GetParent():GetWide()*.5)
		end
		self.btnSendOutfit = b
		function b.SetEnabled2(b,v)
			b:SetDisabled(not v)
			b._set_enabled = v
		end
		b.PaintOver= function(b,w,h)
			if b._set_enabled then
				if UIGetChosenMDL() and UIGetMDLList() and LocalPlayer().latest_want~=UIGetMDLList()[UIGetChosenMDL()] then
					surface.SetDrawColor(55,240,55,40+25*math.sin(RealTime()*7)^2)
					surface.DrawRect(1,1,w-2,h-2)
				end
			end
		end
	
	
	
	local b = cont:Add('DButton','Clear button')
		self.btn_clear = b
		b:SetTooltip[[This removes all traces of you wearing an outfit]]
		b:SetText("#gameui_cancel")
		b:Dock(FILL)
		b:SizeToContents()
		b.DoClick= function()
			UICancelAll()
			self:DoRefresh(trychoose_mdl)
			--self:GetParent():Hide()
		end
		b:SetImage'icon16/cancel.png'
		
		
	
	local div = self:Add"DHorizontalDivider"
	div:Dock( FILL )
	
	functions:Dock(NODOCK)
	sheet:Dock(NODOCK)
	div:SetCookieName(Tag)
	div:SetLeft( functions )
	div:SetRight( sheet )
	div:SetDividerWidth( 4 ) --set the divider width. DEF: 8
	div:SetLeftMin( 150 )	 --set the minimun width of left side
	div:SetRightMin( 0 )
	div:SetLeftWidth( 300 )

	--------------------------------------------------
	
end


gui_readytosend = false
local wanting = false
local want_wsid
local want_mdl
function PANEL:WantOutfitMDL(wsid,mdl,title)
	dbg("WantOutfitMDL",wanting and "ALREADY WANTING" or "",wsid,mdl,title)
	if wanting and want_wsid == wsid then
		want_mdl = mdl
	end
	
	if wanting then return false end
	want_wsid = wsid
	want_mdl = mdl
	
	local worker=co(function()
		if wanting then return end
		wanting = true
		self:GetParent():Hide()
		dbg("WantOutfitMDL",wanting and "ALREADY WANTING" or "",wsid,mdl,title)
		local ok,err = xpcall(UIChoseWorkshop,debug.traceback,wsid)
		if not ok then ErrorNoHalt(err..'\n') wanting=false return end
		GUIOpen(nil,want_mdl)
		wanting = false
	end)
	
	return worker

end


function PANEL:WSChoose()
	self:Hide()
	if self.chosen_id then
		surface.PlaySound"npc/vort/claw_swing1.wav"
		UIChoseWorkshop(self.chosen_id)
	end
end


function GUIBroadcastMyOutfit()
	local mdl,wsid = UIBroadcastMyOutfit()
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
			GUIAddHistory(wsid,title,mdl)
		end)
	end
end

local want_n
local choosing
function GUIChooseMDL(n)
	
	dbg("GUIChooseMDL",n,choosing and "already choosing, changing" or "",want_n)
	want_n = n
	
	if choosing then return false end
	local mdllist = UIGetMDLList()
	local mdl = mdllist and mdllist[n]
	if not mdl then return false end
	
	co(function()
		if choosing then return end
		choosing = true
		UIChangeModelToID(n)
		if n~=want_n and want_n then
			dbg("CHANGE WANT OT",want_n)
			UIChangeModelToID(want_n,true)
		end
		dbg("GUIChooseMDL","FINISH",n)
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
	local s= json.encode(t)
	util.SetPData("0",Tag,s)
end

local function LOAD()
	local s= util.GetPData("0",Tag,false)
	if not s or s=="" or s=="nil" then return {} end
	local t = json.decode(s)
	return t or {}
end

local hist
function GUIAddHistory(wsid,title,mdl)
	if not title or not mdl or not wsid then return end
	if not hist then
		GUIGetHistory()
	end
	for k,v in next,hist do
		local wsid2,mdl2 = v[1],v[2]
		if wsid2==wsid and mdl2==mdl then return end
	end
	
	local t = {wsid,mdl,title}
	table.insert(hist,t)
	SAVE(hist)
	
	GUIRefresh()
	
	return t
end

function GUIGetHistory()
	if not hist then hist = LOAD() end
	return hist
end

function GUIDelHistory(n)
	if n<0 then table.Empty(hist) end
	local ret = table.remove(hist,n)
	SAVE(hist)
	
	GUIRefresh()
	
	return ret
end

function GUICheckTransmit()
	local gui  = GUIPanel()
	if not gui then return end
	local self = gui.content
	if not self then return end
	
	local cansend = UIGetChosenMDL() and UIGetDownloadInfoX() and UIGetMDLList()
	self.btnSendOutfit:SetEnabled2(cansend)
	self.btn_bg:Refresh()
end

function PANEL:DoRefresh(trychoose_mdl)
	dbg("doRefresh",trychoose_mdl)
	self.mdllist:Clear()
	self.btn_bg:Refresh()
	self.mdlhist:Clear()
	
	self.lbl_chosen:SetText("Please choose a workshop addon")

	local wsid = UIGetWSID()
	
	co(function()
		self.lbl_chosen:SetText("-")

		if wsid and tonumber(wsid) then
			self.lbl_chosen:SetText( "Loading info..." )
			local info = co_steamworks_FileInfo(wsid)
			if not self:IsValid() then return end
			if not self.lbl_chosen:IsValid() then return end
			
			if wsid~=UIGetWSID() then
				return
			end
			if not info or not info.title then
				self.lbl_chosen:SetText("-")
			else
				local str = ("%s (%s)"):format(info.title,string.NiceSize(info.size or 0))
				self.lbl_chosen:SetText(str)
			end
		
		elseif wsid and #wsid:find"http" then -- it's a gma download
			local ok,body,len,hdrs,code = co_head(wsid)
			if ok then
				self.lbl_chosen:SetText("GMA: Not OK?")
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
	for k,dat in next,mdllist or {} do
		if trychoose_mdl and trychoose_mdl==dat.Name then
			chosen = true
		end
		local pnl = self.mdllist:AddLine( dat.Name and MDLToUI(dat.Name) or "???" )
		
		if chosen and chosen==true then
			chosen = pnl
		end
		
	end
	
	local extra = UIGetMDLListExtra()
	if extra and extra.discards then
		
		for k,dat in next,extra.discards or {} do
			local pnl = self.mdllist:AddLine( dat.Name and MDLToUI(dat.Name) or "???" )
			pnl:SetTooltip(dat.error_player or dat.error_vvd or "INVALID MODEL")
			local Paint = pnl.Paint or function() end
			pnl.Paint = function(pnl,w,h)
				local r = Paint(pnl,w,h)
				surface.SetDrawColor(240,30,30,120)
				surface.DrawRect(0,0,w,h)
				return r
			end
		end
	
	end
	
	for _,v in next,GUIGetHistory() do
		local wsid,mdl,title = unpack(v)

		
		local pnl = self.mdlhist:Add( 'DOWorkshopIcon' )
		pnl:SetAddon({wsid = wsid,title=MDLToUI(mdl)})
		self.mdlhist:Layout()
		pnl:SetTooltip(title .. '\n'..mdl)
		pnl._OnMousePressed = pnl.OnMousePressed
		pnl.OnMousePressed = function(pnl,mc)
			if mc==MOUSE_RIGHT then
				local m = DermaMenu()
					m:AddOption("#open_workshop",function()
						gui.OpenURL(("https://steamcommunity.com/workshop/filedetails/?id=%d"):format(wsid))
					end):SetIcon'icon16/world.png'
					m:AddOption("#gameui_delete",function()
						for n,vv in next,GUIGetHistory() do
							if vv==v then
								GUIDelHistory(n)
								return
							end
						end
					end):SetIcon'icon16/bin.png'
				m:Open()
				return
			elseif mc==MOUSE_LEFT then
				if not self:WantOutfitMDL(unpack(v))then
					surface.PlaySound"common/warning.wav"
				end
			end
			
		end
	end

	if chosen then
		if chosen~=true then
			
			dbg("SelectItem","AUTO",chosen,trychoose_mdl)
			
			self.mdllist:SelectItem(chosen)

		else
			dbg("Choose missing",trychoose_mdl)
		end
		
	end
	
	self.btn_bg:Refresh()
	
end

local factory = vgui.RegisterTable(PANEL,'EditablePanel')









-- main panel

local PANEL={}
function PANEL:Init()

	local pnl = vgui.CreateFromTable(factory,self)
	self.content = pnl
	pnl:Dock(FILL)
	
	local t=os.date"*t"
	self.m_bPaintHat = t.month==12 and t.day<=25
	
	self:SetCookieName"ofp"
	self:SetTitle"Outfitter"
	self:SetMinHeight(290)
	self:SetMinWidth(312)
	self:SetPos(32,32)
	self:SetDeleteOnClose(false)
	self.btnMinim:SetEnabled(true)
	self.btnMaxim:SetEnabled(true)
	local had_max = self:GetCookie( "pmax", "" ) == '1'
	
	if had_max then
		self:SetSize(640,400)
	else
		self:SetSize(313,293)
	end
	 
	self.btnMaxim.DoClick=function()
		self:SetSize(640,400)
		self:SetCookie( "pmax", '1' )
		had_max = true
		self:CenterVertical()
	end
	
	self:CenterVertical()
	
	if not had_max then
		self.btnMaxim.PaintOver = function(b,w,h)
			if had_max then return end
			b:NoClipping(false)
			surface.SetDrawColor(255,66,22,255*.5 + 255*.3 * math.sin(RealTime()*4))

			surface.DrawOutlinedRect(-1,-1,w+1,h+1)
			surface.DrawOutlinedRect(0,0,w,h)
			b:NoClipping(true)
		end
	end
	self.btnMinim.DoClick=function()
		self:SetSize(313,293)
		self:CenterVertical()
		
	end
	self:SetDraggable( true )
    self:SetSizable( true )
	
	local title = self.lblTitle
	if title then
		self:SetIcon'icon16/user.png'
		--local img = vgui.Create('DImage',title)
		--img:SetImage("icon16/user.png")
		--img:Dock(LEFT)
		--img.PerformLayout = function()
		--	img:SetWide(img:GetTall())
		--	title:SetTextInset(img:GetTall() + 5,0)
		--end
	
		local check = self:Add( "DCheckBoxLabel" )
	 	check:SetConVar(Tag.."_enabled")
		check:SetText( "#gameui_enabled")
		check:SizeToContents()
		check:SetTooltip[[Toggle this if someone's outfit got blocked or should be showing]]
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
		
		local hasf = not outfitter_gui_focusdim:GetBool() or (hovered or not self.hadhover) or self.Dragging or self.Sizing
		if hasf~=self.hierfocused then
			self.hierfocused = hasf
			if hasf then
				self.fadeouttime=nil
				self:SetAlpha(255)
			else
				self.fadeouttime = RealTime()
			end
		end
		if self.fadeouttime then
			local f = (RealTime()-self.fadeouttime)/0.15
			f=1-f
			f=f>1 and 1 or f<0 and 0 or f
			self:SetAlpha(f*200+55)
		end
		
		local x,y=self:CursorPos()
		if x>0 and x<20 and y>0 and y<20 then
			self:SetCursor( "hand" )
		end
	end
end

function PANEL:OnMouseReleasedHook(mc)

	local x,y = self:CursorPos()
	if x<0 or x>20 then return end
	if y<0 or y>20 then return end
	
	
	if mc==MOUSE_LEFT then
		GUIAbout()
		return
	end
	
	local menu = DermaMenu()
	
	if UIGetChosenMDL() and UIGetMDLList() and LocalPlayer().latest_want~=UIGetMDLList()[UIGetChosenMDL()] then
		menu:AddOption( "#gameui_submit", function() GUIBroadcastMyOutfit() end ):SetImage'icon16/transmit.png'
	end
	
	--menu:AddLine()
	
	menu:AddOption( "About", function() GUIAbout() end ):SetImage'icon16/information.png'
	menu:AddOption( "Close", function() self:Hide() end ):SetImage'icon16/door_out.png'
	menu:Open()
end

function PANEL:PerformLayout(w,h)
	DFrame.PerformLayout(self,w,h)
	self.btnMinim:SetEnabled(w>(self:GetMinWidth() + 5) or h>(5 + self:GetMinHeight()))
	
	local check = self.btnCheck
	local cw,ch = 0,0
	if check then
		cw,ch = check:GetSize()
	end
	
	local b = self.btnMinim or self.btnMaxim
	if b and b:IsValid() then
		local bw,bh = b:GetWide(),b:GetTall()
		local bx,by = b:GetPos()
		if check then
			check:SetPos(bx-cw-4,by+bh*.5-ch*.5+1)
			check:SetVisible(w>256)
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

function PANEL:Show(_,trychoose_mdl)
	--if not self:IsVisible() then
		surface.PlaySound"garrysmod/ui_return.wav"
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

local factory = vgui.RegisterTable(PANEL,'DFrame')

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

local prev = rawget(_M,'m_vGUIDlg')
if ValidPanel(prev) then prev:Remove() end
m_vGUIDlg = NULL
local alerted
function GUIOpen(_,trychoose_mdl)
	

	if not ValidPanel(m_vGUIDlg) then
		local d = vgui.CreateFromTable(factory,nil,Tag..'_GUI')
		m_vGUIDlg = d
	end
	
	
	m_vGUIDlg:Show(nil,trychoose_mdl)
	
	if Derma_Message and not alerted and game.SinglePlayer() then
		alerted = true
		Derma_Message("You are playing singleplayer. Outfitter may not work at all.",'WARNING')
	end
	
	return m_vGUIDlg
end

	

if NOUI then return end
concommand.Add(Tag..'_open',function()
	GUIOpen()
end)
--RunConsoleCommand(Tag..'_open')


  

-- button --



local icon = "icon64/outfitter.png"
icon = file.Exists("materials/"..icon,'GAME') and icon or "icon64/playermodel.png"

list.Set("DesktopWindows", Tag, {
	title		= "Outfitter",
	icon		= icon,
	width		= 1,
	height		= 1,
	onewindow	= false,
	init		= function( icon, window )
		window:GetParent():Close()
		window:Remove()
		GUIOpen()
	end
})
