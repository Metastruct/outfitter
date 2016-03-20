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
outfitter_enabled = CreateClientConVar("outfitter_enabled","1",SAVE,true)
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
	
	--TODO: non tpose :(
	local recursing
	local localpl
	hook.Add("PrePlayerDraw",Tag,function(p)
		localpl = localpl or LocalPlayer()
		if p~=localpl then 
			return
		end
		
		if recursing then return end
		recursing=true
		
			p:InvalidateBoneCache()
			Enforce(p)
			p:DrawModel()
		
		recursing=false
		return true
	end)

	
	
-- workshop fetching coroutine 

	local fetching = {}

	local res = {}
	local skip_maxsizes = {}
	local function SYNC(cbs,...)
		for k,cb in next,cbs do
			cb(...)
			co.waittick()
		end
		return ...
	end

	local function steamworks_Download( fileid, uncomp )
		local instant
		local path
		local cb = co.newcb()
		local function cb2(a,b)
			dbg("SWDL",fileid,instant==false and "" or "instant?","result",a,b)
			if instant==nil then
				path = a
				instant = true
				return 
			end
			cb(a,b)
		end
		steamworks.Download( fileid, uncomp, cb2 )
		if instant==nil then
			instant = false
			path = co.waitcb(cb)
		end
		dbg("SWDL",fileid,"returning",path,"instant:",instant)
		return path
	end

	local lme
	local lwsid
	function GetLastMountErr(wsid)
		if lwsid and lwsid~=wsid then return end
		return lme
	end
	
	local function cantmount(wsid,reason)
		fetching[wsid] = false
		res[wsid] = reason or "failed?"
		dbge("FetchWS","downloading",wsid,"failed for",reason)
		lme= reason or "?"
		lwsid=wsid
		return false,reason
	end
	
	do
		local worker,cache = co.work_cacher_filter(
			function(key,fileinfo)
				return (not key) or fileinfo
			end,
			
			co.work_cacher(
				function(wsid)
					local cb = co.newcb()
						steamworks.FileInfo(wsid,cb)
					local fileinfo = co.waitcb(cb)
					
					return fileinfo
					
				end)
			)
		co_steamworks_FileInfo = co.worker(worker) 
	end
	
	do
		local worker,cache = co.work_cacher_filter(
			function(key,fileinfo)
				return (not key) or fileinfo
			end,
			
			co.work_cacher(
				function(wsid)
					local cb = co.newcb()
						steamworks.VoteInfo(wsid,cb)
					local fileinfo = co.waitcb(cb)
					
					return fileinfo
					
				end)
			)
		co_steamworks_VoteInfo = co.worker(worker) 
	end
	
	function coFetchWS(wsid,skip_maxsize)
		
		if skip_maxsize then
			skip_maxsizes[wsid] = true
		end
		
		local dat = fetching[wsid]
		
		if dat then
			if dat==true then 
				return res[wsid] or true
			elseif istable(dat) then
				local cb = co.newcb()
				dat[#dat+1] = cb
				return co.waitcb()
			elseif dat==false then
				local res = res[wsid]
				local canskip = res=="oversize" and skip_maxsize
				if not canskip then
					return false,res
				end
			end
		end
		
		if isdbg then dbg("FetchWS",wsid) end
		
		dat = {}
		fetching[wsid] = dat
		
		local fileinfo = co_steamworks_FileInfo(wsid)
		
		if isdbg then
			dbg("steamworks.FileInfo",wsid,"->",fileinfo)
			if istable(fileinfo) then
				dbg("","title",fileinfo.title)
				dbg("","owner",fileinfo.owner)
				dbg("","tags",fileinfo.tags)
				dbg("","size",string.NiceSize(fileinfo.size or 0))
				dbg("","fileid",fileinfo.fileid)
				
				--TODO: Check banned
				--TODO: Check popularity before mounting
				
				local banned = fileinfo.banned
				local installed = fileinfo.installed
				local disabled = fileinfo.disabled
				if banned then
					dbge(wsid,"BANNED!?")
				end
				if disabled then
					dbge(wsid,"Disabled?")
				end
				if installed then
					dbge(wsid,"installed?")
				end
			end
		end
		
		if not fileinfo or not fileinfo.fileid then
			return SYNC(dat,cantmount(wsid,"fileinfo"))
		end
		
		local maxsz = outfitter_maxsize:GetFloat()
		maxsz = maxsz*1024*1024
		
		if maxsz>0.1 and (fileinfo.size or 0) > maxsz then
			skip_maxsize = skip_maxsize or skip_maxsizes[wsid]

			dbg("FetchWS","MAXSIZE",skip_maxsize and "OVERRIDE" or "",wsid,string.NiceSize(fileinfo.size or 0))
			
			if not skip_maxsize then
				return SYNC(dat,cantmount(wsid,"oversize"))
			end
		end
			
		co.wait(.3)
		
		local TIME = isdbg and SysTime()
		local path = steamworks_Download( fileinfo.fileid, true )
		if isdbg then dbg("Download",wsid,"to",path or "<ERROR>","took",SysTime()-TIME) end
		
		assert(path~=true)
		
		if not path then
			return SYNC(dat,cantmount(wsid,"download"))
		end
		
		local result = path
		fetching[wsid] = true
		res[wsid] = result
		
		return SYNC(dat,result)

	end

	function FetchWS(wsid,cb)
		if co.make(wsid,cb) then return end
		cb(coFetchWS(wsid))
	end

	
-- mount workshop files, don't try remounting, don't return file list (can be read elsewhere)
local res = {}

function WasAlreadyMounted(path)
	local result = res[path]
	if result~=nil then return result end
end

function MountWS( path )
	
	local result = WasAlreadyMounted(path)
	if result~=nil then return result end

	local isdbg = isdbg()
	
	local TIME = isdbg and SysTime()
	dbg("MountGMA",path)
	CRITICAL("mountws",path)
	local ok, files = game.MountGMA( path )
	CRITICAL(false)
	if isdbg then dbg("MountGMA",path,"took",(SysTime()-TIME)) end

	result = ok or false
	res[path] = result
	return result,files -- files returned only once
end

function coMountWS(path,cb)

	local result = WasAlreadyMounted(path)
	if result~=nil then return result end
	
	if cb and co.make(path,cb) then return end
	
	UIMounting(true)
	co.sleep(1.5)
		local res = MountWS( path )
	UIMounting(false)
	co.sleep(.5)
	
	if cb then cb(res) end
	
	return res
	
end
	--          l outfitter.FetchWS(111412589,PrintTable)

--TODO: own cache
function NeedWS(wsid,pl,mdl)
	if co.make(wsid,pl,mdl) then return end
	
	local result = WasAlreadyMounted(path)
	if result~=nil then 
		if not result then return nil,"mount" end
		return result
	end
	
	SetUIFetching(wsid,true)
	
		co.sleep(.1)
		
		local path,err,err2 = coFetchWS( wsid ) -- also decompresses
		
		co.sleep(1)
		
	SetUIFetching(wsid,false,not path and (err and tostring(err) or "FAILED?"))
	
	if not path then
		dbg("NeedWS",wsid,"fail",err)
		return nil,err or "fetchws"
	end
	
	local mdls,err = GMAPlayerModels(path)
	
	if not mdls then
		dbge("NeedWS","GMAPlayerModels",wsid,"fail",err)
		return false,"mdlparse",err
	end
	
	if not mdls[1] then
		dbge("NeedWS","GMAPlayerModels",wsid,"no models!?")
		return	false,"nomdls"
	end
	
	local ok = coMountWS( path )
	
	if not ok then
		dbg("NeedWS",wsid,"mount fail")
		return nil,err or "mount"
	end
	
	return true
	
end
	
		
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


local stp 
function ToggleThirdperson()
	stp = stp or GetConVar"simple_thirdperson_enabled"
	if stp then
		RunConsoleCommand("simple_thirdperson_enabled",stp:GetBool() and "0" or "1")
	end
	
	local ctp = _G.ctp
	if ctp and ctp.Disable then
		if ctp.Enabled then
			ctp.Disable()
		else
			ctp.Enable()		
		end
	end
end