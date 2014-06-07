local modPath = '/mods/EM/'
local addListener = import(modPath .. 'modules/init.lua').addListener
local getUnits = import(modPath .. 'modules/units.lua').getUnits

local SelectBegin = import(modPath .. 'modules/allunits.lua').SelectBegin
local SelectEnd = import(modPath .. 'modules/allunits.lua').SelectEnd


function upgradeShields()
	local upgrades = {}
	local shields = EntityCategoryFilterDown(categories.SHIELD * categories.STRUCTURE, GetSelectedUnits())

	for i, shield in shields do
		local upgrades_to = nil

		if(not shield:IsDead()) then
			local bp = shield:GetBlueprint()
			upgrades_to = bp.General.UpgradesTo

			if(upgrades_to) then
				table.insert(upgrades, shield)
			end
		end
	end

	if(upgrades) then
		local selection = GetSelectedUnits()

		SelectBegin()
		SelectUnits(upgrades)
		IssueBlueprintCommand("UNITCOMMAND_Upgrade", 'urb4204', 1, false)
		IssueBlueprintCommand("UNITCOMMAND_Upgrade", 'urb4205', 1, false)
		IssueBlueprintCommand("UNITCOMMAND_Upgrade", 'urb4206', 1, false)
		IssueBlueprintCommand("UNITCOMMAND_Upgrade", 'urb4207', 1, false)
		SelectUnits(selection)
		SelectEnd()
	end
end

function addShields()
	local units = getUnits()
	local shields = EntityCategoryFilterDown(categories.SHIELD * categories.STRUCTURE, units)

	for _, s in shields do
		addShield(s)
	end

	
end

function init(isReplay, parent)
	local path = modPath .. 'modules/shields.lua'
	IN_AddKeyMapTable({['Ctrl-Shift-S'] = {action =  'ui_lua import("' .. path .. '").upgradeShields()'},})
end
