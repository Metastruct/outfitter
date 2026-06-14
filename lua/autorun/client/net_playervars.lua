
pcall(require,'netqueue')

--TODO: pl:SetNetDataType("varname",TYPE_STRING)

-- magic string length handling
	local TYPE_STRING = TYPE_STRING
	local function assert_int(n) assert( math.floor(n)==n ,"not a whole byte!?") end

	local function net_ReadRest(bytes)
		assert_int(bytes)
		return net.ReadData(bytes)
	end

	local function net_WriteRest(data)
		return net.WriteData(data,#data)
	end

	local function ReadString(magic_len)
		local str = net_ReadRest(magic_len)
		return str
	end

	local function WriteString(data)
		net_WriteRest(data)
	end

	local function tobytes(magic_len)
		
		assert(ubit.band(magic_len,0x7)==0,"bits have not been consumed: "..magic_len..' b, '..(magic_len/8)..' B')
		assert(ubit.rshift(magic_len,3) == magic_len / 8 )
		return magic_len / 8
		
	end
	
	local function ReadType(tn,magic_len)
		if tn == TYPE_STRING then
			assert(magic_len)
			magic_len = tobytes(magic_len)
			return ReadString(magic_len)
		end
		return net.ReadType(tn)
	end

	local function WriteType(dat)
		if TypeID( dat )==TYPE_STRING then
			net.WriteUInt( TYPE_STRING, 8 )
			return WriteString(dat)
		end
		return net.WriteType(dat)
	end
	
	
	
local Tag="NetData"
local data_table=GetNetDataTable and GetNetDataTable() or {}

do
	local function GetNetDataTable()
		return data_table
	end

	_G.GetNetDataTable = GetNetDataTable
	player.GetNetVarsTable = GetNetDataTable
end

local net_playervar_debug = CreateClientConVar("net_playervar_debug","0",true,false)


local SetBurst,IsPlayerVarsBurst do
	local bursting=false
	IsPlayerVarsBurst = function()
		return bursting
	end
	net.IsPlayerVarsBurst = IsPlayerVarsBurst
	
	SetBurst = function(b)
		if net_playervar_debug:GetBool() then
			Msg"[PNVar] Burst " print(b and "ON" or "OFF")
		end
		bursting = b
	end
end

local function Set(id,key,value)
	local tt=data_table[id]
	if not tt then
		tt={}
		data_table[id]=tt
	end
	tt[key]=value
	if net_playervar_debug:GetBool() then
		Msg"[PNVar] " print("Set",id,key,value)
	end
end
local function Get(id,key)
	local tt = data_table[id]
	return tt and tt[key]
end
player.ModifyNetData=Set


net.Receive(Tag,function(len)
		
	-- check for burst
	local id = net.ReadUInt(16)
	if id==0 or id==1 then
		SetBurst(id==1)
		return
	end
	
	id = id - 2
	
	----
	
	local key = net.ReadString()
	local _type = net.ReadUInt( 8 )
	local value = ReadType(_type,len - 16 - #key*8 - 8 - 8 )
	local old = Get(id,key)

	Set(id,key,value)
	
	local change,ret = hook.Call(Tag,nil,id,key,value,old)
	if change == true then
		Set(id,key,ret)
	end
end)

local Player=FindMetaTable("Player")

function Player:SetNetData(key,value)
	if self~=LocalPlayer() then error"not implemented" end
	
	--TODO: Make a generic queue emptier to reduce function garbage
	local f = function()
		net.Start(Tag)
			net.WriteString(key)
			WriteType(value)
		net.SendToServer()
	end
	if net.queuesingle then
		net.queuesingle(f)
	else
		f()
	end
end

	

local lookup={}
function Player:GetNetData(key)
	local id = lookup[self]
	if id == nil then
		id = self:UserID()
		lookup[self] = id
	end
	
	-- inlined: local function Get(id,key)
	local tt = data_table[id]
	return tt and tt[key]
end
