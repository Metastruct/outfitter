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

-- shadowing "dbge" because showing errors to expected behaviors in
-- user targeted code is highly stupid
local function dbge(...)
	Msg("[Outfitter] ")
	print(...)
end

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

local function steamworks_Download_work( fileid )
	local instant
	local path,fd
	local cb
	local done
	
	-- retry
	for i=0,4 do
		if path then break end

		instant,path,fd,cb = nil,nil,nil,nil

		if i~=0 then
			dbg("DownloadUGC","retry attempt ====",i)
			co.sleep(math.random()*3+1)
		end

		cb = co.newcb()
		local function cb2(a,b)
			SafeRunHook("OutfitterDownloadUGCResult",fileid,a,b)
			if done then return end
			
			dbg("DownloadUGC",fileid,instant==false and "" or "instant?","result",a,b)
			if instant==nil then
				path = a
				fd = b
				instant = true
				return
			end
			done = true
			cb(a,b)
		end
		dbgn(2,"DownloadUGC",fileid,"START")
		steamworks.DownloadUGC( fileid, cb2 )
		if instant==nil then
			timer.Simple(60*3,function()
				if done then return end
				dbg("DownloadUGC",fileid,"TIMEOUT (WIP)")
				UIWarnDownloadFailures(wsid)

				--cb2(false,false)
				--done=true
			end)
			instant = false
			path,fd = co.waitcb(cb)
		end
	end

	dbg("DownloadUGC",fileid,"returning",path,fd,instant and "<CACHED>" or "")
	
	return path,fd
end

DownloadUGC = co.worker(steamworks_Download_work)

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
		dbgn(3,"FetchWS","downloading",wsid,"failed for reason:",reason,...)

		local err_msg = ("FetchWS downloading %s failed for reason: %s"):format(tostring(wsid), reason)
		Msg("[Outfitter] ")
		print(err_msg)

		notification.AddLegacy(err_msg, NOTIFY_ERROR, 5)
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
			if fileinfo.error then
				dbg("","error",fileinfo.error)
			end
			dbg("","owner",fileinfo.owner)
			dbg("","tags",fileinfo.tags)
			dbg("","size",string.NiceSize(fileinfo.size or 0))
			dbg("","fileid",fileinfo.fileid)
			local created = os.time() - (fileinfo.created or 0)

			dbg("","created ago",string.NiceTime(created))

			--TODO: Check banned
			--TODO: Check popularity before mounting

			local installed = fileinfo.installed
			local disabled = fileinfo.disabled
			
			if fileinfo.banned then
				dbge(wsid,"BANNED!?")
				return SYNC(dat,cantmount(wsid,"banned"))
			end
			
			if next(fileinfo.children or {}) then
				dbg(wsid,"has dependencies, these will not be mounted")
				--return SYNC(dat,cantmount(wsid,"dependencies"))
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
	if IsTitleBlocked(fileinfo.title) then
		return SYNC(dat,cantmount(wsid,"blocked title"))
	end

	if fileinfo.error and fileinfo.error ~="" then
		return SYNC(dat,cantmount(wsid,"fileinfo: "..tostring(fileinfo.error)))
	end
	
	if tonumber(fileinfo.size or 0)==0 or tonumber(fileinfo.size or 0)==0 then
		return SYNC(dat,cantmount(wsid,"undownloadable"))
	end
	
	local maxsz = outfitter_maxsize:GetFloat()
	maxsz = maxsz*1000*1000

	if maxsz>0.1 and ((fileinfo.size or 0)-1024*1024) > maxsz then
		skip_maxsize = skip_maxsize or skip_maxsizes[wsid]

		dbg("FetchWS","MAXSIZE",skip_maxsize and "OVERRIDE" or "",wsid,string.NiceSize(fileinfo.size or 0))

		if not skip_maxsize then
			return SYNC(dat,cantmount(wsid,"oversize"))
		end
	end

	co.wait(.3)

	local decomp_in_steamworks = true --not HasDecompressHelper()

	local TIME = isdbg and SysTime()
	local path,fd = DownloadUGC( wsid )
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
	assert(DidCrash,"Outfitter has not initialized properly??? Contact Python1320")
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
	if safepath==path then
		safepath = path..'.d.dat'
	end
	--assert(safepath~=path,"path change failed")
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

-- TODO: move


local function http_wrap(ok,err,okerr,...)
	if okerr==ok then
		return true,...
	elseif okerr==err then
		return false,...
	else
		error"Invalid fetch callback called"
	end
end


