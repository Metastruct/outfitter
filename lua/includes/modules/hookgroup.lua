local pairs = pairs
local isfunction = isfunction
local isstring = isstring
local isnumber = isnumber
local isbool = isbool
local print = print
local setmetatable = setmetatable
local getmetatable = getmetatable
local type = type
local assert = assert
local next = next
local error = error
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local hook = hook or require'hook' or hook
AddCSLuaFile()
module("hookgroup")
local HOOKGROUP = {}

--[[---------------------------------------------------------
	    Name: Add
	    Args: string event_name, string name_unused, function func
	    Desc: takes same arguments as hook.Add but discards name_unused (second parameter of hook.Add) if given.
	-----------------------------------------------------------]]
function HOOKGROUP:Add(event_name, name_unused, func)
	local Hooks = self:GetHooks()

	if (not isstring(event_name)) then
		ErrorNoHaltWithStack("bad argument #1 to 'Add' (string expected, got " .. type(event_name) .. ")")

		return
	end

	if isfunction(name_unused) then
		func = name_unused
	end

	if func and (not isfunction(func)) then
		ErrorNoHaltWithStack("bad argument #2 to 'Add' (function or nil expected, got " .. type(func) .. ")")

		return
	end

	Hooks[event_name] = func
	if not self:IsActive() then return end
	hook.Add(event_name, self:GetName(), func)

	return self
end

HOOKGROUP.Set = HOOKGROUP.Add

--[[---------------------------------------------------------
	    Name: Activate
	    Args: string id (optional), bool force=false
	    Desc: Activates the hook group if not already activated, use force to always add all hooks
-----------------------------------------------------------]]
function HOOKGROUP:Activate(id, force)
	local enablers = self:GetActivators()
	assert(id ~= true)
	id = id or true
	local already_enabled = next(enablers)
	enablers[id] = true
	if force ~= true and already_enabled then return end
	local Hooks = self:GetHooks()
	local name = self:GetName()

	for hookname, ourfunc in pairs(Hooks) do
		hook.Add(hookname, name, ourfunc)
	end

	hook.Run("HookGroupActivated", name)

	return self
end

--HOOKGROUP.Enable = HOOKGROUP.Activate
--[[---------------------------------------------------------
	    Name: Deactivate
	    Args: string id (optional), bool force=false
	    Desc: Activates the hook group
-----------------------------------------------------------]]
function HOOKGROUP:Deactivate(id, force)
	local enablers = self:GetActivators()
	assert(id ~= true)
	id = id or true
	local activators_remaining = next(enablers)
	if not activators_remaining and force ~= true then return end
	enablers[id] = nil
	local activators_remaining = next(enablers)
	if force ~= true and activators_remaining then return end
	local Hooks = self:GetHooks()
	local name = self:GetName()

	for hookname, ourfunc in pairs(Hooks) do
		hook.Remove(hookname, name, ourfunc)
	end

	hook.Run("HookGroupDeactivated", name)

	return self
end

--HOOKGROUP.Disable = HOOKGROUP.Activate
function HOOKGROUP:Panic()
	local enablers = self:GetActivators()

	for id, v in pairs(enablers) do
		self:Deactivate(id)
	end

	self:Deactivate(nil, true)

	return self
end

--[[---------------------------------------------------------
	    Name: Remove
	    Args: string hookName, identifier
	    Desc: Removes the hook with the given indentifier.
	-----------------------------------------------------------]]
function HOOKGROUP:Remove(event_name, unused_identifier)
	if (not isstring(event_name)) then
		ErrorNoHaltWithStack("bad argument #1 to 'Remove' (string expected, got " .. type(event_name) .. ")")

		return
	end

	local Hooks = self:GetHooks()
	Hooks[event_name] = nil

	if self:IsEnabled() then
		hook.Remove(event_name, self:GetName())
	end

	return self
end

