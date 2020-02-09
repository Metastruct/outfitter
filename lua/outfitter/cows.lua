-- coroutine workshop --

local Tag='outfitter'
module(Tag,package.seeall)

function IsUGCFilePath(path)
	return path:find("^.:") or path:find("^[%\\%/]") or false
end

-- External decompression helper (nerfed by http.Fetch)

local outfitter_disable_decompress_helper = CreateClientConVar("outfitter_disable_decompress_helper",'1',true)
if not outfitter_disable_decompress_helper:GetBool() then 
	file.Write("decomp_in_steamworks.dat",'INIT')
end
local has_decompress_helper
function HasDecompressHelper()
	if outfitter_disable_decompress_helper:GetBool() then return false end
	return os.time()-(file.Time("of_dchelper.dat",'DATA') or 0)<120
end
---------------------------------



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

local function steamworks_Download( fileid )
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
	steamworks.DownloadUGC( fileid, cb2 )
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

local function cantmount(wsid,reason,...)
	fetching[wsid] = false
	res[wsid] = reason or "failed?"
	if reason~='oversize' or outfitter_maxsize:GetInt()==60 then
		dbgelvl(2,"FetchWS","downloading",wsid,"failed for",reason,...)
	end
	
	lme= reason or "?"
	lwsid=wsid
	return false,reason
end

do -- steamworks fileinfo worker
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


do -- steam webapi fileinfo worker
	-- TODO: conversion to FileInfo and combination interface and aggregator?t

	local conv = {
		[""] = "size",
		[""] = "banned",
		[""] = "id",
		[""] = "previewid",
		[""] = "disabled",
		[""] = "installed",
		[""] = "previewsize",
		[""] = "owner",
		[""] = "fileid",
		[""] = "title",
		[""] = "ownername",
		[""] = "tags",
		
		[""] = "updated",
		[""] = "created",
		[""] = "description",
	}

	local function intFileInfo(wsid)
		local url = "http://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1"
		local dat = {
			itemcount = "1",
			['publishedfileids[0]']=tostring(wsid)
		}
		
		local retok,dat, len, hdr, ok = co.post(url,dat)
		
		if not retok then return nil,dat end
		if ok ~= 200 then return nil,tostring(ok) end
		
		local fileinfo = util.JSONToTable(dat)
		
		if not fileinfo then return nil,'json' end
		fileinfo = fileinfo.response
		
		if not fileinfo then return nil,'response' end
		if fileinfo.result and fileinfo.result~=1 then return false,tostring(fileinfo.result) end
		if fileinfo.resultcount == 0 then return false,'noresults' end

		fileinfo=fileinfo and fileinfo.publishedfiledetails
		fileinfo=fileinfo and fileinfo[1]

		
		if not fileinfo then return false,'fileinfo' end
		if fileinfo.result~=1 then return false,'fileinforesult' end

		do return fileinfo end
		
		local cb = co.newcb()
			steamworks.FileInfo(wsid,cb)
		local fileinfo = co.waitcb(cb)
		
		return fileinfo
	end
	local worker,cache = co.work_cacher_filter(
		function(key,fileinfo)
			return (not key) or fileinfo
		end,
		
		co.work_cacher(intFileInfo)
		)
	co_steamworks_FileInfo2 = co.worker(worker)

	--co(function()
	--	local ret,err = steamworks.coFileInfoX(569576795)
	--	if not ret then ErrorNoHalt(tostring(err)..'\n') end
	--	PrintTable(ret)
	--end)

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
	
	local isdbg = isdbg()
	
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
			local created = os.time() - (fileinfo.created or 0)
			
			dbg("","created ago",string.NiceTime(created))
			
			--TODO: Check banned
			--TODO: Check popularity before mounting
			
			local banned = fileinfo.banned
			local installed = fileinfo.installed
			local disabled = fileinfo.disabled
			if banned then
				dbge(wsid,"BANNED!?")
				return SYNC(dat,cantmount(wsid,"banned"))
			end
			if created<60*60*24*7 then
				dbg(wsid,"WARNING: ONE WEEK OLD ADDON. NOT ENOUGH TIME FOR WORKSHOP MODERATORS.")
			end
			if disabled then
				dbgn(3,"FileInfo",wsid,"Disabled?")
			end
			if installed then
				dbgn(3,"FileInfo",wsid,"installed?")
			end
		end
	end
	
	if not fileinfo or not fileinfo.title then
		return SYNC(dat,cantmount(wsid,"fileinfo"))
	end
	
	local maxsz = outfitter_maxsize:GetFloat()
	maxsz = maxsz*1000*1000
	
	if maxsz>0.1 and (fileinfo.size or 0) > maxsz then
		skip_maxsize = skip_maxsize or skip_maxsizes[wsid]

		dbg("FetchWS","MAXSIZE",skip_maxsize and "OVERRIDE" or "",wsid,string.NiceSize(fileinfo.size or 0))
		
		if not skip_maxsize then
			return SYNC(dat,cantmount(wsid,"oversize"))
		end
	end
		
	co.wait(.3)
	
	local decomp_in_steamworks = true --not HasDecompressHelper()
	
	local TIME = isdbg and SysTime()
	local path = steamworks_Download( wsid )
	if isdbg then dbg("Download",wsid,"to",path or "<ERROR>","took",SysTime()-TIME) end
	
	assert(path~=true)
	
	if not path then
		return SYNC(dat,cantmount(wsid,"download"))
	end
	
	if not IsUGCFilePath(path) and not file.Exists(path,'MOD') then
		return SYNC(dat,cantmount(wsid,"file"))
	end
	
	if not decomp_in_steamworks then
		local err
		path,err = coDecompress(path)
		if not path then
			return SYNC(dat,cantmount(wsid,'decompress'))
		end

		if not IsUGCFilePath(path) and not file.Exists(path,'MOD') then
			dbg(path,"IsUGCFilePath",IsUGCFilePath(path),"file.Exists",file.Exists(path,'MOD'))
			return SYNC(dat,cantmount(wsid,"file"))
		end
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

