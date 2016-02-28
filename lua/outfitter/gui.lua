local Tag='outfitter' 
local NTag = 'OF'

module(Tag,package.seeall)

local mounting
function UIMounting(yes)
	mounting = is
	if is then
		notification.AddProgress( Tag, 
			"Mounting outfitter outfit!" )
	else
		notification.Kill( Tag )
	end
end


function SetUIFetching(wsid,is)
	if is then
		notification.AddProgress( Tag..wsid, 
			"Downloading "..wsid )
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

hook.Add("ChatCommand",Tag,function(com,paramstr,v1)
	com = com:lower()
	
	if com=="outfit" then
		local n = v1 and tonumber(v1:Trim())
		v1=v1 and v1:lower():Trim()
		
		if n then
			UIChangeModelToID(n)
		elseif v1 == "apply" or v1=='aply' or v1=='a' or v1 == "send" or v1=='snd' or v1=='s'  then
			UIBroadcastMyOutfit()
		elseif v1 == "cancel" or v1=='c' or v1=='canecl' then
			UICancelAll()
		else
			GUIWantChangeModel()
			--UIError"Invalid command"
		end
		
	elseif com==Tag then
		local n = v1 and tonumber(v1)
		if n then
			UIChoseWorkshop(n)
		end
	end
	
end)

CWHITE = Color(255,255,255,255)
CBLACK = Color(0,0,0,0)
function UIError(...)
	local t= {Color(200,50,10),'[Outfitter Err] ',CWHITE,...}
	chat.AddText(unpack(t))
end

function UIMsg(...)
	local t= {Color(50,200,10),'[Outfitter] ',CWHITE,...}
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
	
	LocalPlayer():EnforceModel(false)
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
	
	OnChangeOutfit(LocalPlayer(),mdl.Name,wsid)
	
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
		for k,mdl in next,mdls do
			UIMsg("Models:")
			UIMsg(" "..k..". "..mdl)
		end
	else
		UIMsg("Got model: "..tostring(mdls[1].Name))
	end
	
	chosen_wsid = wsid
	mdllist = mdls
	mount_path = path
	
	if mdls[2] then
		UIMsg"Write !outfit <model number> to choose model"
		UIMsg"Finally, write '!outfit send' to send the chosen model to everyone or !outfit cancel to cancel"
	else
		UIChangeModelToID(1)
		UIMsg"Write !outfit send to send this outfit to everyone"
	end
	
end

-- GUIWantChangeModel
	local PANEL = {}
	function PANEL:Init()
		local b = vgui.Create('DButton',self.top,'choose button')
			
			self.chooseb = b
			b:Dock(RIGHT)
			b:SetIcon("icon16/eye.png")
			b:SetText"CHOOSE THIS WORKSHOP ADDON"
			b:SizeToContents()
			b:SetWidth(b:GetSize()+32)
			b:SetEnabled(false)
			b.DoClick=function(b,mc)
				self:WSChoose()
			end
			self:GetBrowser():AddFunction( "gmod", "wssubscribe", function() self:WSChoose() end )
			
	end

	function PANEL:WSChoose()
		self:Hide()
		if self.chosen_id then
			UIChoseWorkshop(self.chosen_id)
		end
	end
	function PANEL:LoadedURL(url,title)
		self.BaseClass.LoadedURL(self,url,title)
		if not url or url=="" then return end
		
		-- sharedfiles/filedetails/?id=422403917&searchtext=playermodel


		local id = url:match'://steamcommunity.com/sharedfiles/filedetails/.*[%?%&]id=(%d+)'
		self.chooseb:SetEnabled(id and true or false)
		self.chosen_id = tonumber(id)
		print(id)
	end
	
	function PANEL:InjectScripts(browser)
		--dbg("Injecting browser code",browser or "NOBROWSER")
		browser:QueueJavascript[[
		
			function SubscribeItem() {
				gmod.wssubscribe();
			};
			
			setTimeout(function() {
				function SubscribeItem() {
					gmod.wssubscribe();
				};
			
				var sub = document.getElementById("SubscribeItemOptionAdd"); 
				if (sub) {
					sub.innerText = "Select";
				};
			}, 0);
			
		]]
	end
	
	function PANEL:Think()
		self.BaseClass.Think(self)
		--print(self.LoadedURL)
	end
	vgui.Register(Tag,PANEL,'custombrowser')

	m_vModelDlg = NULL
	function GUIWantChangeModel()
		if ValidPanel(m_vModelDlg) then
			m_vModelDlg:Show()
			return m_vModelDlg
		end
		
		local d = vgui.Create(Tag,nil,Tag)
		m_vModelDlg = d
		
		
		d:Show()
		d:OpenURL'http://steamcommunity.com/workshop/browse/?appid=4000&searchtext=playermodel&childpublishedfileid=0&browsesort=trend&section=readytouseitems&requiredtags%5B%5D=Model'
		return d
	end
