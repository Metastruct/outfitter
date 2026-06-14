if SERVER then
	AddCSLuaFile()
end


ubit=ubit or {}

local bit=bit
local ubit=ubit

function gen(name)
	local f=bit[name]
	if not f then error"?!?" end
	local function func(...)
		local ret = f(...)
		return ret>=0 and ret or 0x100000000+ret
	end
	ubit[name] = func
	bit['u'..name] = func
end

gen'rol'
gen'rshift'
gen'ror'
gen'bswap'
gen'bxor'
gen'bor'
gen'arshift'
gen'bnot'
gen'tobit'
gen'lshift'
gen'band'
ubit.tohex=bit.tohex
