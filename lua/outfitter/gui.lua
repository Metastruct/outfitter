local Tag='outfitter' 
local NTag = 'OF'

-- lua_openscript_cl srv/outfitter/lua/outfitter/ui.lua;lua_openscript_cl srv/outfitter/lua/outfitter/gui.lua;outfitter_open

module(Tag,package.seeall)


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
		
	local rightpanel = self:Add"EditablePanel"
	rightpanel:Dock(RIGHT)
	
	local l = rightpanel:Add( "DLabel",'hist' )
		l:Dock(TOP)
		l:DockMargin(1,1,1,1)
		l:SetText"#history"
		
		
		
		
	local mdlhist = rightpanel:Add( "DListView",'mdlhist' )
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
	
	
		
	local b = rightpanel:Add('DButton','choose button')
		self.btn_clearhist = b
		
		b:Dock(BOTTOM)
		
		b:SetText("#gameui_clearbutton")
		b.DoClick= function()
			GUIClearHistory()
		end
		b:DockMargin(0,5,0,0)
		b:SetImage'icon16/bin.png'
	
	
	
	local check = Add( "DCheckBoxLabel" )
	 	check:SetConVar(Tag.."_enabled")
		check:SetText( "#gameui_enabled")
		check:SizeToContents()
		check:SetTooltip[[Toggle this if someone's outfit got blocked or should be showing]]
		check:DockMargin(1,0,1,1)
		local btn_en = check
		
	local check = Add( "DCheckBoxLabel" )
	 	check:SetConVar(Tag.."_friendsonly")
		check:SetText( "Load only outfits of friends")
		check:SetTooltip[[When non friend wears an outfit it gets blocked]]
		check:SizeToContents()

		check:DockMargin(1,4,1,1)
	local d_5 = check
	
	local slider = Add( "DNumSlider" )
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
			
	local c = Add( "DComboBox" )
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
	
	

	local slider = Add( "DNumSlider" )
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
	
		
	local debug = Add( "DCheckBoxLabel" )
	 	debug:SetConVar(Tag.."_dbg")
		debug:SetText( "#debug")
		debug:SetTooltip[[Print debug stuff to console. Enable this if something is wrong and in the bugreport give the log output.]]
		debug:SizeToContents()

		debug:DockMargin(1,4,1,1)
		local d_3 = debug
	local check = Add( "DCheckBoxLabel" )
	 	check:SetConVar(Tag.."_unsafe")
		check:SetText( "Unsafe")
		check:SizeToContents()

		check:SetTooltip[[Remove some outfit checks (for yourself only). This should not be needed ever.]]
		check:DockMargin(1,4,1,1)
		local d_1 = check
	local check = Add( "DCheckBoxLabel" )
	 	check:SetConVar(Tag.."_failsafe")
		check:SetText( "Failsafe")
		check:SizeToContents()
		check:SetTooltip[[This gets ticked if you were detected to crash right after applying outfit.]]

		check:DockMargin(1,4,1,1)
		local d_2 = check
	
	local b = Add('DButton','thirdperson')
		b:SetText("Thirdperson toggle")
		b:SetTooltip[[Enables/disable thirdperson (if one is installed)]]

		b.DoClick=function() ToggleThirdperson() end
		b:DockMargin(16,2,16,1)
		b:SetImage'icon16/eye.png'
	
	
	
	local b = Add('EditablePanel')
	b:SetTall(1)
	b:DockMargin(-4,24,-4,1)
	b.Paint = function(b,w,h)
		surface.SetDrawColor(240,240,240,200)
		surface.DrawRect(0,0,w,h)
	end
	local hr_line1 = b
	
	--------------------------------------------------
	
	local b = functions:Add('DButton','Clear button')
		self.btn_clear = b
		b:SetTooltip[[This removes all traces of you wearing an outfit]]
		b:Dock(BOTTOM)
		b:SetText("#discarditem")
		b:SetTall(b:GetTall()+4)
		b.DoClick= function()
			UICancelAll()
			self:GetParent():Hide()
		end
		b:DockMargin(1,16,1,1)
		b:SetImage'icon16/user_delete.png'
	
	local b = functions:Add('DButton','Send button')
		self.btn_send= b
		b:Dock(BOTTOM)
		b:SetText("#gameui_submit")
		b:SetTooltip[[This broadcasts the outfit you have chosen to the whole server]]
		b.DoClick= function()
			GUIBroadcastMyOutfit()
			b._set_enabled  = false
			self:GetParent():Hide()
		end
		b:SetTall(b:GetTall()+24)
		b:DockMargin(24,5,24,0)
		b:SetImage'icon16/transmit.png'
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
	
	functions._PerformLayout = functions.PerformLayout or function() end
	functions.PerformLayout = function(functions,w,h)
		functions._PerformLayout(functions,w,h)
		w,h = functions:GetSize()
		d_1:SetVisible(h>400)
		d_2:SetVisible(h>400)
		d_3:SetVisible(h>400)
		hr_line1:SetVisible(h>500)
		d_4:SetVisible(h>400)
		d_5:SetVisible(h>450)
		self.lbl_chosen:SetVisible(h>300)
		sld_dist:SetVisible(h>450)
		sld_dl:SetVisible(h>450)
		
		local parent = self:GetParent()
		parent = parent and parent:IsValid() and parent.btnCheck
		
		btn_en:SetVisible(not parent or not parent:IsValid() or not parent:IsVisible())
		self.btn_choose:DockMargin(0,h>300 and 24 or 4,1,8)
	end
	
	
	local div = self:Add"DHorizontalDivider"
	div:Dock( FILL )
	
	functions:Dock(NODOCK)
	rightpanel:Dock(NODOCK)
	div:SetCookieName(Tag)
	div:SetLeft( functions )
	div:SetRight( rightpanel )
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
	
	for k,v in next,GUIGetHistory() do
		local wsid,mdl,title = unpack(v)

		
		local pnl = self.mdlhist:AddLine( title,MDLToUI(mdl) )
		
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
	--self:SetSize(700,500)
	self:SetSize(313,293)
	self:CenterHorizontal()
	
	self:SetTitle"Outfitter"
	self:SetMinHeight(290)
	self:SetMinWidth(312)
	self:SetDeleteOnClose(false)
	self.btnMinim:SetEnabled(true)
	self.btnMaxim:SetEnabled(true)
	self.btnMaxim.DoClick=function()
		self:SetSize(700,550)
		self:CenterHorizontal()
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
			self:SetCursor( "arrow" )
		end
	end
end

function PANEL:OnMouseReleasedHook(mc)
	if mc==MOUSE_LEFT then return end
	local x,y = self:CursorPos()
	if x<0 or x>20 then return end
	if y<0 or y>20 then return end
	
	local menu = DermaMenu()
	
	if UIGetChosenMDL() and UIGetMDLList() and LocalPlayer().latest_want~=UIGetMDLList()[UIGetChosenMDL()] then
		menu:AddOption( "#gameui_submit", function() GUIBroadcastMyOutfit() end ):SetImage'icon16/transmit.png'
	end
	
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
end


function PANEL:Show(_,trychoose_mdl)
	--if not self:IsVisible() then
		surface.PlaySound"garrysmod/ui_return.wav"
	--end
	self:SetVisible(true)
	self:MakePopup()
	self:DoRefresh(trychoose_mdl)
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

	