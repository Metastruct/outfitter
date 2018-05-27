local Tag='outfitter'
local NTag = 'OF'

module(Tag,package.seeall)

local GENERIC = "ui/buttonclick.wav"

local NOUI=OUTFITTER_NO_UI

function SOUND(s,force)
	if NOUI or (not force and not CanPlaySounds()) then return end
	surface.PlaySound(s)
end


local mounting
local _mounting
hook.Add('DrawOverlay',Tag,function()
	if not _mounting and not mounting then return end

	if _mounting == true or mounting then _mounting = RealTime() + .5 return end
	if _mounting < RealTime() then _mounting = false end

	local sw,sh = ScrW(),ScrH()
	surface.SetTextColor(255,255,255,255)
	surface.SetFont"closecaption_normal"
	surface.SetDrawColor(90,90,90,200)
	local txt = "#dupes.loading"
	local tw, th = surface.GetTextSize(txt)
	local bw,bh =	tw + 24*2,
					th + 8*2
	local bx,by = 	sw*.5 - bw*.5,
					sh*.2 - bh*.9
	local tx,ty = 	bx + bw*.5 - tw*.5,
					by + bh*.5 - th*.5
					
	surface.DrawRect(bx,by,bw,bh)
	surface.SetDrawColor(255,120,120,200)
	surface.DrawOutlinedRect(bx,by,bw,bh)
	surface.SetDrawColor(255,0,0,200)
	surface.DrawOutlinedRect(bx-1,by-1,bw+2,bh+2)
	surface.DrawOutlinedRect(bx-3,by-3,bw+6,bh+6)
	surface.SetTextPos(tx,ty)
	surface.DrawText(txt)
end)


function UIMounting(yes)
	
	dbg("UIMounting",yes)
	
	if yes then
		_mounting = true
		if mounting then return end
		notification.AddProgress( Tag,
			"(LAG WARNING) Mounting outfitter outfit!" )
		SOUND( GENERIC )
	else
		if not mounting then return end
		timer.Simple(1,function()
			
			if mounting then return end
			
			notification.Kill( Tag )
		end)
		notification.AddProgress( Tag, "Outfit mounted!" )
		SOUND "garrysmod/content_downloaded.wav"
	end
	mounting = yes
end

function UIFullupdate()
	notification.AddLegacy( "Refreshing playerstate...", NOTIFY_ERROR, 4 )
	SOUND'items/cart_explode_trigger.wav'
end

function UIOnEnforce(pl)
	--TODO: exists check. alt: ambient/alarms/warningbell1.wav
	if CanPlaySounds() then
		pl:EmitSound'items/powerup_pickup_agility.wav'
	end
end

local fstatus = {}
function SetUIFetching(wsid,is,FR)
	local ID=Tag..wsid
	
	if is then
		local title = fstatus[wsid]
		if title then return end
		title = true
		fstatus[wsid] = title
		notification.AddProgress( ID, "Downloading "..wsid )
		SOUND( 'ui/hint.wav' )

		co(function()
			local fileinfo = co_steamworks_FileInfo(wsid)
			
			if not fileinfo then return end
			local name = fileinfo.title
			if not name then return end
			
			co.waittick()
			co.waittick()
			local title2 = fstatus[wsid]
			
			if not title2 or title2~=title then return end
			fstatus[wsid] = name
			notification.AddProgress( ID, name..' (Downloading)' )
			--TODO: Timeout?
		end)

	else
		local title = fstatus[wsid] fstatus[wsid] = false
		if not title then return end
		local _title = title
		title = title~=true and title or wsid
		
		notification.AddProgress( ID, title.." ("..(FR and tostring(FR) or "Finished")..")" )
		
		co(function()
			co.sleep(FR and 4 or 1.5)
			
			local status = fstatus[wsid]
			
			if status then return end
			
			notification.Kill( ID )
		end)
		
	end
end



