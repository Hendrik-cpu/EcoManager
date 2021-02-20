local modPath = '/mods/EM/'
local addListener = import(modPath .. 'modules/init.lua').addListener
local addCommand = import(modPath .. 'modules/commands.lua').addCommand
local EcoManager = import(modPath .. 'modules/throttler/EcoManager.lua').EcoManager
local removeListener = import(modPath .. 'modules/init.lua').removeListener
local managerThreadKey = "EcoManager"

manager = nil

function init()
	manager = EcoManager()
	manager:addPlugin('Mass')
	manager:addPlugin('MassBalance', false)
	manager:addPlugin('Energy')
	--manager:addPlugin('Storage')
	addCommand('t', togglePlugin)
	addListener(manageEconomy, 0.3,'em_throttler', managerThreadKey) --activates after 5 minutes
end

function manageEconomy()
	manager:manageEconomy()
end

function ToggleMassBalance()
	local NewStatus = not manager.plugins["massbalance"].Active 
	manager.plugins["massbalance"].Active = NewStatus
	print("MassBalance = " .. tostring(NewStatus))
end

function toggleEcomanager()
	manager.Active = not manager.Active 
	if manager.Active then
		manager:erasePauseMemory()
		addListener(manageEconomy, 0.3,'em_throttler',managerThreadKey)
		print('Throttler started!')
	else
		manager:releaseUnits()
		removeListener(managerThreadKey)
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

