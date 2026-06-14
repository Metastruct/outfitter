local Tag = 'custombrowser'
-- javascript hacks
local fixselect = [[
(function() {
if (document.getElementsByTagName("select").length>0) {

    if (!window.jQuery) {
        var script = document.createElement("SCRIPT");
        script.src = 'https://ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min.js';
        script.type = 'text/javascript';
        document.getElementsByTagName("head")[0].appendChild(script);
    }
    var checkReady = function(callback) {
        if (window.jQuery) {
            callback(jQuery);
        } else {
            window.setTimeout(function() {
                checkReady(callback);
            }, 100);
        }
    };

    checkReady(function($) {

        (function($) {
            console.log("loaded jquery");
            var script = document.createElement("SCRIPT");
            script.src = 'https://cdnjs.cloudflare.com/ajax/libs/select2/4.0.0-rc.2/js/select2.min.js';
            script.type = 'text/javascript';
            document.getElementsByTagName("head")[0].appendChild(script);


            var head = document.getElementsByTagName('head')[0];
            var link = document.createElement('link');
            link.rel = 'stylesheet';
            link.type = 'text/css';
            link.href = 'https://cdnjs.cloudflare.com/ajax/libs/select2/4.0.0-rc.2/css/select2.min.css';
            link.media = 'all';
            head.appendChild(link);

            var checkReady = function(callback) {
                if ($.fn.select2 == null) {
                    window.setTimeout(function() {
                        checkReady(callback);
                    }, 100);
                } else {
                    callback();
                }
            };

            checkReady(function() {
                console.log("loaded select2");
                $('select').select2();
                console.log("injected select replacement");
            });
        })($);



    });

};

})();

]]
local PANEL = {}

function PANEL:Init()
	self.firstload = true
	self:SetVisible(false)
	self:SetSize(ScrW() * 0.9, ScrH() * 0.8)
	self:Center()
	self:SetTitle("Web Browser")
	self:SetDeleteOnClose(false)
	self:ShowCloseButton(true)
	self:SetDraggable(true)
	self:SetSizable(true)

	if self.btnMinim then
		self.btnMinim:SetDisabled(false)

		self.btnMinim.DoClick = function()
			self:SetVisible(false)
		end
	end

	if self.btnMaxim then
		self.btnMaxim:SetDisabled(false)

		self.btnMaxim.DoClick = function()
			self:SetSize(ScrW(), ScrH())
			self:Center()
		end
	end

	local top = vgui.Create("EditablePanel", self)
	self.top = top
	top:Dock(TOP)
	top:SetTall(24)
	local PreviousIcon = "icon16/arrow_left.png"
	local NextIcon = "icon16/arrow_right.png"
	local btn = vgui.Create("DButton", self.top)
	btn:SetText("")
	btn:SetSize(24, 24)
	btn:SetIcon(PreviousIcon)
	btn:Dock(LEFT)

	function btn.DoClick()
		self.browser:GoBack()
		--self.browser:RunJavascript[[history.back();]]
	end

	local btn = vgui.Create("DButton", self.top)
	btn:SetText("")
	btn:SetSize(24, 24)
	btn:SetIcon(NextIcon)
	btn:Dock(LEFT)

	function btn.DoClick()
		self.browser:GoForward()
		--self.browser:RunJavascript[[history.forward();]]
	end

	local entry = vgui.Create("DTextEntry", top)
	self.entry = entry
	entry:Dock(FILL)
	entry:SetTall(24)

	function entry.OnEnter(entry)
		local val = entry:GetText()
		local js, txt = val:match("javascript:(.+)")

		if js and txt then
			self.browser:QueueJavascript(txt)

			return
		end

		self:OpenURL(val)
		self.browser:RequestFocus()
	end

	local btn = vgui.Create("DButton", self.top)
	btn:SetText("")
	btn:SetSize(24, 24)
	btn:Dock(LEFT)

	function btn.DoClick()
		if self.browser:IsLoading() then
			self.browser:StopLoading()
		else
			self.browser:Refresh(true) --RunJavascript[[location.reload(true);]]
		end
	end

	local RefreshIcon = Material("icon16/arrow_refresh.png")
	local CancelIcon = Material("icon16/cross.png")

	btn.Paint = function(btn, w, h)
		DButton.Paint(btn, w, h)

		if not self.browser:IsLoading() then
			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(RefreshIcon)
			surface.DrawTexturedRect(btn:GetWide() / 2 - 16 / 2, btn:GetTall() / 2 - 16 / 2, 16, 16)
		else
			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(CancelIcon)
			surface.DrawTexturedRect(btn:GetWide() / 2 - 16 / 2, btn:GetTall() / 2 - 16 / 2, 16, 16)
		end
	end

	local btn = vgui.Create("DButton", self.top)
	btn:SetText("")
	btn:SetSize(24, 24)
	btn:SetIcon("icon16/script_gear.png")
	btn:Dock(RIGHT)

	function btn.DoClick()
		self.browser:RunJavascript[[var s = document.documentElement.outerHTML; document.write('<html><body><textarea id="dsrc" style="width: 100%; height: 100%;"></textarea></body></html>');  var ta=document.getElementById( 'dsrc'); ta.value=s; void 0;]]
	end

	local browser = vgui.Create("DHTML", self)
	self.browser = browser
	browser:Dock(FILL)
	browser.Paint = function() end
	browser:SetFocusTopLevel(true)

	browser.OnChangeTitle = function(browser, title)
		self:SetTitle(title and title ~= "" and title or "Web browser")
	end

	browser.OnChangeTargetURL = function(browser, url)
		self:StatusChanged(url)
	end

	browser.OnChildViewCreated = print

	browser.OnBeginLoadingDocument = function(browser, url)
		self.loaded = false
		self.entry:SetText(url)
	end

	browser.OnFinishLoadingDocument = function(browser, url)
		self.loaded = true
	end

	browser.OnDocumentReady = function(browser, url)
		self:_InjectScripts(browser)

		if self.InjectScripts then
			self:InjectScripts(browser)
		end

		self.url = url
		self:LoadedURL(url)
		self.entry:SetText(url)
	end

	browser:AddFunction("gmod", "dbg", function(...)
		Msg"[Browser] "
		print(...)
	end)

	browser:AddFunction("console", "info", function(...)
		Msg"[Browser] "
		print(...)
	end)

	browser:AddFunction("gmod", "status", function(txt)
		if txt ~= "" then
			print("status", txt)
		end

		self:StatusChanged(txt)
	end)

	browser:AddFunction("gmod", "reqtoken", function()
		if not GetAuthToken then
			local s = ([[if ('OnAuthToken' in window) { OnAuthToken(false); };]])

			if browser:IsValid() and not browser:IsLoading() then
				browser:QueueJavascript(s)
			end

			return
		end

		Derma_Query("Do you want to send your auth token to this website?", "Auth Token", "Yes", function()
			GetAuthToken(function(dat)
				local s = ([[if ('OnAuthToken' in window) { OnAuthToken("%s"); };]]):format(string.JavascriptSafe(dat))

				if browser:IsValid() and not browser:IsLoading() then
					browser:QueueJavascript(s)
				end
			end)
		end, "No", function() end)
	end)

	browser.ActionSignal = function(...)
		Msg"[BrowserACT] "
		print(...)
	end

	browser.OnKeyCodePressed = function(browser, code)
		if code == KEY_F5 then
			self.browser:RunJavascript[[location.reload(true);]]

			return
		end
	end

	--print("BROWSERKEY",code)
	local status = vgui.Create("DLabel", self)
	self.status = status
	status:SetText""
	status:Dock(BOTTOM)
