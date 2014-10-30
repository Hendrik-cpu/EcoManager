local modPath = '/mods/EM/'
local addListener = import(modPath .. 'modules/init.lua').addListener

function isPaused(u)
	local is_paused
	if EntityCategoryContains(categories.MASSFABRICATION*categories.STRUCTURE, u) then
		is_paused = GetScriptBit({u}, 4)
	else
		is_paused = GetIsPaused({u})
	end

	return is_paused
end

function setPause(units, toggle, pause)
	if toggle == 'pause' then
		SetPaused(units, pause)
	else
		local bit = GetScriptBit(units, toggle)
		local is_paused = bit

		if toggle == 0  then
			is_paused = not is_paused
		end

		if pause ~= is_paused then
			ToggleScriptBit(units, toggle, bit)
		end
	end
end

local Economy = import(modPath .. 'modules/throttler/Economy.lua').Economy
local EcoManager = import(modPath .. 'modules/throttler/EcoManager.lua').EcoManager
local EnergyPlugin = import(modPath .. 'modules/throttler/EnergyPlugin.lua').EnergyPlugin
local StoragePlugin = import(modPath .. 'modules/throttler/StoragePlugin.lua').StoragePlugin

function manageEconomy()
	local eco = Economy()
	local projects = manager:LoadProjects(eco)
	local all_projects = {}

	for _, p in projects do
		table.insert(all_projects, p)
	end

	--print ("n_projects " .. table.getsize(all_projects))

	LOG("NEW BALANCE ROUND")
	plugins = {StoragePlugin(eco), EnergyPlugin(eco)}
	import(modPath .. 'modules/throttler/Project.lua').throttleIndex = 0
	import(modPath .. 'modules/throttler/Project.lua').firstAssister = true

	for _, plugin in plugins do
		local pause = false

		plugin.projects = {}
		for _, p in projects do
			plugin:add(p)
	 	end

	 	plugin:sort()

	 	--LOG(repr(plugin.projects))
		--print ("n_plugin_projects " .. table.getsize(plugin.projects))
	 	for _, p in plugin.projects do
	 		local ratio_inc

	 		if p.throttle < 1 then
		 		if not pause then
	 				local last_ratio = p.throttle
		 			plugin:throttle(eco, p)
	 				ratio_inc = p.throttle - last_ratio
		 			if p.throttle < 1 then
		 				--table.insert(projects, p)
		 			else
			 			pause = true -- plugin throttles all from here
		 			end

		 			eco.energyActual = eco.energyActual + p.energyRequested * (1-ratio_inc)
		 			eco.massActual = eco.massActual + p.massRequested * (1-ratio_inc)
		 		end

		 		if(pause) then
			 		p:SetEnergyDrain(0)
		 			--projects[p.id] = nil
		 		end
		 	end
	 	end
	end


	table.sort(all_projects, function(a, b) return a.index < b.index end)

	local pause_list = {}

	LOG(repr(all_projects))
	for _, p in all_projects do
		p:pause(pause_list)
	end

	for toggle_key, modes in pause_list do
		local toggle = toggle_key

		if toggle ~= 'pause' then
			toggle = tonumber(string.sub(toggle, 8))
		end

		for mode, units in modes do
			setPause(units, toggle, mode == 'pause')
		end
	end
end

function init()
	manager = EcoManager()
	addListener(manageEconomy, 1)
end
