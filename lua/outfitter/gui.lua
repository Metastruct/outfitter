local Tag='outfitter' 
local NTag = 'OF'

module(Tag,package.seeall)

local mounting
function GUIMounting(yes)
	mounting = yes
end

hook.Add("HUDPaint",Tag,function()
	if mounting then
		surface.SetDrawColor(200,20,10,55)
		surface.DrawRect(0,0,ScrW(),ScrH())
	end
end)

function GUIFetching(wsid,is)

end

hook.Add("ChatCommand",Tag,function(com,paramstr,msg)
	if com:lower()=="changemodel" then
		GUIWantChangeModel()
	end
end)

function GUIGetWorkshop(wsid)
	if co.make(wsid) then return end
	GUIFetching(wsid,true)
	coFetchWS( wsid )
	GUIFetching(wsid,false)
end


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
			self:Hide()
			if self.chosen_id then
				GUIGetWorkshop(self.chosen_id)
			end
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

function PANEL:Think()
	self.BaseClass.Think(self)
	--print(self.LoadedURL)
end
vgui.Register(Tag,PANEL,'custombrowser')

m_vModelDlg = NULL
function GUIWantChangeModel()
	if ValidPanel(m_vModelDlg) then
		m_vModelDlg:Show()
		return m_vModelDlg
	end
	
	local d = vgui.Create(Tag,nil,Tag)
	m_vModelDlg = d
	
	
	d:Show()
	d:OpenURL'http://steamcommunity.com/workshop/browse/?appid=4000&searchtext=playermodel&childpublishedfileid=0&browsesort=trend&section=readytouseitems&requiredtags%5B%5D=Model'
	return d
end

GUIWantChangeModel()
-- Notifications?

