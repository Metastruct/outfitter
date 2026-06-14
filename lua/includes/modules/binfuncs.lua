if SERVER then
	AddCSLuaFile()
end

do -- uint conversion..
	local mod   = math.fmod
	local floor = math.floor

	local function rshift(x,n)
		return floor((x%4294967296)/2^n)
	end

	local function band(x,y)
		local z,i,j = 0,1
		for j = 0,31 do
			if (mod(x,2)==1 and mod(y,2)==1) then
				z = z + i
			end
			x = rshift(x,1)
			y = rshift(y,1)
			i = i*2
		end
		return z
	end
	------------------------------------------------------------------

    local byte,char=string.byte,string.char
    to_u_int = function(i,endian)
        if type(i)~="number" then debug.Trace() error"need unsigned integer" end
        if i<0 then error"bad integer x<0" end
        if i>0xffffffff then error"bad integer x>0xffffffff" end
        return endian and char(
				band(i,255) ,
				band(rshift(i,8),255 ),
				band(rshift(i,16),255 ),
				band(rshift(i,24),255 ))
		or 	char(
				band(rshift(i,24),255 ),
				band(rshift(i,16),255 ),
				band(rshift(i,8),255 ),
				band(i,255) )
    end
    from_u_int = function(s,endian,offset)
		offset=offset and tonumber(offset) or 0
        if type(s)~="string" then error"string required" end
        --if s:len()~=4 then error"this is not a uint" end

        local b1,b2,b3,b4=
			byte(s,offset+(endian and 1 or 4)),
            byte(s,offset+(endian and 2 or 3)),
            byte(s,offset+(endian and 3 or 2)),
            byte(s,offset+(endian and 4 or 1))
        local n = b1 + b2*256 + b3*65536 + b4*16777216

       if n<0 then error"conversion failure, garry/python sucks" end
       if n>0xffffffff then error"conversion failure, garry/python sucks" end
       return n
    end

end

local d=0xFFFFFF00
local a=0x00FFFFFF
assert(from_u_int(to_u_int(a))==a)
assert(from_u_int(to_u_int(d))==d)
assert(from_u_int(to_u_int(d,true),true)==d)
assert(from_u_int(to_u_int(d,true),false)==a)
