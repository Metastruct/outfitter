
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
	a:SetPos(2,2)
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
		"Willox",
		"76561197998909316",
		[[Facepunch dude who made this possible]],
	},{
		"CapsAdmin",
		"76561197978977007",
		[[Insipration from Player Appearance Customizer (PAC3)]],
	},{
		"Aerthas",
		"76561198053556165",
		[[Help with initial outfitter prototyping]],
	},{
		"Henke",
		"76561198000730944",
		[[Found anim fix alternative]],
	},{
		"Facepunch forums",
		{'76561197960279927','http://steamcommunity.com/groups/facepunch'},
		[[For helping with all the LAU selflessly and also for emotional support over the years for all of us. Lots of stuff would not have been possible without!]],
	},{
		"Garry",
		"76561197960279927",
		[[<Garry :D> You guys are crazy WTF]],
	},{
		"Python1320",
		"76561197986413226",
		[[The guy who wrote this madness]],
	},{
		"Meta Construct",
		{'76561198047188411',"http://metastruct.net"},
		[[The programming community that made outfitter possible]],
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
	lbl_desc:SetTextColor(Color(255,255,255,255))
	lbl_desc:SetFont"BudgetLabel"
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
		gui.OpenURL"https://github.com/Metastruct/outfitter/issues"
	end
	b:DockMargin(4,2,4,2)
	self:AddItem(b)
	
	local b = vgui.Create( "DButton", self )
	b:SetText"Get outfitter"
	b.DoClick=function()
		gui.OpenURL"http://www.google.com/search?q=garrysmod+outfitter"
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
	local custom
	if istable(id) then
		sid64=id[1]
		id = id[2]
		custom=true
	end
	
	local pnl = vgui.Create('DPanel',self)
	
	local ftitle,fdesc = 'TargetID','default'
	
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
	lbl:SetCursor"hand"
	if sid64 and not custom then 
		co(function()
			local nick,err = co.steamnick(sid64)
			if not nick or not lbl:IsValid() then return end
			lbl:SetText(tostring(nick))
		end)
	end
	
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
local factory = vgui.RegisterTable(PANEL,'DFrame')

function PANEL2:Init() self:_Init(true) end
about_factory = vgui.RegisterTable(PANEL2,'EditablePanel')

if this.m_pAboutDlg and ValidPanel(this.m_pAboutDlg) then
	m_pAboutDlg:Remove()
end

m_pAboutDlg = NULL
function GUIAbout()
	
	if not ValidPanel(m_pAboutDlg) then
		local d = vgui.CreateFromTable(factory,nil,Tag..'_about')
		m_pAboutDlg = d
	end
	
	
	m_pAboutDlg:Show()
	
	return m_pAboutDlg
end

	
concommand.Add(Tag..'_about',function()
	GUIAbout()
end)