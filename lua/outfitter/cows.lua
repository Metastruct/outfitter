-- coroutine workshop --

local Tag='outfitter'
module(Tag,package.seeall)



-- External decompression helper
local outfitter_decompress_ext = CreateClientConVar("outfitter_decompress_ext",'0',true)
local has_decompress_helper
if outfitter_decompress_ext:GetInt()>0 then
	http.Fetch("http://localhost:27099",function(data,len,hdr,code)
		has_decompress_helper = code==200
		if has_decompress_helper then
			dbg('We have external helper!')
		end
	end,function() end)
end
function HasDecompressHelper()
	return outfitter_decompress_ext:GetInt()>0 and (has_decompress_helper or outfitter_decompress_ext:GetInt()==2)
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
			end
			if created<60*60*24*7 then
				dbge(wsid,"ONE WEEK OLD ADDON")
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
	
	local decomp = not HasDecompressHelper()
	
	local TIME = isdbg and SysTime()
	local path = steamworks_Download( fileinfo.fileid, decomp )
	if isdbg then dbg("Download",wsid,"to",path or "<ERROR>","took",SysTime()-TIME) end
	
	assert(path~=true)
	
	if not path then
		return SYNC(dat,cantmount(wsid,"download"))
	end

	if not file.Exists(path,'MOD') then
		return SYNC(dat,cantmount(wsid,"file"))
	end
	
	if not decomp then
		local err
		path,err = coDecompress(path)
		if not path then
			return SYNC(dat,cantmount(wsid,'decompress'))
		end

		if not file.Exists(path,'MOD') then
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


	local crashed = DidCrash("mountws",path)
	
	dbg("MountWS",path,crashed and "CRASHED, BAILING OUT")
	
	if crashed then return nil,"crashed" end
	
	local TIME = SysTime()
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
local worker,cache = co.work_cacher_filter(
	function(key,ok)
		return (not key) or ok
	end,
	co.work_cacher(_coMountWS) 
)
coMountWS = co.worker(worker)




function _coDecompressExt(path)
	if not path then return nil,'invalid parameter' end
	dbgn(2,"coDecompressExt",path)
	
	local ok,data,len,hdr,code = co.post('http://localhost:27099/decompress',{
		file = path
	})
	
	if not ok then
		has_decompress_helper = false
		return coDecompress(path)
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

function coDecompress(path)
	if not path then return nil,'invalid parameter' end
	dbgn(2,"coDecompress",path)
	if HasDecompressHelper() then
		return _coDecompressExt(path)
	end
	
	local safepath = path:gsub("%.cache$",".dat")
	if not file.Exists(safepath,'DATA') then

		file.CreateDir("cache",'DATA')
		file.CreateDir("cache/workshop",'DATA')
		
		for i=1,2048 do
			--print(math.ceil(i^2))
			if collectgarbage('step',math.ceil(i^2)) then dbgn(2,'coDecompress','finished collecting 1') break end
			co.waittick()
		end
		
		local data = file.Read(path,'GAME')				co.sleep(.3)
		if not data then dbge("coDecompress","File Read",path) return nil,'read' end
		
		local decomp,err = util.Decompress(data) data = nil	co.sleep(.3)
		if not decomp then dbge("coDecompress","LZMA Decompress",path,err or "failed :(") return nil,'decompress' end
		local sz = #decomp
		
		file.Write(safepath,decomp)	decomp = nil 		co.sleep(.3)
		
		for i=1,2048 do
			--print(math.ceil(i^2))
			if collectgarbage('step',math.ceil(i^2)) then dbgn(2,'coDecompress','finished collecting 2') break end
			co.waittick()
		end
		
		
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
	
	SetUIFetching(wsid,true)
	
		co.sleep(.1)
		
		local path,err,err2 = coFetchWS( wsid ) -- also decompresses
		
		co.sleep(1)
		
	SetUIFetching(wsid,false,not path and (err and tostring(err) or "FAILED?"))
	
	if not path then
		dbge("NeedWS",wsid,"fail",err)
		return nil,err or "fetchws"
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
	
	local mdls,extra = GMAPlayerModels(path)
	
	if not mdls then
		dbge("NeedWS","GMAPlayerModels",wsid,"fail",extra)
		return false,"mdlparse",extra
	end
	
	if not mdls[1] then
		dbge("NeedWS","GMAPlayerModels",wsid,"has no models")
		return false,"nomdls"
	end
	
	local ok,err = coMountWS( path )
	
	if not ok then
		dbg("NeedWS",wsid,"mount fail",err)
		return nil,err or "mount"
	end
	
	return true
	
end
 