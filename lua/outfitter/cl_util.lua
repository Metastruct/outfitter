local Tag='outfitter' 
local NTag = 'OF'

require'mdlinspect'
require'gmaparse'

module(Tag,package.seeall)

local SAVE =false  --TODO: make save after end of debugging

local Player = FindMetaTable"Player"


function Fullupdate()
	timer.Create(Tag..'fullupdate',.2,1,function()
		UIFullupdate()
		LocalPlayer():ConCommand("record removeme",true)
		RunConsoleCommand'stop'
	end)
end

--TODO: Make outfitter mount all after enabling?
outfitter_enabled = CreateClientConVar("outfitter_enabled","1",true,true)
cvars.AddChangeCallback("outfitter_enabled",function(cvar,old,new)
	if new=='0' then
		DisableEverything()
	elseif new=='1' then
		EnableEverything()
	end
end)

do
	local outfitter_enabled = outfitter_enabled
	function IsEnabled()
		return outfitter_enabled:GetBool()
	end
end

do
	local outfitter_sounds = CreateClientConVar("outfitter_sounds","1",true)
	function CanPlaySounds()
		return outfitter_sounds:GetBool()
	end
end

do
	-- -1: server preference
	-- 0: force disable distance check
	-- 1: force enable distance check
	local outfitter_distance_mode = CreateClientConVar("outfitter_distance_mode","-1",true)
	local outfitter_distance = CreateClientConVar("outfitter_distance","2047",true)
	function ShouldDistance()
		local mode = outfitter_distance_mode:GetInt()
		if mode==0 then
			return false
		elseif mode==1 then
			return true
		end
		return ServerSuggestDistance()
	end
	
	function GetDistance()
		local d = outfitter_distance:GetFloat()
		if ShouldDistance() then return d>0 and d end
	end
	
	function VisibleFilter(pl1,pl2)
		local pos1,pos2 = pl1:GetPos(),pl2:GetPos()
		local dist = GetDistance()
		if not dist then return false end
		return pos1:DistToSqr(pos2)>(dist*dist)
	end
end

do

	local outfitter_nohighperf = CreateClientConVar("outfitter_nohighperf","0",false)
	local highperf = 0
	function IsHighPerf()
		return not outfitter_nohighperf:GetBool() and highperf>0
	end

	function SetHighPerf(mode,refresh_all)
		local washigh = highperf>0
		highperf = highperf + (mode and 1 or -1)
		highperf = highperf<0 and 0 or highperf
		assert(highperf < 12,"HIGHPERF FAIL")
		local ishigh = highperf>0
		
		if ishigh~=washigh and refresh_all then
			RefreshPlayers()
		end
	end
	
end

--TODO
do
	local outfitter_unsafe = CreateClientConVar("outfitter_unsafe","0",SAVE)
	function IsUnsafe()
		return outfitter_unsafe:GetBool()
	end
end

do
	
	-- TODO: OnPlayerVisible calling
	
	local outfitter_friendsonly = CreateClientConVar("outfitter_friendsonly","0",true)

	cvars.AddChangeCallback("outfitter_friendsonly",function(cvar,old,new)
		if new=='1' then
			EnableEverything()
		end
	end)


	function IsFriendly(pl)
		if not outfitter_friendsonly:GetBool() then return true end
		
		if pl.IsFriend then
			return LocalPlayer():IsFriend(pl)
		end
		
		local fs = pl:GetFriendStatus()
		if fs=="friend" then return true end
		return false
	end
end

--TODO
local outfitter_failsafe = CreateClientConVar("outfitter_failsafe","0",SAVE)
function IsFailsafe()
	return outfitter_failsafe:GetBool()
end

--TODO
outfitter_maxsize = CreateClientConVar("outfitter_maxsize","60",SAVE)

