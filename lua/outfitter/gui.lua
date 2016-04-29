local Tag='outfitter' 
local NTag = 'OF'

-- lua_openscript_cl srv/outfitter/lua/outfitter/ui.lua;lua_openscript_cl srv/outfitter/lua/outfitter/gui.lua;outfitter_open

module(Tag,package.seeall)
local _vgui = vgui

local recurse recurse = function(pnl)
	pnl:SetSkin('Outfitter')
	print(pnl)
	for k,v in next,pnl:GetChildren() do
		recurse(v)
	end
end

local vgui = {
	Create=function(...)
		local ret = _vgui.Create(...)
		local _ = ret and ret:IsValid() and recurse(ret)
		timer.Simple(0,function()
			local _ = ret and ret:IsValid() and recurse(ret)
		end)
		return ret
	end,
	CreateFromTable=function(...)
		local ret = _vgui.CreateFromTable(...)
		local _ = ret and ret:IsValid() and recurse(ret)
		timer.Simple(0,function()
			local _ = ret and ret:IsValid() and recurse(ret)
		end) 
		return ret
	end,
	
}
--timer.Simple(1,function() derma.RefreshSkins()  end)
setmetatable(vgui,{__index=_vgui})
 
-- GUIWantChangeModel
	local PANEL = {}
	function PANEL:Init()
		local b = vgui.Create('DButton',self.top,'choose button')
			
			self.chooseb = b
			b:Dock(RIGHT)
			b:SetIcon("icon16/eye.png")
			b:SetText"CHOOSE THIS WORKSHOP ADDON"
			b:SizeToContents()
			b:SetWidth(b:GetSize()+32)
			b:SetEnabled(false)
			b.DoClick=function(b,mc)
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


		local id = url:match'://steamcommunity.com/sharedfiles/filedetails/.*[%?%&]id=(%d+)'
		self.chooseb:SetEnabled(id and true or false)
		self.chosen_id = tonumber(id)
		print(id)
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
	function PANEL:Think()
		self.BaseClass.Think(self)
		--print(self.LoadedURL)
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
	
	local functions = self:Add('DPanelList','settings')
	functions:Dock(LEFT)
	functions:SetWidth(300)
	functions:DockMargin(4,1,24,0)
	
	functions:EnableVerticalScrollbar()
	
	
	
	local function Add(itm,b)
		local c= vgui.Create(itm,functions,b)
		--settingslist:AddItem(c)
		c:Dock(BOTTOM)
		return c
	end
	
	
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
				surface.SetDrawColor(255,66,22,255*.5 + 255*.3 * math.sin(RealTime()*4))

				surface.DrawOutlinedRect(-1,-1,w+1,h+1)
				surface.DrawOutlinedRect(0,0,w,h)
				b:NoClipping(true)
			end
		end
	
	local l = functions:Add( "DLabel",'chosen' )
		self.lbl_chosen = l
		l:Dock(TOP)
		l:DockMargin(1,1,1,1)
		l:SetWrap(true)
		l:SetTooltip[[Title of the chosen workshop addon]]
		l:SetText("Please choose a workshop addon")
		l:SetTall(44)
		
		
	
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
		end
		--TODO : OnRowRightClick
	
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
	local settingspnl = self:Add( "EditablePanel" )
		self.settingspnl=settingspnl
		sheet:AddSheet( "#spawnmenu.utilities.settings", settingspnl, "icon16/cog.png" )
	local infopanel = self:Add( "EditablePanel" )
		self.infopanel=infopanel
		infopanel.Think=function()
			infopanel.Think=function() end
			
			local p = vgui.CreateFromTable(about_factor,infopanel)
			self.aboutpnl = p
			print"create about"
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
		mdlhistpanel:DockPadding( 2,1,2,1 )

		--local lbl = controls:Add( "DLabel" )
		--lbl:SetText( "Player color" )
		--lbl:SetTextColor( Color( 0, 0, 0, 255 ) )
		--lbl:Dock( TOP )
		
		
	local mdlhist = mdlhistpanel:Add( "DListView",'mdlhist' )
		mdlhist:DockMargin(4,4,4,4)
		mdlhist:SetMultiSelect( false )
		mdlhist:AddColumn( "#name" )
		mdlhist:AddColumn( "#gameui_playermodel" )
		self.mdlhist = mdlhist
	
		
		mdlhist:Dock(FILL)
		mdlhist.OnRowSelected = function(mdlhist,n,itm)
			local dat = GUIGetHistory()[n]
			if not dat then return end
			self:WantOutfitMDL(unpack(dat))
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
	c.SetValue = function(c,val)
		c:ChooseOptionID(val==0 and 2 or val==1 and 3 or 1 )
	end
	c.OnSelect = function(c,val)
		RunConsoleCommand("outfitter_distance_mode",tostring(val==1 and -1 or val==2 and 0 or 1))
	end
	c:AddChoice( "Distance mode: Automatic", '-1' )
	c:AddChoice( "Distance mode: disabled", '0' )
	c:AddChoice( "Distance mode: Enabled", '1' )
	
	c:SetConVar(Tag..'_distance_mode')
	local d_4 = c
	c:DockMargin(0,12,0,0)
	
	

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
	
	local b = Add('DButton','thirdperson')
		b:SetText("#tool.camera.name")
		b:SetTooltip[[Enables/disable thirdperson (if one is installed)]]

		b.DoClick=function() ToggleThirdperson() end
		b:DockMargin(16,2,16,1)
		b:SetImage'icon16/eye.png'
	
	--local b = Add('EditablePanel')
	--b:SetTall(1)
	--b:DockMargin(-4,24,-4,1)
	--b.Paint = function(b,w,h)
	--	surface.SetDrawColor(240,240,240,200)
	--	surface.DrawRect(0,0,w,h)
	--end
	--local hr_line1 = b
	
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
		b:SetImage'icon16/stop.png'
	
	functions._PerformLayout = functions.PerformLayout or function() end
	functions.PerformLayout = function(functions,w,h)
		functions._PerformLayout(functions,w,h)
		w,h = functions:GetSize()
		--d_1:SetVisible(h>400)
		--d_2:SetVisible(h>400)
		--d_3:SetVisible(h>400)
		--hr_line1:SetVisible(h>500)
		--d_4:SetVisible(h>400)
		--d_5:SetVisible(h>450)
		--self.lbl_chosen:SetVisible(h>300)
		--sld_dist:SetVisible(h>450)
		--sld_dl:SetVisible(h>450)
		
		local parent = self:GetParent()
		parent = parent and parent:IsValid() and parent.btnCheck
		
		--btn_en:SetVisible(not parent or not parent:IsValid() or not parent:IsVisible())
		--self.btn_choose:DockMargin(0,h>300 and 24 or 4,1,8)
	end
	
	
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
	
	co(function()
		if wanting then return end
		wanting = true
		self:GetParent():Hide()
		dbg("WantOutfitMDL",wanting and "ALREADY WANTING" or "",wsid,mdl,title)
		UIChoseWorkshop(wsid)
		GUIOpen(nil,want_mdl)
		wanting = false
	end)
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
	local mdl = mdllist[n]
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
	return true
