if SERVER then
	AddCSLuaFile()
end


local functions = { }
local added = false
local function Stop()
	hook.Remove("Think", "NextThinkHelper")
end

local function error_func(line)
	ErrorNoHalt("NextThink: "..debug.traceback(line,2))
end

local function Think()
	local n = #functions
	if n == 0 then
		Stop()
		return
	end

	for i = 1, n do
		local func = table.remove(functions, 1)
		xpcall(func,error_func)
	end

end

local function Start()
	if added then
		return
	end

	hook.Add("Think", "NextThinkHelper", Think)
end

function RunNextThink(func)
	if not isfunction(func) then
		error("Expected function", 2)
	end

	functions[#functions + 1] = func
	Start()
end

NextThink = RunNextThink
util.NextThink = NextThink
util.NextFrame = NextThink

do
	-- OnInitialize

	local functions = { }
	local initialized = false

	local function error_func(line)
		ErrorNoHalt("OnInitialize: " .. debug.traceback(line, 2))
	end

	local function Initialize()
		if initialized then return end
		initialized = true
		-- HACK: Make sure RunOnInit works even inside RunOnInit
		local overflow = true
	
		for i = 1, #functions + 262140 do
			local func = functions[i]
	
			if not func then
				overflow = false
				break
			end
	
			xpcall(func, error_func)
		end
	
		if overflow then
			ErrorNoHalt("[WARN] RunOnInit hook list overflowed? ", #functions, "\n")
		end
	
		functions = nil
		hook.Remove("Initialize", "RunOnInitializeHelper")
	end


	function RunOnInit(func)
		if not isfunction(func) then
			error("Expected function", 2)
		end

		if not functions then
			timer.Simple(0,func)
			return
		end

		functions[#functions + 1] = func
	end
	RunOnInitialize = RunOnInit
	OnInitialize = RunOnInit
	util.OnInitialize = RunOnInit

	hook.Add("Initialize", "RunOnInitializeHelper", Initialize)
	hook.Add("InitPostEntity", "RunOnInitializeHelper", function()
		if initialized then return end
		ErrorNoHalt("[WARN] 'Initialize' hook 'RunOnInitializeHelper' did not run! (bugs in other addons? Possibly adding Initialize hooks while in Initialize hook?)\n")
		Initialize()
	end)
end

if CLIENT then

	-- OnLocalPlayer

	local functions = { }
	local initialized = false

	local function error_func(line)
		ErrorNoHalt("OnLocalPlayer: " .. debug.traceback(line, 2))
	end

	local function OnEntityCreated(ent)

		local me = LocalPlayer()
		if ent~=me then return end
		assert(not initialized)
		initialized = true
		
		for i = 1, #functions do
			local func = functions[i]
			xpcall(func, error_func, me)
		end

		functions = nil
		hook.Remove("OnEntityCreated", "OnLocalPlayer")
		hook.Remove("NetworkEntityCreated", "OnLocalPlayer")
	end


	local function util_OnLocalPlayer(func)
		if not isfunction(func) then
			error("Expected function", 2)
		end
		
		if not functions then
			timer.Simple(0,function() func(LocalPlayer()) end)
			return
		end
		
		functions[#functions + 1] = func
	end

	util.OnLocalPlayer = util_OnLocalPlayer
	if IsValid(LocalPlayer()) then
		OnEntityCreated(LocalPlayer()) 
	else
		hook.Add("OnEntityCreated", "OnLocalPlayer", OnEntityCreated)
		hook.Add("NetworkEntityCreated", "OnLocalPlayer", OnEntityCreated)
		
		timer.Simple(1, function()
			if LocalPlayer():IsValid() and not initialized then
				error_func"OnEntityCreated did not catch LocalPlayer??"
				OnEntityCreated(LocalPlayer())
			end
		end)
	end
	
end
