local Tag='outfitter'

-- lua_openscript_cl srv/outfitter/lua/outfitter/ui.lua;lua_openscript_cl srv/outfitter/lua/outfitter/gui.lua;outfitter_open

module(Tag,package.seeall)



local PANEL={}
function PANEL:Init()
	self:SetSize(16,16)
	self:Dock(RIGHT)
end

local CCHECKED = Color(111,255,111,255)
local CNORMAL  = Color(66,66,66,255)
local CBG  = Color(30,30,30,255)
function PANEL:Paint(w,h)
	if self.checked then
		surface.SetDrawColor(100,255,100,255)
	else
		surface.SetDrawColor(150,150,150,255)
	end
	draw.RoundedBox(h*0.5,0,0,h,h,CBG)
	draw.RoundedBox(h*0.5,1,1,h-2,h-2,self.checked and CCHECKED or CNORMAL)
	surface.SetFont"BudgetLabel"
	local txt = self.letter or ""
	local tw,th = surface.GetTextSize(txt)
	surface.SetTextColor(255,255,255,255)
	surface.SetTextPos(-tw*.5+h*.5,h*.5-th*.5)
	surface.DrawText(txt)
end

function PANEL:OnMouseReleased()
	self:GetParent():SetChecked(self.n)
end

function PANEL:SetChecked(checked)
	self.checked = checked
end

function PANEL:PerformLayout()
	self:SetWide(self:GetTall())
end

local radiobtn=vgui.RegisterTable(PANEL,"EditablePanel")


 





local PANEL={}
function PANEL:Init()
	self.lbl = vgui.Create('DLabel',self,'description')
	self.lbl:Dock(FILL)
	self.lbl:SetText"Radio buttons tester"

	self.lbl.Paint=function(self,w,h)
		self:NoClipping(false)
	end
end

function PANEL:OnSelected(n,pnl)
	print(self,"OnSelected",n,pnl)
end

function PANEL:SetText(t)
	self.lbl:SetText(t)
	self.lbl:SizeToContents()
	self.lbl:SetTooltip(t)
	
	self:InvalidateLayout()
	
end

function PANEL:AddOption(description,letter)
	self.n=self.n or 0
	self.n=self.n + 1
	local n = self.n
	
	local pnl = vgui.CreateFromTable(radiobtn,self,'radiolist')
	pnl.n=n
	pnl.letter = letter
	
	pnl:SetTooltip(description)
	pnl.d = description:sub(1,1)
	pnl:DockMargin(n>1 and 2 or 1,1,1,1)

	self.radios=self.radios or {}
	self.radios[n]=pnl
	return n,pnl
end


function PANEL:Think()
end

function PANEL:SetChecked(n)
	for k,v in next,self.radios do
		v:SetChecked(k==n)
	end
	self:OnSelected(n)
end

function PANEL:PerformLayout()
	self:SizeToChildren(true,true)
end



vgui.Register('OFRadioBatton',PANEL,"EditablePanel")


 
 

local vgui = GetVGUI()
 
 
 
 
 

local PANEL={}
function PANEL:Init()
end

function PANEL:Think()
end

function PANEL:Clear()
	for k,v in next,self:GetChildren() do v:Remove() end
end

function PANEL:Refresh()
	self:Clear()
	dbg("self.model")
	local a = mdlinspect.Open(self.model)
	a:ParseHeader()
	local parts = a:BodyPartsEx()
	self.parts = parts

	self:CreatePanels()	
	self:InvalidateLayout()
end

function PANEL:UpdateBG()
	local t = {}
	for k,v in next,self.parts do
		if v.n then
			t[#t+1] = ("%s=%s"):format(v.name,v.n)
		end
	end
	
	RunConsoleCommand("outfitter_bodygroups_set",table.concat(t,","))
end

function PANEL:OnSelected(part,n)
	part.n=n
	self:UpdateBG()
end

function PANEL:CreatePanels()
	for k,part in next,self.parts do
		
		if #part.models<2 then continue end
		
		local r = self:Add("OFRadioBatton")
		r.OnSelected=function(r,n) self:OnSelected(part,n-1) end
		
		r:SetText(part.name:gsub("%.smd$","")
							:gsub("([a-z0-9])([A-Z])([a-z])",
								function(q,a,b) 
									return q..' '..a:lower()..b 
								end)
							:gsub("[_%.%-]"," ")
							:gsub("(%s)%s*","%1"))
		r:Dock(TOP)
		r:SizeToContents()
		local n=0
		for k,partmdl in next,part.models do
			local name = partmdl.name
							:gsub("%.smd$","")
							:gsub("([a-z0-9])([A-Z])([a-z])",
								function(q,a,b) 
									return q..' '..a:lower()..b 
								end)
							:gsub("[_%.%-]"," ")
							:gsub("(%s)%s*","%1")
			name = name=="" and "" or name
			if name~="" then
				n=n+1
			end
			local n,pnl = r:AddOption(name=="" and "disable" or name,name=="" and "" or n)
			if name=="" then
				pnl:SetZPos(-10)
			end
			
			print(part.name.. ' - ' ..name)
			
		end
		
		r:SetChecked(1)
		
	end
end


function PANEL:SetModel(mdl)
	self.model = mdl
	self:Refresh()
end

function PANEL:PerformLayout()
	self:SizeToChildren(false,true)
end



bodygroups_factor=vgui.RegisterTable(PANEL,"EditablePanel")



function GUIOpenBodyGroupOverlay(owner,mdl)
	if not mdl then
		local l = UIGetMDLList()
		if not l then return end
		print(l)
		local chosen = UIGetChosenMDL()
		if not chosen then return false end
		print(chosen)
		mdl = l[chosen]
		if not mdl then return false end
		mdl = mdl.Name
		
		if not mdl then return false end
		if not file.Exists(mdl,'workshop') and not file.Exists(mdl,'GAME') then return false end
	end
	
	dbg("GUIOpenBodyGroupOverlay",mdl)
	
	local frame=vgui.Create('DFrame',nil,'bodygroups selector')
	frame:SetDraggable( false )
	frame:SetSizable( false )
	frame:SetScreenLock( true )
	frame:SetDeleteOnClose( true )
	frame:SetTitle( "Bodygroup selector" )
	frame:ShowCloseButton(false)
	frame:SetIcon('icon16/group_edit.png')
	frame.pnlOwner = owner
	frame:MakePopup()
	frame:RequestFocus()
	function frame:Think()
		if not self.fframe then self.fframe=true return end
		
		if not self:IsActive() then print"noactive" self:Remove() return end
		if self.pnlOwner and (not self.pnlOwner:IsValid() or not self.pnlOwner:IsVisible()) then self:Remove() print"noparent" return end
		local x,y = self:GetPos()
		
		local w,h = self:GetSize()
		local sw,sh =ScrW(),ScrH()
		local nx,ny = (x+w)>sw and (sw-w) or x,
					  (y+h)>sh and (sh-h) or y
		if x~=nx or y~=ny then
			self:SetPos(nx,ny)
		end
	end
	

	frame:SetSize(210,210)
	frame:SetPos(gui.MousePos())
	timer.Simple(60,function() 
		if IsValid(frame) then frame:Remove() end
	end)
	 
	local s=vgui.Create('DScrollPanel',frame)
	s:Dock(FILL)
	
	local a=vgui.CreateFromTable(bodygroups_factor,s)
	a:Dock(TOP)
	a:SetModel(mdl)
	return true
end


 
