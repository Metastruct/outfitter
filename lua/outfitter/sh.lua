local Tag = 'outfitter'
module(Tag, package.seeall)
local outfitter_sv_distance = CreateConVar("outfitter_sv_distance", "1", {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY})

function ServerSuggestDistance()
	return outfitter_sv_distance:GetBool()
end

-- Shared Utils
function UrlToWorkshopID(url)
	if not url or not isstring(url) then return end

	return url:match'://steamcommunity.com/sharedfiles/filedetails/.*[%?%&]id=(%d+)' or url:match'://steamcommunity.com/workshop/filedetails/.*[%?%&]id=(%d+)'
end

function HasMDL(mdl)
	mdl = mdl:gsub("%.mdl$", "")

	return file.Exists(mdl .. '.mdl', 'GAME')
end

function SanityCheckNData(mdl, download_path)
	if not mdl then return false end
	if not download_path then return false end
	if mdl == "" or #mdl > 2048 * 2 then return false end
	if mdl:find("  ", 1, true) or mdl:find("..", 1, true) or mdl:find("\t", 1, true) or mdl:find("\n", 1, true) then return false end

	if tonumber(download_path) then
		if tonumber(download_path) <= 0 then return false end
	else
		if not IsHTTPURL(download_path) then return false end
	end

	return nil
end

-- Find player by userid
function findpl(uid)
	for _, pl in next, player.GetAll() do
		if pl:UserID() == uid then return pl end
	end
end

-- Encodes the shared payload to be sent to everyone: {model_path,25293523 or "https://example.com/asd.gma" or false}
function EncodeOutfitterPayload(model_path, download_path)
	local encoded = model_path and download_path and util.TableToJSON({assert(model_path:find(".mdl", 2, true) and model_path, 'invalid path: ' .. tostring(model_path)), tostring(download_path) or false}) or nil

	return encoded and #encoded < 32000 and encoded
end

function IsHTTPURL(str)
	return tostring(str or ""):find"^https?://.*/" and true or false
end

-- Decodes the shared payload
function DecodeOutfitterPayload(encoded)
	if not encoded or #encoded == 0 then return nil, 'empty' end
	local decoded = util.JSONToTable(encoded)
	if not decoded then return nil, err or 'json parsing failed' end
	local model_path = decoded[1]
	local download_path = decoded[2]
	if not model_path then return nil, 'empty' end
	model_path = tostring(model_path)
	if not model_path:find("%.mdl$") and not model_path:lower():find("%.mdl$") then return nil, 'not a .mdl' end
	
	-- either workshop id or a http url
	if download_path == nil then return nil, 'empty' end
	if not tonumber(download_path) and not download_path:find"^https?://.*/" and download_path ~= false then return nil, 'invalid' end

	return model_path, download_path
end

-- legacy
EncodeOW = EncodeOutfitterPayload
DecodeOW = DecodeOutfitterPayload

net.Receive(Tag, function(...)
	if this.OnReceive then
		OnReceive(...)
	end
end)

-- parse model from file
function MDLIsPlayermodel(f, sz)
	local mdl, err, err2 = mdlinspect.Open(f)
	if not mdl then return nil, err, err2 end
	if mdl.version < 44 or mdl.version > 49 then return false, "bad model version" end
	local ok, err = mdl:ParseHeader()
	if not ok then return false, err or "hdr" end
	if not mdl.bone_count or mdl.bone_count <= 2 then return false, "nobones" end

	if sz then
		local valid, err = mdl:Validate(sz)

		if not valid then
			dbg("MDLIsPlayermodel", f, "validate error", err)

			return false, "valid"
		end
	end

	--print(mdl,mdl.bodypart_count,mdl.skinreference_count)
	local found = false
	local imdls = mdl:IncludedModels()
	
	if mdl.bonecontroller_count ~= mdl.bone_count then
		--dbg("bonecontroller_count differs?!",mdl.bonecontroller_count,mdl.bone_count)
	end
	
	local found
	local found_anm
	for k,v in next,imdls do
		v=v[2]
		
		if v and v:find("_arms_",1,true) then
			return false,"arms"
		end
		
		if v and not v:find"%.mdl$" then
			return false,"badinclude",v
		end
		if v=="models/m_anm.mdl" or v=="models/f_anm.mdl" or v=="models/z_anm.mdl" then
			found_anm = true
		end
		--if v
		--	and v:find"%.mdl$"
		--	and (
		--		v:find("anim",1,true)
		--		or v:find('/m_',1,true)
		--		or v:find('/f_',1,true)
		--		or v:find('/cs_',1,true) )
		--then
		--	found = true
		--	break
		--end
	end
	
	local attachments = mdl:Attachments()
	if not attachments or not next(attachments) then
		if not found_anm then
			--PrintTable(mdl:Attachments())
			if not IsUnsafe() then
				return false,"noattachments"
			end
		else
			dbg("MDLIsPlayermodel",mdl.name,"no attachments but included")
		end
	else
		--PrintTable("ASD",mdl:BoneNames())
		local found
		for k,v in next,attachments do
			local name = v[1]
			--print(name)
			if name=="eyes" or name=="anim_attachment_head" or name=="mouth" or name=="anim_attachment_RH" or name=="anim_attachment_LH" then found=true break end
		end
		if not found then
			if not found_anm then
				--PrintTable(mdl:Attachments())
				if not IsUnsafe() then
					return false,"attachments"
				end
			else
				dbg("MDLIsPlayermodel",mdl.name,"no attachments but included")
			end
		end
		
	end
	-- UNDONE: guess why
	--if not found then
	--	return false,"includemdls"
	--end
	--UNDONE: Bones are named all over the place
	--local bname = mdl:BoneNames() [1]
	--if not bname or (	not bname:lower():find("pelvis",1,true)
	--					and bname~="Root"
	--					and bname~="pelvis"
	--					and bname~="hip"
	--					and bname~="root")
	--then
	--	return false,"bones",bname
	--end

	return true, found_anm
