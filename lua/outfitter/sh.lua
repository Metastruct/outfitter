local Tag='outfitter' 

module(Tag,package.seeall)


function HasMDL(mdl)
	mdl = mdl:gsub("%.mdl$","")
	return file.Exists(mdl..'.mdl','GAME')
end

net.Receive(Tag,function(...) OnReceive(...) end)

local cache = {}
function FlushCache()
	cache = {}
end

function FileExistsCached(fpath)
	local ret = cache[fpath]
	if ret == nil then
		ret = HasMDL(fpath)
		cache[fpath] = ret
	end
	return ret
end