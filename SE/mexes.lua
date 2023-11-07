local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local Button = import('/lua/maui/button.lua').Button
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local ItemList = import('/lua/maui/itemlist.lua').ItemList
local Group = import('/lua/maui/group.lua').Group
local UIUtil = import('/lua/ui/uiutil.lua')
local GameCommon = import('/lua/ui/game/gamecommon.lua')
local ToolTip = import('/lua/ui/game/tooltip.lua')
local TooltipInfo = import('/lua/ui/help/tooltips.lua').Tooltips
local GameMain = import('/lua/ui/game/gamemain.lua')

local modFolder = 'EM/SE'
local GetAllUnits = import('/mods/common/units.lua').Get
local CreateGrid = import('/mods/' .. modFolder .. '/mcibuttons.lua').CreateGrid
local CreateGenericButton = import('/mods/' .. modFolder .. '/mcibuttons.lua').CreateGenericButton


--Thread handling
	local addListener = import('/mods/EM/modules/init.lua').addListener
	local removeListener = import('/mods/EM/modules/init.lua').removeListener
	initialized = false
	function init(isReplay) 
		local parent = import('/lua/ui/game/borders.lua').GetMapGroup()
		CreateModUI(isReplay, parent)
		addListener(UpdateMexes, 0.3,'se_mexes', 'se_mexes')
		
		initialized = true
	end
	function exit()
		hideButtons()
		removeListener('se_mexes')

		initialized =  false
	end

function getNameFromBp(bp)
	local techLevel = false
    local levels = {TECH1 = 1,TECH2 = 2,TECH3 = 3}
    for i, v in bp.Categories do
        if levels[v] then
            techLevel = levels[v]
            break
        end
    end
    if techLevel then
        return LOCF("T%d %s", techLevel, bp.Description)
	else
		return LOC(bp.Description)
    end
end

function getMassProducedWithoutMS(unit)
	if EntityCategoryContains(categories.TECH1, unit) then
		return 2
	elseif EntityCategoryContains(categories.TECH2, unit) then
		return 6
	elseif EntityCategoryContains(categories.TECH3, unit) then
		return 18
	else
		print("Unknown tech level for mass extractor!")
	end
end

function insertMex(mextable, unit)
	if unit:GetFocus() and EntityCategoryContains(categories.MASSEXTRACTION, unit:GetFocus()) then
		table.insert(mextable.U.Y, unit)
	else
		table.insert(mextable.U.N, unit)
	end

	local econoData = unit:GetEconData()
	--print (econoData.massProduced .. "." .. getMassProducedWithoutMS(unit) .. "." .. repr(econoData.massProduced <= getMassProducedWithoutMS(unit)))
	if econoData.energyRequested == econoData.energyConsumed and
	   econoData.massProduced <= getMassProducedWithoutMS(unit) and
	   econoData.energyRequested > 0 then
		table.insert(mextable.MS.N, unit)
	end
end

-- this is not super precise, if you have a damaged disabled mex it will be counted as beeing built
function isMexBeingBuilt(mex)
	if mex:GetEconData().energyRequested ~= 0 then
		return false
	end

	if mex:GetHealth() == mex:GetMaxHealth() then
		return false
	end

	return true
end

function mexesThatAreNotBeeingBuilt(mexes)
	local newMexes = {}
	for _, mex in mexes do
		if not isMexBeingBuilt(mex) then
			table.insert(newMexes, mex)
		end
	end
	return newMexes
end

function updateButton(mexTable, button, enableMarker, tooltipText, countBeingBuilt)
	if not countBeingBuilt then
		mexTable = mexesThatAreNotBeeingBuilt(mexTable)
	end

	local aliveCount = table.getsize(mexTable)

	if aliveCount > 0 then
		local unitBluePrint = mexTable[1]:GetBlueprint()
		ToolTip.AddControlTooltip(button, {text=getNameFromBp(unitBluePrint), body=tooltipText})

		-- assign units that will be selected when the button is clicked
		button.units = mexTable
		button.count:SetText(aliveCount)

		-- set the texture that corresponds to the unit
		local iconName1, iconName2, iconName3, iconName4 = GameCommon.GetCachedUnitIconFileNames(unitBluePrint)
		button.icon:SetTexture(iconName1)

		-- show the button
		button:Show()

		-- show work progress on mexes that are being updated
		if enableMarker then
			local maxWorkProgress = 0
			for _, mex in mexTable do
				if mex:GetWorkProgress() > maxWorkProgress then
					maxWorkProgress = mex:GetWorkProgress()
				end
			end
			button.progress.Height:Set(3)
			button.progress:SetValue(maxWorkProgress)
		else
			button.progress.Height:Set(0)
		end

		-- show the marker
		if enableMarker then
			button.marker:Show()
		else
			button.marker:Hide()
		end

	else
		button:Hide()
	end
end

local buttons
function CreateModUI(isReplay, parent)
	local xPosition = 20
	local yPosition = 420

	buttons = CreateGrid(parent, xPosition, yPosition, 3, 3, CreateGenericButton)

	for tech = 1, 3 do
		img = Bitmap(parent)
		img:SetTexture(UIUtil.UIFile('/game/avatar-engineers-panel/tech-'.. tech .. '_bmp.dds'))
		LayoutHelpers.CenteredLeftOf(img, buttons[1][tech], -6)
	end

	function UpdateMexes()
		local units = GetAllUnits()
		local mexes = {}

		mexes[categories.TECH1] = {MS = {Y = {}, N = {}}, U = {Y = {}, N = {}}}
		mexes[categories.TECH2] = {MS = {Y = {}, N = {}}, U = {Y = {}, N = {}}}
		mexes[categories.TECH3] = {MS = {Y = {}, N = {}}, U = {Y = {}, N = {}}}

		for index, unit in units do
			if not unit:IsDead() and EntityCategoryContains(categories.MASSEXTRACTION, unit) then
				if EntityCategoryContains(categories.TECH1, unit) then
					insertMex(mexes[categories.TECH1], unit)
				elseif EntityCategoryContains(categories.TECH2, unit) then
					insertMex(mexes[categories.TECH2], unit)
				elseif EntityCategoryContains(categories.TECH3, unit) then
					insertMex(mexes[categories.TECH3], unit)
				else
					print("Unknown tech level for mass extractor!")
				end
			end
		end

		updateButton(mexes[categories.TECH1].U.N, buttons[1][1], false, "Select idle T1 Mexes", false)
		updateButton(mexes[categories.TECH1].U.Y, buttons[2][1], true, "Select T1 Mexes that are being updated", false)
		buttons[3][1]:Hide()
		updateButton(mexes[categories.TECH2].U.N, buttons[1][2], false, "Select idle T2 Mexes", false)
		updateButton(mexes[categories.TECH2].U.Y, buttons[2][2], true, "Select T2 Mexes that are being updated", false)
		updateButton(mexes[categories.TECH2].MS.N, buttons[3][2], false, "Select T2 Mexes that are not surrounded by mass storage", true)
		buttons[1][3]:Hide()
		buttons[2][3]:Hide()
		updateButton(mexes[categories.TECH3].MS.N, buttons[3][3], false, "Select T3 Mexes that are not surrounded by mass storage", true)
	end

end

function hideButtons()
	for tech = 1, 3 do
		for c = 1, 3 do
			local button = buttons[c][tech]
			button:Hide()
		end
	end
end
