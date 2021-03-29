local modPath = '/mods/EM/'
local modulesPath = modPath .. 'modules/'
local throttlerPath = modPath .. 'throttler/'

local EconomyPath = throttlerPath .. 'Economy.lua'
local MyPath = modulesPath .. 'ecocommands.lua")'
local throttler = throttlerPath .. 'throttler.lua'
local pauser = import(modulesPath .. 'pause.lua')
local Units = import('/mods/common/units.lua')

function init()
	addHotkey('Ctrl-V', MyPath .. '.PauseAll')
	addHotkey('Ctrl-B', EconomyPath .. '").PauseEcoM80_E90')
	addHotkey('Ctrl-N', EconomyPath .. '").PauseEcoM10_E190')
	addHotkey('Ctrl-T', throttler .. '").toggleEcomanager')
	addHotkey('Ctrl-M', throttler .. '").ToggleMassBalance')
	addHotkey('Ctrl-P', throttler .. '").ToggleMexMode')
	addHotkey('Ctrl-O', throttler .. '").increaseMexPrio')
	addHotkey('Ctrl-L', throttler .. '").decreaseMexPrio')
end

local hotkeys = {}
function addHotkey(hotkey, f)
	LOG('ui_lua import("' .. f .. "()")
	IN_AddKeyMapTable({[hotkey] = {action = 'ui_lua import("' .. f .. "()"},})
	hotkeys[hotkey] = f
end
function getHotkeys()
	return hotkeys
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
	pauser.Pause(units, AllIsPause, 'user')

	if AllIsPause then
		print("Paused all units except selection!")
	else
		pauser.ResetPauseStates()
		print("Unpaused all units!")
	end
end

