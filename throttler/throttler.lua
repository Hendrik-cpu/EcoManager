local modPath = '/mods/EM/'
local modulesPath = modPath .. 'modules/'
local throttlerPath = modPath .. 'throttler/'
local EconomyPath = throttlerPath .. 'Economy.lua")'
local throttler = throttlerPath .. 'throttler.lua")'

local pauser = import(modulesPath .. 'pause.lua')
local Units = import('/mods/common/units.lua')

local addListener = import(modulesPath .. 'init.lua').addListener
local addCommand = import(modulesPath .. 'commands.lua').addCommand
local addHotkey = import(modulesPath .. 'commands.lua').addHotkey
local EcoManager = import(modPath .. 'throttler/EcoManager.lua').EcoManager
local removeListener = import(modulesPath .. 'init.lua').removeListener
local managerThreadKey = "EcoManager"
local resetPauseStates = import(modulesPath .. 'pause.lua').resetPauseStates

manager = nil

function init()
	manager = EcoManager()
	manager:addPlugin('Mass')
	manager:addPlugin('Energy')
	--manager.plugins.energy.Active = false
	addListener(manageEconomy, 0.6,'em_throttler', managerThreadKey)

	addCommand('t', togglePlugin)
	addCommand('energy', energyPriority)
	addCommand('mass', massPriority)
	addCommand('printcats', printCategories)
	addCommand('toggle', toggleAll)
	addCommand('debug', toggleDebugging)

	addHotkey('Ctrl-V', throttler .. '.PauseAll')
	addHotkey('Ctrl-B', EconomyPath .. '.PauseEcoM80_E90')
	addHotkey('Ctrl-N', EconomyPath .. '.PauseEcoM10_E90')
	addHotkey('Ctrl-T', throttler .. '.toggleEcomanager')
	addHotkey('Ctrl-P', throttler .. '.toggleEnergy')
	addHotkey('Ctrl-M', throttler .. '.ToggleMassBalance')
	--addHotkey('Ctrl-P', throttler .. '.ToggleMexMode')
	addHotkey('Ctrl-O', throttler .. '.increaseMexPrio')
	addHotkey('Ctrl-L', throttler .. '.decreaseMexPrio')
	
end

function toggleEcomanager()
	manager.Active = not manager.Active 
	if manager.Active then
		resetPauseStates()
		addListener(manageEconomy, 0.6,'em_throttler',managerThreadKey)
		print('Throttler started!')
	else
		removeListener(managerThreadKey)
		resetPauseStates({ecomanager =  true})
		import(modPath .. "controlPannel/controlPannel.lua").hideButtons()
		print('Throttler terminated!')
	end
end

function toggleEnergy()
	local newState = not manager.plugins.energy.Active
	manager.plugins.energy.Active = newState
	print("Energy plugin set to: " .. tostring(newState))
end

function toggleDebugging()
	if manager.debuggingUI <= 0 then
		manager.debuggingUI = 1
	else
		manager.debuggingUI = 0
	end
end

local toggle = true
function toggleAll(args)
	local toggleKey = args[2]
	ToggleScriptBit(import('/mods/common/units.lua').Get(),tonumber(toggleKey),toggle)
	toggle = not toggle
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
	ToggleScriptBit(Units.Get(categories.STRUCTURE - categories.MASSEXTRACTION), 4, not AllIsPause)
	
	if AllIsPause then
		print("Paused all units except selection!")
	else
		pauser.resetPauseStates()
		print("Unpaused all units!")
	end
end

function manageEconomy()
	manager:manageEconomy()
end

function ToggleMassBalance()
	local NewStatus = not manager.plugins["mass"].massProductionOnly
	manager.plugins["mass"].massProductionOnly = NewStatus
	print("MassThrottle = " .. tostring(not NewStatus))
end

local mexMode = 0
function ToggleMexMode()
	if mexMode > 1 then
		mexMode = 0
	else
		mexMode = mexMode + 1
	end
	local energy = manager.plugins["energy"]
	local mass = manager.plugins["mass"]

	if mexMode == 0 then
		mass.massProductionPriorityMultiplier = 350 --balanced
		energy.constructionCategories.fabs.priority = 1
		print("Balanced mex upgrading activated (multiplier = 350)")
	elseif mexMode == 1 then
		mass.massProductionPriorityMultiplier = 1 --pause eco
		energy.constructionCategories.fabs.priority = 1
		print("Low priority mex upgrading activated (multiplier = 1)")
	elseif mexMode == 2 then
		mass.massProductionPriorityMultiplier = 1000 --power eco
		energy.constructionCategories.fabs.priority = 99
		print("High priority mex upgrading activated (multiplier = 1000), fabs won't pause")
	end
end

function increaseMexPrio()
	adjustMexPrio(10)
end
function decreaseMexPrio()
	adjustMexPrio(-10)
end

function adjustMexPrio(value)
	local newVal = manager.plugins["mass"].massProductionPriorityMultiplier + value
	if newVal < 0 then 
		newVal = 0
	end
	manager.plugins["mass"].massProductionPriorityMultiplier = newVal
	print("multiplier set to: " .. newVal)
end 

function togglePlugin(args)
	local str
	local cmd
	local argsCount = table.getsize(args)
	local InvalidInput = false

	if argsCount < 2 then
		toggleEcomanager()
	else
		local pluginName = args[2]
		if  manager.plugins[pluginName] then 

			local pluginState = manager.plugins[pluginName].Active 
			local state
			if argsCount > 2 then
				state = args[3]
			end

			if not state then
				pluginState =  not pluginState
			else
				if state == "on" then
					pluginState = true 
				elseif state == "off" then
					pluginState = false 
				else
					print("Invalid parameter!")
				end
			end

			manager.plugins[pluginName].Active = pluginState
			print(pluginName .. "Plugin set to " .. tostring(pluginState))

		else
			print("Plugin name doesn't exist!")
		end
	end
end

function energyPriority(args)
	changePriority(args, "energy")
end
function massPriority(args)
	changePriority(args, "mass")
end

function changePriority(args, plugin)
	local category = args[2]
	local priority = args[3]
	local storage = args[4]

	if manager.plugins[plugin].constructionCategories[category].priority then
		manager.plugins[plugin].constructionCategories[category].priority = tonumber(priority)
		print(plugin .. " " ..  category .. " priority set to " .. priority)
		if storage then 
			manager.plugins[plugin].constructionCategories[category].storage = tonumber(storage)/100
			print(plugin .. " " ..  category .. " priority set to " .. storage .. "%")
		end
	else
		print("Invalid input!")
	end
end

function printCategories()
	local str = ""
	for key, plugin in pairs(manager.plugins) do
		str = str .. key .. ':\n' 
		for key, category in pairs(plugin.constructionCategories) do
			str = str .. " ".. key .. '\n' 
			for key, value in pairs(category) do
				str = str .. " " .. key .. " = " .. tostring(value) .. "\n"
			end
		end
	end
	LOG(str)
end