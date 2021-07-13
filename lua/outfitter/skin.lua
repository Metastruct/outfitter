local surface = surface
local draw = draw
local Color = Color

local SKIN = {}

SKIN.PrintName 		= "Outfitter"
SKIN.Author 		= "Python1320"
SKIN.DermaVersion	= 1
SKIN.GwenTexture	= Material( "gwenskin/GModDefault.png" )

SKIN.Colours = setmetatable({},{__index=function(t,k)
	setmetatable(t,{__index=error})
	SKIN.Colours = nil
	SKIN.Colours = table.Copy(SKIN.Colours)
	SKIN.Colours.Window.TitleActive		= Color(0,0,0,255)
	SKIN.Colours.Window.TitleInactive		= Color(0,0,0,255)
	
	return SKIN.Colours[k]
end})

pcall(require,'urlimage')
local function URLImage(m)
	local first=true
	local img
	local function initator(...)
		if first then
			first = false
			img = surface.URLImage and surface.URLImage(m) -- begin fetching
		end
		if not img then return end 
		if img then
			return img(...)
		end
	end
	return initator
end
local xmashat = URLImage "https://metastruct.github.io/outfitter/xmashat.png"
function SKIN:PaintFrame( panel, w, h )
	
	if ( panel.m_bPaintShadow ) then
	
		DisableClipping( true )
		
		surface.SetDrawColor(36,35,33,150)
		surface.DrawRect(w,4,4,h)
		surface.DrawRect(4,h,w-4,4)
		
		DisableClipping( false )
	
	end
	
	if ( panel:HasHierarchicalFocus() ) then
	
		surface.SetDrawColor(200,200,200,190)
		surface.DrawRect(1,1,w-2,24)
		
	else
		
		surface.SetDrawColor(180,180,190,100)
		surface.DrawRect(1,1,w-2,24)
	
	end
	
	surface.SetDrawColor(150,147,147,200)
	surface.DrawRect(1,24,w-2,h-1-24)
	surface.SetDrawColor(130,130,130,200)
	surface.DrawOutlinedRect(0,0,w,h)

	if ( panel.m_bPaintHat ) then
		
		DisableClipping( true )
		
		local w,h = xmashat()
		if w then
			local now = RealTime()
			local startt = panel.skin_xhat_startt
			if startt==nil then 
				startt = now 
				panel.skin_xhat_startt = startt 
			end
			local f = now-startt
			f=f>1 and 1 or f
			surface.SetDrawColor(255,255,255,f*255)
			surface.DrawTexturedRect(-30,-32-8,64,64)
		end
		DisableClipping( false )
	
	end	
	
end

function SKIN:PaintTab( panel, w, h )
	
	
	if ( !panel.m_bBackground ) then return end
	
	h=h-(panel:GetPropertySheet():GetActiveTab() == panel and 6 or 0)
		
	if ( panel.Depressed ) then
		surface.SetDrawColor(122,122,122,200)
		surface.DrawRect(1,1,w-2,h-2)
		surface.SetDrawColor(130,130,130,200)
		surface.DrawOutlinedRect(0,0,w,h)
		return
	end
	
	if ( panel.Hovered ) then
		surface.SetDrawColor(190,190,190,200)
		surface.DrawRect(1,1,w-2,h-2)
		surface.SetDrawColor(130,130,130,200)
		surface.DrawOutlinedRect(0,0,w,h)
		return
	end
	if ( panel:GetPropertySheet():GetActiveTab() == panel ) then
		surface.SetDrawColor(190,180,180,200)
		surface.DrawRect(1,1,w-2,h-2)
		surface.SetDrawColor(130,130,130,200)
		surface.DrawOutlinedRect(0,0,w,h)
	else
		surface.SetDrawColor(190,180,180,200)
		surface.DrawRect(1,1,w-2,h-2)
		surface.SetDrawColor(130,130,130,200)
		surface.DrawOutlinedRect(0,0,w,h)
	end
end

function SKIN:PaintPropertySheet( panel, w, h )

	-- TODO: Tabs at bottom, left, right

	local ActiveTab = panel:GetActiveTab()
	
	
	surface.SetDrawColor(140,137,135,200)
	surface.DrawRect(1,24,w-2,h-2)
	
	surface.SetDrawColor(60,60,60,200)
	surface.DrawOutlinedRect(0,0,w,h)

end

function SKIN:PaintCheckBox( panel, w, h )


	if ( panel:GetDisabled() ) then
	
		local q=0.6
		
		if ( panel:GetChecked() ) then
			surface.SetDrawColor(200*q,255*q,135*q,200)
			surface.DrawRect(1,1,w-2,h-2)
		else
			surface.SetDrawColor(200*q,215*q,200*q,200)
			surface.DrawRect(1,1,w-2,h-2)
		end
	
	else
	
		surface.SetDrawColor(60,60,60,200)
		surface.DrawOutlinedRect(0,0,w,h)
		
		if ( panel:GetChecked() ) then
			surface.SetDrawColor(200,255,135,200)
			surface.DrawRect(1,1,w-2,h-2)
		else
			surface.SetDrawColor(200,215,200,200)
			surface.DrawRect(1,1,w-2,h-2)
		end
		
	end
		
	
	

end


function SKIN:PaintButton( panel, w, h )

	if ( !panel.m_bBackground ) then return end
	
	if ( panel.Depressed || panel:IsSelected() || panel:GetToggle() ) then
		surface.SetDrawColor(190,180,180,200)
		surface.DrawRect(1,1,w-2,h-2)
		surface.SetDrawColor(130,130,130,200)
		surface.DrawOutlinedRect(0,0,w,h)
		return
	end
	
	if ( panel:GetDisabled() ) then
		surface.SetDrawColor(111,111,111,222)
		surface.DrawRect(1,1,w-2,h-2)
		surface.SetDrawColor(79,78,77,222)
		surface.DrawOutlinedRect(0,0,w,h)
		return
	end
	
	if ( panel.Hovered ) then
		surface.SetDrawColor(190,190,190,200)
		surface.DrawRect(1,1,w-2,h-2)
		surface.SetDrawColor(130,130,130,200)
		surface.DrawOutlinedRect(0,0,w,h)
		return
	end

	surface.SetDrawColor(250,248,246,200)
	surface.DrawRect(1,1,w-2,h-2)
	surface.SetDrawColor(130,130,130,200)
	surface.DrawOutlinedRect(0,0,w,h)

end

derma.DefineSkin( "Outfitter", "Agh?", SKIN )
--derma.RefreshSkins()