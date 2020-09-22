local modPath = '/mods/EM/'
local addCommand = import(modPath .. 'modules/commands.lua').addCommand
local setMassStallMexesOnCount = import(modPath .. 'modules/throttlemass.lua').setMassStallMexesOnCount
local setEnergyStallMexesOnCount = import(modPath .. 'modules/throttlemass.lua').setEnergyStallMexesOnCount
local Pause = import(modPath .. 'modules/pause.lua').Pause

function init()
	IN_AddKeyMapTable({['Ctrl-V' ] = {action =  'ui_lua import("/mods/EM/modules/throttlemass.lua").PauseAll()'},})
	IN_AddKeyMapTable({['Ctrl-B' ] = {action =  'ui_lua import("/mods/EM/modules/throttlemass.lua").PauseECO()'},})
	IN_AddKeyMapTable({['Ctrl-N' ] = {action =  'ui_lua import("/mods/EM/modules/throttlemass.lua").PauseECOHard()'},})
	IN_AddKeyMapTable({['Ctrl-M'] = {action =  'ui_lua import("/mods/EM/modules/throttlemass.lua").PauseAllNonECO()'},})
	IN_AddKeyMapTable({['Ctrl-T' ] = {action =  'ui_lua import("/mods/EM/modules/throttle.lua").toggleMassFabsOnly()'},})
	IN_AddKeyMapTable({['Ctrl-Shift-T' ] = {action =  'ui_lua import("/mods/EM/modules/throttle.lua").togglePowerThrottle()'},})

	addCommand('mm', setMassStallMexesOnCount)
	addCommand('me', setEnergyStallMexesOnCount)
end


