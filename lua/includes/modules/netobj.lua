AddCSLuaFile()

require'netqueue'

local net=net

local netobj={}

local function StartWrite(tag,unreliable,...)
	net.Start(tag,unreliable)
	net.WriteTable{...}
end


local function netobj_process(self,mt,shouldfunc,name,id,dat)
	if not shouldfunc then return end
	
	local unreliable = dat and dat[2]
	local notable = dat and dat[3]
	
	local ourfuncs = mt.__index
	ourfuncs[name]=function(...)
		net.Start(mt.tag,unreliable)
			net.WriteUInt(id,mt.bits)
			if not notable then
				net.WriteTable{...}
			else
				assert(false,"unimplemented")
			end
		return net
	end
end

--- Set up structures to send and receive the messages
local function netobj_processto(self,shouldfunc,...)
	local mt=getmetatable(self)
	local mapping=mt.mapping

	for i=1,select('#',...) do
		local v=select(i,...)
		local funcname=istable(v) and v[1] or v
		table.insert(mapping,funcname)
		local nmappings = #mapping
		
		local bits=math.floor(math.log(nmappings,2))+1
		mt.bits = bits
		
		netobj_process(self,mt,shouldfunc,funcname,nmappings,istable(v) and v)
	end
end

--- Expose server functions
function netobj:sv(...)
	netobj_processto(self,CLIENT,...)
	return self
end

--- Expose client functions

function netobj:cl(...)
	netobj_processto(self,SERVER,...)
	return self
end

local netobj_fallback={__index=netobj}

function net.new(tag,target,key)
	local mapping={}
	local ourfuncs=setmetatable({},netobj_fallback)

	local mt={__index=ourfuncs,tag=tag,target=target,mapping=mapping}
	local obj=setmetatable({},mt)
	if SERVER then
		
		util.AddNetworkString(tag)
		
	end
	
	net.Receive(tag,function(len,pl)
		local id = net.ReadUInt(mt.bits)
		local t = mapping[id]
		
		if t==nil then
			ErrorNoHalt(("NetObj '%s' received invalid id %s%s\n"):format(tostring(tag),tostring(id),SERVER and (" From "..tostring(pl)) or ""))
			return
		end
		
		local name = t
		local notable
		if istable(t) then
			name = t[1]
			notable=t[3]
		end
		
		local funct = target[name]
		if not isfunction(funct) then
			ErrorNoHalt(("NetObj '%s' unable to call '%s'%s\n"):format(tostring(tag),tostring(name),SERVER and (" From "..tostring(pl)) or ""))
			return
		end
		
		if notable then
			if SERVER then
				funct(target,pl)
			else
				funct(target)
			end
		else
			local t=net.ReadTable()
			
			if SERVER then
				funct(target,pl,unpack(t))
			else
				funct(target,unpack(t))
			end
		end
	end)
	
	if key~=nil then
		target[key]=obj
	end
	
	return obj
end