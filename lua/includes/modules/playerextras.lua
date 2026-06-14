if SERVER then
	AddCSLuaFile()
end

do -- is stuck checker

	local output = {}
	local pl_filt
	local filter_tbl  = {}
	local function filter_func(e)
		if e==pl_filt then return false end
		local cg = e:GetCollisionGroup()

		return
			cg~=15 -- COLLISION_GROUP_PASSABLE_DOOR
		and cg~=11 -- COLLISION_GROUP_WEAPON
		and cg~=1 -- COLLISION_GROUP_DEBRIS
		and cg~=2 -- COLLISION_GROUP_DEBRIS_TRIGGER
		and cg~=20 -- COLLISION_GROUP_WORLD

	end
	local t = {output = output ,mask=MASK_PLAYERSOLID}
	FindMetaTable"Player".IsStuck=function(pl,fast,pos)
		t.start = pos or pl:GetPos()
		t.endpos = t.start
		if fast then
			filter_tbl[1] = pl
			t.filter = filter_tbl
		else
			pl_filt = pl
			t.filter = filter_func
		end


		util.TraceEntity(t,pl)
		return output.StartSolid,output.Entity,output
	end

end


--------------

local Tag = "player_cache"

local next=next

local cache = player.GetAllCached and player.GetAllCached() or {}
local cache_count = player.CountAll and player.CountAll() or 0

function player.GetAllCached()
	return cache
end
function player.CountAll()
	return cache_count
end

function player.All()
	return next,cache
end

function player.iterator()
	local i = 1

	local function iter_all()
		local val = cache[i]
		i = val and i + 1 or 1

		return val
	end

	return iter_all
end


local SERVER = SERVER

local function updatePlayerCacheList()
	local plylist = player.GetAll()
	cache_count = #plylist

	for i = 1, cache_count do
		local ply = plylist[i]
		-- assert(ply:IsValid())
		cache[i] = ply
	end

	for i = cache_count + 1, cache_count + 256 do
		if cache[i] == nil then break end
		cache[i] = nil
	end
	
end

local function EntityCreated(pl)
	if not pl:IsPlayer() then
		return
	end

	updatePlayerCacheList(pl)

end

if SERVER then
	hook.Add("OnEntityCreated", Tag, EntityCreated)
else
	hook.Add("NetworkEntityCreated", Tag, EntityCreated)
end



local function EntityRemoved(pl, fullupdate)
	--assert(pl:IsPlayer()==pl:IsPlayer(),"isplayer mismatch")
	if not pl:IsPlayer() then return end
	updatePlayerCacheList(pl)

	for i = cache_count, 1, -1 do
		local candidate = cache[i]

		if candidate == pl then
			table.remove(cache, i)
			cache_count = cache_count - 1
		end
	end
end

if SERVER then
	hook.Add("PlayerDisconnected", Tag, EntityRemoved)
end
hook.Add("EntityRemoved", Tag, EntityRemoved)

local TEST=false

if TEST then 
	
	updatePlayerCacheList()
	
	local Tag='a'
	local DBG=print
	
	hook.Add("Think", Tag, function()
		for k, pl in pairs(player.GetAllCached()) do
			if not pl:IsValid() then
				DBG("INVALID IN THINK ", pl," - ", player.UserIDToNick(player.ToUserID(pl)))
				updatePlayerCacheList(pl)
			end
		end
	
		if CLIENT then
			for k, pl in pairs(player.InPVS()) do
				if not pl:IsValid() then
					DBG("INVALID IN PVS THINK ", pl," - ", player.UserIDToNick(player.ToUserID(pl)))
					
				end
			end
		end
	end)
	hook.Add("EntityRemoved", Tag, function(pl,reas)
		if not pl:IsPlayer() then return end
		DBG("EntityRemoved",pl,reas and "FULLUPDATE" or "")
	
	end)
	hook.Add("PlayerDisconnected", Tag, function(pl,reas)
		if not pl:IsPlayer() then return end
		DBG("PlayerDisconnected",pl,reas and "FULLUPDATE" or "")
	end)
end
-------------------------------------

local Tag = 'PlayerSlowThink'
--By: Python1320, original by Lixquid