local function Command(com,v1)
	com = com:lower()
	
	if NOUI then return end
	
	if com=="outfit" or com=="otufit" or com=="oufit" or com=="fouti" then
		local n = v1 and tonumber(v1:Trim())
		v1=v1 and v1:lower():Trim()
		dbg("outfitcmd",v1,n)
		if n then
			UIChangeModelToID(n)
			
		elseif v1 == "apply" or v1=='aply' or v1=='a' or v1 == "send" or v1=='snd' or v1=='s'  then
			UIBroadcastMyOutfit()
		elseif v1 == "cancel" or v1=='c' or v1=='canecl'  or v1=='d'  or v1=='del'  or v1=='delete' or v1=='remove' then
			UICancelAll()
		elseif v1 == "autowear" or v1== "save" then
			SetAutowear()
		elseif v1 == "fullupdate" then
			Fullupdate()
		else
			GUIOpen()
			--UIError"Invalid command"
		end
		return true
		
	elseif com==Tag or com=='outfiter'  or com=='oufiter'  or com=='oufitr' or com=='utfitter' or com=='utfiter' then
		local n = v1 and tonumber(v1)
		if n then
			UIChoseWorkshop(n)
		elseif v1 == "fullupdate" then
			Fullupdate()
		elseif v1 and v1:len()>0 then
			GUIWantChangeModel(v1)
		else
			GUIOpen()
		end
		return true
	end
end


concommand.Add(Tag..'_cmd',function(_,_,args)
	Command('outfit',unpack(args))
end)

concommand.Add(Tag,function(_,_,args)
	Command(Tag,unpack(args))
end)

hook.Add("ChatCommand",Tag,function(com,v1)
	return Command(com,v1)
end)

concommand.Add("outfitter_bodygroups_list",function(pl,_,_,mdl)
	if not mdl or mdl:Trim()=="" then
		mdl = pl:GetModel()
	end
	
	MsgN("Listing bodygroups of ",mdl)
	local ok,mdl = pcall(mdlinspect.Open,mdl)
	if not ok then print(mdl) return end
	
	local t = mdl:BodyParts()
	MsgN"================"
	local found
	for i,dat in next,t do
		found=true
		if dat.nummodels and dat.nummodels>1 then
			Msg(' '..tostring(dat.nummodels)..' groups  |  ')
			print(dat.name)
		else
			Msg(' No groups |  ')
			print(dat.name)
		end
		
	end
	if not found then print"No bodygroups??" end
	MsgN"================"
end)

concommand.Add("outfitter_bodygroups_set",function(pl,cmd,args,line)
	if line:Trim()=="" then 
		print("Usage: outfitter_bodygroups_set HeadAttachment=0,Backpack=2,Shorts=1")
		return
	end
	
	local t={}
	for entry in line:gmatch'[^%,]+' do
		local k,v = entry:match'([^%="]+)%=(%d)'
		if k then
			t[k]=tonumber(v)
		end
	end
	
	local mdl = mdlinspect.Open(pl:GetModel())
	local bodyparts = mdl:BodyParts()
	local bp = mdlinspect.BodyPartBuilder(bodyparts,0)
	print(table.ToString(t))
	for k,v in next,t do
		local ok,a,b,c = bp:Set(k,v)
		if not ok then
			Msg("[Set Bodygroup] Failed setting ",k,": ")print(b)
		end
	end
	pl:SetBodyGroupData(bp:GetValue())
	Msg"Bodygroups: "print(bp:GetValue())
end)


CWHITE = Color(255,255,255,255)
CBLACK = Color(0,0,0,0)
local ns = 0
function UIError(...)
	dbgn(2,...)
	local t= {Color(200,50,10),'[Outfitter ERROR] ',CWHITE,...}
	local now = RealTime()
	if ns<now then
		ns=now + 1
		SOUND("common/warning.wav")
	end
	local t2={}
	for i=1,select('#',...) do
		local v=select(i,...)
		v=tostring(v) or "no value"
		t2[i]=v
	end
	local str = table.concat(t2,' ')
	
	notification.AddLegacy( str, NOTIFY_ERROR, 4 )
	chat.AddText(CWHITE,unpack(t))
end

local ns = 0
function UIMsg(...)
	local t= {Color(50,200,10),'[Outfitter] ',CWHITE,...}
	local now = RealTime()
	if ns<now then
		ns=now + 1
		SOUND("weapons/grenade/tick1.wav")
	end
	chat.AddText(unpack(t))
