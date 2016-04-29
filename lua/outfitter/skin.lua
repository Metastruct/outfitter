local surface = surface
local draw = draw
local Color = Color

local SKIN = {}

SKIN.PrintName 		= "Outfitter"
SKIN.Author 		= "Python1320"
SKIN.DermaVersion	= 1
SKIN.GwenTexture	= Material( "gwenskin/GModDefault.png" )


function SKIN:PaintFrame( panel, w, h )
	
	--if ( panel.m_bPaintShadow ) then
	
		DisableClipping( true )
		
		surface.SetDrawColor(60,55,55,50)
		surface.DrawRect(w,0,4,h+4)
		surface.DrawRect(0,h,w,4)
		DisableClipping( false )
	
	--end
	
	if ( panel:HasHierarchicalFocus() ) then
	
		surface.SetDrawColor(200,200,200,190)
		surface.DrawRect(1,1,w-2,24)
		
	else
		
		surface.SetDrawColor(180,180,190,100)
		surface.DrawRect(1,1,w-2,24)
	
	end
	
	surface.SetDrawColor(150,147,147,200)
	surface.DrawRect(1,24,w-2,h-2-24)
	surface.SetDrawColor(130,130,130,200)
	surface.DrawOutlinedRect(0,0,w,h)

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

	surface.SetDrawColor(250,248,246,200)
	surface.DrawRect(1,1,w-2,h-2)
	surface.SetDrawColor(130,130,130,200)
	surface.DrawOutlinedRect(0,0,w,h)

end

derma.DefineSkin( "Outfitter", "Agh?", SKIN )
--derma.RefreshSkins()