end

function PANEL:StatusChanged(txt)
	if self.statustxt ~= txt then
		self.statustxt = txt
		self.status:SetText(txt or "")
	end
end

function PANEL:LoadedURL()
end

function PANEL:OpenURL(url)
	self.browser:StopLoading()
	self.browser:OpenURL(url)
	self.entry:SetText(url)

	if self.firstload then
		self.firstload = nil
	end
end

function PANEL:Think(w, h)
	DFrame.Think(self, w, h)

	if input.IsKeyDown(KEY_ESCAPE) then
		if self.firstload then
			self:Close()
		else
			self:SetVisible(false)
		end

		if gui and gui.HideGameUI then
			gui.HideGameUI()
		end
	end

	if not self.wasloading and self.browser:IsLoading() then
		self.wasloading = true
	end

	if self.wasloading and not self.browser:IsLoading() then
		self.wasloading = false
	end
end

function PANEL:GetBrowser()
	return self.browser
end

function PANEL:_InjectScripts(browser)
	browser:QueueJavascript[[function alert(str) { console.log("Alert: "+str); }]]
	browser:QueueJavascript(fixselect)
	-- fix links and background transparency problems
	browser:QueueJavascript[[
		setTimeout(function() {
			document.documentElement.style.backgroundColor = 'white';
		}, 0);
		
		setTimeout(function() {
			  var elems = document.getElementsByTagName("a");
				for (var i = 0; i < elems.length; i++) {
					var dat = elems[i]['target'];
					if (dat == "_blank" || dat == "_parent"|| dat == "_top") {
						elems[i]['target'] = "_self";
					}
				}
		}, 0);
		
	]]
	browser:QueueJavascript[[
		function getLink() {
			gmod.status(this.href || "-");
		}
		function clickLink() {
			gmod.status("Loading...");
		}
		function killstatus() {
			gmod.status("");
		}
		var links = document.getElementsByTagName("a");
		for (i = 0; i < links.length; i++) {
			links[i].addEventListener('mouseover',getLink,false);
			links[i].addEventListener('mouseout',killstatus,false);
			links[i].addEventListener('click',clickLink,false);
		}

	]]
end

function PANEL:Show()
	if not self:IsVisible() then
		self:SetVisible(true)
		self:MakePopup()
		self:SetKeyboardInputEnabled(true)
		self:SetMouseInputEnabled(true)
	end

	if ValidPanel(self.browser) then
		self.browser:RequestFocus()
	end
	--hook.Run("OnContextMenuOpen")
	--print(self.browser.URL)
end

