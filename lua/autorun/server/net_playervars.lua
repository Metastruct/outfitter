-- luacheck: globals ubit GetNetDataTable player.GetNetVarsTable net.queuesingle net.queue

--TODO: pl:SetNetDataType("varname",TYPE_STRING)

-- magic string length handling
local TYPE_STRING = TYPE_STRING
local function assert_int(n)
	assert(math.floor(n) == n, "not a whole byte!?")
end

local function net_ReadRest(bytes)
	assert_int(bytes)
	return net.ReadData(bytes)
end

local function net_WriteRest(data)
	return net.WriteData(data, #data)
end

local function ReadString(magic_len)
	local str = net_ReadRest(magic_len)
	return str
end

local function WriteString(data)
	net_WriteRest(data)
end

local function tobytes(magic_len)
	assert(
		ubit.band(magic_len, 0x7) == 0,
		"bits have not been consumed: " .. magic_len .. " b, " .. (magic_len / 8) .. " B"
	)
	assert(ubit.rshift(magic_len, 3) == magic_len / 8)
	return magic_len / 8
end

local function ReadType(tn, magic_len)
	if tn == TYPE_STRING then
		assert(magic_len)
		magic_len = tobytes(magic_len)
		return ReadString(magic_len)
	end
	return net.ReadType(tn)
end

local function WriteType(dat)
	if TypeID(dat) == TYPE_STRING then
		net.WriteUInt(TYPE_STRING, 8)
		return WriteString(dat)
	end
	return net.WriteType(dat)
end

local Tag = "NetData"
local data_table = GetNetDataTable and GetNetDataTable() or {}

local function GetNetDataTable()
	return data_table
end

_G.GetNetDataTable = GetNetDataTable
player.GetNetVarsTable = GetNetDataTable

local net_playervar_debug = CreateConVar("net_playervar_debug", "0")

local function Set(id, key, value)
	local tt = data_table[id]
	if not tt then
		tt = {}
		data_table[id] = tt
	end
	tt[key] = value
	if net_playervar_debug:GetBool() then
		Msg"[PNVar] "
		print("Set", id, key, value)
	end
end
local function Get(id, key)
	local tt = data_table[id]
	return tt and tt[key]
end

local lookup = setmetatable({}, { __mode = "k" })

util.AddNetworkString(Tag)
require"netqueue"

local SetBurst
do
	local BurstON = function(pl)
		net.Start(Tag)
		net.WriteUInt(1, 16)
		net.Send(pl)
	end
	local BurstOFF = function(pl)
		net.Start(Tag)
		net.WriteUInt(0, 16)
		net.Send(pl)
	end

	SetBurst = function(pl, burst)
		burst = burst or burst == nil

		if net_playervar_debug:GetBool() then
			Msg"[PNVar] Burst "
			print(burst and "ON" or "OFF", pl)
		end

		net.queuesingle(pl, burst and BurstON or BurstOFF)
	end
end

local function ReplicateData(id, key, value, targets)
	local queuefunc = function(pl)
		net.Start(Tag)
		net.WriteUInt(id + 2, 16)
		net.WriteString(key)
		WriteType(value)
		net.Send(pl)
	end

	net.queue(targets or true, queuefunc)
end

hook.Add("PlayerInitialSpawn", Tag, function(pl)
	-- only transmit valid players data
	-- TODO: Purge old players?
	local valid_userids = {}
	for k, v in pairs(player.GetAll()) do
		valid_userids[v:UserID()] = true
	end

	SetBurst(pl, true)

	for id, keyvals in next, data_table do
		if valid_userids[id] then
			-- transmit even own values if any?

			for key, value in next, keyvals do
				ReplicateData(id, key, value, pl)
			end
		end
	end

	SetBurst(pl, false)
end)

local Player = FindMetaTable("Player")

function Player:SetNetData(key, value)
	local id = lookup[self]
	if not id then
		id = self:UserID()
		lookup[self] = id
	end

	local lastval = Get(id, key)

	Set(id, key, value)

	if lastval ~= value then
		ReplicateData(id, key, value)
	end
end

net.Receive(Tag, function(len, pl)
	-- local id = pl:UserID()
	local key = net.ReadString()
	local _type = net.ReadUInt(8)
	local value = ReadType(_type, len - #key * 8 - 8 - 8)

	-- for necessity
	local success, override = hook.Call(Tag, nil, pl, key, value)
	if success == true then
		if override ~= nil then
			value = override
		end

		pl:SetNetData(key, value)
	-- else
		-- TODO: RejectMessage()
	end
end)

function Player:GetNetData(key)
	local id = lookup[self]
	if not id then
		id = self:UserID()
		lookup[self] = id
	end

	return Get(id, key)
end

-- local frametime = FrameTime()
local now = RealTime()
hook.Add("Think", Tag, function()
	-- frametime = FrameTime()
	now = RealTime()
end)

--TODO: data size based limit
--TODO bursting like https://github.com/wiremod/wire/pull/1023
function Player:NetDataShouldLimit(k,	len) --,v,maxdatlen
	local t = self.nd_ratelimit
	if t == nil then
		t = {}
		self.nd_ratelimit = t
	end

	local nextt = t[k] or 0
	if nextt > now then
		return true, now - nextt
	end

	nextt = now + (len or 1)
	t[k] = nextt

	--return false
end