end

local badbones = {
	["valvebiped.bip01_r_foot"] = true,
	["valvebiped.bip01_head1"] = true,
	["valvebiped.bip01_head"] = true
}

local spines = {
	["valvebiped.bip01_spine4"] = true,
	["valvebiped.bip01_spine3"] = true,
	["valvebiped.bip01_spine2"] = true,
	["valvebiped.bip01_spine1"] = true
}

local findone = {
	["valvebiped.bip01_r_clavicle"] = true,
	["valvebiped.bip01_r_upperarm"] = true,
	["valvebiped.bip01_r_forearm"] = true,
	["valvebiped.bip01_r_hand"] = true,
	["valvebiped.bip01_l_hand"] = true
}

-- parse model from file
function MDLIsHands(f, sz)
	local mdl, err, err2 = mdlinspect.Open(f)
	if not mdl then return nil, err, err2 end
	if mdl.version < 44 or mdl.version > 49 then return false, "version" end
	local ok, err = mdl:ParseHeader()
	if not ok then return false, err or "hdr" end
	if not mdl.bone_count or mdl.bone_count <= 2 then return false, "nobones" end

	if sz then
		local valid, err = mdl:Validate(sz)

		if not valid then
			dbg("MDLIsHands", f, "validate error", err)

			return false, "valid"
		end
	end

	--print(mdl,mdl.bodypart_count,mdl.skinreference_count)
	local found = false
	local imdls = mdl:IncludedModels()
	--TODO: include stuff or have animations (seqs)
	local found_anm

	for k, v in next, imdls do
		v = v[2]
		if v == "models/m_anm.mdl" then return false, "player" end
		--print("----------------",v)
		if v and not v:find"%.mdl$" then return false, "badinclude", v end

		if v:find("/c_arms_", 1, true) then
			found_anm = true
		end
	end

	local bonenames = mdl:BoneNames()
	local hadspine
	local gotone

	for _, name in next, bonenames do
		name = name:lower()
		--print(name)
		local isspine = spines[name]

		if isspine then 
			if hadspine then
				--return false,'bones',name
			end 
			hadspine = true
		end

		
		gotone = gotone or findone[name]
		if badbones[name] then return false, 'bones', name end
	end

	if not gotone or not hadspine then return false, 'bones' end
	local attachments = mdl:Attachments()

	if attachments and next(attachments) then
		for k, v in next, attachments do
			local name = v[1]
			--print(name)
			if name == "eyes" or name == "anim_attachment_head" or name == "mouth" then return false, "player" end
		end
	end

	return true
end

--[[
local fp ="models/player/"
local flist = file.Find(fp..'*.mdl','GAME')
-- flist = {'matress.mdl'}

for _,fn in next,flist do

	local fpath = fp..fn
	local f = file.Open(fpath,'rb','GAME')
	print(('%50s'):format(fn),MDLIsPlayermodel(f))
	f:Close()
	
end--]]
local t = {"", "", "", ""}

local function GenID(_1, _2, _3, _4, _5)
	if not _1 then return end
	t[1] = _1
	t[2] = tostring(_2)
	t[3] = tostring(_3)
	t[4] = tostring(_4)
	assert(not _5)

	return table.concat(t, "|")
end

local Player = FindMetaTable"Player"

function Player.OutfitHash(pl)
	return pl.outfitter_latest
end