function PANEL:Close()
	self:SetVisible(false)
	self:Remove()
	--hook.Run("OnContextMenuClose")
end

vgui.Register(Tag, PANEL, "DFrame")
local webbrowser_panel

function _G.GetWebBrowserPanel()
	return webbrowser_panel
end

local function HidePanel()
	webbrowser_panel:Close()
end

local function ShowPanel(url)
	local new = false

	if not ValidPanel(webbrowser_panel) then
		new = true
		webbrowser_panel = vgui.Create(Tag)
		--_G.p=webbrowser_panel
	end

	webbrowser_panel:Show()

	if url and url ~= "" then
		webbrowser_panel:OpenURL(url)
	else
		if new then
			webbrowser_panel.entry:RequestFocus()
		end
	end

	return webbrowser_panel
end

local webbrowser_enabled = CreateClientConVar("webbrowser_enabled", "0", true, false, "Displays the glua_utilities webbrowser.")
local mediaurls = {"mp4"} -- File extensions that shouldn't be opened with ingame browser.
gui.OLDOpenURL = gui.OLDOpenURL or gui.OpenURL

function gui.OpenURL(url, useold)
	local extension = url:match(".+%.(.-)%s*$")
	if not webbrowser_enabled:GetBool() or useold or table.HasValue(mediaurls, extension) then return gui.OLDOpenURL(url) end
	local browser = ShowPanel(url)

	return browser.browser, browser
end

function gui.OpenURLIngame(url)
	local extension = url:match(".+%.(.-)%s*$")

	if table.HasValue(mediaurls, extension) then
		error"invalid url"
	end

	local browser = ShowPanel(url)

	return browser.browser, browser
end

local function webbrowser(a, b, c, line)
	local url = line:gsub('^%"', ""):gsub('%"$', "")
	ShowPanel(url)
end

concommand.Add("webbrowser_open", webbrowser, nil, "Opens the glua_utilities web browser.")
local webbrowser_f1_open = CreateClientConVar("webbrowser_f1_open", "0", true, false, "Allows F1 to open the glua_utilities web browser.")
local f1key = input.LookupKeyBinding(KEY_F1)

local rec

hook.Add("PlayerBindPress", 'webbrowser', function(pl, key, press)
	if key ~= f1key or not press or not webbrowser_f1_open:GetBool() then return end
	if rec then return end
	rec = true
	local ret = hook.Run("PlayerBindPress", pl, key, press)
	
	if ret then
		rec = false

		return ret
	end

	rec = false
	local forceurl = hook.Run("WebBrowserF1")
	
	if forceurl == false then return end
	
	ShowPanel(forceurl)
end)

local webbrowser = _G.webbrowserbutton or {}
_G.webbrowserbutton = webbrowser

function webbrowser:CreateContextMenuButton(iconlayout)
	local container = iconlayout:Add("DPanel")
	container:SetSize(128, 32)
	container.webbrowserbutton = true
	local txt = container:Add("DTextEntry")
	txt:SetPlaceholderText("Web Browser")
	txt:SetText""
	txt:Dock(FILL)

	txt.OnEnter = function()
		gui.OpenURLIngame(txt:GetText())
		txt:SetText""
	end

	local button = container:Add("DImageButton")
	button:SetImage("icon16/world_go.png")
	button:Dock(RIGHT)
	button:SetWidth(container:GetTall() - 8)
	button:DockMargin(4, 4, 4, 4)

	button.DoClick = function()
		gui.OpenURLIngame(txt:GetText())
	end

	return container
end

function webbrowser:GetContextMenuButton(iconlayout)
	local contextbutton = nil

	for i = 0, iconlayout:ChildCount() do
		local child = iconlayout:GetChild(i)

		if IsValid(child) and child.webbrowserbutton then
			contextbutton = child
			break
		end
	end

	return contextbutton
end

--forcefully removes it in case it fucks up
function webbrowser:RemoveContextMenuButton(iconlayout, buttonpanel)
	if IsValid(buttonpanel) then
		buttonpanel:Remove()
	end
end

function webbrowser:GetContextMenuLayout()
	if not IsValid(g_ContextMenu) then return end
	local iconlayout = nil

	for i = 0, g_ContextMenu:ChildCount() do
		local child = g_ContextMenu:GetChild(i)

		if IsValid(child) and child:GetName() == "DIconLayout" then
			iconlayout = child
			break
		end
	end

	return iconlayout
end

function webbrowser:HandleContextMenuButton(docleanup)
	local iconlayout = self:GetContextMenuLayout()
	if not IsValid(iconlayout) then return end
	local buttonpanel = self:GetContextMenuButton(iconlayout)

	if IsValid(buttonpanel) and docleanup then
		self:RemoveContextMenuButton(iconlayout, buttonpanel)
		iconlayout:InvalidateLayout()
	end

	if not IsValid(buttonpanel) then
		self:CreateContextMenuButton(iconlayout)
		iconlayout:InvalidateLayout()
	end
end

hook.Add("ContextMenuCreated", "webbrowserbutton", function()
	webbrowserbutton:HandleContextMenuButton(true)
end)
