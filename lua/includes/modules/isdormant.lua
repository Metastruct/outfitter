if SERVER then
	AddCSLuaFile()
	return
end

local Tag="isdormant"

	
--[[
hook.Add("HUDPaint",Tag,function()
	local x,y=128,128
	surface.SetFont"BudgetLabel"
	
	local t=player.InPVS()
	
	local sw = ScrW()
	
	for i,pl in next, player.GetAll() do
		
		local txt=pl:Name()
		local tw,th = surface.GetTextSize(txt)
		local tx,ty=sw-tw-16,y+th*i
		
		surface.SetTextPos(tx,ty)
		if pl:InPVS() then
			surface.SetTextColor(255,244,244,111)
		else
			surface.SetTextColor(111,133,111,155)
		end
		surface.DrawText(txt)
	
	end
	
end)]]

local fn=0
local function Think()
	fn = fn + 1
end

hook.Add("Think",Tag,Think)
local t={}

--for k,v in next,player.GetAll() do if not v:IsDormant() then t[v]=fn+1 end end

local t2={}
function player.InPVS()
	local i=0
	for pl,pvsfn in next,t do
		if pvsfn and pvsfn < fn then
			i=i+1
			t2[i]=pl
		end
end

	for i=i+1,#t2 do
		t2[i]=nil
	end

	return t2
end

local Player=FindMetaTable"Player"
function Player:InPVS()
	local t = t[self]
	return  t and t < fn
end

local NaN = 0/0
hook.Add("NotifyShouldTransmit",Tag,function(pl,here)
	if pl:IsPlayer() and pl~=LocalPlayer() then
		t[pl]=here and fn+1 or NaN
	end
end)

hook.Add("EntityRemoved",Tag,function(pl)
	if pl:IsPlayer() then
		t[pl]=nil
	end
end)



-- For entities
--TODO: Make one for weapons too

local Entity = FindMetaTable "Entity"
local Tag = 'EntityShouldTransmit'
local function OnShouldTransmit(ent, should, special, entlist)
	--TODO: remove
	Msg("[ShouldTransmit] ")
	print(ent, should and "IN" or "OUT", should and special and "FIRST" or (not should and special and "LAST") or "")
	local f = ent.OnShouldTransmit
	if not f then
		return
	end

	return f(ent, should, firstlast, entlist)
end

local hooked = {  }
function ents.GetTransmitList()
	return hooked
end

function ents.HookShouldTransmit(class)
	assert(class and #class > 0 and class ~= "player", "invalid class")
	local tbl = scripted_ents.GetStored(class)
	assert(tbl, "class not found (is it an engine class?)")
	local t = hooked[class]
	if not t then
		t = {  }
		for k, v in next, ents.FindByClass(class) do
			if not v:IsDormant() then
				t[v] = true
				print("HOOKING", v)
			end

		end

		hooked[class] = t
	end

	return t
end

function Entity:HookShouldTransmit()
	ents.HookShouldTransmit(self:GetClass())
end

local function assert(ok,...)
	if not ok then
		ErrorNoHalt(addn(...))
	end

	return ok
end

local prevclass
hook.Add("NotifyShouldTransmit", Tag, function(ent, inside)
	local class = ent:GetClass()
	local entlist = hooked[class]
	if not entlist then
		return
	end

	if inside then
		local is_first = not next(entlist)
		entlist[ent] = true
		OnShouldTransmit(ent, true, is_first, entlist)
	else
		assert(entlist[ent], ent, "missing")
		entlist[ent] = nil
		local is_last = not next(entlist)
		OnShouldTransmit(ent, false, is_last, entlist)
	end

end)
hook.Add("EntityRemoved", Tag, function(ent)
	local class = ent:GetClass()
	local entlist = hooked[class]
	if not entlist then
		return
	end

	entlist[ent] = nil
	local is_last = not next(entlist)
	OnShouldTransmit(ent, false, is_last, entlist)
end)

--[[
function ENT:Initialize()
	self:HookShouldTransmit()
end

function ENT:OnShouldTransmit(transmitting, firstlast, entlist)
	if not firstlast then
		return
	end

	if transmitting then
		hook.Add("Think", "myclass", function()
			for ent, _ in next, entlist do
			end

		end)
	else
		hook.Remove("Think", "myclass")
	end

end
--]]