end

function GUIClearHistory()
	GUIDelHistory(-1)
end

local function SAVE(t)
	local s= util.TableToJSON(t)
	util.SetPData("0",Tag,s)
end

local function LOAD()
	local s= util.GetPData("0",Tag,false)
	if not s or s=="" then return {} end
	local t = util.JSONToTable(s)
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
	
	local cansend = UIGetChosenMDL() and UIGetWSID() and UIGetMDLList()
	self.btnSendOutfit:SetEnabled2(cansend)
	
end

function PANEL:DoRefresh(trychoose_mdl)
	dbg("doRefresh",trychoose_mdl)
	self.mdllist:Clear()
	
	self.mdlhist:Clear()
	
	self.lbl_chosen:SetText("Please choose a workshop addon")

	local wsid = UIGetWSID()
	
	if wsid then
		co(function()
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
			
			
		end)
	end
	
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
	
	for _,v in next,GUIGetHistory() do
		local wsid,mdl,title = unpack(v)

		
		local pnl = self.mdlhist:AddLine( title,MDLToUI(mdl) )
		pnl._OnMousePressed = pnl.OnMousePressed
		pnl.OnMousePressed = function(pnl,mc)
			if mc~=MOUSE_LEFT then
				local m = DermaMenu()
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
			end
			return pnl._OnMousePressed(pnl,mc)
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
	
	
end

