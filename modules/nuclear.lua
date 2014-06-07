local modPath = '/mods/EM/'
local boolstr = import(modPath .. 'modules/utils.lua').boolstr
local addListener = import(modPath .. 'modules/init.lua').addListener

local getUnits = import(modPath .. 'modules/units.lua').getUnits

local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local Button = import('/lua/maui/button.lua').Button
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local ItemList = import('/lua/maui/itemlist.lua').ItemList
local Group = import('/lua/maui/group.lua').Group
local UIUtil = import('/lua/ui/uiutil.lua')
local GameCommon = import('/lua/ui/game/gamecommon.lua')
local ToolTip = import('/lua/ui/game/tooltip.lua')
local TooltipInfo = import('/lua/ui/help/tooltips.lua').Tooltips
local AvatarsClickFunc = import('/lua/ui/game/avatars.lua').ClickFunc
local StatusBar = import('/lua/maui/statusbar.lua').StatusBar

local nukeButton = nil

local overlays = {}

function CreateTextBG(parent, control, color )
	background = Bitmap(control)
	background:SetSolidColor(color)
	background.Top:Set(control.Top)
	background.Left:Set(control.Left)
	background.Right:Set(control.Right)
	background.Bottom:Set(control.Bottom)
	background.Depth:Set(function() return parent.Depth() + 1 end)
end

function createButton(parent)
	local buttonBackgroundName = UIUtil.SkinnableFile('/game/avatar-factory-panel/avatar-s-e-f_bmp.dds')

	local bg = Bitmap(parent, buttonBackgroundName)

    bg.Height:Set(64)
    bg.Width:Set(64)

	bg.units = {}
	bg.HandleEvent = AvatarsClickFunc

	bg.icon = Bitmap(bg)
    bg.icon.Height:Set(48)
    bg.icon.Width:Set(48)

	LayoutHelpers.AtCenterIn(bg.icon, bg, 0)

	bg.nuke_progress = StatusBar(bg, 0, 1, false, false,
							UIUtil.UIFile('/game/unit-over/health-bars-back-1_bmp.dds'),
							UIUtil.UIFile('/game/unit-over/bar01_bmp.dds'), true, "Unit RO Health Status Bar")

	bg.nuke_progress.Width:Set(52)
    bg.nuke_progress.Height:Set(0)

    LayoutHelpers.AtLeftTopIn(bg.nuke_progress, bg, 6, 2)

    bg.def_progress = StatusBar(bg, 0, 1, false, false,
							UIUtil.UIFile('/game/unit-over/health-bars-back-1_bmp.dds'),
							UIUtil.UIFile('/game/unit-over/bar01_bmp.dds'), true, "Unit RO Health Status Bar")

	bg.def_progress.Width:Set(52)
    bg.def_progress.Height:Set(0)

    LayoutHelpers.AtLeftTopIn(bg.def_progress, bg, 6, 56)

    bg.nuke_count = UIUtil.CreateText(bg.icon, '', 12, UIUtil.bodyFont)
	bg.nuke_count:SetColor('red')
    bg.nuke_count:SetDropShadow(true)
	LayoutHelpers.AtTopIn(bg.nuke_count, bg.icon, 2)
    LayoutHelpers.AtRightIn(bg.nuke_count, bg.icon, 4)

    bg.def_count = UIUtil.CreateText(bg.icon, '', 12, UIUtil.bodyFont)
	bg.def_count:SetColor('green')
    bg.def_count:SetDropShadow(true)
	LayoutHelpers.AtBottomIn(bg.def_count, bg.icon, 2)
    LayoutHelpers.AtRightIn(bg.def_count, bg.icon, 4)

	CreateTextBG(bg, bg.nuke_count, '77000000')
	CreateTextBG(bg, bg.def_count,  '77000000')

	return bg
end

function siloData(silos)
	local data = {progress=0, count=0}

	for _, u in silos do
		local p = u:GetWorkProgress()
		local info = u:GetMissileInfo()

		if(u:GetWorkProgress() > data.progress) then
			data.progress = p
		end

		data.count = data.count + info.nukeSiloStorageCount + info.tacticalSiloStorageCount
	end

	return data
end

function updateButton()
	local button = nukeButton
	local units = getUnits()
	local nukes = EntityCategoryFilterDown(categories.NUKE, units)
	local defs = EntityCategoryFilterDown(categories.SILO * categories.ANTIMISSILE, units)

	local current = nil
	local data = nil

	if(table.getsize(nukes) > 0) then
		data = siloData(nukes)

		button.nuke_progress.Height:Set(4)
		button.nuke_progress:SetValue(data.progress)
		button.nuke_count:SetText(data.count)

		button.units = nukes

		if(current == nil) then
			current = nukes[1]
		end
	else
		button.nuke_count:SetText(0)
		button.nuke_progress.Height:Set(0)
	end

	if(table.getsize(defs) > 0) then
		data = siloData(defs)

		button.def_progress.Height:Set(4)
		button.def_progress:SetValue(data.progress)
		button.def_count:SetText(data.count)

		if(current == nil) then
			current = defs[1]
		end
	else
		button.def_count:SetText(0)
		button.def_progress.Height:Set(0)
	end

	if(current) then
		local bp = current:GetBlueprint()
		local iconName1, iconName2, iconName3, iconName4 = GameCommon.GetCachedUnitIconFileNames(bp)
		button.icon:SetTexture(iconName1)
		button:Show()
	else
		button:Hide()
	end
