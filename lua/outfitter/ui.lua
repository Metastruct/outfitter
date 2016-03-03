local Tag='outfitter' 
local NTag = 'OF'

module(Tag,package.seeall)

local mounting
function UIMounting(yes)
	mounting = is
	if is then
		notification.AddProgress( Tag, 
			"Mounting outfitter outfit!" )
		surface.PlaySound( "buttons/button15.wav" )
	else
		notification.Kill( Tag )
	end
end

function UIFullupdate()
	notification.AddLegacy( "Warning: Fullupdate requested", NOTIFY_ERROR, 4 )
	surface.PlaySound'items/cart_explode_trigger.wav'
end

function UIOnEnforce(pl)
	--TODO: exists check. alt: ambient/alarms/warningbell1.wav
	pl:EmitSound'items/powerup_pickup_agility.wav'
end

function SetUIFetching(wsid,is)
	if is then
		notification.AddProgress( Tag..wsid, 
			"Downloading "..wsid )
		surface.PlaySound( "buttons/button15.wav" )
	else
		notification.Kill( Tag..wsid )
	end
end


hook.Add("HUDPaint",Tag,function()
	if mounting then
		surface.SetDrawColor(200,20,10,55)
		surface.DrawRect(0,0,ScrW(),ScrH())
	end
end)

hook.Add("ChatCommand",Tag,function(com,v1)
	com = com:lower()
	
	if com=="outfit" then
		local n = v1 and tonumber(v1:Trim())
		v1=v1 and v1:lower():Trim()
		dbg("outfitcmd",v1,n)
		if n then
			UIChangeModelToID(n)
		elseif v1 == "apply" or v1=='aply' or v1=='a' or v1 == "send" or v1=='snd' or v1=='s'  then
			UIBroadcastMyOutfit()
		elseif v1 == "cancel" or v1=='c' or v1=='canecl'  or v1=='d'  or v1=='del'  or v1=='delete' or v1=='remove' then
			UICancelAll()
		else
			GUIWantChangeModel()
			--UIError"Invalid command"
		end
		
	elseif com==Tag then
		local n = v1 and tonumber(v1)
		if n then
			UIChoseWorkshop(n)
		elseif v1 and v1:len()>0 then
			GUIWantChangeModel(v1)
		end
	end
	
end)

CWHITE = Color(255,255,255,255)
CBLACK = Color(0,0,0,0)
local ns = 0
function UIError(...)
	local t= {Color(200,50,10),'[Outfitter Err] ',CWHITE,...}
	local now = RealTime()
	if ns<now then 
		ns=now + 1
		surface.PlaySound("common/warning.wav")
		return 
	end
	chat.AddText(unpack(t))
end

local ns = 0
function UIMsg(...)
	local t= {Color(50,200,10),'[Outfitter] ',CWHITE,...}
	local now = RealTime()
	if ns<now then 
		ns=now + 1
		surface.PlaySound("weapons/grenade/tick1.wav")
		return 
	end
	chat.AddText(unpack(t))
end

local mdllist 
local chosen_wsid
local tried_mounting
local mount_path
local chosen_mdl

function UICancelAll()
	UIMsg"Unsetting everything"
	
	mdllist = nil
	chosen_wsid = nil
	mount_path = nil
	tried_mounting = nil
	chosen_mdl = nil
	
	RemoveOutfit()
end

function UIBroadcastMyOutfit(mdl)
	BroadcastMyOutfit(mdl,chosen_wsid)
end

function UIChangeModelToID(n)
	
	dbg("UIChangeModelToID",n)
	
	if co.make(n) then return end
	
	if not chosen_wsid then
		return UIError"Type only !outfit first to choose workshop addon"
	end
	if not mdllist or #mdllist==0 then
		return UIError"No models to choose from"
	end
	local mdl = mdllist[n]
	if not mdl then
		return UIError"Invalid model index"
	end
	
	local alreadymounted = WasAlreadyMounted(chosen_wsid)
	local ok
	if alreadymounted~=nil then
		ok = alreadymounted
	else
		assert(mount_path,"mount_path missing for "..tostring(chosen_wsid))
		ok = coMountWS( mount_path )
	end
	if not ok then
		return UIError"The workshop addon could not be mounted"
	end
	
	assert(mdl.Name)
	
	OnChangeOutfit(LocalPlayer(),mdl.Name,chosen_wsid)
	
	notification.AddLegacy( "Outfit changed!", NOTIFY_UNDO, 2 ) 
	surface.PlaySound( "buttons/button15.wav" )
	UIMsg"Write '!outfit send' to send this outfit to everyone"
	
end

function MDLToUI(s)
	if not s then return s end
	if #s==0 then return s end
	s=s:gsub("^models/player/","")
	s=s:gsub("^models/","")
	  
	s=s:gsub("_([a-z])",function(a) return ' '..a:upper() end)
	s=s:gsub("_"," ")
	  
	s=s:gsub("%.mdl","")
	  
	s=s:gsub("/([a-z])",function(a) return '/'..a:upper() end)
	
	local a,b = s:match'^(.+)/(.-)$'
	if b then
		s = ('%s ( %s )'):format(b,a)
	end
	
	s=s:gsub("/",", ")
	
	return s
end

function UIChoseWorkshop(wsid)
	if co.make(wsid) then return end
	
	mdllist = nil
	chosen_wsid = nil
	mount_path = nil
	tried_mounting = nil
	chosen_mdl = nil
	
	SetUIFetching(wsid,true)
	co.sleep(.5)
	local path,err = coFetchWS( wsid ) -- also decompresses
	co.sleep(.2)
	SetUIFetching(wsid,false)
	if not path then
		dbg("UIChoseWorkshop",wsid,"fail",err)
		return UIError("Download failed for workshop "..wsid..": "..tostring(err~=nil and tostring(err) or GetLastMountErr and GetLastMountErr()))
	end
	co.sleep(.2)
	local mdls,err = GMAPlayerModels( path )
	if not mdls then
		dbge("UIChoseWorkshop","GMAPlayerModels",wsid,"fail",err)
		return UIError("Parsing workshop addon "..wsid.." failed: "..tostring(err))
	end
	if not mdls[1] then
		dbge("UIChoseWorkshop","GMAPlayerModels",wsid,"no models!?")
		return UIError("Workshop addon "..wsid.." has no playermodels")
	end
	
	co.sleep(.2)
	
	if mdls[2] then
		UIMsg("Models:")
		for k,mdl in next,mdls do
			UIMsg(" "..k..". "..tostring(mdl and MDLToUI(mdl.Name)))
		end
	else
		UIMsg("Got model: "..tostring(MDLToUI(mdls[1].Name)))
	end
	
	chosen_wsid = wsid
	mdllist = mdls
	mount_path = path
	
	if mdls[2] then
		UIMsg"Write !outfit <model number> to choose a model"
	else
		UIChangeModelToID(1)
	end
	
end
