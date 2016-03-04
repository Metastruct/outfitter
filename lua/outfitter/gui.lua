local Tag='outfitter' 
local NTag = 'OF'

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
	functions:DockMargin(16,16,24,0)
	
	functions:EnableVerticalScrollbar()
	
	local enabled = functions:Add( "DCheckBoxLabel" )
	 	enabled:SetConVar(Tag.."_enabled")
		enabled:SetText( "Enabled")
		enabled:SizeToContents()
		enabled:Dock(TOP)
	local debug = functions:Add( "DCheckBoxLabel" )
	 	debug:SetConVar(Tag.."_dbg")
		debug:SetText( "Debug output")
		debug:SizeToContents()
		debug:Dock(TOP)
	
	local b = functions:Add('DButton','choose button')
		self.btn_choose = b

		b:Dock(TOP)
		b:SetText("Choose outfit")
		b.DoClick= function()
			
			GUIWantChangeModel(nil,true)
			
			self:GetParent():Hide()
		end
		b:DockMargin(0,24,32,0)
		b:SetImage'icon16/folder_user.png'
	
	
	
	local l = functions:Add( "DLabel",'chosen' )
		self.lbl_chosen = l
		l:Dock(TOP)
		l:DockMargin(1,1,1,1)
		l:SetWrap(true)
		l:SetText("\n")
		l:SetTall(44)
		
	
	local mdllist = functions:Add( "DListView",'modelname' )
		mdllist:SetMultiSelect( false )
		mdllist:AddColumn( "Model" )
		self.mdllist = mdllist
		mdllist:DockMargin(0,5,0,0)
		mdllist:Dock(TOP)
		mdllist:SetTall(128)
		mdllist.OnRowSelected = function(mdllist,n,itm)
			local ret = GUIChooseMDL(n)
			if not ret then
				surface.PlaySound"common/warning.wav"
			end
		end
		--TODO : OnRowRightClick
	
	
	
	local l = self:Add( "DLabel",'hist' )
		l:Dock(TOP)
		l:DockMargin(1,1,1,1)
		l:SetText"Previously used workshop models"
		
		
		
		
	local mdllist = self:Add( "DListView",'mdlhist' )
		mdllist:DockMargin(4,4,4,4)
		mdllist:SetMultiSelect( false )
		mdllist:AddColumn( "Title" )
		mdllist:AddColumn( "Model" )
		self.mdlhist = mdllist
		
		mdllist:DockMargin(0,5,0,0)
	
		
		mdllist:Dock(FILL)
		mdllist.OnRowSelected = function(mdllist,n,itm)
			local dat = GUIGetHistory()[n]
			if not dat then return end
			self:WantOutfitMDL(unpack(dat))
		end
		
		
	local b = self:Add('DButton','choose button')
		self.btn_clearhist = b

		b:Dock(BOTTOM)
		b:SetText("Clear history")
		b.DoClick= function()
			GUIClearHistory()
		end
		b:DockMargin(0,5,0,0)
		b:SetImage'icon16/bin.png'
	
	
	local b = functions:Add('DButton','Send button')
		self.btn_send= b
		b:Dock(TOP)
		b:SetText("Send outfit")
		b.DoClick= function()
			GUIBroadcastMyOutfit()
			self:GetParent():Hide()
		end
		b:DockMargin(0,5,32,0)
		b:SetImage'icon16/transmit.png'
		
	local b = functions:Add('DButton','Clear button')
		self.btn_clear = b
		
		b:Dock(TOP)
		b:SetText("Clear outfit")
		b.DoClick= function()
			UICancelAll()
			self:GetParent():Hide()
		end
		b:DockMargin(0,5,32,0)
		b:SetImage'icon16/user_delete.png'
		
end

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
			UIChangeModelToID(want_n)
		end
		dbg("GUIChooseMDL","FINISH",n)
		want_n = nil
		choosing = false
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


function PANEL:DoRefresh(trychoose_mdl)
	dbg("doRefresh",trychoose_mdl)
	self.mdllist:Clear()
	
	self.mdlhist:Clear()
	
	self.lbl_chosen:SetText( "" )

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
			
			self.lbl_chosen:SetText(info and info.title or "")
			
		end)
	end
	
	local tm = UITriedMounting()
	local mdllist = UIGetMDLList()

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
	self:SetSize(800,600)
	self:Center()
	
	self:SetTitle"Outfitter"
	
	self:SetDeleteOnClose(false)
    self:ShowCloseButton( true )
    self:SetDraggable( true )
    self:SetSizable( true )

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

	
	
	
	
	
	