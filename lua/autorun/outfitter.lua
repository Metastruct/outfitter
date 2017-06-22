--do return end
--[[

BUGS
====================

GOING THROUGH WITHOUT REJECT !outfitter 187243854

OUTFITTER REJECTS
	191146401 -- noattachments
	164449803 -- hip
	503568129
	393931403
	252519802
	Strict mode?

Worldmodel vanishing
	is it pac bug or outfitter?

Prevent workshop addon overriding resources to prevent crashes and trolling
	database list of: player - wsaddon - model, etc

Any prop wear from any game instead of a workshop addon

OnDeathRagdollCreated Enforce call lags to hell, but without it ragdoll won't get applied force
ent:SnatchModelInstance()
"hl2mp_ragdoll"

TODO
====================
	BodyGroups testing 	471628201
	list favorited from workshop (playermodels heuristic?)
	Add icons to history list
	PAC part for outfitter
		Multiple ws addons single outfit?
			separate workshop mounter thing
	Hands model from outfits
	
	Interlock functions so they don't execute at the same time?
		At least prevent more than 2 downloads at once
		LZMA decompress in separate step
	
	Bodygroups
	skin

	Allow custom skinning from jpg??
	
	Whitelist mode for competitive servers
	
	mdl parse further to prevent easy crashing
	
	
	More sounds / notifications
		npc/vort/claw_swing1.wav

		npc/scanner/scanner_scan1.wav
		npc/scanner/scanner_scan2.wav

		common/warning.wav
		buttons/button2.wav
		BEP BEP BEP ui/system_message_alert.wav

		ui/buttonclick.wav

		items/suitchargeok1.wav

		items/suitchargeno1.wav

		Great scott
		vo/trainyard/kl_morewarn01.wav
		
]]

AddCSLuaFile("includes/modules/gmaparse.lua")
AddCSLuaFile("includes/modules/mdlinspect.lua")
AddCSLuaFile("includes/modules/co.lua")

require"co"


local Tag='outfitter'

--TODO:
 -- !outfitter 187243854
 -- bodygroups
module(Tag,package.seeall)

_M.this = setmetatable({},{__index = function(self,k) return rawget(_M,k) end,__newindex=_M})
this.Tag =Tag
this.NTag = 'OF'

local outfitter_dbg_tosv = SERVER and CreateConVar("outfitter_dbg_tosv","0") or CreateClientConVar("outfitter_dbg_tosv","0",false,false)
local outfitter_dbg = SERVER and CreateConVar("outfitter_dbg","1") or CreateClientConVar("outfitter_dbg","0",true,false)
_M.outfitter_dbg = outfitter_dbg

function isdbg(n)
	return outfitter_dbg:GetInt()>(n or 0)
end

function dbg(...)
	if isdbg() then
		Msg"[Outfitter] "
		if outfitter_dbg_tosv:GetBool() then
			if easylua then
				easylua.Print(...)
			else
				ErrorNoHalt(...)
			end
		else
			print(...)
		end
	end
end

function dbgn(n,...)
	if isdbg(n) then
		return dbg(...)
	end
end

function dbge(...)
	--if not outfitter_dbg:GetBool() then return end
	
	local t = {'[OF]'}
	for i=1,select('#',...) do
		local v=select(i,...)
		v=tostring(v) or "no value"
		t[i]=v
	end
	ErrorNoHalt(table.concat(t,' ')..'\n')
end
--concommand.Add()

local S=SERVER
local C=CLIENT
local function inc(str)
	return function(m)
		local path = Tag..'/'..str..'.lua'
		
		if S and (m=='sh' or m=='cl') then
			AddCSLuaFile(path)
		end
		
		if m == 'sh'
			or (S and m=='sv')
			or (C and m=='cl')
		then
			include(path)
		end
	end
end

inc 'sh'		'sh'
inc 'sv'		'sv'
inc 'cl_util'	'cl'
inc 'cows'		'cl'
inc 'cl'		'cl'
inc 'ui'		'cl'
inc 'skin'		'cl'
inc 'gui'		'cl'
inc 'net'		'sh'

