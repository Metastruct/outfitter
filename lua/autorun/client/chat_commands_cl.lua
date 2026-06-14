-- Example: list.Set("ChatCommands","test",function(paramstr,msg) PrintTable{paramstr,msg} return true end)

local cmds={["!"]=true,["\\"]=true,["/"]=true,["."]=true}
local disable_legacy,disable_legacy2
local function Parse(pl,msg)
	if not cmds[msg:sub(1,1)] then return end
	local pos=string.find(msg," ",1,true)

	local com,paramstr
	if pos then
		com,paramstr=msg:sub(2,pos-1),msg:sub(pos+1,-1)
	else
		com=msg:sub(2,-1)
		paramstr=""
	end

	local ret = hook.Run("ChatCommand",com,paramstr,msg)
	if ret==true then return ret end
	if ret==false then return end
	
	local commands = list and list.GetForEdit("ChatCommands")
	local command = commands[com] or commands[com:lower()]
	
	if command then
		local ok,ret = xpcall(command,debug.traceback,paramstr,msg)
		if not ok then ErrorNoHalt(("%s\n"):format(ret)) end
		if ret==true then return ret end
		if ret==false then return end
	end
	
end

hook.Add("OnPlayerChat","ChatCommand",function(pl,msg)
	if pl~=LocalPlayer() then return end
	return Parse(pl,msg)
end)

hook.Add("PlayerSay","ChatCommand",function(pl,msg)
	if pl~=LocalPlayer() then return end
	if not disable_legacy then
		hook.Remove("OnPlayerChat","ChatCommand")
		disable_legacy =  true
	end

	return Parse(pl,msg)
end)

-- For custom chatboxes
hook.Add("OnClientChatCommand","ChatCommand",function(...)
	if not disable_legacy2 then
		hook.Remove("PlayerSay","ChatCommand")
		hook.Remove("OnPlayerChat","ChatCommand")
		disable_legacy2 = true
	end	
	return Parse(...)
end)
