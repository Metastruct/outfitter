local Tag='costumizer' 

module(Tag,package.seeall)


function HasMDL(mdl)
	return file.Exists(mdl,'GAME')
end

net.Receive(Tag,function(...) OnReceive(...) end)

local cache = {}
function FlushCache()
	cache = {}
end

function FileExistsCached(fpath)
	local ret = cache[fpath]
	if ret == nil then
		ret = file.Exists(fpath,'GAME')
		cache[fpath] = ret
	end
	return ret
end