local factor = vgui.RegisterTable(PANEL,'EditablePanel')

local PANEL={}
function PANEL:Init()

	local pnl = vgui.CreateFromTable(factor,self)
	self.content = pnl
	pnl:Dock(FILL)

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
		self:CenterHorizontal()
	end
	
	self:CenterHorizontal()
	
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
		self:CenterHorizontal()
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
	
	menu:AddOption( "About", function() GUIAbout() self:GetParent():Hide() end ):SetImage'icon16/information.png'
	menu:AddOption( "Close", function() self:GetParent():Hide() end ):SetImage'icon16/stop.png'
	menu:Open()
end

function PANEL:PerformLayout(w,h)
	DFrame.PerformLayout(self,w,h)
	local check = self.btnCheck
	self.btnMinim:SetEnabled(w>(self:GetMinWidth() + 5) or h>(5 + self:GetMinHeight()))
	local cw,ch = check:GetSize()
	local b = self.btnMinim or self.btnMaxim
	if b and b:IsValid() then
		local bw,bh = b:GetWide(),b:GetTall()
		local bx,by = b:GetPos()
		check:SetPos(bx-cw-4,by+bh*.5-ch*.5-4)
		check:SetVisible(w>256)
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

local factor = vgui.RegisterTable(PANEL,'DFrame')

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
function GUIOpen(_,trychoose_mdl)
	
	if not ValidPanel(m_vGUIDlg) then
		local d = vgui.CreateFromTable(factor,nil,Tag..'_GUI')
		m_vGUIDlg = d
	end
	
	
	m_vGUIDlg:Show(nil,trychoose_mdl)
	
	return m_vGUIDlg
end

	
concommand.Add(Tag..'_open',function()
	GUIOpen()
end)
RunConsoleCommand(Tag..'_open')


-- Credits --

local Tag='outfitter' 

module(Tag,package.seeall)



local avatar_size=184
local avatars = {}
-- FUCK YOU GARRY
local function GetCachedAvatar184(sid64)
	local c = avatars[sid64]
	if c then
		c.shouldhide = false
		if c.hidden then
			c.hidden =false
			c:SetVisible(true)
		end
		return c
	end

	local a = vgui.Create'AvatarImage'
	a:SetPaintedManually(true)
	a:SetSize(1,1)
	a:ParentToHUD()
	a:SetAlpha(0)
	a:SetPos(ScrW()-1,ScrH()-1)
	a:SetSteamID(sid64,avatar_size)
	a.Think=function(self)
		if self.shouldhide then
			if not self.hidden then
				self.hidden = true
				self:SetVisible(false)
			end
		else
			self.shouldhide = true
		end
	end
	a.shouldhide = false
	avatars[sid64]=a
	return a
end


