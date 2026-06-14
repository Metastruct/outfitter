if SERVER then
	AddCSLuaFile() 
	return
end

module("urlimage",package.seeall)
_M._MM = setmetatable({},{__index=function(s,k) return rawget(_M,k) end,__newindex=_M})
local inDebug
function setDebug(d)
	inDebug = d
end

if _MM.getDebug then
	setDebug(getDebug())
end

function getDebug()
	return inDebug
end

function dbg(...) 
	if not inDebug then return end
	Msg"[UrlImg] "print(...) 
end

function DBG(...) Msg"[UrlImg] "print(...) end

FindMetaTable"IMaterial".ReloadTexture = function(self,name)
	self:GetTexture(name or "$basetexture"):Download()
end

-- texture parsers for real w/h
local IsPNG = string.IsPNG
if not IsPNG then require'imgparse' IsPNG = string.IsPNG end
local IsJPG = string.IsJPG
local IsVTF = string.IsVTF

local PNG = file.ParsePNG
local VTF = file.ParseVTF
local JPG = file.ParseJPG
local assert_ = assert

local assert = function(a,b)
	if a==nil and b=='nodb' then return end
	return assert_(a,b)
end

if not sql.obj then pcall(require,'sqlext') end
--
local db
function db_init()
	local _db = assert(sql.obj("urlimage"))
	assert(_db.migrate,"Please upgrade urlimage dependencies")
	
	_db=assert(_db:create([[
			`url`		TEXT NOT NULL CHECK(url <> '') UNIQUE,
			`ext`		TEXT NOT NULL CHECK(ext = 'vtf' OR ext = 'png' OR ext = 'jpg'),
			`last_used`	INTEGER NOT NULL DEFAULT 0,
			`fetched`	INTEGER NOT NULL DEFAULT (cast(strftime('%%s', 'now') as int) - 1477777422),
			`locked`	BOOLEAN NOT NULL DEFAULT 1,
			`size`		INTEGER DEFAULT 0,
			`w`			INTEGER(2) NOT NULL DEFAULT 0,
			`h`			INTEGER(2) NOT NULL DEFAULT 0,
			`fileid`	INTEGER PRIMARY KEY AUTOINCREMENT]])
		:migrate(function(db)
			db:alter("ADD COLUMN file_size INTEGER;")
		end)
		:coerce{last_used=tonumber, fileid=tonumber,w=tonumber,file_size=tonumber,h=tonumber, locked=function(l) return l=='1' end })
	local l = assert(_db:update("locked = 0 WHERE locked != 0"))

	if l>0 then dbg("unlocked entries: ",l) end
	db = _db
end

-- print(db:columns())

--  Msg"insert " 		print(assert(		db:insert{url = "http://asd.com/0", last_used = os.time()}))
--  Msg"replace " 		print(				db:insert({url = "http://asd.com/0", last_used = 1337},true))
--  Msg"insert " 		print(assert(		db:insert{url = "http://asd.com/1", last_used = os.time()-123}))
--  Msg"count " 		print(tonumber(		db:select1"count(*) as count".count))
--  Msg"Delete none " 	PrintTable(assert(	db:delete("url = %s",'derp')))
--  Msg"count " 		print(tonumber(		db:select1"count(*) as count".count))
--  Msg"list "			PrintTable(			db:select("*","WHERE URL != %s","http://asd.co"))
--  Msg"update "		PrintTable(			db:update("locked = 1 WHERE fileid=%d",123))
--  Msg"list"			PrintTable(			db:select("*","WHERE URL != %s","http://asd.co"))
--  Msg"raw"			PrintTable(assert(	db:sql1("select * from %s limit %d",db,1)))
--  Msg"Delete all " 	print(assert(		db:delete("url != %s",'derp')))
--do return end
---------------


MAX_ENTRIES = 2048
function find_purgeable()
	if not db then return nil,'nodb' end
	dbg("find_purgeable()")
	local a,b = db:select('*','WHERE locked != 1 ORDER BY last_used ASC LIMIT(select max(0,count(*) - %d) from %s)',MAX_ENTRIES,db)
	if a==true then return false end
	return a,b
end

function get_cache_info()
	if not db then return nil,'nodb' end
	return {
		
		count = tonumber(db:select('count(*) as count')[1].count or -1),
		bytes = db:select('sum(file_size) as file_size')[1].file_size or -1,
		
	}
