--do return end
--[[
!changemodel ->webbrowser from workshop opens
open playermodel workshop page, click choose button
downloading...
find models
(this is where it mounts for you)
dialog with models to choose from
choose model
applies it on you
!applymodel or something -> broadcast to server

server: 
broadcast to everyone, rate limiting only

everyone:
(mdl,wsid) changed for player
(if mdl exists: just change model and done)
get file info from workshop, check file size
download
(check gma for malicious)
check gma for mdls
mount (with dialog)
check all players for this wsid
    for each player with this wsid: recheck wanted mdl existence
	
]]

AddCSLuaFile("includes/modules/gmaparse.lua")
AddCSLuaFile("includes/modules/mdlinspect.lua")

local Tag='outfitter' 

--TODO:
 -- bodygroups
module(Tag,package.seeall)

_M.this = setmetatable({},{__index = function(self,k) return rawget(_M,k) end,__newindex=_M})
this.Tag =Tag
this.NTag = 'OF'

local outfitter_dbg = SERVER and CreateConVar("outfitter_dbg","1") or CreateClientConVar("outfitter_dbg","1",false,false)
_M.outfitter_dbg = outfitter_dbg

function isdbg()
	return outfitter_dbg:GetBool()
end

function dbg(...)
	if isdbg() then
		Msg"[Outfitter] "print(...)
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
inc 'gui'		'cl'
inc 'net'		'sh'

