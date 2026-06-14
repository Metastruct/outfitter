Garry's Mod sqlite minimal extensions


### Examples 

```lua
print("\n======DEMO======\n")

-- Table creation
	local delme = assert(sql.obj("delme14"))
		delme:create([[
			`name`		TEXT NOT NULL CHECK(name <> '') UNIQUE,
			`ver`		INTEGER NOT NULL DEFAULT 0]])
		
		-- at some point you may want to add more columns
		:migrate(function(db)
			db:alter("ADD COLUMN test1 TEXT;")
			print"ran first migrations"
		end) -- or even more migrations
		:migrate(function(db,dbname)
			db:alter("ADD COLUMN test2 TEXT;")
			print"ran second migrations"
		end) -- migrate will return nil if it fails

-- let's insert data
	local NAME="escaped i am '123"
	local rowid = delme:insert{name = NAME,ver=123}
	print("ROWID is returned (sqlite has implicit rowid): ",rowid)

-- error handling
	local rowid,err = delme:insert{name = NAME}
	assert(rowid==nil and err)
	print("errors are returned as nil,errormsg:",err)

-- select data
	local return_values = "rowid, name, ver as version"

	-- %s is automatically escaped. If you want to add raw %s add it yourself
	local rules = "WHERE version >= 0 and 'escape''testing' = %s ORDER BY name ASC LIMIT(%d)"
	
	local ret = delme:select(return_values,rules,"escape'testing",123)
	for k,v in next,ret do
		print("select return data: ",v.rowid, v.name,v.version)
	end

	-- empty result set is returned as true
	assert(delme:select("*","WHERE name=%s","noexist")==true)

-- delete
	assert(0==delme:delete('name = %s',"doesnotexist"))
	
	
print("\n================\n")

--[[

======DEMO======

Creating delme14
ran first migrations
Upgraded delme14 to version 1
ran second migrations
Upgraded delme14 to version 2
ROWID is returned (sqlite has implicit rowid): 	1
errors are returned as nil,errormsg:	UNIQUE constraint failed: delme14.name (Query: INSERT INTO delme14 ('name') VALUES ('escaped i am ''123');)
select return data: 	1	escaped i am '123	123

================
--]]
```
