
local Tag='coext'
if SERVER then AddCSLuaFile() end


if not co then require"co" end

local function http_wrap(ok,err,okerr,...)
	if okerr==ok then
		return true,...
	elseif okerr==err then
		return false,...
	else
		error"Invalid fetch callback called"
	end
end

function co.post(url,data,hdr)
	
	local ok,err = co.newcb(),co.newcb()
	http.Post(url,data,ok,err,hdr)
	
	return http_wrap(ok,err,co.waitone())

end

function co.fetch(url,hdr)
	
	local ok,err = co.newcb(),co.newcb()
	http.Fetch(url,ok,err,hdr)
	
	return http_wrap(ok,err,co.waitone())

end


co.PlayURL=function(url,params)
	local cb=co.newcb()
	sound.PlayURL(url,params or '',cb)
	return co.waitcb(cb)
end

co.PlayFile=function(url,params)
	local cb=co.newcb()
	sound.PlayFile(url,params or '',cb)
	return co.waitcb(cb)
end



-- server info query
-- TODO: Validate IP
do
	local cbs={}

	local _sinfo
	local function runcbs(entry,...)
		local ip,port = entry[1],entry[2]
		local callbacks = cbs[ip] and cbs[ip][port]
		
		if not callbacks then return end
		
		cbs[ip][port]=nil
		if not next(cbs[ip]) then
			cbs[ip]=nil
		end
		
		local ncallbacks = #callbacks
		for i=1,ncallbacks do
			local func = callbacks[i]
			local ok,err = xpcall(func,debug.traceback,...)
			if not ok then ErrorNoHalt(err..'\n') end
		end
	end

	local function sinfo()
		_sinfo = _sinfo or serverquery.getServerInfoWorker(function(ret,entry,err)
			--print(">",ret,entry,err)
			if ret then
				
				assert(entry,"entry missing??")
			
				runcbs(entry,entry)
				
				return
			end
			
			if ret==false then
				if entry==true then
					return -- worker started
				elseif entry==false then
					return --worker ended
				else
					-- error
					runcbs(entry,nil,err or "timeout",entry)
					
					return
					
				end
			end
		
			if err then
				ErrorNoHalt(tostring(err)..'\n')
			end
		end)
		return _sinfo
	end

	function co.serverinfo(ip,port)
		if not port then port=27015 end
		local a,b = ip:match'^(.+)%:(%d+)$'
		if b then
			ip,port = a,tonumber(b)
		end
		assert(not ip:find(":",1,true))
		assert(ip and port)
		
		local cb = co.newcb()
		
		cbs[ip] = cbs[ip] or {}
		cbs[ip][port] = cbs[ip][port] or {}
		local t = cbs[ip][port]
		t[#t+1]=cb
		
		sinfo().add_queue(ip, port)
		
		return co.waitcb(cb)
		
	end

	--co(function()
	--	print("1",co.serverinfo"195.154.166.219".name)
	--	print("2",co.serverinfo"195.154.166.219".name)
	--	print("7",co.serverinfo"46.174.53.218:27015".name)
	--	co(function()
	--		print("3",co.serverinfo"94.23.170.2".name)
	--		print("4",co.serverinfo"94.23.170.2".name)
	--	end)
	--	print("8",co.serverinfo"94.23.170.2".name)
	--end)
	--co(function()
	--	print("5",co.serverinfo"46.174.53.218:27015".name)
	--	print("6",co.serverinfo"46.174.53.218:27015".name)
	--end)
end


-- server players query
-- TODO: Validate IP
do

	local cbs={}

	local _sinfo
	local function runcbs(entry,...)
		local ip,port = entry[1],entry[2]
		local callbacks = cbs[ip] and cbs[ip][port]
		
		if not callbacks then return end
		
		cbs[ip][port]=nil
		if not next(cbs[ip]) then
			cbs[ip]=nil
		end
		
		local ncallbacks = #callbacks
		for i=1,ncallbacks do
			local func = callbacks[i]
			local ok,err = xpcall(func,debug.traceback,...)
			if not ok then ErrorNoHalt(err..'\n') end
		end
	end

	local function sinfo()
		_sinfo = _sinfo or serverquery.playerListFetcher(function(ret,entry,err)
			--print(">",ret,entry,err)
			if ret then
				
				assert(entry,"entry missing??")
			
				runcbs(entry,entry)
				
				return
			end
			
			if ret==false then
				if entry==true then
					return -- worker started
				elseif entry==false then
					return --worker ended
				else
					-- error
					runcbs(entry,nil,err or "timeout",entry)
					
					return
					
				end
			end
		
			if err then
				ErrorNoHalt(tostring(err)..'\n')
			end
		end)
		return _sinfo
	end

	function co.serverplayers(ip,port)
		if not port then port=27015 end
		local a,b = ip:match'^(.+)%:(%d+)$'
		if b then
			ip,port = a,tonumber(b)
		end
		assert(not ip:find(":",1,true))
		assert(ip and port)
		
		local cb = co.newcb()
		
		cbs[ip] = cbs[ip] or {}
		cbs[ip][port] = cbs[ip][port] or {}
		local t = cbs[ip][port]
		t[#t+1]=cb
		
		sinfo().add_queue(ip, port)
		
		return co.waitcb(cb)
		
	end

	--co(function()
	--	PrintTable(co.serverplayers"195.154.166.219")
	--end)
end

local function shuffle( t )
    local rand = math.random
    local iterations = #t
    local j
    
    for i = iterations, 2, -1 do
        j = rand(i)
        t[i], t[j] = t[j], t[i]
    end
end


function co.dns(a,b)
	local cb = co.newcb()
	b=b or 'A'
	http.ResolveDNS(a,b,cb)
	
	local ret,err = co.waitcb(cb)
	if not ret then return nil,err end
	if ret.errstr then
		return nil,ret.errstr,ret.errcode
	end
	if not ret[1] then
		return ret
	end
	
	shuffle(ret)
	for _,v in next,ret do
		if (b=='A' or b=='AAAA') and v.address then
			return v.address,ret
		elseif b=='TXT' and v.txt then
			return v.txt,ret
		elseif b~='A' and b~='AAAA' and v.address then
			return v.address,ret
		end
	end
	return true,ret
	
end
--[[
co(function()
	local ip = assert(co.dns("g1.metastruct.net"))
	PrintTable(assert(co.serverinfo(ip)))
end)
--]]








if not CLIENT then return end

function steamworks.coGetList(a,b,c,d,e,f)
	local cb = co.newcb()
	steamworks.GetList(a,b,c,d,e,f,cb)
	return co.waitcb(cb)
end


function steamworks.coFileInfo(a)
	local cb = co.newcb()
	steamworks.FileInfo(a,cb)
	return co.waitcb(cb)
end

function steamworks.coFileInfos(idlist)
	if not idlist[1] then return end
	local cb = co.newcb()
	local t = {}
	for _,id in next,idlist do
		t[id]=false
	end
	
	for id,state in next,t do
		steamworks.FileInfo(id,cb)
	end
	
	local any
	for id,state in next,t do
		local _,data = co.waitone(cb)
		if data then
			local id = data.id
			if nil == t[id] then
				print("WTF",id)
			else
				any = true
				t[id] = data
			end
			
		end
	end
	return any and t
end

function steamworks.coDownload( fileid, uncomp )
	local instant
	local path
	local cb = co.newcb()
	local function cb2(...)
		if instant==nil then
			path = ...
			instant = true
			return
		end
		return cb(...)
	end
	steamworks.Download( fileid, uncomp, cb2 )

	if instant==nil then
		instant = false
		path = co.waitcb(cb)
	end
	return path
end


function steamworks.coDownloadUGC( fileid )
	local instant
	local path,fd
	local cb = co.newcb()
	local function cb2(...)
		if instant==nil then
			path,fd = ...
			instant = true
			return
		end
		return cb(...)
	end
	steamworks.DownloadUGC( fileid, cb2 )

	if instant==nil then
		instant = false
		path,fd = co.waitcb(cb)
	end
	return path,fd
end



gameevent.Listen"player_disconnect"
local disconnected = {}
local waiters = {}

local function DoWaiters(userid,res)
	local t = waiters[userid]
	if not t then return end
	waiters[userid] = nil
	for i=1,#t do
		local callback = t[i]
		callback(res,not res and "disconnect" or nil)
	end
end

hook.Add("player_disconnect",Tag,function(t)
	local userid = t.userid
	disconnected[userid]= true
	DoWaiters(userid,false)
end)

local pl_to_userid = setmetatable({},{__mode='k'})
local function NetworkEntityCreated(pl)
	if pl:IsPlayer() then
		local userid = pl:UserID()
		pl_to_userid[pl]=userid or -1
		DoWaiters(userid,true)
	end
end

hook.Add("NetworkEntityCreated",Tag,NetworkEntityCreated)

function player.HasDisconnected(userid)
	if not isnumber(userid) then
		local usrid = pl_to_userid[pl]
		if usrid == nil then
			return nil,"invalid"
		end
		userid = usrid
	end
	assert(userid>=0)
	return disconnected[userid] or false
end

local localplayer
local OnLocalPlayer = util.OnLocalPlayer or function() end
OnLocalPlayer(function(ent)
	localplayer = ent or LocalPlayer()
end)

function co.wait_player(pl) -- or player
	
	if pl and pl:IsValid() then return true end
	
	assert(pl~=NULL)
	
	if not pl then
		if not localplayer then
			while not localplayer do
				co.waittick() -- TODO: hack
				localplayer = localplayer or (LocalPlayer():IsValid() and LocalPlayer())
			end
			pl = localplayer
			local userid = pl:UserID()
			pl_to_userid[pl]=userid
		else
			return nil,"invalidplayer"
		end
	end
	
	local userid = pl_to_userid[pl]
	if userid == nil then
		return nil,"invalid"
	end
	
	assert(userid>=0)
	
	local disconnected = player.HasDisconnected(userid)
	
	if disconnected then return false,"disconnected" end
	
	local t = waiters[userid] if t==nil then t = {} waiters[userid] = t end
	
	local cb = co.newcb()
	t[#t+1]=cb
	
	return co.waitcb(cb)
	
end

local function inv_1(a,...)
	return not a,...
end

co.waitpl = function(...)
	return inv_1(co.wait_player(...))
end


-- steam nicks fetching

local bad = '[unknown]'
local noexist = '< blank >'
local function GetPlayerName(sid64)
	local ret = steamworks.GetPlayerName(sid64)
	if ret == noexist then
		return nil,'profile'
	end
	if ret == bad then
		return nil,'request'
	end
	if not ret or ret=="" then
		return nil,'invalid'
	end
	return ret
end

function co.steamnick(sid64,timeout)
	local res,err = GetPlayerName(sid64)
	if res or (err and err ~= 'request') then return res,err end
	
	steamworks.RequestPlayerInfo(sid64)
	
	for i=0,timeout or 10,0.2 do
		local res,err = GetPlayerName(sid64)
		if res or (err and err ~= 'request') then return res,err end
		co.sleep(0.2)
	end
	return nil,'timeout'
end


function co.steamnick_promise(sid64)
	local res,err = GetPlayerName(sid64)
	if res or (err and err ~= 'request') then return function() return res,err end end
	
	steamworks.RequestPlayerInfo(sid64)
	
	return function(timeout)
		for i=0,timeout or 10,0.2 do
			local res,err = GetPlayerName(sid64)
			if res or (err and err ~= 'request') then return res,err end
			co.sleep(0.2)
		end
		return nil,'timeout'
	end
end

--[[ testing
co(function()
	local sid = LocalPlayer():SteamID64()
	local nick,err = co.steamnick(sid)
	print("me",sid,"\n\t",('%q'):format(tostring(nick)),err)
	
	local sid = tostring(os.time()%99999)
	local nick,err = co.steamnick(sid)
	print("invalidsid",sid,"\n\t",('%q'):format(tostring(nick)),err)
	local sid = '76561198599860287'
	local nick,err = co.steamnick(sid)
	print("noprofile",sid,"\n\t",('%q'):format(tostring(nick)),err)
	local sid = table.Random(player.GetHumans()):SteamID64()
	local nick,err = co.steamnick(sid)
	print("rndplayer",sid,"\n\t",('%q'):format(tostring(nick)),err)
	local sid = '76561197960287930'
	local nick,err = co.steamnick(sid)
	print("gaben",sid,"\n\t",('%q'):format(tostring(nick)),err)
	local t={}
	for i=1,4 do
		local sid = "76561".. math.random(197960265730,201356655932)
		t[i]={sid,co.steamnick_promise(sid)}
	end
	for i=1,#t do
		local sid,promise = t[i][1],t[i][2]
		print("promise"..i,sid,"\n\t",promise())
	end
end)
--]]
