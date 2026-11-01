local Tag = 'outfitter'

module(Tag, package.seeall)

local PER_PAGE = 30
local MAX_BATCHES_PER_PAGE = 8
local PAGE_GRID_SPACING = 16
local PAGE_GRID_MAJOR_EVERY = 5
local CARD_MIN_W = 180
local CARD_FOOTER = 74
local CARD_PADDING = 10
local CARD_GAP = 12
local DESCRIPTION_MAX_LEN = 1500
local DEPENDENCY_ROW_H = 44
local STAR_SIZE = 14
local STAR_SPACING = 2
local MIN_VOTES_FOR_STARS = 25
local REQUIRED_TAGS = { "Model" }
local DEFAULT_SEARCH = "playermodel"

local SORTS = {
	{ "#outfitter_ws_trending", "trending", true },
	{ "#outfitter_ws_popular", "popular", true },
	{ "#outfitter_ws_latest", "latest", true },
	{ "#outfitter_ws_favorites", "favorite" },
	{ "#outfitter_ws_friendfavs", "friend_favs" },
}

local COLOR_PAGE_TOP = Color(40, 59, 97)
local COLOR_PAGE_BOTTOM = Color(41, 45, 50)
local COLOR_PAGE_GRID = Color(20, 24, 32)
local COLOR_PAGE_GRID_MAJOR = Color(27, 34, 44)
local COLOR_DIM = Color(0, 0, 0, 200)
local COLOR_DIALOG = Color(41, 42, 49)
local COLOR_DIALOG_BAR = Color(44, 47, 55)
local COLOR_DIALOG_STATS = Color(38, 39, 46)
local COLOR_TAG = Color(66, 71, 82)
local COLOR_BUTTON = Color(52, 56, 65)
local COLOR_WEAR = Color(102, 158, 26)
local COLOR_WEAR_HOVER = Color(126, 186, 38)
local COLOR_LABEL = Color(115, 118, 123)
local COLOR_BODY = Color(173, 178, 183)
local COLOR_ERROR = Color(235, 90, 80)
local COLOR_CARD_TOP = Color(46, 49, 54)
local COLOR_CARD_BOTTOM = Color(36, 38, 43)
local COLOR_CARD_HOVER_TOP = Color(62, 66, 73)
local COLOR_CARD_HOVER_BOTTOM = Color(46, 49, 54)
local COLOR_INPUT = Color(27, 29, 33)
local COLOR_BORDER = Color(84, 88, 93)
local COLOR_ACCENT = Color(75, 157, 248)
local COLOR_TEXT = Color(255, 255, 255)
local COLOR_TEXT_DIM = Color(177, 178, 180)
local COLOR_TEXT_DISABLED = Color(110, 113, 118)
local COLOR_BADGE = Color(180, 184, 188)
local COLOR_BADGE_TEXT = Color(23, 24, 28)

local FONT_TITLE = 'outfitter_ws_title'
local FONT_TEXT = 'outfitter_ws_text'
local FONT_BADGE = 'outfitter_ws_badge'
local FONT_HEADING = 'outfitter_ws_heading'

surface.CreateFont(FONT_HEADING, { font = "Roboto", size = 25, weight = 700, extended = true })
surface.CreateFont(FONT_TITLE, { font = "Roboto", size = 17, weight = 500, extended = true })
surface.CreateFont(FONT_TEXT, { font = "Roboto", size = 15, weight = 400, extended = true })
surface.CreateFont(FONT_BADGE, { font = "Roboto", size = 14, weight = 400, extended = true })

local matGradient = Material("gui/gradient_down")
local matGradientUp = Material("gui/gradient_up")

local function PaintGradient(x, y, w, h, top, bottom)
	surface.SetDrawColor(bottom)
	surface.DrawRect(x, y, w, h)
	surface.SetDrawColor(top)
	surface.SetMaterial(matGradient)
	surface.DrawTexturedRect(x, y, w, h)
end

local function PaintPage(w, h)
	local fade_h = math.floor(h * 0.75)
	local major_spacing = PAGE_GRID_SPACING * PAGE_GRID_MAJOR_EVERY

	surface.SetDrawColor(COLOR_PAGE_TOP)
	surface.DrawRect(0, 0, w, fade_h)

	render.OverrideBlend(true, BLEND_ONE, BLEND_ONE, BLENDFUNC_ADD)

	surface.SetDrawColor(COLOR_PAGE_GRID)
	for x = PAGE_GRID_SPACING, w, PAGE_GRID_SPACING do
		surface.DrawRect(x % major_spacing == 0 and x + 1 or x, 0, 1, fade_h)
	end
	for y = PAGE_GRID_SPACING, fade_h, PAGE_GRID_SPACING do
		surface.DrawRect(0, y % major_spacing == 0 and y + 1 or y, w, 1)
	end

	surface.SetDrawColor(COLOR_PAGE_GRID_MAJOR)
	for x = major_spacing, w, major_spacing do
		surface.DrawRect(x, 0, 1, fade_h)
	end
	for y = major_spacing, fade_h, major_spacing do
		surface.DrawRect(0, y, w, 1)
	end

	render.OverrideBlend(false)

	surface.SetDrawColor(COLOR_PAGE_BOTTOM)
	surface.SetMaterial(matGradientUp)
	surface.DrawTexturedRect(0, 0, w, fade_h)
	surface.DrawRect(0, fade_h, w, h - fade_h)
