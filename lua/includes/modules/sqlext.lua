--https://gist.github.com/Python1320/eec8cdc84828a8261b00

AddCSLuaFile()

local sql=sql

local tablevers

-- http://www.sqlite.org/lang_corefunc.html#last_insert_rowid
function sql.LastRowID()
	local ret = sql.Query("SELECT last_insert_rowid() as x")[1].x
	return ret
end

setmetatable(sql,{__call=function(self,query,...)
	local t = {...}
	for k,v in next,t do
		if isstring(v) then
			t[k] = sql.SQLStr(v)
		elseif isbool(v) then
			v=tostring(v)
		end
	end
	query = query..';'
	if #t > 0 then
		query = query:format(unpack(t))
	end
	local ret = sql.Query(query)
	
	assert(ret~=true,'uuuhoh')
	if ret == false then
		return nil,sql.LastError()..' (Query: '..query..')'
	elseif ret == nil then
		return true
	else
		return ret
	end
end})

-- http://www.tutorialspoint.com/sqlite/sqlite_date_time.htm
local escape=sql.SQLStr
local function gen_datefunc(fname)
	local beginning = "SELECT "..fname.."("
	local function func(...)
		
		local mods = {...}
		for k,v in next,mods do
			mods[k]=isnumber(v) and v or escape(v)
		end
		local q=beginning..table.concat(mods,",")..") as x;"

		local ret = sql.Query(q)
		ret = ret and ret[1]
		ret = ret and ret.x
		ret = ret and ret~="NULL" and ret
		
		return ret
		
	end
	
	sql[fname]=func
end

gen_datefunc 'date'
gen_datefunc 'time'
gen_datefunc 'datetime'
gen_datefunc 'julianday'
gen_datefunc 'strftime'
	
	
	
	


local mt = {}
function mt:create(infos,after,...)
	local name = getmetatable(self).name
	assert(name)
	if not sql.TableExists(name) then
		MsgN("Creating ",name)
		assert(sql(("CREATE TABLE %%s (%s) %s"):format(infos,after or ""),name,...))
		if tablevers then
			tablevers:update("ver = 0 WHERE name = %s",name)
		end
	end
	return self
end

function mt:coerce(kv)
	getmetatable(self).coerce = kv
	return self
end

function mt:drop()
	local name = getmetatable(self).name
	if sql.TableExists(name) then
		assert(sql(("DROP TABLE %s"):format(name)))
	end
	return self
end
function mt:insert(kv,or_replace)
	local name = getmetatable(self).name
	
	local keys,values={},{}
	local i=0
	for k,v in pairs(kv) do
		i=i+1
		keys[i] = sql.SQLStr(k)
		values[i] = (isnumber(v)) and tostring(v)
		or v==true and 1
		or v==false and 0
		or isstring(v) and sql.SQLStr(v)
		or error"Invalid input"
	end
	
	local a,b = sql(("INSERT %sINTO %s (%s) VALUES (%s)"):format(or_replace and "OR REPLACE " or "",name,table.concat(keys,", "),table.concat(values,", ")))
	if a==true then
		return tonumber(sql.LastRowID())
	end
	return a,b
end

function mt:coercer(a,...)
	local coerce = getmetatable(self).coerce
	if coerce and a and a~=true then
		for i=1,#a do
			local t = a[i]
			for k,v in next,t do
				local coercer = coerce[k]
				if coercer then
					t[k] = coercer(v)
				end
			end
		end
	end
	return a,...
end
function mt:select(vals,extra,...)
	local name = getmetatable(self).name
	
	return self:coercer(self:sql(("SELECT %s FROM %s %s"):format(vals,name,extra or ""),...))
end


local function return_changes(a,...)
	if a==true then
		local changes = tonumber(sql'SELECT changes() as changes'[1].changes)
		return changes
	end
	return a,...
end
function mt:update(extra,...)
	local name = getmetatable(self).name
	local query = ("UPDATE %s SET %s"):format(name,extra)
	return return_changes( self:sql( query ,...) )
end

function mt:alter(extra,...)
	local name = getmetatable(self).name
	local query = ("ALTER TABLE %s %s"):format(name,extra)
	return assert(return_changes( self:sql( query ,...) ))
end

function mt:delete(extra,...)
	local name = getmetatable(self).name
	local query = ("DELETE FROM %s WHERE %s"):format(name,extra)
	return return_changes( self:sql( query ,...) )
end

local function firstval(a,...)
	if a and a~=true then assert(not a[2]) return a[1] end
	return a,...
end
function mt:select1(...) return firstval(self:select(...)) end


function mt:sql(a,...)
	local t = {...}
	local name = getmetatable(self).name
	
	for k,v in next,t do
		local mt = istable(v) and getmetatable(v)
		if mt and mt.name then t[k] = mt.name end
	end
	
	return sql(a,unpack(t))
end
function mt:sql1(...) return firstval(self:sql(...)) end

local function columns(a,b)
	if a then
		return a[1].name
	end
	return a,b
end
function mt:columns()
	local name = getmetatable(self).name
	if sql.TableExists(name) then
		return columns(sql("PRAGMA table_info(%s)",name))
	end
	return nil,'no such table'
end


function sql.obj(name)
	return setmetatable({name=name},{name=name,__index=mt})
end


local ok,err = xpcall(function()
	local t = assert(sql.obj("sqlext"))
		:create([[
			`name`		TEXT NOT NULL CHECK(name <> '') UNIQUE,
			`ver`		INTEGER NOT NULL DEFAULT 0]])
		:coerce{ver=tonumber}
	tablevers = t
end,debug.traceback)
if not ok then
	ErrorNoHalt(err..'\n')
end

local function read_table_version(name)
	if not tablevers then return nil,'tablevers unavailable' end
	local ret,err = tablevers:select("*","WHERE name = %s",name)
	if ret == nil then return nil,err end
	if ret == true then return false end
	return ret and ret[1] and ret[1].ver or false
end

function mt:migrate(cb)
	local info = getmetatable(self)
	
	local name = info.name
	local _ver = (info._ver or 0) + 1
	info._ver = _ver
	
	if info._migrate_errors then return nil,'migration errors' end
	
	local table_version = read_table_version(name)
	if table_version == nil then
		return self
	elseif not table_version then
		table_version = 0
		tablevers:insert{name=name,ver=1}
	end
	if _ver <= table_version then
		return self
	end
	
	local ok,ret = xpcall(cb,debug.traceback,self,name)
	
	if not ok then
		ErrorNoHalt(ret..'\n')
		info._migrate_errors = true
		return nil,'migration errors'
	end
	
	if ret==false then
		return self
	end
	
	tablevers:update("ver = %d WHERE name = %s",_ver,name)
	MsgN("Upgraded ",name," to version ",_ver)
	
	return self
end
