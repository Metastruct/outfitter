local BUILDER, PART = pac.PartTemplate("base")

PART.ClassName = "outfitter_outfit"
PART.Group = "entity"
PART.Icon = "icon16/basket.png"

PART.ImplementsDoubleClickSpecified = true

BUILDER:StartStorableVars()
	BUILDER:SetPropertyGroup("generic")
	BUILDER:GetSet("OutfitData", "", {editor_panel = "generic_multiline", description = "Outfitter outfit data as JSON. Double-click the part in the tree to import current outfit."})
BUILDER:EndStorableVars()

function PART:GetNiceName()
	if self.OutfitData and self.OutfitData ~= "" then
		local data = util.JSONToTable(self.OutfitData)
		if data and data.mdl then
			local parts = string.Split(data.mdl, "/")
			return "Outfitter: " .. (parts[#parts] or "?")
		end
	end
	return "Outfitter Outfit"
end

function PART:OnDoubleClickSpecified()
	if self:GetPlayerOwner() ~= pac.LocalPlayer then return end
	if not outfitter or not outfitter.api then return end

	local data = outfitter.api.get_current()
	if data then
		self.OutfitData = util.TableToJSON(data)
		if pace and pace.PopulateProperties then
			pace.PopulateProperties(self)
		end
	end
end

function PART:OnWorn()
	if self:GetPlayerOwner() ~= pac.LocalPlayer then return end
	if not self.OutfitData or self.OutfitData == "" then return end
	if not outfitter or not outfitter.api then return end

	local data = util.JSONToTable(self.OutfitData)
	if data then
		outfitter.api.apply(data)
	end
end

function PART:OnRemove()
	if self:GetPlayerOwner() ~= pac.LocalPlayer then return end
	if outfitter and outfitter.api then
		outfitter.api.clear()
	end
end

BUILDER:Register()