function co_head(url,data,hdr)
	hdr=hdr or {}
	--hdr["Accept-Encoding"] = hdr["Accept-Encoding"] or "none"

	local ok,err = co.newcb(),co.newcb()
	HTTP({
		method = "HEAD",
		url = url,
		headers = hdr,
		success = function(code, data, headers,...)
			ok(data, #data, headers,code,...)
		end,
		failed = function(...)
			err(...)
		end
	})
	return http_wrap(ok,err,co.waitone())
end

-- TODO: MOVE
-- TODO: cache


local function checkhttp(ok,ret,len,hdrs,retcode)
	if retcode==404 then return nil,'not found' end
	if retcode~=200 then return nil,"http error",retcode end
	local size = hdrs["Content-Length"] and tonumber(hdrs["Content-Length"])
	

	local maxsz = outfitter_maxsize:GetFloat()
	maxsz = maxsz*1000*1000

	if size and maxsz>=1 and size > math.min(maxsz,1024*1024*1024) then
		skip_maxsize = skip_maxsize or skip_maxsizes[wsid]

		dbg("NeedHTTPGMA","MAXSIZE",skip_maxsize and "OVERRIDE" or "",wsid,string.NiceSize(size))

		if not skip_maxsize then
			return nil,"oversize"
		end
	end
	return true
end

function NeedHTTPGMA(download_info,pl,mdl)
	if co.make(download_info,pl,mdl) then return end
	local download_info_actual = MakeURLDownloadable(download_info)
	-- 1. first try getting header info
	local filename = download_info:match( "([^/]+)$" )

	local ok,ret,len,hdrs,retcode = co_head(download_info_actual)
	if ok then
		local size = hdrs["Content-Length"] and tonumber(hdrs["Content-Length"])
		local ETag = hdrs["ETag"]
		local can_range = hdrs["Accept-Ranges"] and hdrs["Accept-Ranges"]:find"bytes" and true or false
		dbg("NeedHTTPGMA Header",download_info,"ETag=",ETag,"Size=",size,"can_range=",can_range,table.ToString(hdrs))

		local ok,err,err2 = checkhttp(ok,ret,len,hdrs,retcode)
		if not ok then
			return ok,err,err2
		end
	end

	
	co.sleep(.1)
	-- 2. then actually download the thing
	SetUIFetching(filename,true,nil,true)
	--dbgn(2,'NeedHTTPGMA','minimized garbage for download',coMinimizeGarbage())
	local ok,data,len,hdrs,retcode = co.fetch( download_info_actual )	
	SetUIFetching(filename,false,not ok and ddata or retcode~=200 and "server returned an error" or nil,true)
	if not ok then return nil,data or 'download failed' end

	-- TODO: lower memory usage instantly rather than this?
	--dbgn(2,'NeedHTTPGMA','minimized garbage after download',coMinimizeGarbage())

	local ETag = hdrs["ETag"]
	local ETag = hdrs["Last-Modified"]
	local can_range = hdrs["Accept-Ranges"] and hdrs["Accept-Ranges"]:find"bytes" and true or false
	dbg("NeedHTTPGMA Downloaded",download_info,"ETag=",ETag,"Size=",string.NiceSize(len),"can_range=",can_range,table.ToString(hdrs))

	local ok,err,err2 = checkhttp(ok,data,len,hdrs,retcode)
	if not ok then
		return ok,err,err2
	end
	file.CreateDir("cache",'DATA')
	file.CreateDir("cache/httpgma",'DATA')

	local sha1 = util.SHA1(data)
	
	local path = ("cache/httpgma/%s.dat"):format(sha1)
	file.Write(path,data)
	data=nil
	dbgn(2,'NeedHTTPGMA','minimized garbage after data discard',coMinimizeGarbage())
	path="data/"..path
	
	local ok,err = GMABlacklist(path)
	if not ok and err=='notgma' and TestLZMA(path) then
		local newpath,err = coDecompress(path)
		if not newpath then
			dbge("NeedWS",download_info,"fail",err)
			return nil,err or "decompress"
		end
		path = newpath

		-- retry --
		ok,err = GMABlacklist(path)
		-----------
	end

	if not ok then
		dbge("NeedHTTPGMA","GMABlacklist",download_info,"->",err)
		return
	end

	local mdls,extra,errlist = GMAPlayerModels(path)

	if not mdls then
		dbge("NeedHTTPGMA","GMAPlayerModels",download_info,"fail",extra)
		return false,"mdlparse",extra
	end

	if not mdls[1] then
		dbge("NeedHTTPGMA","GMAPlayerModels",download_info,"has no models")
		return false,"nomdls"
	end

	local has = not mdl
	if not has then
		has = extra.playermodels[mdl] or extra.hands[mdl]
		if not has then
			-- TODO: Make enforced
			local bad = extra.potential[mdl] or extra.discards[mdl]
			if bad then
				dbge("NeedHTTPGMA",download_info,path,"requested mdl was discarded",mdl)
--			elseif GMAHasFile()
			else
				dbge("NeedHTTPGMA",download_info,path,"missing requested mdl",mdl)
			end

		end
	end

	local ok,err = coMountWS( path )

	if not ok then
		dbg("NeedHTTPGMA",download_info,"mount fail",err)
		return nil,err or "mount"
	end

	return true

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