local modPath = '/mods/EM/'
local throttleMassPath = modPath .. 'modules/throttlemass.lua'
local addCommand = import(modPath .. 'modules/commands.lua').addCommand
local setMassStallMexesOnCount = import(throttleMassPath).setMassStallMexesOnCount
local setEnergyStallMexesOnCount = import(throttleMassPath).setEnergyStallMexesOnCount
local Pause = import(modPath .. 'modules/pause.lua').Pause

function init()
	IN_AddKeyMapTable({['Ctrl-V' ] = {action =  'ui_lua import("' .. throttleMassPath .. '").PauseAll()'},})
	IN_AddKeyMapTable({['Ctrl-B' ] = {action =  'ui_lua import("' .. throttleMassPath .. '").PauseECO()'},})
	IN_AddKeyMapTable({['Ctrl-N' ] = {action =  'ui_lua import("' .. throttleMassPath .. '").PauseECOHard()'},})
	IN_AddKeyMapTable({['Ctrl-M'] = {action =  'ui_lua import("' .. throttleMassPath .. '").PauseAllNonECO()'},})
	IN_AddKeyMapTable({['Ctrl-T' ] = {action =  'ui_lua import("' .. modPath .. 'modules/throttler/EcoManager.lua").DisableNewEcoManager()'},})
	--IN_AddKeyMapTable({['Ctrl-Shift-T' ] = {action =  'ui_lua import("/mods/EM/modules/throttle.lua").togglePowerThrottle()'},})

	addCommand('mm', setMassStallMexesOnCount)
	addCommand('me', setEnergyStallMexesOnCount)
end


