local modPath = '/mods/EM/'
local isPaused = import(modPath .. 'modules/throttler.lua').isPaused
local Project = import(modPath .. 'modules/throttler/Project.lua').Project
local Economy = import(modPath .. 'modules/throttler/Economy.lua').Economy
local EnergyPlugin = import(modPath .. 'modules/throttler/EnergyPlugin.lua').EnergyPlugin
local StoragePlugin = import(modPath .. 'modules/throttler/StoragePlugin.lua').StoragePlugin

local getUnits = import(modPath .. 'modules/units.lua').getUnits
local econData = import(modPath .. 'modules/units.lua').econData

EcoManager = Class({
	eco = nil,
	projects = {},

	LoadProjects = function(self, eco)
		local unpause = {}

		self.projects = {}
		units = EntityCategoryFilterDown(categories.STRUCTURE + categories.ENGINEER, getUnits())

		for _, u in units do
			local project

			if not u:IsDead() then
				local focus = u:GetFocus()

				if not focus then
					local is_paused = isPaused(u)

					if EntityCategoryContains(categories.MASSFABRICATION*categories.STRUCTURE, u) then
						data = econData(u)
						if data.energyRequested == 0 and not isPaused(u) then
							focus = u
						end
					elseif is_paused and (u:IsIdle() or u:GetWorkProgress() == 0) then
						table.insert(unpause, u)
					end
				end

				if focus then
					local id = focus:GetEntityId()

					project = self.projects[id]
					if not project then
						--LOG("Adding new project " .. id)

						project = Project(focus)
						self.projects[id] = project
					end

					--LOG("Entity " .. u:GetEntityId() .. " is an assister")

					project:AddAssister(eco, u)
				end
			end
		end

		if unpause then
			import(modPath .. 'modules/throttler.lua').setPause(unpause, 'pause', false)
		end

		return self.projects
	end,
	manageEconomy = function(self)
		local eco = Economy()
		local projects = manager:LoadProjects(eco)
		local all_projects = {}

		for _, p in projects do
			table.insert(all_projects, p)
		end

		--print ("n_projects " .. table.getsize(all_projects))

		--LOG("NEW BALANCE ROUND")
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

		--LOG(repr(all_projects))
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
})


