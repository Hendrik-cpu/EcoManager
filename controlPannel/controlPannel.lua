local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local UIUtil = import('/lua/ui/uiutil.lua')
local GameCommon = import('/lua/ui/game/gamecommon.lua')

local modFolder = 'EM/SupremeEconomyEM'
local CreateGrid = import('/mods/' .. modFolder .. '/mcibuttons.lua').CreateGrid
local CreateManagerButton = import('/mods/' .. modFolder .. '/mcibuttons.lua').CreateManagerButton
local addLabel = import('/mods/' .. modFolder .. '/mcibuttons.lua').addLabel
local GameMain = import('/lua/ui/game/gamemain.lua')
local ToolTip = import('/lua/ui/game/tooltip.lua')

function init(isReplay)
	local parent = import('/lua/ui/game/borders.lua').GetMapGroup()
	CreateModUI(isReplay, parent)
end
function round(num, numDecimalPlaces)
	local mult = 10^(numDecimalPlaces or 0)
	return math.floor(num * mult + 0.5) / mult
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

	local collapsedProjects = {}
	local existingCollections = {}
	local i = 1
	for _, project in projects do
		local k = project[pluginName .. "FinalFactor"] .. project.unitName .. project.throttle
		local index = existingCollections[k]
		if index then
			table.insert(collapsedProjects[index].throttle,project.throttle)
			for _, a in project.assisters or {} do
				table.insert(collapsedProjects[index].assisters,a)
			end
		else
			local assisters  = {}
			for _, a in project.assisters or {} do
				table.insert(assisters,a)
			end
			existingCollections[k] = i
			collapsedProjects[i] = {project = project, assisters = assisters, throttle = {project.throttle}}
			i = i + 1
		end
	end

	for index, set in collapsedProjects do
		if index <= cols then
			local project = set.project
			local button = grid[index][row]

			-- assign units that will be selected when the button is clicked
			local units = {}
			for _, a in set.assisters do
				table.insert(units, a.unit)
			end

			button.units = units
			local sum = 0
			local count = 0
			for _, t in set.throttle or {} do
				sum = sum + t
				count = count + 1
			end
			local averageThrottle = sum / count

			if averageThrottle > 0 then
				button.progress:SetValue(averageThrottle)
				button.progress.Height:Set(3)
			else
				button.progress.Height:Set(0)
			end

			button.count:SetText(table.getsize(units))

			-- display the info
			button.info1:SetText(round(project[pluginName .. "FinalFactor"],2))
			button.info1:SetColor(color)

			-- button.info2:SetText(round(project.massRequested,2))
			-- button.info2:SetColor('green')

			-- setup the new tooltip
			local tooltipText
			tooltipText = 
			"massRequested: " .. project.massRequested ..
			"\nmassConsumed: " .. project.massConsumed ..	
			"\nenergyRequested: " .. project.energyRequested ..
			"\nenergyConsumed: " .. project.energyConsumed ..
			"\ntimeLeft: " .. project.timeLeft ..
			"\nbuildRate: " .. project.buildRate ..
			"\nmassAdjacencyBonus: " .. project.massAdjacencyBonus ..
			"\nenergyAdjacencyBonus: " .. project.energyAdjacencyBonus

			ToolTip.AddControlTooltip(button, {text=project.unitName or "Unknown", body=tooltipText})

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
