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





-- fix non-tweening anims
do
	local Tag = Tag..'_fix_anims'

	local fixing

	local function DoFix()
		fixing = false
		FixLocalPlayerAnimations()
	end

	local function QueueFix()
		if fixing then return end
		timer.Create(Tag, 0.678, 1, DoFix)
		fixing = true
		dbgn(5,"Queueing local player animation fixing due to changed model")
	end

	local last_model_index
	local last_model_name

	local function CreateMove()
		--if not IsFirstTimePredicted() then return end
		local pl = LocalPlayer()
		--local model = pl:GetModel()
		--
		--if last_model_name ~= model then
		--	last_model_name = model
		--end

		local m_nModelIndex = pl:GetInternalVariable"m_nModelIndex"
		if last_model_index == m_nModelIndex then return end
		last_model_index = m_nModelIndex
		QueueFix()
		
	end

	hook.Add("CreateMove", Tag, CreateMove)
end

-- Fix TTT and other gamemodes setting playermodel
do
	
	TTTFIX = engine.ActiveGamemode() == "terrortown"
	--TODO: exponential backoff
	local Tag='outfitter_tttfix'
	hook.Add('PrePlayerDraw',Tag,function(pl)
		local mdl = pl:GetEnforceModel()
		if not mdl or mdl=='' then return end
		if pl==LocalPlayer() then return end
		
		if mdl == pl:GetModel() then return end
		if not TTTFIX then return end
		dbgn(11,'fixEnforce',pl,pl:GetModel(),'->',mdl)
		pl:EnforceModel(mdl)
	end)
end