-- Model enforcing
	
	-- ragdoll model

	local function Enforce(rag)
		local mdl = rag.enforce_model
		if mdl then
			--TODO: not having this causes crashes?
			rag:InvalidateBoneCache()
			
			rag:SetModel(mdl)
			rag:InvalidateBoneCache()
			
		end
	end

	local enforce_models = {}
	function ThinkEnforce_DeathRagdoll()
		for rag,count in next,enforce_models do
			if rag:IsValid() and count>0 then
				
				enforce_models[rag] = count - 1
				Enforce(rag)
				
			else
				enforce_models[rag] = nil
			end
		end
	end


	function DeathRagdoll_RenderOverride(rag)
		if rag.enforce_model then
			rag:SetModel(rag.enforce_model)
			if enforce_models[rag] then
				rag:InvalidateBoneCache()
			end
		end
		rag:DrawModel()
	end

	function OnDeathRagdollCreated(rag,pl)
		local mdl = pl:GetEnforceModel()
		if not mdl then return end
		
		local mdlr = rag:GetModel()
		local mdlp = pl:GetModel()
		
		local hasenforced   = mdlr==mdl
		local isplyenforced = mdlp==mdl
		dbgn(2,"DeathRagdollEnforce",pl,rag,mdl,hasenforced and ("ENFORCED RAG: "..tostring(mdlr)) or "" ,isplyenforced and "" or ("NOT ENFORCED PLY: "..tostring(mdlp)) )
		
		rag.enforce_model = mdl
		enforce_models[rag] = 8
		Enforce(rag)
		
		rag.RenderOverride=DeathRagdoll_RenderOverride
		
	end





	-- player model
	-- TODO: ResetHull()
	local function Enforce(pl)
		if pl.enforce_model then
			pl:SetModel(pl.enforce_model)
			pl:ResetHull() -- sorry PAC
		end
	end

	local enforce_models = {}
	function ThinkEnforce()
		for pl,count in next,enforce_models do
			if pl:IsValid() and count>0 then
				
				enforce_models[pl] = count - 1
				Enforce(pl)
				
			else
				enforce_models[pl] = nil
			end
		end
	end

	-- Set model and start setting it for next 3 ticks while some other forces fight us
	--TODO: what forces
	function StartEnforcing(pl)
		enforce_models[pl] = 34
		Enforce(pl)
	end
	
	
	-- Set or unset actual model to be enforced clientside
	--TODO: Check if loaded, if not: Refine so that the model is parsed for materials, load materials and then enforce model. less lag!
	function Player.EnforceModel(pl,mdl,nocheck)
		dbg("EnforceModel",pl,mdl or "UNENFORCE")
		
		if not mdl then
			if pl.original_model then
				pl:SetModel(pl.original_model)
				pl.original_model = nil
			end
			pl.enforce_model = nil
				
			-- need to fullupdate or it doesn't reset either
			if pl==LocalPlayer() then
				Fullupdate()
			end
			
			return true
		end
		
		if not nocheck then
			local exists = HasMDL(mdl)
			if not exists then return false,"invalid" end
		end
		
		local curmdl = pl:GetModel()
		local curenforce = pl.enforce_model
		local origmdl = pl.original_model
		
		if not origmdl then
			pl.original_model = pl:GetModel()
		end
		
		StartEnforcing(pl)
		
		pl.enforce_model = mdl
		
		if pl==LocalPlayer() and curmdl ~= mdl then
			Fullupdate()
		end
		
		return true
		
	end

	function Player.GetEnforceModel(pl,mdl)
		return pl.enforce_model
	end

	function OnPlayerInPVS(pl)
		if not pl.enforce_model then return end
		
		local orig = pl.original_model
		local neworig = pl:GetModel()
		-- pl.original_model = neworig
		dbgn(2,"OnPlayerInPVS","enforce",pl,pl.enforce_model,"orig",orig,orig==neworig)
		StartEnforcing(pl)
	end
	
	--TODO: REVISIT (Single frame spazzing on local player wear)
	local recursing
	local localpl
	hook.Add("PrePlayerDraw",Tag,function(p)
		localpl = localpl or LocalPlayer()
		if p~=localpl then 
			return
		end
		
		if recursing then return end
		recursing=true
					
			Enforce(p)
			--p:DrawModel()
		
		recursing=false
		--return true
	end)

	

