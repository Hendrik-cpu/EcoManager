local modPath = '/mods/EM/'

local IsAutoSelection = import(modPath .. "modules/allunits.lua").IsAutoSelection
local originalCreateUI = CreateUI

local unitData = import(modPath ..'modules/units.lua').unitData

local KeyMapper = import('/lua/keymap/keymapper.lua')

local originalOnSelectionChanged = OnSelectionChanged
function OnSelectionChanged(oldSelection, newSelection, added, removed)
	if not IsAutoSelection() then
		if(table.getsize(added) > 0 and table.getsize(newSelection) == 1) then
			local mexes = EntityCategoryFilterDown(categories.MASSEXTRACTION * categories.STRUCTURE, newSelection)

			if(mexes and table.getsize(mexes) == 1) then
				local options = import(modPath .. 'modules/utils.lua').getOptions(true)
				local mex = mexes[1]
				local data = unitData(mex)

				if(options['em_mexes'] == 'click' and (EntityCategoryContains(categories.TECH1, mex) or data['bonus'] >= 1.5)) then
					import(modPath ..'modules/mexes.lua').upgradeMexes(mexes, true)
				end
			end
		end
		
		originalOnSelectionChanged(oldSelection, newSelection, added, removed)
	end
end

function CreateUI(isReplay, parent)
	options.gui_scu_manager=0
    originalCreateUI(isReplay)
    AddBeatFunction(import(modPath .. 'modules/allunits.lua').UpdateAllUnits)
    import(modPath .. "modules/init.lua").init(isReplay, import('/lua/ui/game/borders.lua').GetMapGroup())
    import(modPath .. 'modules/scumanager.lua').Init()
    KeyMapper.SetUserKeyAction('scu_upgrade_marker', {action =  'UI_Lua import("' .. modPath .. 'modules/scumanager.lua").CreateMarker()', category = 'user', order = 4})

    import('/lua/ui/game/multifunction.lua').Contract()
end