end

local function IsResultAllowed(info)
	if info.banned or info.disabled then return false end
	if IsAddonNSFWBlocked(info, info.id) then return false end

	local maxsize = OutfitMaxSize()
	return maxsize <= 0.1 or (info.size or 0) <= maxsize
end

local function Ellipsize(text, font, maxw)
	surface.SetFont(font)
	if surface.GetTextSize(text) <= maxw then return text end

	if not utf8.len(text) then
		text = utf8.force(text)
	end

	local lo, hi = 0, utf8.len(text)
	while lo < hi do
		local mid = math.ceil((lo + hi) / 2)
		if surface.GetTextSize(utf8.sub(text, 1, mid) .. "...") <= maxw then
			lo = mid
		else
			hi = mid - 1
		end
	end

	return utf8.sub(text, 1, lo):TrimRight() .. "..."
end

local function StarCount(info)
	if (info.total or 0) < MIN_VOTES_FOR_STARS then return 0 end
	return math.Clamp(math.ceil((info.score or 0) * 5), 0, 5)
end

local star_cache = {}
local function StarShape(index, x, y)
	local key = index .. ':' .. x .. ':' .. y
	local shape = star_cache[key]
	if shape then return shape end

	local radius = STAR_SIZE / 2
	local cx = x + radius + (index - 1) * (STAR_SIZE + STAR_SPACING)
	local cy = y + radius

	local points = {}
	for i = 0, 9 do
		local r = i % 2 == 0 and radius or radius * 0.42
		local a = math.rad(-90 + i * 36)
		points[i + 1] = { x = cx + math.cos(a) * r, y = cy + math.sin(a) * r }
	end

	local polys = {}
	for i = 1, 10 do
		polys[i] = { { x = cx, y = cy }, points[i], points[i % 10 + 1] }
	end

	shape = { points = points, polys = polys }
	star_cache[key] = shape
	return shape
end

local function PaintStars(count, x, y)
	draw.NoTexture()
	for i = 1, 5 do
		local shape = StarShape(i, x, y)
		if i <= count then
			surface.SetDrawColor(COLOR_ACCENT)
			for _, poly in ipairs(shape.polys) do
				surface.DrawPoly(poly)
			end
		else
			surface.SetDrawColor(COLOR_BORDER)
			local points = shape.points
			for n = 1, 10 do
				local a, b = points[n], points[n % 10 + 1]
				surface.DrawLine(a.x, a.y, b.x, b.y)
			end
		end
	end
end

local function StyleButton(b, base, hover)
	base = base or COLOR_INPUT
	hover = hover or COLOR_ACCENT

	b:SetFont(FONT_TEXT)
	b.UpdateColours = function(b)
		b:SetTextStyleColor(b:IsEnabled() and COLOR_TEXT or COLOR_TEXT_DISABLED)
	end
	b.Paint = function(b, w, h)
		local color = COLOR_INPUT
		if b:IsEnabled() then
			color = b:IsHovered() and hover or base
		end
		draw.RoundedBox(2, 0, 0, w, h, color)
	end
end

local function WorkshopPageURL(wsid)
	return "https://steamcommunity.com/sharedfiles/filedetails/?id=" .. wsid
end

local CARD = {}

function CARD:Init()
	self:SetText("")

	local icon = self:Add('DOWorkshopIcon')
	self.icon = icon
	icon:SetFullBleed(true)
	icon:SetMouseInputEnabled(false)
end