end


--function find_oldest()
--	if not db then return nil,'nodb' end
--	dbg("find_oldest()")
--	local a,b = db:select('*','WHERE locked != 1 ORDER BY last_used ASC LIMIT(1)')
--	return a,b
--end

function update_dimensions(fileid,w,h)
	if not db then return nil,'nodb' end

	dbg("update_dimensions()",fileid,w,h)
	assert(tonumber(fileid))
	return db:update("w = %d, h=%d WHERE fileid=%d",w,h,fileid)
end
function update_size(fileid,sz)
	if not db then return nil,'nodb' end
	assert(tonumber(fileid))
	assert(tonumber(sz))

	dbg("update_size()",fileid,sz)
	return db:update("file_size = %d WHERE fileid=%d",sz,fileid)
end

function record_use(fileid,nolock)
	if not db then return nil,'nodb' end

	dbg("record_use()",fileid,nolock)
	assert(tonumber(fileid))
	nolock = nolock and "" or ", locked = 1"
	return db:update("last_used = (cast(strftime('%%s', 'now') as int) - 1477777422)"..nolock.." WHERE fileid=%d",fileid)
end

function get_record(urlid)
	if not db then return nil,'nodb' end

	dbg("get_record()",urlid)
	local record = assert(db:select1('*',isnumber(urlid) and "WHERE fileid = %d" or "WHERE url = %s",urlid))
	return record~=true and record
end

function record_validate(r)
	local err
	if not istable(r) then r,err = get_record(r) end
	dbg("record_validate()",r,r and r.url or r.fileid,err)
	if not r or not r.w or r.w==0 then return false end
	
	return r and file.Exists(FPATH(r.fileid,r.ext),'DATA') and r
end

function new_record(url,ext)
	if not db then return nil,'nodb' end

	dbg("new_record()",url,ext)
	local fileid = assert(db:insert{url = url,ext = ext})
	return fileid
end

--print(update_last_used(db:insert{url = "f"}))
--db:insert{url = "http://asd.com/1",last_used = 1}
--db:insert{url = "http://asd.com/2",ext="jpg"}
--db:insert{url = "http://asd.com/3",last_used = 3}
--db:insert{url = "http://asd.com/4"}
--Msg"list "			PrintTable(			db:select("*","WHERE URL != %s","http://asd.co"))

BASE = "cache/uimg"
file.CreateDir("cache",'DATA')
file.CreateDir(BASE,'DATA')
function FPATH(a,ext,open_as)
	--Msg(("FPATH %q %q %q -> "):format(a or "",ext or "",tostring(open_as or "")))
	if ext=="vmt" then
		a=a..'_vmt'
		ext="txt"
	end
	
	local ret =("%s/%s%s%s%s%s"):format(BASE,tostring(a),
		ext and "." or "",
		ext or "",
		open_as and "\n." or "",
		open_as or "")
	--print(ret)
	return ret
end

function ToMaterialPath(...)
	return ("../data/%s"):format(FPATH(...))
end
FPATH_R=ToMaterialPath

local generated = {}
function Material(fileid, ext, isSurface, pngParameters)
	dbg("Material()",fileid,ext,pngParameters)
	local path = ToMaterialPath(fileid,ext )
	local a,b
	
	if ext == 'vtf' or ext == 'VTF' then
		path = ToMaterialPath(fileid)
		local matid = "uimgg".. fileid .. (isSurface and "surface" or "render")
		dbg("_G.CreateMaterial()",("%q"):format(path),isSurface and "UnlitGeneric" or "VertexLitGeneric",matid)
		a,b = CreateMaterial(matid, isSurface and "UnlitGeneric" or "VertexLitGeneric", {
			["$vertexcolor"] = "1",
			["$vertexalpha"] = "1",
			["$nolod"] = "1",
			["$basetexture"] = path,
			["Proxies"] =
			{
				["AnimatedTexture"] =
				{
					["animatedTextureVar"] = "$basetexture",
					["animatedTextureFrameNumVar"] = "$frame",
					["animatedTextureFrameRate"] = 8,
				}
			}
		})
	else
		dbg("_G.Material()",("%q"):format(path),pngParameters)
		a,b = _G.Material(path,pngParameters)
	end
	
	-- should no longer be needed, if it even works
	--if a then a:ReloadTexture() end
	
	return a,b,path,matid