end

local mdllist
local handslist
local chosen_wsid
local tried_mounting
local mount_path
local chosen_mdl
local mdllist_extra
function UIGetMDLList()
	return mdllist
end

function UIGetMDLListExtra()
	return mdllist_extra
end

function UITriedMounting()
	return tried_mounting
end
function UIGetChosenMDL()
	return chosen_mdl
end
function UIGetWSID()
	return chosen_wsid
end

function UICancelAll()
	UIMsg"Unsetting everything"
	
	mdllist = nil
	mdllist_extra = nil
	chosen_wsid = nil
	mount_path = nil
	tried_mounting = nil
	chosen_mdl = nil
	
	RemoveOutfit()
	EnforceHands()
	UIClearBodyGroupData()
end

function UIClearBodyGroupData()
	LocalPlayer():SetBodyGroupData(0)
end

function UIBroadcastMyOutfit()
	 
	local mdl,wsid = BroadcastMyOutfit()
	if mdl then
		SOUND"ui/item_robot_arm_pickup.wav"
	else
		SOUND"ui/item_robot_arm_drop.wav"
	end
	return mdl,wsid
end

local relay_opengui
function UIChangeModelToID(n,opengui)

	if co.make(n,opengui) then return end
	
	dbg("UIChangeModelToID",n)
	
	UIClearBodyGroupData()
	
	chosen_mdl = nil
	
	if not chosen_wsid then
		if opengui then GUIOpen() end
		return UIError"Type only !outfit first to choose workshop addon"
	end
	if not mdllist or #mdllist==0 then
		if opengui then GUIOpen() end
		return UIError"No models to choose from"
	end
	local mdl = mdllist[n]
	if not mdl then
		if opengui then GUIOpen() end
		return UIError"Invalid model index"
	end
	
	assert(mount_path,"mount_path missing for "..tostring(chosen_wsid))
	local ok,err = coMountWS( mount_path )

	if not ok then
		if opengui then GUIOpen() end
		return UIError("The workshop addon could not be mounted: "..tostring(err))
	end
	
	assert(mdl.Name)
	
	chosen_mdl = n
	relay_opengui = opengui
	
	-- returns instantly, but should be instant anyway
	OnChangeOutfit(LocalPlayer(),mdl.Name,chosen_wsid)
	dbg("EnforceHands?",ShouldHands(),n,mdllist[2]==nil,handslist,handslist and handslist[1])
	if n==1 and nil==mdllist[2] and handslist and next(handslist)~=nil and ShouldHands() then
		local _,entry = next(handslist)
		EnforceHands(entry.Name)
	else
		EnforceHands()
	end
		
end

hook.Add("OutfitApply",Tag,function(pl,mdl)
	
	if pl==LocalPlayer() and mdl then
		local opengui = relay_opengui
		relay_opengui=false
		
		if NOUI then return end
		
		notification.AddLegacy( "Outfit changed!", NOTIFY_UNDO, 2 )
		SOUND( GENERIC )
		
		UIMsg"Write '!outfit send' to send this outfit to everyone"
		if opengui then
			GUIOpen()
		end
		
	end
end)

