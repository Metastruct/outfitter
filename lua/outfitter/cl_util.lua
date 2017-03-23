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
	local outfitter_hands = CreateClientConVar("outfitter_hands","1",true)
	function ShouldHands()
		return outfitter_hands:GetBool()
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
outfitter_maxsize = CreateClientConVar("outfitter_maxsize","60",true)

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

function TestLZMA(fpath)
	local f = file.Open(fpath,'rb','MOD')

	if not f then
		return nil,"file"
	end
	
	local dat = f:Read(14)
	f:Close()
	
	if not dat or #dat<14 then return false,'size' end
	
	local decompressed_size,dict_size,props = util.DecompressInfo(dat)
	if not decompressed_size then return decompressed_size,dict end
	if decompressed_size > 1024*1024*512 then
		return nil,'oversize'
	end
	
	--TODO: Check 2^n and 2^n + 2^(n-1)
	-- https://svn.python.org/projects/external/xz-5.0.3/doc/lzma-file-format.txt
	
	return true
	
end
function GMABlacklist(fpath,wsid)
	assert(fpath)
	local f = file.Open(fpath,'rb','MOD')
	dbg("GMABlacklist",fpath,f and "" or "INVALIDFILE")
	
	if not f then
		return nil,"file"
	end
	
	local gma,err = gmaparse.Parser(f)
	if not gma then return nil,err end

	local ok ,err = gma:ParseHeader()
	if not ok then return nil,err end
	

	local paths = {}
	local check_vtfs = {}
	for i=1,8192*2 do
		local entry,err = gma:EnumFiles()
		if not entry then
			if err then dbge("GMABlacklist","enumfiles",wsid,err) end
			break
		end
		local path = entry.Name
		assert(path)
		
		paths[#paths+1] = path:lower()
		if path:Trim():sub(-4):lower()=='.vtf' then
			--print(path,entry.Offset)
			assert(not check_vtfs[entry.Offset] )
			check_vtfs[entry.Offset] = path
		end
	end
	
	local endheader = f:Tell()
	
	if not next(check_vtfs) then dbgn(3,"CheckVTF","none found??") end
	
	for offset,path in next, check_vtfs do
		dbgn(2,"CheckVTF",path)
		
		if not gma:SeekToFileOffset(offset) then return nil,'seekfail' end
		
		local dat, err = file.ParseVTF(f)
		if not dat then 
			dbge("GMABlacklist","ParseVTF",path,wsid,"could not parse",err)
		elseif dat.width>4096 or dat.height>4096 then
			dbge("GMABlacklist","ParseVTF",wsid,"oversize")
			return nil,'oversize vtf'
		end
	end
	
	for i=1,#paths do
		local path = paths[i]
		
		--Check 1: modules
		if path :find("includes",4,true) and path:gsub("\\","/"):gsub("/./","/"):gsub("/./","/"):gsub("/+","/"):find("lua/includes/",1,true) then
			return nil,"includes"
		end
		
		--Check 2
		-- Model overrides / script overrides / config overrides / etc

		
	end
	
	return true
	
end


function GMAParseModels(gma)
	local mdls,vvds,mdlfiles,phys = {},{},{},{}
	for i=1,32000 do
		local entry,err = gma:EnumFiles()
		if not entry then
			if err then 
				dbge("GMAParseModels",err) 
				return nil,err
			end
			break
		end
		local path = entry.Name
		local ext = path:sub(-4):lower()
		local path_extless = path:sub(1,-5):lower()
		
		if ext=='.mdl' then
			mdls[#mdls+1] = table.Copy(entry)
		elseif ext=='.vvd' then
			mdlfiles[path_extless] = true
			vvds[path:lower()] = entry.Offset
		elseif ext=='.vtx' then
			--mdlfiles[path:gsub("%.[^%.]+%.vtx$",""):lower()] = true
			mdlfiles[path_extless] = true
		elseif ext=='.phy' then
			phys[path_extless] = true
		end
	end
	return mdls,vvds,mdlfiles,phys
end

-- purge {false,false,good,false}
function RemoveListVals(t,val)
	for i=#t,1,-1 do
		if t[i]==val then
			table.remove(t,i)
		end
	end
end

function CategorizeBadModelPath(n)
	if n:find("/c_arms",1,true) 				then return "arms" end
	if n:find("/c_hands",1,true) 				then return "arms" end
	if n:find("arms.",1,true) 				then return "arms" end
	if n:find("hands.",1,true) 				then return "arms" end
	if n:find("/c_",1,true) 				then return "viewmodel" end
	if n:find("/w_",1,true) 				then return "worldmodel" end
	--if n:find("_animations.mdl",1,true) 	then return "animation" end
	if n:find("_animation",1,true) 	then return "animation" end
	if n:find("_anims_",1,true) 			then return "animation" end
	if n:find("/weapons/.",1,true) 			then return "prop" end
	if n:find("/prop_",1,true) 			then return "prop" end
	if n:find("/props_",1,true) 			then return "prop" end
end

function CheckVVD(gma,vvds,path_extless)
	-- validate VVD vertex count 
	local vvd_offset = vvds[path_extless..'.vvd'] or vvds[path_extless..'.VVD']
	if vvd_offset then
		if not gma:SeekToFileOffset(vvd_offset) then return nil,"seekfail" end
		local ok ,in_err = ValidateVVDVerts(gma:GetFile())
		if not ok then
			dbg("CheckVVD","ValidateVVDVerts",path_extless,in_err)
			return nil,in_err
		end
		return true
	else
		dbge("CheckVVD","vvd not found",path_extless..'.vvd')
	end
end


function GMAPlayerModels(fpath)
	assert(fpath)
	local f = file.Open(fpath,'rb','MOD')
	dbgn(2,"GMAPlayerModels pre",fpath,f and "" or "INVALIDFILE")
	
	if not f then return nil,"file" end
	
	local gma,err = gmaparse.Parser(f)
	if not gma then return nil,err end

	local ok ,err = gma:ParseHeader()
	if not ok then return nil,err end

	local modellist,vvds,mdlfiles,phys = GMAParseModels(gma)
	if modellist==nil then return nil,vvds end


	local playermodels = {}
	local hands = {}
	local potential = {}
	local discards = {}
	local extra = {
		playermodels = playermodels,
		hands = hands,
		potential = potential,
		discards = discards
	}
	
	--TODO: Check CRC?
	--TODO: Check other files exist for mdl (otherwise might be anim for example)
	
	-- go through all model entries found from the gma
	for k,entry in next,modellist do
		local path = entry.Name
		local path_extless = entry.Name:sub(1,-5)
		
		local cat = CategorizeBadModelPath(path)
		
		if not gma:SeekToFileOffset(entry) then return nil,"seekfail" end
		
		can = mdlfiles[path_extless]
		local discard
		local isplr,err,err2 = MDLIsPlayermodel(gma:GetFile(),entry.Size)
		local plerr
		if isplr==nil then 
			dbge("MDLIsPlayermodel",path_extless,err,err2) 
			discard=true
		elseif not isplr then
			plerr = err
			entry.error_player = plerr
		elseif not phys[path_extless] then
			isplr=false
			plerr = 'physics'
			entry.error_player = plerr
		end
		
		if not gma:SeekToFileOffset(entry) then return nil,"seekfail" end
		local ishands,err,err2 = MDLIsHands(gma:GetFile(),entry.Size)
		local handserr
		if ishands==nil then 
			dbge("MDLIsHands",path_extless,err,err2) 
		elseif not isplr then
			handserr = err
			entry.error_hands = handserr
		elseif phys[path_extless] then
			ishands = false
			handserr = 'physics'
			entry.error_hands = handserr
		end
		

		
		
		local vvd_ok,err = CheckVVD(gma,vvds,path_extless)
		entry.vvd_ok = vvd_ok
		if not vvd_ok then
			discard = true
			ishands = false
			isplr = false
		end
		if not ((ishands and not isplr) or (isplr and not ishands) or (not ishands and not isplr)) then
			ishands = false
			isplr = false
			dbge("GMAPlayerModels","Disagreement",fpath,path)
		end
		dbgn(2,"CategorizeModel",cat,isplr and "player" or ishands and "hands" or "unkn",path)
		
		discard = discard 
			or plerr == 'nobones'
			
			or cat == 'arms' 
			or cat == 'prop' 
			or cat == 'animation' 
			or cat == 'viewmodel' 
			or cat == 'worldmodel'
		
		if isplr then
			playermodels[path]=entry
		elseif ishands then
			hands[path]=entry
		elseif not discard then
			potential[path]=entry
		else
			discards[path]=entry
		end
	end
	
	dbg("GMAPlayerModels",fpath,table.Count(playermodels),table.Count(potential),table.Count(hands))
	if IsUnsafe() then
		for k,v in next,potential do
			playermodels[k]=v
		end
	end
		
	
	local mdl_list = {}
	for path,entry in next,playermodels do
		mdl_list[#mdl_list+1] = entry -- entry.Name 
	end
	return mdl_list,extra
	
end

--outfitter.EnforceHands("models/weapons/c_arms_timeshiftsoldier.mdl")

local function Think()
	ThinkEnforce()
	ThinkEnforce_DeathRagdoll()
end
hook.Add("Think",Tag,Think)





-------------------

local viewing
local view={}
function CalcView(pl,pos,oang,fov)
	local speedup = 60
	local t = RealTime()*speedup
	t=( t )%360
	local slowdown= math.sin(t/360*math.pi*2 +math.pi + math.pi*.1)*speedup*.80
	
	local ang = Angle(15, ((t - slowdown) + LocalPlayer():GetAngles().y)%360,0)
	view.origin = pos - ang:Forward()*111
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
concommand.Add("outfitter_camera_toggle",function(a,b,c) if c[1] then ToggleThirdperson(tonumber(c[1])) else ToggleThirdperson() end end) 

------------




local MAX_NUM_LODS = 8
function ParseVVD(f)
	local dat = {}
	dat.id					= f:Read(4)
	if dat.id~='IDSV' then return nil,'not vvd' end
	dat.version				= f:ReadLong()
	if (dat.version or 9999)>10 then return nil,'invalid vvd' end
	dat.checksum			= f:ReadLong()
	dat.numLODs				= f:ReadLong()
	if (dat.numLODs or 9999)>MAX_NUM_LODS then return nil,'invalid vvd' end

	local t = {}
	for i=1,MAX_NUM_LODS do
		t[i] = f:ReadLong()
	end

	dat.numLODVertexes = t
	dat.numFixups			= f:ReadLong()
	dat.fixupTableStart		= f:ReadLong()
	dat.vertexDataStart		= f:ReadLong()
	dat.tangentDataStart	= f:ReadLong()
	return dat
end

function ValidateVVDVerts(f)
	local dat,err = ParseVVD(f)
	
	if not dat then return nil,err end
	
	local num = dat.numLODVertexes[1]
	if num> 44031 --[[magic]] then return false,'too many verts' end
	return true,num
end



do 
	--TODO: skin, bodygroup, etc??
	local HACKT=Tag.."_handshack"
	local function hackt()
		local h = LocalPlayer():GetHands()
		if not h or not h:IsValid() then return end
		local m = h:GetModel()
		if not m then return end
		h:SetModel(m)
	end
	
	local oldmodel
	local enforce,skin,bodygroup
	local function PreDrawPlayerHands(ent)
		local old = ent:GetModel()
		if old~=enforce then
			dbgn(3,'EnforceHands',oldmodel,old,enforce)
			if enforce==nil then
				dbgn(3,"EnforceHands","oldmodel",oldmodel)
				local _=oldmodel and ent:SetModel(oldmodel)
				oldmodel = nil
				hook.Remove("PreDrawPlayerHands",Tag)
				timer.Destroy(HACKT)
			else
				dbgn(3,"EnforceHands","enforce",enforce)
				local _=enforce and ent:SetModel(enforce)
			end
			oldmodel = old
		end
	end

	function EnforceHands(mdl,_skin,_bodygroup)
		enforce = mdl
		if enforce then
			if not timer.Exists(HACKT) then
				timer.Create(HACKT,5,0,hackt)
			end
			hook.Add("PreDrawPlayerHands",Tag,PreDrawPlayerHands)
		else
			timer.Destroy(HACKT)
		end
		_skin,_bodygroup = skin,bodygroup
	end
end