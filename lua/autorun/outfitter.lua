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

	(partially fixed) 1367741116 ragdoll lags to hell
	(partially fixed) OnDeathRagdollCreated Enforce call lags to hell, but without it ragdoll won't get applied force
		
Worldmodel vanishing
	is it pac bug or outfitter?

Prevent workshop addon overriding resources to prevent crashes and trolling
	database list of: player - wsaddon - model, etc

Any prop wear from any game instead of a workshop addon

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



local function requireSH(name)
	AddCSLuaFile(("includes/modules/%s.lua"):format(name))
	local ok,err = pcall(require,name)
	if not ok then
		hook.Add("Initialize",Tag..'fail',function()

			timer.Simple(1,function()
				chat.AddText(Color(200,50,10,255),"OUTFITTER LOADING FAILED:",Color(255,255,255,255),err)
			end)
		
		end)
		return
	end
end

if not util.OnLocalPlayer then
	requireSH 'hookextras'
end


requireSH 'binfuncs'
requireSH 'co'
requireSH 'coext'
requireSH 'fileextras'
requireSH 'gmaparse'
requireSH 'imgparse'
requireSH 'isdormant'
requireSH 'mdlinspect'
requireSH 'netobj'
requireSH 'netqueue'
requireSH 'playerextras'
requireSH 'sqlext'
requireSH 'ubit'
requireSH 'urlimage'


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
	return dbgelvl(2,...)
end

function dbgelvl(lvl,...)
	--if not outfitter_dbg:GetBool() then return end
	local caller = debug.getinfo((lvl or 1)) or {}
	local src = caller.source or "?"
	src=src:gsub(".*/lua/","/")
	local t = {'[OF ERROR]',src..':'..(caller.currentline or -1)..':' }
	for i=1,select('#',...) do
		local v=select(i,...)
		v=tostring(v) or "no value"
		t[#t+1]=v
	end
	local traceback = debug.traceback
	ErrorNoHalt(traceback(table.concat(t,' '),(lvl or 1))..'\n')
end


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
			return include(path)
		end
	end
end

_M.json = inc 'json'		'sh'

inc 'cl_util'	'cl'
inc 'cl_hacks'	'cl'
inc 'sh'		'sh'
inc 'sv'		'sv'
inc 'cows'		'cl'
inc 'cl'		'cl'
inc 'ui'		'cl'
inc 'skin'		'cl'

inc 'gui_about'	'cl'
inc 'gui_ofworkshopicon'	'cl'
inc 'gui_bodygroups'		'cl'
inc 'gui'		'cl'

inc 'net'		'sh'