function MountWS( path )
	
	--TODO: Check blacklist
	--[[ TODO: 	think I found a fix
				if something mounts fine once
				it gets whitelisted
		]]

	assert(path,'no file given')
	local crashed = DidCrash("mountws",path)
	
	dbg("MountWS",path,crashed and "CRASHED, BAILING OUT")
	
	if crashed then return nil,"crashed" end
	
	local TIME = SysTime()
	CRITICAL("mountws",path)
	local ok, files = MountGMA( path )
	CRITICAL(false)
	local took = SysTime() - TIME
	if isdbg() then dbg("MountGMA",path,"took",math.Round(took*1000)..' ms') end

	result = ok or false
	return result,files,took
end

local function _coMountWS(path)
	UIMounting(true)
	co.sleep(.3)
		local res,files,took = MountWS( path )
	UIMounting(false)
	co.sleep(math.Clamp((took or 0)*2.4,.2,2))
		
	return res,files,took
end
local worker,cache = co.work_cacher_filter(
	function(key,ok)
		return (not key) or ok
	end,
	co.work_cacher(_coMountWS) 
)
coMountWS = co.worker(worker)




function _coDecompressExt(path)
	if not HasDecompressHelper() then return nil,'no helper' end
	if not path then return nil,'invalid parameter' end
	dbgn(2,"coDecompressExt",path)
	
	local ok,data,len,hdr,code = co.post('http://localhost:27099/decompress',{
		file = path
	})
	
	if not ok or code~=200 then
		has_decompress_helper = false
		dbge("_coDecompressExt",data,code)
		return nil,data
	end
	
	
	if code ~= 200 then
		dbge(data)
		return nil,'idk'
	end
	
	local resultpath = path..'.decompressed'
	local ex = file.Exists(resultpath,'GAME')
	if not ex then dbge("coDecompress","File not found",path,'->',resultpath) return nil,'missing decompress' end
	return resultpath
end

-- TODO rework if even needed anymore
function coDecompress(path)
	if not path then return nil,'invalid parameter' end
	if IsUGCFilePath(path) then return nil,'new workshop file' end
	
	dbgn(2,"coDecompress",path)
	
	local ok,ret = _coDecompressExt(path)
	if ok then return ok,ret end
	
	local safepath = path:gsub("%.cache$",".dat")
	if not file.Exists(safepath,'DATA') then

		file.CreateDir("cache",'DATA')
		file.CreateDir("cache/workshop",'DATA')
		
		dbgn(2,'coDecompress','finished collecting 1',coMinimizeGarbage())
		
		local data = file.Read(path,'GAME')				co.sleep(.3)
		if not data then dbge("coDecompress","File Read",path) return nil,'read' end
		
		local decomp_in_steamworks,err = util.Decompress(data) data = nil	co.sleep(.3)
		if not decomp_in_steamworks then dbge("coDecompress","LZMA Decompress",path,err or "failed :(") return nil,'decompress' end
		local sz = #decomp_in_steamworks
		
		file.Write(safepath,decomp_in_steamworks)	decomp_in_steamworks = nil 		co.sleep(.3)
		
		dbgn(2,'coDecompress','finished collecting 2',coMinimizeGarbage())
		
		if file.Size('data/'..safepath,'GAME')~=sz then 
			dbge("coDecompress","LZMA Decompress SZ",
				file.Size('data/'..safepath,'GAME') or "FILE NO EXIST?",
				sz,path,safepath) 
			return nil,'decompress' 
		end
		
		co.sleep(.2)
	end
	
	return 'data/'..safepath