local avatar_size=184
local avatars = {}
local function GetCachedAvatar184(sid64)
	local c = avatars[sid64]
	if c then
		c.shouldhide = false
		if c.hidden then
			c.hidden =false
			c:SetVisible(true)
		end
		return c
	end

	local a = vgui.Create'AvatarImage'
	a:SetPaintedManually(true)
	a:SetSize(1,1)
	a:ParentToHUD()
	a:SetAlpha(0)
	a:SetPos(ScrW()-1,ScrH()-1)
	a:SetSteamID(sid64,avatar_size)
	a.Think=function(self)
		if self.shouldhide then
			if not self.hidden then
				self.hidden = true
				self:SetVisible(false)
			end
		else
			self.shouldhide = true
		end
	end
	a.shouldhide = false
	avatars[sid64]=a
	return a
end
function SetAvatarTexture184(sid64)
	local cached = GetCachedAvatar184(sid64)
	surface.SetTexture(0)
	if cached then
		cached:SetPaintedManually(false)
		cached:PaintManual()
		cached:SetPaintedManually(true)
	end
end


local credits = {
	{
		"Python1320",
		"76561197986413226",
		[[The guy who wrote all this madness]],
	},
	{
		"Willox",
		"76561197998909316",
		[[Facepunch dude who made this possible]],
	},{
		"Garry",
		"76561197960279927",
		[[<Garry :D> You guys are crazy WTF]],
	},{
		"CapsAdmin",
		"76561197978977007",
		[[Insipration from Player Appearance Customizer (PAC3)]],
	},{
		"Facepunch forums",
		'http://steamcommunity.com/groups/facepunch',
		[[For helping with all the LAU selflessly and also for emotional support over the years for all of us. Lots of stuff would not have been possible without!]],
	},{
		"Meta Construct",
		"http://metastruct.uk.to",
		[[For testing server and being the inspiration and nagging reminder to continue outfitter]],
	},
}

local inited
local function initcredits()
	if inited then return end
	inited=true
	
	credits[#credits+1] = {
		LocalPlayer():GetName(),
		LocalPlayer():SteamID64(),
		[[For being interested in outfitter!]],
	}
end

local PANEL={}

function PANEL:Init(asd) local _
	
	asd = asd==true
	self.is_panel = asd
	
	initcredits()
	if not self.is_panel then
		self:SetTitle"Outfitter (About)"
		local W,H=290,350
		self:SetMinHeight(100)
		self:SetMinWidth(200)
		self:SetSize(W,H)
		self:SetDeleteOnClose(true)
		self:Center()

		_=self.btnMinim and self.btnMinim:SetVisible(false)
		_=self.btnMaxim and self.btnMaxim:SetVisible(false)
		
		self:SetDraggable( true )
		self:SetSizable( true )
		
		local title = self.lblTitle
		if title then
			self:SetIcon'icon16/information.png'
			
		end
	end
	
	local pnl = vgui.Create('DScrollPanel',self)
	self.content = pnl
	
	-- HACK
		pnl.VBar:SetParent(self)
		pnl.VBar:Dock(RIGHT)
		pnl.VBar:DockMargin(-pnl.VBar:GetWide()+4,0,0,0)
	pnl:Dock(FILL)
	
	self:GenDesc()
	for _,entry in next,credits do
		self:GenAbout(entry)
	end
end

