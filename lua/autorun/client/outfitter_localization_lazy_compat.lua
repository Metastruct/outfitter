-- Outfitter localization lazy-compat.
-- If the language library didn't load resource/localization/en/outfitter.properties
-- (e.g. the gma is mounted lazily, so phrases are never registered), hot-load them
-- manually: from the mounted resource files if readable, otherwise by fetching the
-- file over HTTP from the outfitter GitHub repo. Prints a red warning to the console.

if not CLIENT then return end

local check_key = "outfitter_maintitle"
local fetch_url = "https://raw.githubusercontent.com/Metastruct/outfitter/refs/heads/dev/resource/localization/en/outfitter.properties"
local cache_path = "outfitter/localization/en/outfitter.properties"

local local_paths = {
	"resource/localization/en/outfitter.properties",
}

local red = Color(255, 0, 0)
local white = Color(255, 255, 255)

local function localization_loaded()
	local p = language.GetPhrase(check_key)

	return p ~= nil and p ~= "" and p ~= check_key
end

local function unescape(value)
	-- unescape in reverse order so \\n etc. survive
	return value
		:gsub("\\([^\\ntr])", "%1")
		:gsub("\\\\", "\\")
		:gsub("\\n", "\n")
		:gsub("\\t", "\t")
		:gsub("\\r", "\r")
end

local function apply_properties(content)
	if not content or content == "" then return 0 end

	local adds = 0

	for line in content:gmatch("[^\r\n]+") do
		if line:match("^%s*#") or line:match("^%s*$") then continue end

		local key, value = line:match("([^=]+)=(.*)")

		if key and value ~= nil then
			language.Add(key, unescape(value))
			adds = adds + 1
		end
	end

	return adds
end

local fetching = false

local function fetch_from_github()
	if fetching then return end
	fetching = true

	http.Fetch(fetch_url, function(body, _, _, code)
		fetching = false

		local adds = apply_properties(body)

		if adds > 0 then
			file.CreateDir("outfitter/localization/en")
			file.Write(cache_path, body)

			MsgC(red, "[Outfitter] Localization was not loaded, "
				.. "hot-loaded ", white, tostring(adds), red, " phrases from GitHub: ", white, fetch_url, "\n")
		else
			MsgC(red, "[Outfitter] Localization was not loaded and fetching failed (HTTP " .. tostring(code) .. ")\n")
		end
	end, function(err)
		fetching = false

		MsgC(red, "[Outfitter] Localization was not loaded and fetching failed: ")
		MsgC(white, tostring(err), "\n")
	end)
end

local function outfitter_localization_lazy_compat()
	if localization_loaded() then return end

	MsgC(red, "[Outfitter] WARNING: Localization not loaded by the engine (", white, check_key, red, " doesn't resolve), "
		.. "hot-loading it manually.\n")

	for _, path in ipairs(local_paths) do
		local content = file.Read(path, "GAME")
		if content then
			local adds = apply_properties(content)
			if adds > 0 then
				MsgC(red, "[Outfitter] Localization was not loaded, hot-loaded ")
				MsgC(white, tostring(adds), red, " phrases from ", white, path, "\n")
				return
			end
		end
	end

	local cached = file.Read(cache_path, "DATA")
	if cached then
		local adds = apply_properties(cached)
		if adds > 0 then
			MsgC(red, "[Outfitter] Localization was not loaded, hot-loaded ")
			MsgC(white, tostring(adds), red, " phrases from cached copy (", white, cache_path, red, ")\n")
			return
		end
	end

	fetch_from_github()
end

util.OnInitialize(function()
	timer.Simple(0, outfitter_localization_lazy_compat)
end)

concommand.Add("outfitter_reload_localization", outfitter_localization_lazy_compat)