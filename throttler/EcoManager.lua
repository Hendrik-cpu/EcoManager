local modPath = '/mods/EM/'
local modulesPath = modPath .. 'modules/'
local throttlerPath = modPath .. 'throttler/'

local Units = import('/mods/common/units.lua')

local pauser = import(modulesPath .. 'pause.lua')
local isPaused = pauser.isPaused
local moduleName = "ecomanager"

EcoManager = Class({

	Active = true,
	ActivationTimer = 5  * 60,
	debuggingUI = 0,
	ActivationMessagePrinted = false,
	ProjectMetaData = {},
	plugins = {},

	LoadProjects = function(self, eco)
		local unpause = {}
		self.projects = {}
		self.ProjectPositions = {}
		self.mexPositions = {}
		self.allBuildingsPostions = {}
		self.countAssisters = 0
		self.countProjects = 0
		local units = Units.Get(categories.STRUCTURE + categories.ENGINEER + categories.NUKE + categories.SILO)

		for _, u in units do
			local project
			local id = u:GetEntityId()
			
			if not u:IsDead() then
				if EntityCategoryContains(categories.STRUCTURE * categories.MASSEXTRACTION, u) then
					table.insert(self.mexPositions, { position = u:GetPosition(), massProduction = u:GetBlueprint().Economy.ProductionPerSecondMass })
				end

				--all units positions
				local pos = u:GetPosition()
				if(not self.allBuildingsPostions[pos[1]]) then
					self.allBuildingsPostions[pos[1]] = {}
				end
				self.allBuildingsPostions[pos[1]][pos[3]] = u

				--if pauser.canInvertState(u,moduleName) then

					local focus = u:GetFocus()
					local isConstruction = false
					local isMassFabricator = false
					local isMassStorage = false
					local isMissile = false

					if not focus then
						local is_paused = isPaused(u)

						if EntityCategoryContains(categories.MASSFABRICATION*categories.STRUCTURE, u) then
							isMassFabricator = true
							focus = u
						elseif EntityCategoryContains(categories.NUKE + categories.SILO, u) then
							isMissile = true
							focus = u
						elseif is_paused and (u:IsIdle() or u:GetWorkProgress() == 0) then
						 	--table.insert(unpause, u)
						end
					else
						isConstruction = true
					end

					if focus then
						local id = focus:GetEntityId()
						if id == u:GetEntityId() then
							--LOG(u:GetBlueprint().Description .. " is focusing itself, something went wrong here! Let's not add it to the project list.")
							if isPaused(u) then
								--table.insert(unpause, u)
							end
						else
							project = self.projects[id]
							if not project then
								--LOG("Adding new project " .. id)
								project = import(throttlerPath .. 'Project.lua').Project(focus, isConstruction)
								project.isMassFabricator = isMassFabricator
								
								-- map positions
								local pos = focus:GetPosition()
								if(not self.ProjectPositions[pos[1]]) then
									self.ProjectPositions[pos[1]] = {}
								end
						
								self.ProjectPositions[pos[1]][pos[3]] = focus
								project.Position = pos

								self.projects[id] = project
								self.countProjects = self.countProjects + 1
							end
							--LOG("Entity " .. u:GetEntityId() .. " is an assister")
							project:AddAssister(eco, u)
							self.countAssisters = self.countAssisters + 1
						end
					end
				--end
			end
		end


		for _, p in self.projects do
			p:LoadFinished(eco)
		end

		--LOG("Projects: " .. self.countProjects .. "Assisters: " .. self.countAssisters)
		return self.projects
	end,

	addPlugin = function(self, name, throttleMode, timer)
		FullName = name .. 'Plugin'
		local plugin = import(throttlerPath .. FullName .. '.lua')[FullName]()
		plugin:setThrottleMode(throttleMode)
		self.plugins[string.lower(name)] = plugin
	end,

	manageEconomy = function(self)
		
		if not self.Active then
			return false
		end
		pauser.cleanStates()
		
		--local all_projects = {}
		self.pause_list = {}
		local eco = import(throttlerPath .. 'Economy.lua').Economy()
		--self.ProjectPositions = {}

		self:LoadProjects(eco)
		-- for _, p in self:LoadProjects(eco) do
		-- 	table.insert(all_projects, p)
		-- end

		--preemptive pausing of future assisters, add preemtive projects too? not possible because blueprint cant be retrieved from command queue?
		--for factories it doesn't work, guess the project position is not the same as the engineers target
		local engineers = Units.Get(categories.ENGINEER)
		for _, e in engineers do
			local is_paused = isPaused(e)
			if not e:IsDead() then
				if e:GetFocus() then

				elseif not e:IsIdle() then
					
					local pause = false
		
					local queue = e:GetCommandQueue()
					local p = queue[1].position
					if(queue[1].type == 'Guard' or queue[1].type == 'Repair') then
						if(self.ProjectPositions[p[1]] and self.ProjectPositions[p[1]][p[3]]) then
							local unitID = self.ProjectPositions[p[1]][p[3]]:GetEntityId()
							local project = self.projects[unitID]

							if (VDist3(p, e:GetPosition()) < 15) then --and (project.throttle > 0) then --engineer build range
								local eID = e:GetEntityId()
								self.projects[unitID]:AddAssister(eco, e)
								--print("Egnineer" .. eID .. " added to " .. self.projects[unitID].unitName .. "[" .. unitID .. "]")
								pause = true
							end
						end
					end

					if pause then
						if not self.pause_list.pause then self.pause_list.pause = {pause={}, no_pause={}} end
						table.insert(self.pause_list.pause.pause, e)
					else
						if not self.pause_list.pause then self.pause_list.pause = {pause={}, no_pause={}} end
						table.insert(self.pause_list.pause.no_pause, e)
					end
				else
					if not self.pause_list.pause then self.pause_list.pause = {pause={}, no_pause={}} end
					table.insert(self.pause_list.pause.no_pause, e)	
				end
			end
		end

		-- print ("n_projects " .. table.getsize(all_projects))
		--LOG("NEW BALANCE ROUND")

		import(throttlerPath .. 'Project.lua').throttleIndex = 0
		import(throttlerPath .. 'Project.lua').firstAssister = false
		--LOG("start: " .. eco.energyActual .. " mass:".. eco.massActual)
		local energyActual = eco.energyActual
		local massActual = eco.massActual
		for name, plugin in pairs(self.plugins) do
			if plugin.throttleMode > 0 then
				--LOG("Plugin " .. name .. " cycle started.")
				eco.energyActual = energyActual
				eco.massActual = massActual
				local pause = false
				plugin:resetCycle()
				for _, p in self.projects do
					plugin:add(p)
				end

				plugin:sort()

				--print ("n_plugin_projects " .. table.getsize(plugin.projects))
				for _, p in plugin.projects do
					local ratio_inc

					if p.throttle < 1 then
						if not pause then
							local last_ratio = p.throttle
							local lastThrottle = self.ProjectMetaData[p.id].lastRatio
							plugin:throttle(eco, p)
							if p.throttle > 0 and p.throttle < 1 then
								--LOG("ADJUST THIS SHIT")
								p:adjust_throttle(eco) -- round throttle to nearest assister
								--LOG("ADJUSTED TO " .. p.throttle)
							end

							if p.throttle == 1 then
								pause = true
							end

							if p.throttle ~= lastThrottle then
								self.ProjectMetaData[p.id] = {lastRatio = p.throttle}
							end

							ratio_inc = p.throttle - last_ratio
							eco:setStallFactor()
							eco.energyActual = eco.energyActual + p.energyRequested * (1-ratio_inc) * eco.massStallFactor --use consumption instead of requested? (but there is a rounding bug when stalling hard with many engineers)
							eco.massActual = eco.massActual + p.massRequested * (1-ratio_inc) * eco.energyStallFactor
						end

						if pause then
							p:SetEnergyDrain(0)
						end
					end
				end
				
				--update control pannel
				if self.debuggingUI == 1 then
					import(modPath .. "controlPannel/controlPannel.lua").debugProjectStats(plugin.projects,name)
				elseif self.debuggingUI == 0 then
					import(modPath .. "controlPannel/controlPannel.lua").hideButtons()
					self.debuggingUI = -1
				end
			end
		end
		--LOG("end: " .. eco.energyActual .. " mass:".. eco.massActual)

		table.sort(self.projects, function(a, b) return a.index < b.index end)
		--LOG(repr(all_projects)) --printing of a table?

		for _, plugin in pairs(self.plugins) do
			for _, p in plugin.projects do
				p:pause(self.pause_list)
			end
		end

		for toggle_key, modes in self.pause_list do
			local toggle = toggle_key

			if toggle ~= 'pause' then
				toggle = tonumber(string.sub(toggle, 8))
			end

			for mode, units in modes do
				
				self:setPaused(units, toggle, mode == 'pause')
			end
		end

	end,
	
	setPaused = function(self, units, toggle, pause)
		if toggle == 'pause' then
			pauser.Pause(units, pause, moduleName)
		else
			pauser.Toggle(units, pause, moduleName, toggle)
		end
	end
})