function PANEL:GenDesc()
	
	
	local lbl_desc = vgui.Create('DLabel',self)
	local amt = #file.Find("cache/workshop/*.*",'MOD')
	
	local txt = ("Workshop cache: %d addons!"):format(amt)
	lbl_desc:SetText(txt)
	lbl_desc:DockMargin(4,4,4,4)
	--lbl_desc:SetFont(fdesc) 
	lbl_desc:SetDark(true) 
	lbl_desc:SetAutoStretchVertical(true)
	lbl_desc:SetWrap(true)
	lbl_desc:Dock(TOP)
	self:AddItem(lbl_desc)
	
	
	local lbl_desc = vgui.Create('DLabel',self)
	lbl_desc:SetText[[Hello there! Outfitter was made to fill the need of the GMod community and for procrastination. 
Although mostly working, outfitter still has bugs and you can help with that by reporting them.]]
	lbl_desc:DockMargin(4,4,4,14)
	--lbl_desc:SetFont(fdesc) 
	lbl_desc:SetDark(false) 
	lbl_desc:SetAutoStretchVertical(true)
	lbl_desc:SetWrap(true)
	lbl_desc:Dock(TOP)
	self:AddItem(lbl_desc)
	
		
	local b = vgui.Create( "DButton", self )
	b:SetText"Bug reporting"
	b.DoClick=function()
		gui.OpenURL"http://google.com"
	end
	b:DockMargin(4,2,4,2)
	self:AddItem(b)
	
	local b = vgui.Create( "DButton", self )
	b:SetText"Get outfitter"
	b.DoClick=function()
		gui.OpenURL"http://google.com?q=garrysmod+outfitter"
	end
	b:DockMargin(4,2,4,2)
	self:AddItem(b)
	
	local lbl_desc = vgui.Create('DLabel',self)
	lbl_desc:SetText[[Finally, the people responsible for this mess include but are not limited to:]]
	lbl_desc:DockMargin(4,14,4,8)
	--lbl_desc:SetFont(fdesc) 
	lbl_desc:SetDark(false) 
	lbl_desc:SetAutoStretchVertical(true)
	lbl_desc:SetWrap(true)
	lbl_desc:Dock(TOP)
	self:AddItem(lbl_desc)
end

function PANEL:AddItem(i)
	i:Dock(TOP)
	self.content:AddItem(i)
end
local link
function PANEL:GenAbout(entry)
	local title,id,desc = unpack(entry)
	local sid64 = isstring(id) and id:match'^%d+$' and id
	if istable(id) then
		id = id[1]
		sid64=id[2]
	end
	
	local pnl = vgui.Create('DPanel',self)
	
	local ftitle,fdesc = 'huddefault','default'
	
	self:AddItem(pnl)
	pnl:SetTall(140)
	pnl:DockMargin(0,0,0,4)
	pnl:DockPadding(1,1,1,4)
	
	local avatar = vgui.Create('EditablePanel',pnl)
	avatar:Dock(LEFT)
	avatar:SetWidth(48)
	avatar:DockMargin(2,2,2,2)
	
	avatar.Paint=sid64 and function(avatar,w,h)
		local sz = w<h and w or h
		SetAvatarTexture184(sid64)
		local ox = w-sz
		local oy = 0
		if h-sz<5 then
			oy = h*.5-sz*.5
		end
		
		surface.SetDrawColor(255,255,255,255)
		surface.DrawTexturedRect(ox,oy,sz,sz)
		--surface.SetDrawColor(33,33,33,111)
		--surface.DrawOutlinedRect(0,0,w,h)
		if avatar:IsHovered() then
			surface.SetDrawColor(111,155,255,77)
			surface.DrawRect(ox,oy,sz,sz)
		end
	end or function(avatar,w,h)
		local sz = w<h and w or h
		local ox = w-sz
		local oy = 0
		if h-sz<5 then
			oy = h*.5-sz*.5
		end
		surface.SetDrawColor(120,110,100,90)
		surface.DrawOutlinedRect(ox,oy,sz,sz)
		
		surface.SetDrawColor(255,255,255,255)
		link = link or Material"icon16/link.png"
		surface.SetMaterial(link)
		surface.DrawTexturedRect(ox+sz*.5-8,oy+sz*.5-8,16,16)
		--surface.SetDrawColor(33,33,33,111)
		--surface.DrawOutlinedRect(0,0,w,h)
	end

	avatar:SetCursor"hand"
	avatar:SetMouseInputEnabled(true)
	avatar.OnMousePressed = function(avatar)
		local url = id
		if url:match'^%d+$' then
			url = 'http://steamcommunity.com/profiles/'..url
		end
		gui.OpenURL(url)
	end
	
	--function pnl.Paint(pnl,w,h)
	--	surface.SetDrawColor(255,255,255,100)
	--	surface.DrawOutlinedRect(0,0,w,h)
	--end

	local lbl = vgui.Create('DButton',pnl)
	lbl:SetText(title)
	lbl:SetFont(ftitle) lbl:SetDark(true) lbl:SetAutoStretchVertical(true)
	lbl:Dock(TOP)
	lbl:SetDrawBorder(false)
	lbl:SetDrawBackground(false)
	lbl:SetContentAlignment( 1 )
	local curtxt = title
	lbl:SetCursor"hand"
	if sid64 then steamworks.RequestPlayerInfo(sid64) end
	lbl.Think=sid64 and function()
		local nowtxt = steamworks.GetPlayerName(sid64)
		if nowtxt and nowtxt~= "" then
			curtxt = nowtxt
			lbl.Think = function() end
			lbl:SetText(curtxt)
		end
	end or function() end
	
	lbl:DockMargin(4,0,0,0)
	lbl:SetMouseInputEnabled(true)
	lbl.DoClick = function()
		local url = id
		if url:match'^%d+$' then
			url = 'http://steamcommunity.com/profiles/'..url
		end
		gui.OpenURL(url)
	end
	
	local lbl_desc = vgui.Create('DLabel',pnl)
	lbl_desc:SetText(desc)
	lbl_desc:DockMargin(4+4,0,0,0)
	lbl_desc:SetFont(fdesc) lbl_desc:SetDark(true) lbl_desc:SetAutoStretchVertical(true)
	lbl_desc:SetWrap(true)
	lbl_desc:Dock(TOP)
	lbl_desc.PaintOver=function(lbl,w,h)
		surface.SetDrawColor(120,110,100,5)
		surface.DrawOutlinedRect(0,0,w,h)
	end
	
	function pnl.PerformLayout(pnl)
		local t = {}
		local minh = self:GetTall()
		for k,v in next,pnl:GetChildren() do
			local dock = v:GetDock()
			if dock==LEFT or dock==RIGHT then
				t[v]={dock,v:GetSize()}
				v:SetTall(1)
			end
		end
		pnl:SizeToChildren(false,true)
		local msz = 48+1*2+2*2+3.456
		if pnl:GetTall()<msz then
			pnl:SetTall(msz)
		end
		--for p,dat in next,t do
		--	p:Dock(dat[1])
		--	p:SetSize(dat[2],dat[3])
		--end
		--
	end
