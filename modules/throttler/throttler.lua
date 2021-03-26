local modPath = '/mods/EM/'
local addListener = import(modPath .. 'modules/init.lua').addListener
local addCommand = import(modPath .. 'modules/commands.lua').addCommand
local EcoManager = import(modPath .. 'modules/throttler/EcoManager.lua').EcoManager
local removeListener = import(modPath .. 'modules/init.lua').removeListener
local managerThreadKey = "EcoManager"
local resetPauseStates = import(modPath .. 'modules/pause.lua').resetPauseStates

manager = nil

function init()
	manager = EcoManager()
	--manager:addPlugin('Mass')
	--manager:addPlugin('MassBalance', false)
	manager:addPlugin('Mass')
	manager:addPlugin('Energy')
	addCommand('t', togglePlugin)
	addCommand('energy', energyPriority)
	addCommand('mass', massPriority)
	addCommand('printcats', printCategories)
	addListener(manageEconomy, 0.3,'em_throttler', managerThreadKey) 
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

function toggleEcomanager()
	manager.Active = not manager.Active 
	if manager.Active then
		resetPauseStates({ecomanager = true})
		addListener(manageEconomy, 0.3,'em_throttler',managerThreadKey)
		print('Throttler started!')
	else
		removeListener(managerThreadKey)
		resetPauseStates({ecomanager =  true})
		print('Throttler terminated!')
	end
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
	
	if manager.plugins[plugin].constructionCategories[category].priority then
		manager.plugins[plugin].constructionCategories[category].priority = tonumber(priority)
		print(plugin .. " " ..  category .. " priority set to " .. priority)
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