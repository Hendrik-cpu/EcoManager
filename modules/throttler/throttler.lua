local modPath = '/mods/EM/'
local addListener = import(modPath .. 'modules/init.lua').addListener
local EcoManager = import(modPath .. 'modules/throttler/EcoManager.lua').EcoManager
local manager

function manageEconomy()
	manager:manageEconomy()
end

function ToggleMassBalance()
	local NewStatus = not manager.plugins["MassBalance"].Active 
	manager.plugins["MassBalance"].Active = NewStatus
	print("MassBalance = " .. tostring(NewStatus))
end

function init()
	manager = EcoManager()
	manager:addPlugin('Mass')
	manager:addPlugin('MassBalance', false)
	manager:addPlugin('Energy')
	--manager:addPlugin('Storage')
	addListener(manageEconomy, 0.3)
end