function GMAPlayerModels(fpath)
	assert(fpath)
	local f = file.Open(fpath,'rb','MOD')
	dbg("GMAPlayerModels",fpath,f and "" or "INVALIDFILE")
	
	if not f then
		return nil,"file"
	end
	
	local gma,err = gmaparse.Parser(f)
	if not gma then return nil,err end

	local ok ,err = gma:ParseHeader()
	if not ok then return nil,err end

	local mdls = {}
	local mdlfiles = {}
	for i=1,8192*2 do
		local entry,err = gma:EnumFiles()
		if not entry then 
			if err then dbge("enumfiles",err) end
			break 
		end
		local path = entry.Name
		local ext = path:sub(-4)
		if ext=='.mdl' then
			mdls[#mdls+1] = table.Copy(entry)
		elseif ext=='.vvd' then
			mdlfiles[path:sub(1,-5):lower() ] = true
		elseif ext=='.vtx' then
			mdlfiles[path:sub(1,-10):lower()] = true
		end
	end
	
	local potential={}
	
	--TODO: Check CRC?
	--TODO: Check other files exist for mdl (otherwise might be anim for example)
	
	local one_error
	for k,entry in next,mdls do
		
		
		local seekok = gma:SeekToFileOffset(entry)
		if not seekok then return nil,"seekfail" end
		
		
		local can,err,err2
		
		local noext = entry.Name:sub(1,-5)
		can = mdlfiles[noext]

		if not can then
			can,err,err2 = false,"vvd"
		else
			can,err,err2 = MDLIsPlayermodel(gma:GetFile(),entry.Size)
		end
		if can==nil then dbge("MDLIsPlayermodel","ERROR",err,err2) end
		if can then
			local n = entry.Name
			if n:find("_arms.",1,true) 	then can,err =false,"arms" 		 end
			if n:find("_hands.",1,true) then can,err =false,"arms" 		 end
			if n:find("/c_",1,true) 	then can,err =false,"viewmodel"  end
			if n:find("/w_",1,true) 	then can,err =false,"worldmodel" end
		end
		if not can then
			dbg("","Bad",entry.Name,err,err2 or "",IsUnsafe() and "UNSAFE ALLOW" or "")
			potential[entry]=err or "?"
			if not IsUnsafe() then
				mdls[k]=false
			end
		end
	end
	-- purge bad
	for i=#mdls,1,-1 do
		if mdls[i]==false then
			table.remove(mdls,i)
		end
	end
	dbg("GMAPlayerModels post",#mdls)
	if #mdls>0 then
		return mdls,nil,potential
	else
		return nil,"nomdls",potential
	end
end


local function Think()
	ThinkEnforce()
	ThinkEnforce_DeathRagdoll()
end
hook.Add("Think",Tag,Think)


local viewing
local view={}
function CalcView(pl,pos,ang,fov)
	local speedup = 60
	local t = RealTime()*speedup
	t=(ang.y + t)%360
	local slowdown= math.sin(t/360*math.pi*2 +math.pi + math.pi*.1)*speedup*.45
	
	local ang = Angle(20, t - slowdown,0)
	view.origin = pos - ang:Forward()*150
	view.fov = fov
	view.angles = ang
	return view
end
function ShouldDrawLocalPlayer()
	return viewing
end
function InThirdperson()
	return viewing
end

function ToggleThirdperson(want)
	if want==false or (viewing and want==nil) then
		hook.Remove("CalcView",Tag)
		hook.Remove("ShouldDrawLocalPlayer",Tag)
		viewing = false
	elseif not viewing and want~=false then
		viewing = true
		hook.Add("CalcView",Tag,CalcView)
		hook.Add("ShouldDrawLocalPlayer",Tag,ShouldDrawLocalPlayer)
	end

end