end

function fwrite(fileid,ext,data)
	dbg("fwrite()",fileid,ext,#data)
	local path = FPATH(fileid,ext)
	file.Write(path,data)
	return path
end
function fopen(fileid,ext)
	dbg("fopen()",fileid,ext)
	return file.Open(FPATH(fileid,ext),'rb','DATA')
end

local delete_record delete_record = function(record)
	dbg("delete_record()",record)
	if istable(record) then
		
		if next(record)==nil then return 0 end
		
		if record[1] then
			local aggr = 0
			for k,record in next,record do
				aggr = aggr + assert(delete_record(record))
			end
			return aggr
		else
			return delete_record(record.fileid or record.fileid)
		end
	elseif isnumber(record) then
		if not db then return nil,'nodb' end
		return db:delete('fileid = %d',record)
	elseif isstring(record) then
		if not db then return nil,'nodb' end
		return db:delete('url = %s',record)
	else error"wtf" end
end

function delete_fileid(fileid,ext)
	dbg("delete_fileid()",fileid,ext)
	
	local deleted = false
	local function D(path,place)
		if file.Exists(path,place) then
			deleted = true
			file.Delete(path,place)
			return deleted
		end
	end
	
	if ext then
		D(FPATH(fileid,ext),'DATA')
	end
	D(FPATH(fileid,'vmt'),'DATA')
	D(FPATH(fileid,'jpg'),'DATA')
	D(FPATH(fileid,'png'),'DATA')
	D(FPATH(fileid,'vtf'),'DATA')
	
	return deleted
end



function data_format(bytes)
	if 		IsJPG(bytes) then return 'jpg'
	elseif 	IsPNG(bytes) then return 'png'
	elseif 	IsVTF(bytes) then return 'vtf'
	end
	dbg("data_format()","FAILURE",("%q"):format(bytes))
end

local mw,mh = 	render.MaxTextureWidth(),render.MaxTextureHeight()
mw=mw>2048 and 2048 mh=mh>2048 and 2048
function read_image_dimensions(fh,fmt)
	dbg("read_image_dimensions()",fh,fmt)
	local reader = fmt=='png' and PNG or fmt=='jpg' and JPG or fmt=='vtf' and VTF
	if not reader then return nil,'No reader for format: '..tostring(fmt) end
	
	local w,h
	local t = reader(fh)
	
	w = t.width
	h = t.height
	if not w or not h then
		return nil,'invalid file'
	end
	if w>mw or h>mh then
		return nil,'excessive dimensions'
	end
	return w,h
end

function record_to_material(r, data, isSurface)
	dbg("record_to_material()",r and r.fileid)
	if not r.used then
		assert(record_use(r.fileid))
		r.used = true
	end
	return Material(r.fileid, r.ext, isSurface, data), r.w, r.h
end

local function remove_error(cached,...)
	cached.error = nil
	return ...
end

cache = _MM.cache or {}
local cache = cache

fastdl_override = false
local fastdl = GetConVarString"sv_downloadurl":gsub("/$","")..'/'
function GetFastDL()
	return fastdl_override or fastdl
end

function FixupURL(url)
	if not url:sub(3,10):find("://",1,true) then
		url = GetFastDL()..url
	else

		url = url:gsub([[^http%://onedrive%.live%.com/redir?]],[[https://onedrive.live.com/download?]])
		url = url:gsub( "github.com/([a-zA-Z0-9_]+)/([a-zA-Z0-9_]+)/blob/", "github.com/%1/%2/raw/")

		if url:find("dropbox",1,true) then
			url = url:gsub([[^http%://dl%.dropboxusercontent%.com/]],[[https://dl.dropboxusercontent.com/]])
			url = url:gsub([[^https?://www.dropbox.com/s/(.+)%?dl%=[01]$]],[[https://dl.dropboxusercontent.com/s/%1]])
		end

	end
	
	return url
end



function URLFetchHead(url,cb,headers)
	HTTP{
		url			= url,
		method		= "HEAD",
		parameters = headers,
		success = function( code, body, headers )
			cb(code==200 and assert(headers) or nil,code,headers,body)
		end,
		failed = function( reason )
			cb(nil,reason)
		end
	}
end
function HeadContentSize(t)
	return t['Content-Length']
end



local n = URLIMAGE_EMERGENCY_UID or (10000-1)
local function get_uid()
	n = n + 1
	URLIMAGE_EMERGENCY_UID = n
	DBG("Emergency UID",n)
	return n
end
-- Returns: mat,w,h
-- Returns: false = processing, nil = error
function GetURLImage(url, data, isSurface)
	
	url = FixupURL(url)
	
	local cached = cache[url]
	if cached then
		if cached.processing then
			return false
		elseif cached.error then
			return nil,cached.error
		elseif cached.record then
			return record_to_material(cached.record, data, isSurface)
		else
			cached.error = "invalid cache state"
			error(cached.error)
		end
	end
	
	-- find if record exists --
	
	cached = {error = "failure"}
	cache[url] = cached
	
	local cached_record = get_record(url)
	if cached_record then
		
		assert(next(cached_record)~=nil)
		
		if record_validate(url) then
			record_use(cached_record.fileid)
			cached.record = cached_record
			return remove_error(cached, record_to_material(cached_record, data, isSurface) )
		else
			DBG("INVALID RECORD","DELETING",url)
			assert(delete_record(url))
		end
	end
	
	-- it's a new url --
	dbg("Fetching",url)
	
	local function fail(err)
		delete_record(url)
		cached.processing = false
		cached.error = tostring(err)
		dbg("Fetch failed for",url,": "..cached.error)
	end
	
	local function fetched(data,len,hdr,code)
		
		dbg("fetched()",url,string.NiceSize(len),code)
		
		if code~=200 then
			return fail(code)
		end
		if len<=8 or len>1024*1024*25 then -- 26MB
			return fail'invalid filesize'
		end
		
		local ext = data_format(data)
		if not ext then
			return fail'unknown format'
		end
		
		-- build a new record --
		
		local fileid = assert(new_record(url,ext))
		local nodb
		
		if not fileid then 
			nodb = true
			fileid = get_uid()
		end
		
		assert(fileid)
		
		local record = {fileid = fileid}
		
		fwrite(fileid,ext,data) data = nil
		local fh = fopen(fileid,ext)
		
		local w,h = read_image_dimensions(fh,ext)
		fh:Close()
		if not w then return fail(h) end
		
		if not nodb then
			assert(update_dimensions(fileid,w,h))
			assert(update_size(fileid,len))
				
			-- We don't have to build the record manually, we can just get it again
			record = assert(get_record(url))
			
			assert(record)
			
			cached.record = record
			
		else
			record.url = url
			record.ext = 		ext
			record.last_used = 	os.time()
			record.fetched = 	os.time()
			record.locked = 	true
			record.w = 	w
			record.h = 		h
			record.fileid = fileid
			cached.record = record
		end
	
		if not record_validate(cached.record) then
			return fail'record_validate()'
		end
			
		if not nodb then
			-- we now have some sort of record, so let's use it so it's top of LRU
			record_use(fileid,true) -- maybe remove?
		end
			
		cached.processing = false
		remove_error(cached)
		
		
	end
	URLFetchHead(url,function(h,err)
		if h then
			local sz = HeadContentSize(h)
			if sz and tonumber(sz) then
				
				if tonumber(sz)>15*1000*1000 then
					return fail'filesize'
				end
			end
		else
			dbg("Head query failed",err)
		end
		http.Fetch(url,fetched,fail)	
	end)
	
	cached.processing = true
	
	return false
	
end

local lastFrameCalled = -1
local frameCount
local IKNOWWHATIMDOING=false
local errored = false

function SuppressSanityChecks(s)
	IKNOWWHATIMDOING = s ~= false
end

function URLImage(url, data)
	local fn = FrameNumber()
	if lastFrameCalled == fn - 1 then
		frameCount=frameCount+1
		if frameCount > 18 then
			if not errored then
				errored = true
				if not IKNOWWHATIMDOING then 
					ErrorNoHalt("URLImage called every frame, you must keep a reference to the result of URLImage, url="..tostring(url))
					debug.Trace()
				end
			end
		end
	
	elseif lastFrameCalled ~= fn then
		frameCount = 0
	end
	lastFrameCalled=fn
	
	local mat,w,h = GetURLImage(url, data, true)
	dbg("URLImage",fn,url,mat,w)
	
	local function setmat()
		surface.SetMaterial(mat)
		return w,h, mat
	end
	
	if mat then
		dbg("URLImage",url,"instant mat",mat)
		return setmat
	end
	
	local trampoline trampoline = function()
		mat,w,h = GetURLImage(url, data, true)
		if not mat then
			if mat==nil then
				trampoline = function() return mat,w,h end
				DBG("URLImage failed for ",url,": ",w,h)
			end
			
			return mat
		end
		trampoline = setmat
		return setmat()
	end
	
	local function return_trampoline()
		return trampoline()
	end
	return return_trampoline
end

local WTF=function()end

-- Only start downloading when first called
function LazyURLImage(url, data)
	local cb 
	cb = function(...)
		cb = WTF
		cb = surface.URLImage(url, data)
		return cb(...)
	end
	return function(...)
		return cb(...)
	end
end
local lastFrameCalled = -1
local frameCount
local errored = false

function URLMaterial(url, data)
	local fn = FrameNumber()
	if lastFrameCalled == fn - 1 then
		frameCount=frameCount+1
		if frameCount > 18 then
			if not errored then
				errored = true
				if not IKNOWWHATIMDOING then 
					ErrorNoHalt("URLMaterial called every frame, you must keep a reference to the result of URLMaterial, url="..tostring(url))
					debug.Trace()
				end
			end
		end
	elseif lastFrameCalled ~= fn then
		frameCount = 0
	end
	lastFrameCalled=fn
	
	
	local mat,w,h = GetURLImage(url, "vertexlitgeneric " .. (data or ""), false)
	local function setmat()
		render.SetMaterial(mat)
		return w,h, mat
	end
	
	if mat then
		dbg("URLImage",url,"instant mat",mat)
		return setmat
	end
	
	local trampoline trampoline = function()
		mat,w,h = GetURLImage(url, "vertexlitgeneric " .. (data or ""), false)
		if not mat then
			if mat==nil then
				trampoline = function() return mat,w,h end
				DBG("URLMaterial failed for ",url,": ",w,h)
			end
			
			return mat
		end
		trampoline = setmat
		return setmat()
	end
	
	local function return_trampoline()
		return trampoline()
	end
	return return_trampoline
	
end

surface.URLImage = URLImage
surface.LazyURLImage = LazyURLImage
render.URLMaterial = URLMaterial

function do_purge()
	--TODO: Purge
	local purgeables = find_purgeable()
	if not purgeables or purgeables == true or #purgeables == 0 then return end
	local purgestart = SysTime()

	for _, purgeable in next, purgeables do
		if not delete_fileid(purgeable.fileid) then
			dbg("already deleted?", table.ToString(purgeable))
		end

		if not delete_record(purgeable.url) then
			DBG("Could not delete", table.ToString(purgeable))
		end
	end

	local purgelen = SysTime() - purgestart
	DBG("Images purged: ", #purgeables, ". took ", math.Round(purgelen*1000), "ms")
end

local ok,err = xpcall(db_init,debug.traceback)

if not ok then
	ErrorNoHalt(err..'\n')
end


local ok2,err2 = xpcall(do_purge,debug.traceback)

if not ok2 then
	ErrorNoHalt(err2..'\n')
end

function GetStartupFailure()
	return not ok and (err or "Unknown")
end

do return end

local test1 = surface.URLImage "materials/silk_icon_flags.png?b=cdq"
local test2 = surface.URLImage "http://g1.metastruct.net:2095/jpg.jpg?c=dqd"
local test3 = surface.URLImage "http://g1.metastruct.net:2095/vtf.vtf?c=qdq"
hook.Add("DrawOverlay","a",function()
	surface.SetDrawColor(255,255,255,255)
 
	local w,h = test1()
	if w then
		--print(w)
		surface.DrawTexturedRect(0,0,w,h)
	end
	local w1,h1 = test2()
	if w1 then
		surface.DrawTexturedRect(1+(w or 0),0,w1,h1)
	end
	local w2,h2 = test3()
	if w2 then
		surface.DrawTexturedRect(2+(w or 0)+(w1 or 0),0,w2,h2)
	end
end)
 