function UIChoseWorkshop(wsid,opengui)
	if co.make(wsid,opengui) then return end
	
	mdllist = nil
	chosen_wsid = nil
	mount_path = nil
	tried_mounting = nil
	chosen_mdl = nil
	
	SetUIFetching(wsid,true)
		co.sleep(.5)
			local path,err,err2 = coFetchWS( wsid ) -- also decompresses
		co.sleep(.2)
	SetUIFetching(wsid,false,not path and (err and tostring(err) or "FAILED?"))
	
	if not path then
		dbg("UIChoseWorkshop",wsid,"FetchWS failed:",err,err2)
		if opengui then GUIOpen() end
		return UIError("Download failed for workshop "..wsid..": "..tostring(err~=nil and tostring(err) or GetLastMountErr and GetLastMountErr()))
	end
	co.sleep(.2)
	
	local mdls,extra,err = GMAPlayerModels( path )
	--PrintTable(mdls)
	
	if not mdls and extra=='notgma' then
		dbgn(2," TestLZMA(",path,") ==", ("%q"):format(file.Read(path,'GAME'):sub(1,14)),TestLZMA(path) )
	end
	if not mdls and extra=='notgma' and TestLZMA(path) then
		local newpath,extra = coDecompress(path)
		if not newpath then
			if opengui then GUIOpen() end
			return UIError("Download failed for workshop "..wsid..": "..tostring(extra~=nil and tostring(extra) or GetLastMountErr and GetLastMountErr())) 
		end
		path = newpath
		
		-- retry --
		mdls,extra,err = GMAPlayerModels( path )
		-----------
	end
	
	
	if not mdls then
		dbge("UIChoseWorkshop",wsid,"GMAPlayerModels failed for:",extra,err)
		notification.AddLegacy( '[Outfitter] '..tostring(extra=="nomdls" and "no valid models found" or extra), NOTIFY_ERROR, 2 )
		if opengui then GUIOpen() end
		return UIError("Parsing workshop addon "..wsid.." failed: "..tostring(extra=="nomdls" and "no valid models found" or extra))
	end
	
	local ok,err = GMABlacklist(path)
	if not ok then
		if opengui then GUIOpen() end
		return UIError("OUTFIT BLOCKED: "..tostring(err=="oversize vtf" and "Contains too big textures" or err))
	end
	
	if not mdls[1] then
		dbg("UIChoseWorkshop","GMAPlayerModels",wsid,"no valid models!?")
		
		if opengui then GUIOpen() end
		
		UIError("Workshop addon "..wsid.." has no valid playermodels")
		if extra and istable(extra) and extra.discards and next(extra.discards) then
			for mdl,dat in next,extra.discards or {} do
				mdl = MDLToUI(mdl)
				if dat.error_vvd then
					UIError(mdl,":",tostring(TranslateError(dat.error_vvd)))
				elseif dat.error_player then
					UIError(mdl,":",tostring(TranslateError(dat.error_player)))
				end
			end
		end
		
	end
	
	co.sleep(.2)
	
	if mdls[2] then
		UIMsg("Models:")
		for k,mdl in next,mdls do
			UIMsg(" "..k..". "..tostring(mdl and MDLToUI(mdl.Name)))
		end
	elseif mdls[1] then
		UIMsg("Got model: "..tostring(MDLToUI(mdls[1].Name)))
	end
	
	chosen_wsid = wsid
	mdllist = mdls
	mdllist_extra = extra
	handslist = extra.hands
	mount_path = path
	
	if mdls[2] then
		UIMsg"Write !outfit <model number> to choose a model"
		if opengui then GUIOpen() end
	else
		UIChangeModelToID(1,opengui)
	end
	

end





-- autowear --



function SetAutowear()
	local pl = LocalPlayer()
	
	local mdl,wsid,skin,bodygroup = pl:OutfitInfo()
	
	local t = {mdl=mdl,wsid=wsid,skin=skin,bodygroup=bodygroup,setbodygroupdata = pl:GetBodyGroupData(),hands = pl.outfitter_hands}
	
	
	if mdl then
		util.SetPData("0",Tag..'_autowear',util.TableToJSON(t))
		UIMsg("Autowear ON")
	else
		util.RemovePData("0",Tag..'_autowear')
		UIMsg("Autowear OFF")
	end

end

			
local oversized = {}
function coUIOversizeMsg(pl,wsid)

	
	if oversized[wsid] then return end
	oversized[wsid] = true
	
	local fileinfo = co_steamworks_FileInfo(wsid)
	
	local maxsz = outfitter_maxsize:GetFloat()
	maxsz = maxsz*1000*1000
	maxsz = string.NiceSize(maxsz)
	local szstr=""
	if fileinfo and istable(fileinfo) and fileinfo.size then
		szstr = ("(%s) "):format(string.NiceSize(fileinfo.size or 0))
	end
	
	UIMsg("The outfit of ",pl,(" is too big %saccording to your settings (%s) so it was not mounted!"):format(szstr,maxsz))

