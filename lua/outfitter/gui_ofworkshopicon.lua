local Tag='outfitter'

module(Tag,package.seeall)


local PANEL = {}

function PANEL:Init()
	self:SetTall( 128 )
	self:SetWide( 128 )
end

-- Adapted from https://github.com/robotboy655/gmod-lua-menu/blob/master/lua/menu/custom/addons.lua
-- TODO: Use coroutines, cache results

local gDataTable = gDataTable or {}
function PANEL:SetAddon( data )
	self.Addon = data
	if ( gDataTable[ data.wsid ] ) then self.AdditionalData = gDataTable[ data.wsid ] return end

	steamworks.FileInfo( data.wsid, function( result )
		if not result then return end
		steamworks.VoteInfo( data.wsid, function( result )
			if not result then return end
			if ( gDataTable[ data.wsid ] ) then
				gDataTable[ data.wsid ].VoteData = result
			end
		end )

		gDataTable[ data.wsid ] = result

		if ( !file.Exists( 'cache/workshop/' .. result.previewid .. '.cache',"GAME" ) ) then
			steamworks.Download( result.previewid, false, function( name ) end )
		end

		if ( !IsValid( self ) ) then return end

		self.AdditionalData = result

	end )
end

local missingMat = Material( "../html/img/addonpreview.png", "nocull smooth" )
local lastBuild = 0
local imageCache = {}
function PANEL:Paint( w, h )

	if ( self.AdditionalData && imageCache[ self.AdditionalData.previewid ] ) then
		self.Image = imageCache[ self.AdditionalData.previewid ]

	end

	if ( !self.Image && self.AdditionalData && file.Exists( "cache/workshop/" .. self.AdditionalData.previewid .. ".cache", "GAME" ) && CurTime() - lastBuild > 0.1 ) then
		self.Image = AddonMaterial( "cache/workshop/" .. self.AdditionalData.previewid .. ".cache" )
		imageCache[ self.AdditionalData.previewid ] = self.Image
		lastBuild = CurTime()
		self.errcheck = false
		self.errored = false
	end


	draw.RoundedBox( 4, 0, 0, w, h, Color( 0, 0, 0, 255 ) )
	
	if not self.errcheck then
		self.errcheck = true
		if self.Image and self.Image:IsError() then
			self.errored = true
		end
	end
	
	if self.Image and not self.errored then
		surface.SetMaterial( self.Image )
	else
		surface.SetMaterial( missingMat )
	end
	local imageSize = self:GetTall() - 10
	surface.SetDrawColor( color_white )
	surface.DrawTexturedRect( 5, 5, imageSize, imageSize )

	if ( self.Addon && self.Hovered ) then
		draw.RoundedBox( 0, 5, h - 25, w - 10, 15, Color( 0, 0, 0, 180 ) )
		draw.SimpleText( self.Addon.title, "Default", 8, h - 24, Color( 255, 255, 255 ) )
	end

end

vgui.Register( "DOWorkshopIcon", PANEL, "Panel" )