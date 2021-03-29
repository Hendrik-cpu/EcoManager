local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local UIUtil = import('/lua/ui/uiutil.lua')

local modFolder = 'EM/modules/SupremeEconomyEM'
local CreateGrid = import('/mods/' .. modFolder .. '/mcibuttons.lua').CreateGrid
local CreateGenericButton = import('/mods/' .. modFolder .. '/mcibuttons.lua').CreateGenericButton

local GameMain = import('/lua/ui/game/gamemain.lua')


function init(isReplay)
	local parent = import('/lua/ui/game/borders.lua').GetMapGroup()
	CreateModUI(isReplay, parent)
end

local rows = 2
local cols = 2
local grid = {}

function updateUI()
	-- hide all buttons
	for r = 1, rows do
		for c = 1, cols do
			local button = grid[r][c]
			button:Hide()
		end
	end
end

function CreateModUI(isReplay, parent)
	local xPosition = 360
	local yPosition = 5

	grid = CreateGrid(parent, xPosition, yPosition, rows, cols , CreateGenericButton)

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

	GameMain.AddBeatFunction(updateUI)
end
