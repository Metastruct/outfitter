local Tag='outfitter'

module(Tag,package.seeall)


local function FixNPCWrongAnim(pl,slot,act)
	local seq_bad = pl:LookupSequence("jump_holding_land")
	if seq_bad<=0 then return end

	local seq_ok = pl:LookupSequence("jump_land")
	if seq_ok<=0 then return end
	pl:AnimSetGestureSequence(slot,seq_ok)
	
end

local Player = FindMetaTable"Player"
local Player_AnimRestartGesture = Player.AnimRestartGesture
function Player:AnimRestartGesture(slot,act,...)
	local ret = Player_AnimRestartGesture(self,slot,act,...)
	if act == ACT_LAND then
		FixNPCWrongAnim(self,slot,act)
	end
	return ret
end
