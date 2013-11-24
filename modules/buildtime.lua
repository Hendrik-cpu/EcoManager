local modPath = '/mods/EM/'

local addListener = import(modPath .. 'modules/init.lua').addListener
local getUnits = import(modPath .. 'modules/units.lua').getUnits
local getAssisting = import(modPath .. 'modules/units.lua').getAssisting

local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local ItemList = import('/lua/maui/itemlist.lua').ItemList
local Group = import('/lua/maui/group.lua').Group
local UIUtil = import('/lua/ui/uiutil.lua')

local overlays = {}

function getConstructions()
	local units = getUnits()
	local constructions = {}

	for _, u in units do
		local focus = u:GetFocus()
		if(focus) then
			constructions[focus:GetEntityId()] = focus
		end
	end

	return constructions
end

function createBuildtimeOverlay(unit, buildtime)
	local parent = import('/lua/ui/game/worldview.lua').viewLeft
	local overlay = Bitmap(parent)
	overlay.unit = unit
	--overlay:SetSolidColor('99000000')
	overlay:SetSolidColor('black')
	overlay.Width:Set(8)
	overlay.Height:Set(8)
	
	local worldView = import('/lua/ui/game/worldview.lua').viewLeft
	overlay:SetNeedsFrameUpdate(true)

	overlay.OnFrame = function(self, delta)
		if(not unit:IsDead()) then
			local pos = worldView:Project(unit:GetPosition())
			LayoutHelpers.AtLeftTopIn(overlay, worldView, pos.x - overlay.Width() / 2, pos.y - overlay.Height() / 2 + 1)
		else
			overlay:Destroy()
			overlays[unit:GetEntityId()] = nil
		end
	end
	
	overlay.buildtime = buildtime
	overlay.text = UIUtil.CreateText(overlay, overlay.buildtime, 9, UIUtil.bodyFont)
	overlay.text:SetColor('white')
    overlay.text:SetDropShadow(true)
	LayoutHelpers.AtCenterIn(overlay.text, overlay, 0, 0)

	overlay.unit = unit

	return overlay
end

function mod(a, b)
	return a - math.floor(a/b)*b
end

function formatBuildtime(buildtime)
	return string.format("%.2d:%.2d", buildtime/60, mod(buildtime, 60))
end

function updateBuildtimeOverlay(unit, buildtime)
	local id = unit:GetEntityId();

	if not overlays[id] then
		overlays[id] = createBuildtimeOverlay(unit, buildtime)
	end

	overlays[id].buildtime = buildtime
	overlays[id].text:SetText(formatBuildtime(overlays[id].buildtime))
end

function checkConstructions()
	local constructions = getConstructions()
	local assisting

	for _, u in constructions do
		local id = u:GetEntityId()
		local bp = u:GetBlueprint()
		local consumed = {mass=0, energy=0}
		local progress = 0

		assisting = getAssisting(u)

		if(table.getsize(assisting['engineers']) > 0) then
			for _, e in assisting['engineers'] do
				progress = math.max(progress, e:GetWorkProgress())
				data = e:GetEconData()
				consumed['mass'] = consumed['mass'] + data['massConsumed']
				consumed['energy'] = consumed['energy'] + data['energyConsumed']
			end
		end			
		
		local left = 1-progress
		local cost = {mass=bp.Economy.BuildCostMass*left, energy=bp.Economy.BuildCostEnergy*left}
		local time_left

		if(consumed['energy'] == 0 or consumed['mass'] == 0) then
			time_left = 99999
		else
			time_left = math.max(cost['mass'] / consumed['mass'], cost['energy'] / consumed['energy'])
		end

		updateBuildtimeOverlay(u, time_left)
	end

	for id, o in overlays do -- clean overlays
		if(not constructions[id]) then
			overlays[id]:Destroy()
			overlays[id] = nil
		end
	end

end

function init()
	addListener(checkConstructions, 0.8)
end