local modPath = '/mods/EM/'
local SelectBegin = import(modPath .. 'modules/allunits.lua').SelectBegin
local SelectEnd = import(modPath .. 'modules/allunits.lua').SelectEnd

local triggerEvent = import(modPath .. 'modules/events.lua').triggerEvent
local addListener = import(modPath .. 'modules/init.lua').addListener
local getEconomy = import(modPath ..'modules/economy.lua').getEconomy
local getUnits = import(modPath .. 'modules/units.lua').getUnits
local unitData = import(modPath ..'modules/units.lua').unitData

local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local ItemList = import('/lua/maui/itemlist.lua').ItemList
local Group = import('/lua/maui/group.lua').Group
local UIUtil = import('/lua/ui/uiutil.lua')

local Pause = import(modPath .. 'modules/pause.lua').Pause
local CanUnpause = import(modPath .. 'modules/pause.lua').CanUnpause

local pause_queue = {}
local overlays = {}

function SetPaused(units, state)
    Pause(units, state, 'mexes')
end

function isMexBeingBuilt(mex)
	if mex:GetEconData().energyRequested ~= 0 then
		return false
	end
		
	if mex:GetHealth() == mex:GetMaxHealth() then
		return false
	end
	
	return true
end

function getMexes()
	local units = getUnits() or {}
	local all_mexes = EntityCategoryFilterDown(categories.MASSEXTRACTION * categories.STRUCTURE, units)
	local mexes = {all={}, upgrading={}, idle={}, assisted={}}

	mexes['all'] = all_mexes
			
	for _, mex in all_mexes do
		if(not mex:IsDead()) then
			data = unitData(mex)
	
			if(data['is_idle']) then -- Idling mex, should be upgraded / paused
				for _, category in {categories.TECH1, categories.TECH2} do
					if(EntityCategoryContains(category, mex)) then
						if(category == categories.TECH1 or data['bonus'] >= 1.5) then -- upgrade T1 and T2 with MS
							--table.insert(mexes['idle'][category], mex)
							table.insert(mexes['idle'], mex)
						end
					end
				end
			elseif mex:GetFocus() then
				table.insert(mexes['upgrading'], mex)

				if(data['assisting'] > 0 and GetIsPaused({mex}) and CanUnpause(mex, 'mexes')) then
					table.insert(mexes['assisted'], mex)
				end
			end
		end
	end

	return mexes
end

function upgradeMexes(mexes, unpause) 
	if not mexes or table.getsize(mexes) == 0 then
		return false
	end

	--local old = GetSelectedUnits()
	local upgrades = {}

	for _, m in mexes do
		if(m:IsIdle()) then
			local bp = m:GetBlueprint()
			local upgrades_to = bp.General.UpgradesTo

			if(not unpause) then
				table.insert(pause_queue, m)
			end

			if(not upgrades[upgrades_to]) then
				upgrades[upgrades_to] = {}
			end

			table.insert(upgrades[upgrades_to], m)
		end
	end

	if(table.getsize(upgrades) > 0) then
		SelectBegin()

		for upgrades_to, up_mexes in upgrades do
			SelectUnits(up_mexes)
			IssueBlueprintCommand("UNITCOMMAND_Upgrade", upgrades_to, 1, false)
		end

		--SelectUnits(old)
		SelectEnd()
	end

	if(unpause) then
		SetPaused(mexes, false)
	end
	
	return true
end

function upgradeMexById(id)
	local units = getUnits()

	if not units then
		return
	end

	for k, u in units do
		if(u:IsDead()) then
			units[k] = nil
		end
	end

	local all_mexes = EntityCategoryFilterDown(categories.MASSEXTRACTION * categories.STRUCTURE, units)
	
	for _, m in all_mexes do
		if(m:GetEntityId() == id) then
			if(not m:GetFocus()) then
				upgradeMexes({m})
			end

			return
		end
	end
end

function pauseMexes()
	local pause = {}

	for k, m in pause_queue do
		if(not m:IsDead() and m:GetFocus()) then
			table.insert(pause, m)
			pause_queue[k] = nil
		end
	end

	if(table.getsize(pause) > 0) then
		triggerEvent('toggle_pause', pause, true)
		SetPaused(pause, true)
	end
end

function CreateMexOverlay(unit)
	local overlay = Bitmap(GetFrame(0))
	local id = unit:GetEntityId()
		
	overlay:SetSolidColor('black')
	overlay.Width:Set(10)
	overlay.Height:Set(10)
	
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
		
	overlay.id = unit:GetEntityId()
	overlay.destroy = false
	overlay.text = UIUtil.CreateText(overlay, '0', 10, UIUtil.bodyFont)
	overlay.text:SetColor('green')
    overlay.text:SetDropShadow(true)
	LayoutHelpers.AtCenterIn(overlay.text, overlay, 0, 0)

	return overlay
end

function UpdateMexOverlay(mex)
	local id = mex:GetEntityId()
	local data = unitData(mex)
	local tech = 0
	local color = 'green'

	if(isMexBeingBuilt(mex)) then
		return false
	end

	if(not overlays[id]) then
		overlays[id] = CreateMexOverlay(mex)
	end

	local overlay = overlays[id]

	if(EntityCategoryContains(categories.TECH1, mex)) then
		tech = 1
	elseif(EntityCategoryContains(categories.TECH2, mex)) then
		tech = 2
	else
		tech = 3
	end

	if(data['is_idle'] or (mex:GetWorkProgress() < 0.02)) then
		if(tech >= 2 and data['bonus'] < 1.5) then
			color = 'red'
		elseif(tech == 3) then
			color = 'white'
		else
			color = 'green'
		end
	else
		color = 'yellow'
	end

	overlay.text:SetColor(color)
	overlay.text:SetText(tech)
end

function mexOverlay()
	options = import(modPath .. 'modules/utils.lua').getOptions(true)
	mexes = getMexes()

	if(options['em_mexoverlay'] == 1) then
		for _, m in mexes['all'] do
			if(m:IsIdle() or m:GetFocus()) then
				UpdateMexOverlay(m)
			end
		end
	end
	
	for id, overlay in overlays do
		if(not overlay or overlay.destroy or options['em_mexoverlay'] == 0) then
			overlay:Destroy()
			overlays[id] = nil
		end
	end
end

function checkMexes()
	local mexes

	mexes = getMexes()

	options = import(modPath .. 'modules/utils.lua').getOptions(true)

	if(table.getsize(mexes['idle']) > 0) then
		local auto_upgrade = options['em_mexes'] == 'auto';

		if(not auto_upgrade) then
			local eco = getEconomy()
			local tps = GetSimTicksPerSecond()
		end

		if(auto_upgrade) then
			upgradeMexes(mexes['idle'])
		end
	end

	for id, overlay in overlays do
		if(not overlay or overlay.destroy or options['em_mexoverlay'] == 0) then
			overlay:Destroy()
			overlays[id] = nil
		end
	end
	
	if(table.getsize(mexes['assisted']) > 0) then
		Pause(mexes['assisted'], false, 'user') -- unpause assisted mexes
	end
end

function init(isReplay, parent)
	if(not isReplay) then
		addListener(checkMexes, 1, 'em_mexes')
		addListener(pauseMexes, 0.2, 'em_mexes')
	end

	addListener(mexOverlay, 1)
end