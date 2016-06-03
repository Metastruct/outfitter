-- coroutine workshop --

local Tag='outfitter' 
module(Tag,package.seeall)

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
				dbgn(3,"FileInfo",wsid,"Disabled?")
			end
			if installed then
				dbgn(3,"FileInfo",wsid,"installed?")
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

	if not file.Exists(path,'MOD') then
		return SYNC(dat,cantmount(wsid,"file"))
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
	
	local crashed = DidCrash("mountws",path)
	if crashed then return nil,"crashed" end

	local TIME = SysTime()
	dbg("MountGMA",path)
	CRITICAL("mountws",path)
	local ok, files = game.MountGMA( path )
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
		
local worker,cache = co.work_cacher(_coMountWS)
coMountWS = co.worker(worker)


--TODO: own cache
function NeedWS(wsid,pl,mdl)
	if co.make(wsid,pl,mdl) then return end
	
	SetUIFetching(wsid,true)
	
		co.sleep(.1)
		
		local path,err,err2 = coFetchWS( wsid ) -- also decompresses
		
		co.sleep(1)
		
	SetUIFetching(wsid,false,not path and (err and tostring(err) or "FAILED?"))
	
	if not path then
		dbg("NeedWS",wsid,"fail",err)
		return nil,err or "fetchws"
	end
	
	local ok,err = GMABlacklist(path)
	if not ok then
		dbge("NeedWS","GMABlacklist",wsid,"->",err)
		return
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
	
	local ok,err = coMountWS( path )
	
	if not ok then
		dbg("NeedWS",wsid,"mount fail",err)
		return nil,err or "mount"
	end
	
	return true
	
end
	