function CARD:SetInfo(info)
	self.info = info
	self.icon:SetFileInfo(info)
	self.stars = StarCount(info)
	self:SetTooltip(info.title or "")

	local total = info.total or 0
	local parts = {}
	if total > 0 then
		local phrase = total == 1 and "outfitter_ws_rating" or "outfitter_ws_ratings"
		parts[1] = language.GetPhrase(phrase):format(string.Comma(total))
	end
	parts[#parts + 1] = string.NiceSize(info.size or 0)
	self.badge = table.concat(parts, ", ")
end

function CARD:DoRightClick()
	local m = DermaMenu()
	m:AddOption("#outfitter_openws", function()
		gui.OpenURL(WorkshopPageURL(self.info.id))
	end):SetIcon 'icon16/world.png'
	m:Open()
end

function CARD:PerformLayout(w, h)
	self.icon:SetPos(0, 0)
	self.icon:SetSize(w, w)

	local info = self.info
	if not info then return end

	local maxw = w - CARD_PADDING * 2
	self.title = Ellipsize(info.title or "", FONT_TITLE, maxw)

	local owner = info.ownername or ""
	self.author = owner ~= "" and Ellipsize(language.GetPhrase("outfitter_ws_by"):format(owner), FONT_TEXT, maxw) or ""
end

function CARD:Paint(w, h)
	local hovered = self:IsHovered()
	PaintGradient(0, w, w, h - w, hovered and COLOR_CARD_HOVER_TOP or COLOR_CARD_TOP, hovered and COLOR_CARD_HOVER_BOTTOM or COLOR_CARD_BOTTOM)

	PaintStars(self.stars or 0, CARD_PADDING, w + 8)
	draw.SimpleText(self.title or "", FONT_TITLE, CARD_PADDING, w + 26, COLOR_TEXT)
	draw.SimpleText(self.author or "", FONT_TEXT, CARD_PADDING, w + 49, COLOR_TEXT_DIM)
end

function CARD:PaintOver(w, h)
	if not self.badge or not self:IsHovered() then return end

	surface.SetFont(FONT_BADGE)
	local tw, th = surface.GetTextSize(self.badge)
	local bh = th + 8
	draw.RoundedBox(2, 8, w - bh - 8, tw + 14, bh, COLOR_BADGE)
	draw.SimpleText(self.badge, FONT_BADGE, 15, w - bh - 4, COLOR_BADGE_TEXT)
end

vgui.Register(Tag .. '_workshop_card', CARD, 'DButton')

local BBCODE_TAGS = {
	b = true, i = true, u = true, s = true, strike = true, spoiler = true, noparse = true, hr = true,
	h1 = true, h2 = true, h3 = true, url = true, list = true, olist = true, ["*"] = true,
	quote = true, code = true, table = true, tr = true, th = true, td = true, img = true,
	previewyoutube = true, previewicon = true,
}

local function DescriptionText(text)
	text = (text or ""):gsub("\r", "")
	text = text:gsub("%[[iI][mM][gG]%].-%[/[iI][mM][gG]%]", "")
	text = text:gsub("%[/?([%w%*]+)[^%]\n]*%]", function(tag)
		if BBCODE_TAGS[tag:lower()] then return "" end
	end)
	text = text:gsub("\n%s*\n[%s\n]*", "\n\n"):Trim()

	if #text > DESCRIPTION_MAX_LEN then
		if not utf8.len(text) then
			text = utf8.force(text)
		end
		text = utf8.sub(text, 1, DESCRIPTION_MAX_LEN):TrimRight() .. "..."
	end

	return text
end

local function GalleryURLs(info)
	local urls, seen = {}, {}

	local function add(url)
		if isstring(url) and url:match("^https://[%w%.%-_/%?=&%%]+$") and not seen[url] then
			seen[url] = true
			urls[#urls + 1] = url
		end
	end

	add(info.previewurl)
	for _, preview in ipairs(info.extra_previews or {}) do
		if preview.type == 0 then
			add(preview.url)
		end
	end

	return urls
end

local GALLERY_HTML = [[<!doctype html><html><head><meta charset="utf-8"><style>
html, body { margin: 0; height: 100%; overflow: hidden; background: #24262d; }
div { box-sizing: border-box; }
.image { background-color: #1e2026; background-repeat: no-repeat; background-position: center; background-size: contain; }
#main { position: absolute; top: 0; left: 0; right: 0; bottom: 80px; }
#main.single { bottom: 0; }
#strip { position: absolute; left: 0; right: 0; bottom: 0; height: 72px; }
#scroll { position: absolute; top: 0; bottom: 0; left: 30px; right: 30px; overflow: hidden; white-space: nowrap; font-size: 0; }
.thumb { display: inline-block; width: 128px; height: 72px; margin-right: 6px; border: 1px solid transparent; cursor: pointer; }
.thumb:hover, .thumb.on { border-color: #fff; }
.arrow { position: absolute; top: 0; bottom: 0; width: 24px; background: #343841; color: #fff; font: 16px/72px sans-serif; text-align: center; cursor: pointer; }
.arrow:hover { background: #4b9df8; }
#prev { left: 0; }
#next { right: 0; }
</style></head><body>
<div id="main" class="image"></div>
<div id="strip"><div id="prev" class="arrow">&lt;</div><div id="scroll"></div><div id="next" class="arrow">&gt;</div></div>
<script>
var urls = {{URLS}};
var main = document.getElementById("main");
var strip = document.getElementById("strip");
var scroll = document.getElementById("scroll");
var thumbs = [];
var selected = 0;

function sel(index) {
	selected = Math.max(0, Math.min(urls.length - 1, index));
	main.style.backgroundImage = "url('" + urls[selected] + "')";
	for (var i = 0; i < thumbs.length; i++) {
		thumbs[i].className = i == selected ? "thumb image on" : "thumb image";
	}
	var thumb = thumbs[selected];
	if (thumb) {
		if (thumb.offsetLeft - scroll.offsetLeft < scroll.scrollLeft) {
			scroll.scrollLeft = thumb.offsetLeft - scroll.offsetLeft;
		} else if (thumb.offsetLeft - scroll.offsetLeft + thumb.offsetWidth > scroll.scrollLeft + scroll.clientWidth) {
			scroll.scrollLeft = thumb.offsetLeft - scroll.offsetLeft + thumb.offsetWidth - scroll.clientWidth;
		}
	}
}

function makeThumb(index) {
	var thumb = document.createElement("div");
	thumb.style.backgroundImage = "url('" + urls[index] + "')";
	thumb.onclick = function() { sel(index); };
	scroll.appendChild(thumb);
	thumbs.push(thumb);
}

if (urls.length > 1) {
	for (var i = 0; i < urls.length; i++) {
		makeThumb(i);
	}
	document.getElementById("prev").onclick = function() { sel(selected - 1); };
	document.getElementById("next").onclick = function() { sel(selected + 1); };
} else {
	strip.style.display = "none";
	main.className = "image single";
}

if (urls.length > 0) {
	sel(0);
}
</script></body></html>]]

local function SectionLabel(parent, text)
	local label = parent:Add('DLabel')
	label:Dock(TOP)
	label:DockMargin(0, 14, 0, 4)
	label:SetTall(18)
	label:SetFont(FONT_TEXT)
	label:SetTextColor(COLOR_LABEL)
	label:SetText(text)
	return label
end

local QUICK = {}

function QUICK:Init()
	local dialog = self:Add('EditablePanel')
	self.dialog = dialog
	dialog.Paint = function(_, w, h)
		surface.SetDrawColor(COLOR_DIALOG)
		surface.DrawRect(0, 0, w, h)

		local media = self.media
		if media:GetAlpha() == 0 then
			local x, y, mw, mh = media:GetBounds()
			draw.SimpleText(language.GetPhrase("outfitter_loadinginfo"), FONT_TEXT, x + mw / 2, y + mh / 2, COLOR_BODY, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	local bar = dialog:Add('EditablePanel')
	bar:Dock(BOTTOM)
	bar:SetTall(48)
	bar:DockPadding(10, 9, 10, 9)
	bar.Paint = function(_, w, h)
		surface.SetDrawColor(COLOR_DIALOG_BAR)
		surface.DrawRect(0, 0, w, h)
	end

	local wear = bar:Add('DButton')
	wear:Dock(LEFT)
	wear:SetWide(110)
	wear:SetText("#outfitter_ws_wear")
	StyleButton(wear, COLOR_WEAR, COLOR_WEAR_HOVER)
	wear.DoClick = function()
		self.OnWear(self.info)
	end

	local open = bar:Add('DButton')
	open:Dock(LEFT)
	open:DockMargin(8, 0, 0, 0)
	open:SetWide(160)
	open:SetText("#outfitter_openws")
	StyleButton(open, COLOR_BUTTON)
	open.DoClick = function()
		gui.OpenURL(WorkshopPageURL(self.info.id))
	end

	local close = bar:Add('DButton')
	close:Dock(RIGHT)
	close:SetWide(90)
	close:SetText("#outfitter_close")
	StyleButton(close, COLOR_BUTTON)
	close.DoClick = function()
		self:Remove()
	end

	local media = dialog:Add('DHTML')
	self.media = media
	media:Dock(LEFT)
	media:DockMargin(12, 12, 0, 12)
	media:SetAlpha(0)
	media.OnDocumentReady = function(media)
		media:SetAlpha(255)
	end

	local details = dialog:Add('DScrollPanel')
	self.details = details
	details:Dock(FILL)
	details:DockMargin(14, 12, 6, 12)

	local vbar = details:GetVBar()
	vbar:SetHideButtons(true)
	vbar:SetWide(8)
	vbar.Paint = function(_, w, h)
		draw.RoundedBox(4, 0, 0, w, h, COLOR_INPUT)
	end
	vbar.btnGrip.Paint = function(grip, w, h)
		draw.RoundedBox(4, 0, 0, w, h, grip:IsHovered() and COLOR_ACCENT or COLOR_BORDER)
	end

	local header = details:Add('EditablePanel')
	self.header = header
	header:Dock(TOP)
	header:DockMargin(0, 0, 10, 0)
	header:SetTall(46)
	header.Paint = function(_, w)
		local rating_w = STAR_SIZE * 5 + STAR_SPACING * 4
		PaintStars(self.stars or 0, w - rating_w, 4)
		draw.SimpleText(self.ratings or "", FONT_TEXT, w, 22, COLOR_BODY, TEXT_ALIGN_RIGHT)
	end

	local title = header:Add('DLabel')
	self.title = title
	title:SetFont(FONT_HEADING)
	title:SetTextColor(COLOR_TEXT)
	title:SetWrap(true)
	title:SetContentAlignment(7)
	header.PerformLayout = function(_, w)
		title:SetPos(0, 0)
		title:SetWide(math.max(w - 110, 100))
		local _, th = title:GetContentSize()
		title:SetTall(th)
		header:SetTall(math.max(th, 46))
	end

	local created = details:Add('DLabel')
	self.created = created
	created:Dock(TOP)
	created:DockMargin(0, 4, 10, 0)
	created:SetTall(20)
	created:SetFont(FONT_TEXT)
	created:SetTextColor(COLOR_BODY)

	local stats = details:Add('Panel')
	self.stats = stats
	stats:Dock(TOP)
	stats:DockMargin(0, 8, 10, 0)
	stats:SetTall(78)
	stats.Paint = function(_, w, h)
		surface.SetDrawColor(COLOR_DIALOG_STATS)
		surface.DrawRect(0, 0, w, h)
		for i, row in ipairs(self.stat_rows or {}) do
			local y = 8 + (i - 1) * 21
			draw.SimpleText(row[1], FONT_TEXT, 12, y, COLOR_LABEL)
			draw.SimpleText(row[2], FONT_TEXT, 100, y, COLOR_BODY)
		end
	end

	self.tags_label = SectionLabel(details, "#outfitter_ws_tags")
	self.tags_label:DockMargin(0, 14, 10, 4)

	local tags = details:Add('DIconLayout')
	self.tags = tags
	tags:Dock(TOP)
	tags:DockMargin(0, 0, 10, 0)
	tags:SetSpaceX(6)
	tags:SetSpaceY(6)

	self.deps_label = SectionLabel(details, "#outfitter_ws_required")
	self.deps_label:DockMargin(0, 14, 10, 4)

	local deps = details:Add('EditablePanel')
	self.deps = deps
	deps:Dock(TOP)
	deps:DockMargin(0, 0, 10, 0)
	deps:SetTall(0)

	local deps_status = details:Add('DLabel')
	self.deps_status = deps_status
	deps_status:Dock(TOP)
	deps_status:DockMargin(0, 6, 10, 0)
	deps_status:SetWrap(true)
	deps_status:SetAutoStretchVertical(true)
	deps_status:SetFont(FONT_TEXT)
	deps_status:SetTextColor(COLOR_BODY)

	local description = details:Add('DLabel')
	self.description = description
	description:Dock(TOP)
	description:DockMargin(0, 14, 10, 6)
	description:SetWrap(true)
	description:SetAutoStretchVertical(true)
	description:SetContentAlignment(7)
	description:SetFont(FONT_TEXT)
	description:SetTextColor(COLOR_BODY)
end

function QUICK:SetDependenciesVisible(visible)
	self.deps_label:SetVisible(visible)
	self.deps:SetVisible(visible)
	self.deps_status:SetVisible(visible)
end

function QUICK:SetInfo(info)
	self.info = info
	self.stars = StarCount(info)

	local total = info.total or 0
	local ratings = total == 1 and "outfitter_ws_rating" or "outfitter_ws_ratings"
	self.ratings = total > 0 and language.GetPhrase(ratings):format(string.Comma(total)) or language.GetPhrase("outfitter_ws_noratings")

	self.title:SetText(info.title or "")
	self.created:SetText(language.GetPhrase("outfitter_ws_created"):format(info.ownername or ""))

	self.stat_rows = {
		{ language.GetPhrase("outfitter_ws_posted"), os.date("%d %b %Y", info.created or 0) },
		{ language.GetPhrase("outfitter_ws_updated"), os.date("%d %b %Y", info.updated or 0) },
		{ language.GetPhrase("outfitter_ws_filesize"), string.NiceSize(info.size or 0) },
	}

	self.tags:Clear()
	local has_tags = false
	for _, name in ipairs(string.Explode(",", info.tags or "")) do
		name = name:Trim()
		if name ~= "" then
			has_tags = true
			local tag = self.tags:Add('DLabel')
			tag:SetFont(FONT_TEXT)
			tag:SetTextColor(COLOR_TEXT)
			tag:SetContentAlignment(5)
			tag:SetText(name)
			local tw = tag:GetContentSize()
			tag:SetSize(tw + 20, 24)
			tag.Paint = function(_, w, h)
				draw.RoundedBox(2, 0, 0, w, h, COLOR_TAG)
			end
		end
	end
	self.tags_label:SetVisible(has_tags)
	self.tags:SetVisible(has_tags)

	self.description:SetText(DescriptionText(info.description))
	self:FetchExtraInfo(info)
	self:FetchDependencies(info)
end

function QUICK:FetchExtraInfo(info)
	steamworks.FileInfo(info.id, function(extra)
		if not IsValid(self) then return end

		if not extra or extra.error then
			extra = info
		end

		self.description:SetText(DescriptionText(extra.description))
		self.media:SetHTML(string.Replace(GALLERY_HTML, "{{URLS}}", util.TableToJSON(GalleryURLs(extra))))
	end, true)
end

function QUICK:FetchDependencies(info)
	self:SetDependenciesVisible(true)
	self.deps_status:SetTextColor(COLOR_BODY)
	self.deps_status:SetText("#outfitter_depscheck")

	co(function()
		local graph, err = coResolveWSDependencies(info.id)
		if not IsValid(self) then return end
		self:ShowDependencies(graph, err)
	end)
end

function QUICK:ShowDependencies(graph, err)
	if not graph then
		self.deps_status:SetTextColor(COLOR_ERROR)
		self.deps_status:SetText(language.GetPhrase("outfitter_ws_depsfailed"):format(tostring(err)))
		return
	end

	if graph.count == 0 then
		self:SetDependenciesVisible(false)
		return
	end

	local root = graph.nodes[graph.root]
	local total = root and root.size or 0
	for i, id in ipairs(graph.order) do
		local node = graph.nodes[id]
		if not node.error then
			total = total + node.size
		end
		self:AddDependencyRow(id, node, i)
	end
	self.deps:SetTall(#graph.order * DEPENDENCY_ROW_H)

	local text = language.GetPhrase("outfitter_ws_depstotal"):format(string.NiceSize(total))
	local maxsize = OutfitMaxSize()
	local oversize = maxsize > 0.1 and total > maxsize
	if oversize then
		text = text .. "\n" .. language.GetPhrase("outfitter_ws_depsoversize"):format(string.NiceSize(maxsize))
	end
	self.deps_status:SetTextColor(oversize and COLOR_ERROR or COLOR_BODY)
	self.deps_status:SetText(text)
end

function QUICK:AddDependencyRow(id, node, index)
	local row = self.deps:Add('DButton')
	row:Dock(TOP)
	row:DockMargin(0, index > 1 and 4 or 0, 0, 0)
	row:SetTall(DEPENDENCY_ROW_H - 4)
	row:SetText("")
	row:SetTooltip(node.title or id)
	row.DoClick = function()
		gui.OpenURL(WorkshopPageURL(id))
	end

	local title = node.title or id
	local detail = node.error and language.GetPhrase("outfitter_ws_unavailable") or string.NiceSize(node.size)
	local detail_color = node.error and COLOR_ERROR or COLOR_BODY

	local thumb = row:Add('DOWorkshopIcon')
	thumb:SetPos(4, 4)
	thumb:SetSize(DEPENDENCY_ROW_H - 12, DEPENDENCY_ROW_H - 12)
	thumb:SetFullBleed(true)
	thumb:SetMouseInputEnabled(false)
	if not node.error then
		thumb:SetAddon({ wsid = id, title = title })
	end

	row.Paint = function(row, w, h)
		surface.SetDrawColor(row:IsHovered() and COLOR_TAG or COLOR_DIALOG_STATS)
		surface.DrawRect(0, 0, w, h)

		surface.SetFont(FONT_TEXT)
		local dw = surface.GetTextSize(detail)
		local left = h + 4
		draw.SimpleText(Ellipsize(title, FONT_TEXT, w - left - dw - 22), FONT_TEXT, left, h / 2, COLOR_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(detail, FONT_TEXT, w - 10, h / 2, detail_color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
end

function QUICK:Think()
	local parent = self:GetParent()
	local pw, ph = parent:GetSize()
	if self:GetWide() ~= pw or self:GetTall() ~= ph then
		self:SetSize(pw, ph)
	end

	local canvas = self.details:GetCanvas()
	local _, y, _, h = self.description:GetBounds()
	if y + h + 6 ~= canvas:GetTall() then
		self.details:InvalidateLayout()
	end
end

function QUICK:PerformLayout(w, h)
	local margin = 16
	local dialog = self.dialog
	dialog:SetPos(margin, margin)
	dialog:SetSize(w - margin * 2, h - margin * 2)
	self.media:SetWide(math.floor(dialog:GetWide() * 0.48))
end

function QUICK:Paint(w, h)
	surface.SetDrawColor(COLOR_DIM)
	surface.DrawRect(0, 0, w, h)
end

function QUICK:OnMousePressed()
	local x, y = self.dialog:CursorPos()
	if x < 0 or y < 0 or x > self.dialog:GetWide() or y > self.dialog:GetTall() then
		self:Remove()
	end
end

vgui.Register(Tag .. '_workshop_quickview', QUICK, 'EditablePanel')

local PANEL = {}

function PANEL:Init()
	self:SetTitle("#outfitter_ws_title_browser")
	self:SetIcon('icon16/folder_user.png')
	self:SetSize(math.min(ScrW() - 64, 1056), math.min(ScrH() - 64, 720))
	self:SetMinWidth(400)
	self:SetMinHeight(320)
	self:SetSizable(true)
	self:SetDeleteOnClose(false)
	self:Center()

	self.sort = SORTS[1]
	self.query = ""
	self:ResetPages()

	local body = self:Add('EditablePanel')
	self.body = body
	body:Dock(FILL)
	body:DockPadding(12, 12, 12, 12)
	body.Paint = function(_, w, h)
		PaintPage(w, h)
	end

	local toolbar = body:Add('EditablePanel')
	toolbar:Dock(TOP)
	toolbar:DockMargin(0, 0, 0, 12)
	toolbar:SetTall(30)

	local sort = toolbar:Add('DComboBox')
	sort:Dock(RIGHT)
	sort:DockMargin(8, 0, 0, 0)
	sort:SetWide(170)
	sort:SetSortItems(false)
	sort:SetFont(FONT_TEXT)
	sort.UpdateColours = function(sort)
		sort:SetTextStyleColor(COLOR_TEXT)
	end
	sort.Paint = function(_, w, h)
		draw.RoundedBox(2, 0, 0, w, h, COLOR_INPUT)
	end
	sort.DropButton.Paint = function(_, w, h)
		local cx, cy = w / 2, h / 2
		draw.NoTexture()
		surface.SetDrawColor(COLOR_TEXT_DIM)
		surface.DrawPoly({ { x = cx - 5, y = cy - 2 }, { x = cx + 5, y = cy - 2 }, { x = cx, y = cy + 3 } })
	end
	local openmenu = sort.OpenMenu
	sort.OpenMenu = function(sort, ...)
		openmenu(sort, ...)

		local menu = sort.Menu
		if not IsValid(menu) then return end

		menu.Paint = function(_, w, h)
			surface.SetDrawColor(COLOR_INPUT)
			surface.DrawRect(0, 0, w, h)
		end
		for _, option in ipairs(menu:GetCanvas():GetChildren()) do
			option:SetFont(FONT_TEXT)
			option.UpdateColours = function(option)
				option:SetTextStyleColor(COLOR_TEXT)
			end
			option.Paint = function(option, w, h)
				if option:IsHovered() then
					surface.SetDrawColor(COLOR_ACCENT)
					surface.DrawRect(0, 0, w, h)
				end
			end
		end
	end
	for i, v in ipairs(SORTS) do
		sort:AddChoice(v[1], v, i == 1)
	end
	sort.OnSelect = function(_, _, _, data)
		self.sort = data
		self:ResetPages()
		self:Fetch()
	end

	local search = toolbar:Add('DTextEntry')
	self.search = search
	search:Dock(FILL)
	search:SetFont(FONT_TEXT)
	search:SetPlaceholderText("#outfitter_ws_search")
	search.Paint = function(search, w, h)
		draw.RoundedBox(2, 0, 0, w, h, COLOR_INPUT)
		if search:HasFocus() then
			surface.SetDrawColor(COLOR_ACCENT)
			surface.DrawOutlinedRect(0, 0, w, h)
		end
		if search:GetValue() == "" then
			draw.SimpleText(language.GetPhrase("outfitter_ws_search"), FONT_TEXT, 4, h / 2, COLOR_TEXT_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		search:DrawTextEntryText(COLOR_TEXT, COLOR_ACCENT, COLOR_TEXT)
	end
	search.OnEnter = function()
		self:Search(search:GetValue())
	end

	local footer = body:Add('EditablePanel')
	footer:Dock(BOTTOM)
	footer:DockMargin(0, 12, 0, 0)
	footer:SetTall(28)

	local prev = footer:Add('DButton')
	self.prev = prev
	prev:Dock(LEFT)
	prev:SetWide(96)
	prev:SetText("#outfitter_ws_prev")
	StyleButton(prev)
	prev.DoClick = function()
		self.page = math.max(self.page - 1, 1)
		self:Fetch()
	end

	local nextb = footer:Add('DButton')
	self.next = nextb
	nextb:Dock(RIGHT)
	nextb:SetWide(96)
	nextb:SetText("#outfitter_ws_next")
	StyleButton(nextb)
	nextb.DoClick = function()
		self.page = self.page + 1
		self:Fetch()
	end

	local status = footer:Add('DLabel')
	self.status = status
	status:Dock(FILL)
	status:SetFont(FONT_TEXT)
	status:SetTextColor(COLOR_TEXT_DIM)
	status:SetContentAlignment(5)
	status:SetText("")

	local notice = body:Add('DLabel')
	self.notice = notice
	notice:Dock(TOP)
	notice:SetTall(64)
	notice:SetFont(FONT_TITLE)
	notice:SetTextColor(COLOR_TEXT)
	notice:SetContentAlignment(5)
	notice:SetVisible(false)

	local scroll = body:Add('DScrollPanel')
	self.scroll = scroll
	scroll:Dock(FILL)

	local vbar = scroll:GetVBar()
	vbar:SetHideButtons(true)
	vbar:SetWide(8)
	vbar.Paint = function(_, w, h)
		draw.RoundedBox(4, 0, 0, w, h, COLOR_INPUT)
	end
	vbar.btnGrip.Paint = function(grip, w, h)
		draw.RoundedBox(4, 0, 0, w, h, grip:IsHovered() and COLOR_ACCENT or COLOR_BORDER)
	end

	local grid = scroll:Add('DIconLayout')
	self.grid = grid
	grid:Dock(TOP)
	grid:DockMargin(0, 0, 8, 0)
	grid:SetSpaceX(CARD_GAP)
	grid:SetSpaceY(CARD_GAP)

	local layout = grid.PerformLayout
	grid.PerformLayout = function(grid, w, h)
		local width = grid:GetWide()
		local columns = math.max(math.floor((width + CARD_GAP) / (CARD_MIN_W + CARD_GAP)), 1)
		local cardw = math.floor((width - (columns - 1) * CARD_GAP) / columns)
		for _, card in ipairs(grid:GetChildren()) do
			if card:GetWide() ~= cardw then
				card:SetSize(cardw, cardw + CARD_FOOTER)
				grid.LastW = 0
			end
		end

		layout(grid, w, h)

		if scroll:GetCanvas():GetTall() ~= grid:GetTall() then
			scroll:InvalidateLayout()
		end
	end
end

function PANEL:ResetPages()
	self.page = 1
	self.page_starts = { 0 }
end

function PANEL:SetNotice(text)
	self.notice:SetText(text or "")
	self.notice:SetVisible(text and true or false)
	self.notice:GetParent():InvalidateLayout()
end

function PANEL:Search(str)
	str = (str or ""):Trim()

	local wsid = UrlToWorkshopID(str, true)
	if wsid then
		self:Choose(wsid)
		return
	end

	self.query = str
	self:ResetPages()
	self:Fetch()
end

function PANEL:SearchText()
	if self.query ~= "" then return self.query end
	return self.sort[3] and DEFAULT_SEARCH or nil
end

function PANEL:Fetch()
	self.loaded_maxsize = OutfitMaxSize()
	self.request = (self.request or 0) + 1

	self.grid:Clear()
	self.prev:SetEnabled(false)
	self.next:SetEnabled(false)
	self.status:SetText("")
	self:SetNotice("#outfitter_loadinginfo")

	self.shown = 0
	self.hidden = 0
	self.page_starts[self.page + 1] = nil

	self:FetchBatch(self.request, self.page_starts[self.page], 1)
end

function PANEL:FetchBatch(request, offset, batch)
	steamworks.GetList(self.sort[2], REQUIRED_TAGS, offset, PER_PAGE, 0, "0", function(data)
		if not IsValid(self) or self.request ~= request then return end

		if not data then
			self:FinishPage(self.shown > 0 and nil or "#outfitter_ws_failed")
			return
		end

		self:FetchInfos(data, request, offset, batch)
	end, self:SearchText())
end

function PANEL:FetchInfos(data, request, offset, batch)
	local ids = {}
	for i = 0, (data.numresults or 0) - 1 do
		local id = data.results and data.results[i]
		if id then
			ids[#ids + 1] = id
		end
	end

	local total = data.totalresults or 0
	local count = #ids
	if count == 0 then
		self:ShowBatch({}, 0, total, request, offset, batch)
		return
	end

	local infos = {}
	local remaining = count
	for n, id in ipairs(ids) do
		steamworks.FileInfo(id, function(info)
			if not IsValid(self) or self.request ~= request then return end

			infos[n] = info or false
			remaining = remaining - 1
			if remaining == 0 then
				self:ShowBatch(infos, count, total, request, offset, batch)
			end
		end)
	end
end

function PANEL:ShowBatch(infos, count, total, request, offset, batch)
	local consumed = 0
	for n = 1, count do
		if self.shown >= PER_PAGE then break end

		consumed = n

		local info = infos[n]
		if info and IsResultAllowed(info) then
			self:AddCard(info)
			self.shown = self.shown + 1
		else
			self.hidden = self.hidden + 1
		end
	end

	if self.shown > 0 then
		self:SetNotice(nil)
	end

	local next_offset = offset + consumed
	local has_more = count > 0 and next_offset < total

	if has_more and self.shown < PER_PAGE and batch < MAX_BATCHES_PER_PAGE then
		self:FetchBatch(request, next_offset, batch + 1)
		return
	end

	self.page_starts[self.page + 1] = has_more and next_offset or nil
	self:FinishPage(self.shown == 0 and "#outfitter_ws_noresults" or nil)
end

function PANEL:FinishPage(notice)
	self.grid:Layout()
	self.scroll:GetVBar():SetScroll(0)
	self:SetNotice(notice)

	self.prev:SetEnabled(self.page > 1)
	self.next:SetEnabled(self.page_starts[self.page + 1] ~= nil)

	local text = language.GetPhrase("outfitter_ws_page"):format(string.Comma(self.page))
	if self.hidden > 0 then
		text = text .. "  (" .. language.GetPhrase("outfitter_ws_hidden"):format(self.hidden) .. ")"
	end
	self.status:SetText(text)
end

function PANEL:AddCard(info)
	local card = self.grid:Add(Tag .. '_workshop_card')
	card:SetSize(CARD_MIN_W, CARD_MIN_W + CARD_FOOTER)
	card:SetInfo(info)
	card.DoClick = function()
		self:OpenQuickView(info)
	end
end

function PANEL:CloseQuickView()
	if IsValid(self.quickview) then
		self.quickview:Remove()
	end
end

function PANEL:OpenQuickView(info)
	self:CloseQuickView()

	local quickview = self.body:Add(Tag .. '_workshop_quickview')
	self.quickview = quickview
	quickview:SetSize(self.body:GetSize())
	quickview.OnWear = function(wear_info)
		self:Choose(wear_info.id)
	end
	quickview:SetInfo(info)
end

function PANEL:Choose(wsid)
	self:CloseQuickView()
	self:SetVisible(false)
	surface.PlaySound "npc/vort/claw_swing1.wav"
	UIChoseWorkshop(tonumber(wsid), self.returntoui, true)
end

function PANEL:OnClose()
	self:CloseQuickView()
	if self.returntoui then
		GUIOpen()
	end
end

function PANEL:Open(str, returntoui)
	self.returntoui = returntoui
	self:SetVisible(true)
	self:MakePopup()

	if str and tostring(str) ~= "" then
		self.search:SetValue(tostring(str))
		self:Search(tostring(str))
	elseif self.loaded_maxsize ~= OutfitMaxSize() then
		self:ResetPages()
		self:Fetch()
	end
end

vgui.Register(Tag .. '_workshop', PANEL, 'DFrame')

local prev = rawget(_M, 'm_vModelDlg')
if ValidPanel(prev) then prev:Remove() end
m_vModelDlg = NULL

function GUIWantChangeModel(str, returntoui)
	if not ValidPanel(m_vModelDlg) then
		m_vModelDlg = vgui.Create(Tag .. '_workshop', nil, Tag)
	end

	m_vModelDlg:Open(str, returntoui)

	return m_vModelDlg
end
