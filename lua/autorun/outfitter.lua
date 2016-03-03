--do return end
--[[

OUTFITTER REJECTS
	191146401
	164449803
	503568129
	393931403
	252519802

Try to get hands model?


Interlock functions so they don't execute at the same time?
	At least prevent more than 2 downloads
	LZMA decompress in separate step
	
fix not loading after join for some reason
add loading outfit only when seeing in PVS
Bodygroups/skin editor

002 CCollisionProperty::m_vecMaxsPreScaled - vec[] differs (1st diff) (net 7.413762 28.663610 71.754700 - pred 16.000000 16.000000 72.000000) delta(8.586238 -12.663610 0.245300)
003 CCollisionProperty::m_vecMins - vec[] differs (1st diff) (net -16.088356 -28.536236 -4.704368 - pred -16.000000 -16.000000 0.000000) delta(0.088356 12.536236 4.704368)
004 CCollisionProperty::m_vecMaxs - vec[] differs (1st diff) (net 7.413762 28.663610 71.754700 - pred 16.000000 16.000000 72.000000) delta(8.586238 -12.663610 0.245300)

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
 -- bodygroups
module(Tag,package.seeall)

_M.this = setmetatable({},{__index = function(self,k) return rawget(_M,k) end,__newindex=_M})
this.Tag =Tag
this.NTag = 'OF'

local outfitter_dbg_tosv = SERVER and CreateConVar("outfitter_dbg_tosv","0") or CreateClientConVar("outfitter_dbg_tosv","0",false,false)
local outfitter_dbg = SERVER and CreateConVar("outfitter_dbg","1") or CreateClientConVar("outfitter_dbg","1",false,false)
_M.outfitter_dbg = outfitter_dbg

function isdbg(n)
	return outfitter_dbg:GetInt()>(n or 0)
end

function dbg(...)
	if isdbg() then
		if outfitter_dbg_tosv:GetBool() then
			Msg"[Outfitter] "easylua.Print(...)
		else
			Msg"[Outfitter] "print(...)
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
	
	local t = {'[Outfitter]'}
	local t={}
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
inc 'cl'		'cl'
inc 'ui'		'cl'
inc 'gui'		'cl'
inc 'net'		'sh'