end

PANEL._Init = PANEL.Init
local PANEL2=table.Copy(PANEL)

function PANEL:PerformLayout(w,h)
	DFrame.PerformLayout(self,w,h)
end
function PANEL:Hide()
        self:SetVisible(false)
end


function PANEL:Show()
	surface.PlaySound"garrysmod/ui_return.wav"
	self:SetVisible(true)
	self:MakePopup()
end

function PANEL:Init() self:_Init(false) end
local factor = vgui.RegisterTable(PANEL,'DFrame')

function PANEL2:Init() self:_Init(true) end
about_factor = vgui.RegisterTable(PANEL2,'EditablePanel')

if this.m_pAboutDlg and ValidPanel(this.m_pAboutDlg) then
	m_pAboutDlg:Remove()
end

m_pAboutDlg = NULL
function GUIAbout()
	
	if not ValidPanel(m_pAboutDlg) then
		local d = vgui.CreateFromTable(factor,nil,Tag..'_about')
		m_pAboutDlg = d
	end
	
	
	m_pAboutDlg:Show()
	
	return m_pAboutDlg
end

	
concommand.Add(Tag..'_about',function()
	GUIAbout()
end)
  

-- button --

--TODO: Integrate better?

list.Set("DesktopWindows", Tag, {
	title		= "Outfitter",
	icon		= "icon64/playermodel.png",
	width		= 1,
	height		= 1,
	onewindow	= false,
	init		= function( icon, window )
		window:GetParent():Close()
		window:Remove()
		GUIOpen()
	end
})