--[[---------------------------------------------------------
	    Name: Run
	    Args: string hookName, vararg args
	    Desc: Calls hooks associated with the hook name.
	-----------------------------------------------------------]]
HOOKGROUP.Run = HOOKGROUP.Call

--[[---------------------------------------------------------
	    Name: Run
	    Args: string hookName, table gamemodeTable, vararg args
	    Desc: Calls hooks associated with the hook name.
	-----------------------------------------------------------]]
function HOOKGROUP:Call(name, ...)
	--
	-- Run hooks
	--
	local Hooks = self:GetHooks()
	local Hook = Hooks[name]
	if not Hook then return end

	return Hook(...)
end

function HOOKGROUP:Get(name)
	local Hooks = self:GetHooks()

	return Hooks[name]
end

function HOOKGROUP:GetTable()
	return getmetatable(self)._Hooks
end

function HOOKGROUP:GetHooks()
	return getmetatable(self)._Hooks
end

function HOOKGROUP:GetName()
	return getmetatable(self)._group_name
end

function HOOKGROUP:IsActive()
	return next(getmetatable(self)._Activators)
end

--HOOKGROUP.IsEnabled=HOOKGROUP.IsActive
function HOOKGROUP:GetActivators()
	return getmetatable(self)._Activators
end

local function __tostring(self)
	local str = "<HookGroup %s>"
	local meta = getmetatable(self)
	local name = meta and meta._group_name or "???"

	return str:format(name)
end

--[[---------------------------------------------------------
	    Name: NewObj
	    Args: string name
	    Desc: Creates a new hook group object
	-----------------------------------------------------------]]
function NewObj(name)
	local hookgroup = setmetatable({}, {
		__index = HOOKGROUP,
		__tostring = __tostring,
		_group_name = name,
		_Hooks = {},
		_Activators = {}
	})

	return hookgroup
end

--[[---------------------------------------------------------
	    Name: New
	    Args: string name
	    Desc: Creates a new hook group object that can be called like the hook library
	-----------------------------------------------------------]]
function New(name)
	local hookgroup

	local cached = setmetatable({}, {
		__index = function(self, k)
			local orig = HOOKGROUP[k]
			if not orig or not isfunction(orig) then return orig end

			local function bouncer(...)
				return orig(hookgroup, ...)
			end

			self[k] = bouncer

			return bouncer
		end
	})

	--	__tostring = __tostring,
	--	_group_name = name
	hookgroup = setmetatable({}, {
		__index = cached,
		__tostring = __tostring,
		_group_name = name,
		_Hooks = {},
		_Activators = {}
	})

	return hookgroup
end

local function test()
	local hookgroup = _M
	local g1 = hookgroup.New("testgroup1")
	local g2 = hookgroup.New("testgroup2")
	local activated
	local deactivated

	hook.Add("HookGroupActivated", "hookgroup", function(name)
		print("HookGroupActivated", name)
		activated = name
	end)

	hook.Add("HookGroupDeactivated", "hookgroup", function(name)
		print("HookGroupDeactivated", name)
		deactivated = name
	end)

	local thought = 0

	g1.Add("Thonk", "unused", function()
		assert(false, "should not be called")
	end)

	g1.Add("Thonk", function()
		thought = thought + 1
	end)

	g2.Add("Thonk", function()
		thought = thought + 1
	end)

	assert(not activated)
	g1.Activate("herp")
	assert(activated == "testgroup1")
	activated = nil
	g1.Activate("hurp")
	assert(not activated, "activated but should not have been")
	hook.Run("Thonk")
	assert(thought == 1, "did not Thonk but should have")
	g1.Deactivate("herp")
	assert(not activated, "something activated but should not have been")
	assert(not deactivated, "something deactivated but should not have been")
	g1.Deactivate("hurp")
	hook.Run("Thonk")
	assert(thought == 1, "Thonk but should NOT have")
	assert(deactivated, "should have deactivated")
end

--test()