end

function CreateUI(isReplay, parent)
	nukeButton = createButton(parent)
	LayoutHelpers.AtLeftTopIn(nukeButton, parent, 2, 580)
end

function nukeWatcher()
	drawOverlays()
end

function CreateNukeOverlay(unit)
	local overlay = Bitmap(GetFrame(0))
	overlay.destroy = false
	overlay.id = unit:GetEntityId()
	overlay.unit = unit
	overlay:SetSolidColor('black')
	overlay.Width:Set(15)
	overlay.Height:Set(15)
	
	overlay:SetNeedsFrameUpdate(true)
	overlay.OnFrame = function(self, delta)
		if(not unit:IsDead()) then
			local worldView = import('/lua/ui/game/worldview.lua').viewLeft
			local pos = worldView:Project(unit:GetPosition())
			LayoutHelpers.AtLeftTopIn(overlay, worldView, pos.x - overlay.Width() / 2, pos.y - overlay.Height() / 2 + 1)
		else
			overlay.destroy = true
			overlay:Hide()
		end
	end
	
	overlay.text = UIUtil.CreateText(overlay, '0', 12, UIUtil.bodyFont)
	overlay.text:SetColor('red')
    overlay.text:SetDropShadow(true)
	LayoutHelpers.AtCenterIn(overlay.text, overlay, 0, 0)

	overlay.progress = UIUtil.CreateText(overlay, '0%', 12, UIUtil.bodyFont)
	overlay.progress:SetColor('white')
    overlay.progress:SetDropShadow(true)
	LayoutHelpers.AtCenterIn(overlay.progress, overlay, 15, 0)
	
	overlay.eta = UIUtil.CreateText(overlay, 'ETA', 10, UIUtil.bodyFont)
	overlay.eta:SetColor('white')
    overlay.eta:SetDropShadow(true)
	LayoutHelpers.AtCenterIn(overlay.eta, overlay, -15, 0)

	overlay.unit = unit
	
	return overlay
end

function round(num, idp)
	if(not idp) then
		return tonumber(string.format("%." .. (idp or 0) .. "f", num))
	else
  		local mult = 10^(idp or 0)
		return math.floor(num * mult + 0.5) / mult
  	end
end


function updateNukeOverlay(unit, options)
	local id = unit:GetEntityId()
	local info = unit:GetMissileInfo()
	local count = info.nukeSiloStorageCount + info.tacticalSiloStorageCount
	local color

	if(not overlays[id]) then
		overlays[id] = CreateNukeOverlay(unit)
	end

	local overlay = overlays[id]

	if(count > 0) then
		color = 'green'
	else
		color = 'red'
	end

	overlay.text:SetText(count)
	overlay.text:SetColor(color)

	local progress = unit:GetWorkProgress()
	if(progress > 0 and options['em_nukeoverlay'] == 2) then
		local tick = GameTick()

		if(not overlay.last_progress or overlay.last_progress > progress) then
			overlay.last_progress = progress
			overlay.last_tick = GameTick()
			overlay.current_eta = 0
		elseif(tick - overlay.last_tick > 20 and progress > overlay.last_progress) then
			--overlay.current_eta = round(GetGameTimeSeconds() + ((tick - overlay.last_tick) / 10) * ((1 - progress) / (progress - overlay.last_progress)))
			overlay.current_eta = round(GetGameTimeSeconds() + (((tick - overlay.last_tick)) * ((1 - progress) / (progress - overlay.last_progress)))/10 )
			overlay.last_progress = unit:GetWorkProgress()
			overlay.last_tick = tick
		end

		local eta = math.max(0, overlay.current_eta - GetGameTimeSeconds())
		overlay.progress:SetText(math.floor(progress*100) .. "%")
		overlay.eta:SetText("ETA " .. string.format("%.2d:%.2d", eta / 60, math.mod(eta, 60)))
		overlay.progress:Show()
		overlay.eta:Show()
	else
		overlay.progress:Hide()
		overlay.eta:Hide()
	end
end

function drawOverlays()
	local options = import(modPath .. 'modules/utils.lua').getOptions(true)
	
	if(options['em_nukeoverlay'] > 0) then
		local units = EntityCategoryFilterDown(categories.SILO * (categories.ANTIMISSILE + categories.NUKE), getUnits())

		for _, u in units do
			if(not u:IsDead()) then
				updateNukeOverlay(u, options)
			end
		end
	end

	for id, overlay in overlays do
		if(overlay.destroy or options['em_nukeoverlay'] == 0) then
			overlays[overlay.id] = nil
			overlay:Destroy()
		end
	end
end


function init(isReplay, parent)
	addListener(nukeWatcher, 1)
end