local RealTime = RealTime
local player = player
local hook = hook
local next = next
local FrameTime = FrameTime
local math = math
local ticint
	local function getintervals()
		return ticint
	end

	local function getintervalc()
		local ft = FrameTime()
		return ft > 0.3 and 0.3 or ft
	end

	local getinterval
	getinterval = function()
		if SERVER then
			ticint = engine.TickInterval()
			getinterval = getintervals
		else
			getinterval = getintervalc
		end

		return getinterval()
	end

local iterating_players = {  }
local function refreshplayers(t)
	local pls = player.GetAllCached()
	local plsc = #pls
	for i = 1, plsc do
		iterating_players[i] = pls[i]
	end

	local ipc = #iterating_players
	if ipc == plsc then
		return plsc
	end

	for i = ipc, plsc + 1, -1 do
		iterating_players[i] = nil
	end

	return plsc
end

function GetPlayerThinkCache()
	return iterating_players
end

local function Call(pl)
	if not pl:IsValid() then
		return
	end

	hook.Call(Tag, nil, pl)
end

local iterid = 1
local function iter()
	iterid = iterid + 1
	local pl = iterating_players[iterid]
	if pl == nil then
		iterid = 1
		return true
	end

	Call(pl)
end

local iterations_per_tick
local iterations_per_tick_frac
local fracpart = 0
local nextthink = 0
local printed
local function Think()
	local pl = iterating_players[iterid]
	if pl == nil then
		local now = RealTime()
		if nextthink > now then
			--if not printed then
			--	printed = true
			--	--print("=========",nextthink - now)
			--end

			return
		end

		nextthink = now + 1
		--printed = false
		fracpart = fracpart >= 1 and 1 or fracpart
		local plc = refreshplayers(iterating_players)
		if plc == 0 then
			return
		end

		iterid = 1
		iterations_per_tick = #player.GetAllCached() * getinterval()
		iterations_per_tick_frac = iterations_per_tick - math.floor(iterations_per_tick)
		iterations_per_tick = math.floor(iterations_per_tick)
		pl = iterating_players[iterid]
		if pl == nil then
			return
		end
		if fracpart>=0.3 then
			fracpart = 0
			Call(pl)
			iterid = iterid + 1
			pl = iterating_players[iterid]
			if pl == nil then
				return
			end
		end
	end

	fracpart = fracpart + iterations_per_tick_frac
	if fracpart > 1 then
		fracpart = fracpart - 1
		Call(pl)
		iterid = iterid + 1
		pl = iterating_players[iterid]
		if pl == nil then
			return
		end

	end

	for i = 1, iterations_per_tick do
		Call(pl)
		iterid = iterid + 1
		pl = iterating_players[iterid]
		if pl == nil then
			return
		end

	end

end


hook.Add("Think", Tag, Think)


-- Fix parent positioning function --

local Tag="f_pp"
if SERVER then

	util.AddNetworkString(Tag)

	local Entity=FindMetaTable"Entity"
	function Entity:FixParentPositioning()

		local ply = self:GetParent()
		if not ply:IsPlayer() then error"Parent is not a player" end

		net.Start(Tag)
			net.WriteEntity(self)
		net.Send(ply)
	end

end


-- player revive
if SERVER then
	local Player = FindMetaTable"Player"
	Player.Revive=Player.Revive or function(pl)
		if pl:Alive() then return end
		local pos = pl:GetPos()
		pl:Spawn()
		pl:SetPos(pos)
	end
end

if SERVER then return end

local t={}

local added = false

local LocalPlayer=LocalPlayer

local function PreDrawOpaqueRenderables()
	local mypos=LocalPlayer():GetPos()
	local ok
	for _,ent in next,t do
		ok=true
		if not ent:IsValid() then
			t[_]=nil
			continue
		end
		ent:SetRenderAngles(ent:GetNetworkAngles())
		ent:SetRenderOrigin(ent:GetNetworkOrigin()+mypos)
	end
	if not ok then
		added=false
		hook.Remove("PreDrawOpaqueRenderables",Tag)
	end
end

net.Receive(Tag,function()
	if not added then
		hook.Add("PreDrawOpaqueRenderables",Tag,PreDrawOpaqueRenderables)
		added = true
	end

	local ent = net.ReadEntity()

	if not IsValid(ent) then return end

	table.insert(t,ent)

end)

player.GetByUserID = player.GetByID

