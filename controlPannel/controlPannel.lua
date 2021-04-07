local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local UIUtil = import('/lua/ui/uiutil.lua')
local GameCommon = import('/lua/ui/game/gamecommon.lua')

local modFolder = 'EM/SupremeEconomyEM'
local CreateGrid = import('/mods/' .. modFolder .. '/mcibuttons.lua').CreateGrid
local CreateManagerButton = import('/mods/' .. modFolder .. '/mcibuttons.lua').CreateManagerButton
local addLabel = import('/mods/' .. modFolder .. '/mcibuttons.lua').addLabel
local GameMain = import('/lua/ui/game/gamemain.lua')

function init(isReplay)
	local parent = import('/lua/ui/game/borders.lua').GetMapGroup()
	CreateModUI(isReplay, parent)
end
function round(num, numDecimalPlaces)
	return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
end

local rows = 2
local cols = 30
local grid = {}
local colorOptions = {energy = "yellow", mass = "green"}
local columnAssignment = {energy = 1, mass = 2}

function updateUI(projects, pluginName)

	local color = colorOptions[pluginName]
	local row = columnAssignment[pluginName]
	-- hide all buttons
	hideButtons(row)

	local existingFactors = {}
	local collapsedProjects = {}
	for _, project in projects do
		local k = project[pluginName .. "FinalFactor"] .. project.unitName .. project.throttle
		if not existingFactors[k] then
			existingFactors[k] = true
			table.insert(collapsedProjects, project)
		end
	end

	for index, project in collapsedProjects do
		if index <= cols then
			local button = grid[index][row]

			-- assign units that will be selected when the button is clicked
			-- button.units = project.getUnits()

			if project.throttle != 0 then
				button.progress:SetValue(project.throttle)
				button.progress.Height:Set(3)
			else
				button.progress.Height:Set(0)
			end

			-- button.count:SetText(table.getsize(button.units))

			-- display the info
			button.info1:SetText(round(project[pluginName .. "FinalFactor"]))
			button.info1:SetColor(color)

			button.info2:SetText(round(project.neutralFactor))
			button.info2:SetColor(color)

			button.info3:SetText(round(project.massReversePayoff))
			button.info3:SetColor(color)

			-- addLabel(button, "ff", 0)
			-- button["ff"]:SetText(round(project[pluginName .. "FinalFactor"],2))
			-- button["ff"]:SetColor(color)

			-- set the texture that corresponds to the unit
			local iconName1, iconName2, iconName3, iconName4 = GameCommon.GetCachedUnitIconFileNames(project.unit:GetBlueprint())
			button.icon:SetTexture(iconName1)

			-- show the button
			button:Show()

			-- show the construction marker
			button.marker:Show()
		end
	end
end

function hideButtons(s,e)
	-- hide all buttons
	if not s then
		s = 1
		e = rows
	end
	if not e then e = s end
	
	for r = s, e do
		for c = 1, cols do
			local button = grid[c][r]
			button:Hide()
		end
	end
end

function CreateModUI(isReplay, parent)
	local xPosition = 360
	local yPosition = 5

	grid = CreateGrid(parent, xPosition, yPosition, cols, rows, CreateManagerButton)
	hideButtons()

	local resourceIconHeight = 32

	local img = Bitmap(parent)
	img.Width:Set(resourceIconHeight/58 * 70)
	img.Height:Set(resourceIconHeight)
	img:SetTexture(UIUtil.UIFile('/game/resources/mass_btn_up.dds'))
	LayoutHelpers.CenteredAbove(img, grid[1][1], 0)

	local count = 1
	img.Update = function(self)
		print("OnUpdate".. count)
		count = count + 1
	end

	img.OnFrame = function(self)
		print("OnFrame".. count)
		count = count + 1
	end

	local img = Bitmap(parent)
	img.Width:Set(resourceIconHeight)
	img.Height:Set(resourceIconHeight)
	img:SetTexture(UIUtil.UIFile('/game/resources/energy_btn_up.dds'))
	LayoutHelpers.CenteredAbove(img, grid[2][1], 0)

	--GameMain.AddBeatFunction(updateUI)
end