function Player.OutfitUpdateHash(pl)
	local hash = GenID(pl:OutfitInfo())
	pl.outfitter_latest = hash

	return hash
end

function Player.OutfitCheckHash(pl, nhash)
	local cur = pl:OutfitHash()
	cur = cur or false
	nhash = nhash or false

	return cur == nhash
end

function Player.OutfitInfo(pl)
	return pl.outfitter_mdl, pl.outfitter_download_path, pl.outfitter_skin, pl.outfitter_bodygroups
end

function Player.OutfitSetInfo(pl, mdl, download_path, skin, bodygroups)
	pl.outfitter_mdl = mdl
	pl.outfitter_download_path = download_path
	pl.outfitter_skin = skin
	pl.outfitter_bodygroups = bodygroups
	pl:OutfitUpdateHash()
end

local function filt(ok, err, ...)
	if not ok then
		ErrorNoHalt(err .. '\n')

		return nil
	end

	return err, ...
end

function SafeRunHook(...)
	return filt(xpcall(hook.Run, debug.traceback, ...))
end

--- Crashing code detector thingy
--TODO: Stack, blacklist of files
function InitCrashSys()
	local Tag = Tag .. '_blacklist'
	local CrashingTagk = Tag .. 'ing2k'
	local CrashingTagv = Tag .. 'ing2v'

	local function SAVE(t)
		local s = json.encode(t)
		util.SetPData("0", Tag, s)
	end

	local function LOAD()
		local s = util.GetPData("0", Tag, false)
		if not s or s == "" or s == "nil" then return {} end
		local t = json.decode(s)

		return t
	end

	local crashlist = LOAD() or {}

	function GetCrashList()
		return crashlist
	end

	local function SaveList()
		SAVE(crashlist)
	end

	if CLIENT then
		concommand.Add(Tag .. "_clear", function()
			local n = table.Count(crashlist)
			table.Empty(crashlist)
			SAVE()
			chat.AddText("Cleared blacklist (had " .. n .. ")")
		end)

		concommand.Add(Tag .. "_dump", function()
			PrintTable(crashlist)
		end)
	end

	function DidCrash(key, val)
		if IsUnsafe() or not AutoblacklistEnabled() then return false end
		local t = crashlist[key]

		return t and t[val]
	end

	function CRITICAL(a, b)
		util.SetPData("0", CrashingTagk, a or "")
		if not a or a == "" then return end
		util.SetPData("0", CrashingTagv, b)
	end

	-- check for crashes
	local key = util.GetPData("0", CrashingTagk, false)
	if not key or key == "" then return end
	local val = util.GetPData("0", CrashingTagv, "")
	local err = ("[%s] CRASH: %s on %q\n"):format(Tag, tostring(key), tostring(val))
	local t = crashlist[key]

	if not t then
		t = {}
		crashlist[key] = t
	end

	local curval = t[val]
	t[val] = (t[val] and tonumber(t[val]) or 0) + 1
	SaveList()
	SetFailsafe()

	util.OnInitialize(function()
		ErrorNoHalt(err)
	end)
end

if CLIENT then
	InitCrashSys()
end

function MakeURLDownloadable(url)
	url = url:Trim()

	if url:find("dropbox", 4, true) then
		url = url:gsub([[^http%://dl%.dropboxusercontent%.com/]], [[https://dl.dropboxusercontent.com/]])
		url = url:gsub([[^https?://dl.dropbox.com/]], [[https://www.dropbox.com/]])
		url = url:gsub([[^https?://www.dropbox.com/s/(.+)%?dl%=[01]$]], [[https://dl.dropboxusercontent.com/s/%1]])
		url = url:gsub([[^https?://www.dropbox.com/s/(.+)$]], [[https://dl.dropboxusercontent.com/s/%1]])
	end

	if url:find("drive.google.com", 4, true) and not url:find("export=download", 4, true) then
		local id = url:match("https://drive.google.com/file/d/(.-)/") or url:match("https://drive.google.com/file/d/(.-)$") or url:match("https://drive.google.com/open%?id=(.-)$")
		if id then return "https://drive.google.com/uc?export=download&id=" .. id end
	end

	if url:find("gitlab.com", 1, true) then
		url = url:gsub("^(https?://.-/.-/.-/)blob", "%1raw")
	end

	url = url:gsub([[^http%://onedrive%.live%.com/redir?]], [[https://onedrive.live.com/download?]])
	url = url:gsub("pastebin%.com/([a-zA-Z0-9]*)$", "pastebin.com/raw.php?i=%1")
	url = url:gsub("github%.com/([a-zA-Z0-9_]+)/([a-zA-Z0-9_]+)/blob/", "github.com/%1/%2/raw/")

	return url
end