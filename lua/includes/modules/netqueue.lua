if CLIENT then
	--TODO
	net.queuesingle= function(a,...) return a(...) end
	return
end

AddCSLuaFile()

local meta={__index=table}
local queue=setmetatable({},meta )
local started=false
local next=next
local pcall=pcall
local debug=debug
local function doqueue()
	local sent
	for pl,plqueue in next,queue do
		sent=true
		
		if plqueue==true or not pl.IsValid or not pl:IsValid() then
			queue[pl]=nil
		elseif pl:IsTimingOut() then
			-- TODO: track queue? Deduping
		else
			for i=1,2 do -- Something might be sending every tick, bad bad
			
				local func = plqueue:remove(1)
				if not func then
					queue[pl]=nil
				else
					--Dbg("doqueue",pl)
					local ok,err = xpcall(func,debug.traceback,pl)
					if not ok then
						ErrorNoHalt(err..'\n')
					end
					if err==true then
						plqueue[#plqueue]=func
					end
				end
				
			end
		end
	end
	if not sent then
		started=false
		hook.Remove("Tick",'netqueue')
	end
end

function net.queuesingle(pl,func)
	
	if not started then
		hook.Add("Tick",'netqueue',doqueue)
	end
	
	local plqueue=queue[pl]
	
	if plqueue == nil then
		plqueue = setmetatable({},meta)
	
		queue[pl]=plqueue
	end
	

	if plqueue==true then return false end
	
	if #plqueue>50000 then

		ErrorNoHalt("[NetQueue] Queue overflow: "..tostring(pl)..'\n')

		queue[pl] = true
		
		return false
		
	end

	plqueue:insert(func)
	
	return true
end

function net.queue(targets,func)
	if targets==true then
		targets=nil
	elseif targets and isentity(targets) then
		targets={targets}
	end
	
	local notok = false
	for _,pl in next,(targets or player.GetHumans()) do
		notok = notok or not net.queuesingle(pl,func)
	end

	return not notok
	
end

concommand.Add("netqueue_dump",function(pl) if SERVER and IsValid(pl) and not pl:IsAdmin() then return end
	print"Lua NetQueue:"
	local ok
	for pl,v in next,queue do
		Msg("\t",pl,": ")print(table.Count(v))
		if not ok then ok=true end
	end
	if not ok then print"\tEMPTY" end
end)