end

--TODO: own cache
function NeedWS(wsid,pl,mdl)
	if co.make(wsid,pl,mdl) then return end
	
	-- already mounted, don't mount again
	if steamworks.IsSubscribed(wsid) and file.Exists(mdl,'GAME') then return true end
	
	SetUIFetching(wsid,true)
	
		co.sleep(.1)
		
		local path,err,err2 = coFetchWS( wsid ) -- also decompresses
		
		co.sleep(1)
		
	SetUIFetching(wsid,false,not path and (err and tostring(err) or "FAILED?"))
	
	if not path then
		if err~='oversize' then
			dbge("NeedWS",wsid,"fail",err,err2)
		end
		return nil,err or "fetchws",err2
	end
	
	local ok,err = GMABlacklist(path)
	if not ok and err=='notgma' and TestLZMA(path) then
		local newpath,err = coDecompress(path)
		if not newpath then
			dbge("NeedWS",wsid,"fail",err)
			return nil,err or "decompress"
		end
		path = newpath
		
		-- retry --
		ok,err = GMABlacklist(path)
		-----------
	end
	
	if not ok then
		dbge("NeedWS","GMABlacklist",wsid,"->",err)
		return
	end
	
	local mdls,extra,errlist = GMAPlayerModels(path)
	
	if not mdls then
		dbge("NeedWS","GMAPlayerModels",wsid,"fail",extra)
		return false,"mdlparse",extra
	end
	
	if not mdls[1] then
		dbge("NeedWS","GMAPlayerModels",wsid,"has no models")
		return false,"nomdls"
	end
	
	local has = not mdl
	if not has then
		has = extra.playermodels[mdl] or extra.hands[mdl]
		if not has then
			-- TODO: Make enforced
			local bad = extra.potential[mdl] or extra.discards[mdl]
			if bad then
				dbge("NeedWS",wsid,path,"requested mdl was discarded",mdl)
--			elseif GMAHasFile()
			else
				dbge("NeedWS",wsid,path,"missing requested mdl",mdl)		
			end
			
		end
	end
	
	local ok,err = coMountWS( path )
	
	if not ok then
		dbg("NeedWS",wsid,"mount fail",err)
		return nil,err or "mount"
	end
	
	return true
	
end


function GetQueryUGCChildren(workshopid)
	local ok,ret,len,hdrs,retcode = co.fetch("http://steamcommunity.com/sharedfiles/filedetails/?id="..workshopid)
	if not ok then return nil,ret end
	if retcode==404 then return false end
	if retcode~=200 then return nil,retcode,ret end
	
	local _,posa = ret:find('id="RequiredItems">',1,true)
	if not posa then 
		if ret:find('publishedfileid',1,true) then
			return {} -- probably just no require items
		end
		if ret:find("store.steampowered.com",1,true) then
			return false -- 404
		end
		return nil,"internal error: steam format changed"
	end
	
	local posb
	for i=0,6 do
		local _,new_posb = ret:find('<div class="requiredItem">',posb or posa,true)
		if not new_posb then break end
		posb = new_posb
	end
	if not posb then return nil,"internal error: format changed" end
	
	local t = {}
	for id in ret:sub(posa,posb):gmatch'id%=(%d+)' do
		t[#t+1]=id
	end
	return t
end

--[[
co(function()
	Msg"no children:"
	PrintTable(GetQueryUGCChildren '1100368137') 
	Msg"1 children:"
	PrintTable(GetQueryUGCChildren '848953556') 
	Msg"2 children:"
	PrintTable(GetQueryUGCChildren '918084741') 
	Msg"no exist:"
	PrintTable(GetQueryUGCChildren '123')
end)

no children:{
}
1 children:{
	[1] = "757604550",
}
2 children:{
	[1] = "757604550",
	[2] = "775573383",
}
no exist:false
]]