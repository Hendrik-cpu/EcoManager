local modPath = '/mods/EM/'
local throttleMassPath = modPath .. 'modules/throttlemass.lua'
local MyPath = 'ui_lua import("' .. modPath .. 'modules/ecocommands.lua")'

local addCommand = import(modPath .. 'modules/commands.lua').addCommand
local setMassStallMexesOnCount = import(throttleMassPath).setMassStallMexesOnCount
local setEnergyStallMexesOnCount = import(throttleMassPath).setEnergyStallMexesOnCount
local Pause = import(modPath .. 'modules/pause.lua').Pause
local Units = import('/mods/common/units.lua')

function init()
	IN_AddKeyMapTable({['Ctrl-V' ] = {action =  MyPath .. '.PauseAll()'},})
	IN_AddKeyMapTable({['Ctrl-T' ] = {action =  'ui_lua import("' .. modPath .. 'modules/throttler/EcoManager.lua").DisableNewEcoManager()'},})

	IN_AddKeyMapTable({['Ctrl-B' ] = {action =  'ui_lua import("' .. throttleMassPath .. '").PauseECO()'},})
	IN_AddKeyMapTable({['Ctrl-N' ] = {action =  'ui_lua import("' .. throttleMassPath .. '").PauseECOHard()'},})
	IN_AddKeyMapTable({['Ctrl-M'] = {action =  'ui_lua import("' .. throttleMassPath .. '").PauseAllNonECO()'},})
	--IN_AddKeyMapTable({['Ctrl-Shift-T' ] = {action =  'ui_lua import("/mods/EM/modules/throttle.lua").togglePowerThrottle()'},})

	addCommand('mm', setMassStallMexesOnCount)
	addCommand('me', setEnergyStallMexesOnCount)
end

local AllIsPause=false
function PauseAll()
	local units={}
	local selected={}

	for _, u in GetSelectedUnits() or {} do
		selected[u:GetEntityId()]=true
	end

	for _, u in Units.Get() do
		if not selected[u:GetEntityId()] then
			table.insert(units, u)
		end
	end

	AllIsPause=not AllIsPause
	Pause(units, AllIsPause, 'user')

	if AllIsPause then
		print("Paused all units except selection!")
	else
		import(modPath .. 'modules/throttler/ecomanager.lua').ResetPauseStates()
		print("Unpaused all units!")
	end
end