end



-- This is a horrible hack because of forethought was lacking when the rest of the code was made
-- duplicated from two different functions, etc
function coDoAutowear()
	local dat = util.GetPData("0",Tag..'_autowear')
	if not dat then return end
	local t = util.JSONToTable(dat)
	if not t then return end
	if not t.mdl then return end
	if t.mdl=="" then return end
	
	local mdl,wsid,skin,bodygroup,setbodygroupdata = t.mdl,t.wsid,t.skin,t.bodygroup,t.setbodygroupdata
	local hands = t.hands
	
	if not mdl then return end
	
	dbg("Autowearing",mdl,"from",wsid,"setbodygroupdata=",setbodygroupdata)
	
	
	SetUIFetching(wsid,true)
		co.sleep(.5)
			local path,err,err2 = coFetchWS( wsid )
		co.sleep(.2)
	SetUIFetching(wsid,false,not path and (err and tostring(err) or "FAILED?"))
	
	if not path then
		dbg("coDoAutowear",wsid,"FetchWS failed:",err,err2)
		if opengui then GUIOpen() end
		return UIError("Download failed for workshop "..wsid..": "..tostring(err~=nil and tostring(err) or GetLastMountErr and GetLastMountErr()))
	end
	co.sleep(.2)
	
	local mdls,extra,err = GMAPlayerModels( path )
	
	if not mdls and extra=='notgma' then
		dbgn(2," TestLZMA(",path,") ==", ("%q"):format(file.Read(path,'GAME'):sub(1,14)),TestLZMA(path) )
	end
	if not mdls and extra=='notgma' and TestLZMA(path) then
		local newpath,extra = coDecompress(path)
		if not newpath then
			if opengui then GUIOpen() end
			return UIError("Download failed for workshop "..wsid..": "..tostring(extra~=nil and tostring(extra) or GetLastMountErr and GetLastMountErr())) 
		end
		path = newpath
		
		-- retry --
		mdls,extra,err = GMAPlayerModels( path )
		-----------
	end
	
	
	if not mdls then
		dbge("coDoAutowear",wsid,"GMAPlayerModels failed for:",extra,err)
		notification.AddLegacy( '[Outfitter] '..tostring(extra=="nomdls" and "no valid models found" or extra), NOTIFY_ERROR, 2 )
		return UIError("Parsing workshop addon "..wsid.." failed: "..tostring(extra=="nomdls" and "no valid models found" or extra))
	end
	
	local ok,err = GMABlacklist(path)
	if not ok then
		return UIError("OUTFIT BLOCKED: "..tostring(err=="oversize vtf" and "Contains too big textures" or err))
	end
	
	if not mdls[1] then
		dbge("coDoAutowear","GMAPlayerModels",wsid,"no models!?")
		return UIError("Workshop addon "..wsid.." has no playermodels")
	end
	
	co.sleep(.2)
	
	local chosen_wsid = wsid
	local mdllist = mdls
	local handslist = extra.hands
	local mount_path = path
	local mdllist_extra = extra
	
	
	
	assert(mount_path,"mount_path missing for "..tostring(chosen_wsid))
	local ok,err = coMountWS( mount_path )

	if not ok then
		return UIError("The workshop addon could not be mounted: "..tostring(err))
	end
	
	assert(mdl)
	
	
	-- returns instantly, but should be instant anyway
	OnChangeOutfit(LocalPlayer(),mdl,chosen_wsid)
	
	dbg("coDoAutowear","EnforceHands",ShouldHands(),next(handslist or {}))
	if next(handslist or {})~=nil and ShouldHands() then
		local _,entry = next(handslist)
		EnforceHands(entry.Name)
	else
		EnforceHands()
	end
	
	--LocalPlayer():SetWantOutfit(mdl,wsid,skin,bodygroup)
	
	if setbodygroupdata and setbodygroupdata~=0 then
		dbg("SetBodyGroupData",setbodygroupdata)
		LocalPlayer():SetBodyGroupData(setbodygroupdata)
	end
	
	BroadcastMyOutfit()
	
	return true
end

