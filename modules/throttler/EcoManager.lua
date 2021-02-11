local modPath = '/mods/EM/'
local Pause = import(modPath .. 'modules/pause.lua').Pause
local throttleActivationTimer = (5 * 60)
local activationMSG_Not_Printed = true
local Economy = import(modPath .. 'modules/throttler/Economy.lua').Economy
local EnergyPlugin = import(modPath .. 'modules/throttler/EnergyPlugin.lua').EnergyPlugin
local StoragePlugin = import(modPath .. 'modules/throttler/StoragePlugin.lua').StoragePlugin

local Units = import('/mods/common/units.lua')
local econData = import(modPath .. 'modules/units.lua').econData
local LastUnitsPauseState = {}
local throttlerDisabled = false
mexPositions = {}

function isPaused(u)
	local is_paused
	if EntityCategoryContains(categories.MASSFABRICATION*categories.STRUCTURE, u) then
		is_paused = GetScriptBit({u}, 4)
	else
		is_paused = GetIsPaused({u})
	end

	return is_paused
end
local Project = import(modPath .. 'modules/throttler/Project.lua').Project

function SetPaused(units, state)
	Pause(units, state, 'throttle')
end

function setPause(units, toggle, pause)
	
	for _, u in units do
		LastUnitsPauseState[u:GetEntityId()] = pause
	end

	if toggle == 'pause' then
		SetPaused(units, pause)
	else
		local bit = GetScriptBit(units, toggle)
		local is_paused = bit 
 
		if toggle == 0 then 
			is_paused = not is_paused 
		end

		if pause ~= is_paused then
			ToggleScriptBit(units, toggle, bit)
		end
	end
end 

function ResetPauseStates()
	LastUnitsPauseState = {}
end

function DisableNewEcoManager()
	throttlerDisabled = not throttlerDisabled
	if throttlerDisabled then
		Pause(Units.Get(), false, 'throttle')
		print("Throttler disabled!")
	else
		throttleActivationTimer = 0
		ResetPauseStates()
		print("Throttler enabled!")
	end
end

EcoManager = Class({
	eco = nil,
	projects = {},
	plugins = {},
	ProjectPositions = {},

	__init = function(self)
		self.eco = Economy()
	end,

	LoadProjects = function(self, eco)
		local unpause = {}
		mexPositions = {}
		self.projects = {}
		local units = Units.Get(categories.STRUCTURE + categories.ENGINEER)

		for _, u in units do
			local project
			local StateUntouched = true

			if LastUnitsPauseState[u:GetEntityId()] then
				StateUntouched = isPaused(u) == LastUnitsPauseState[u:GetEntityId()]
			end

			if not u:IsDead() then
				if EntityCategoryContains(categories.STRUCTURE * categories.MASSEXTRACTION, u) then
					table.insert(mexPositions, { position = u:GetPosition(), massProduction = u:GetBlueprint().Economy.ProductionPerSecondMass })
				end

				if StateUntouched then

					local focus = u:GetFocus()
					local isConstruction = false
					local isMassFabricator = false
					local isMassStorage = false

					if not focus then
						local is_paused = isPaused(u)

						if EntityCategoryContains(categories.MASSFABRICATION*categories.STRUCTURE, u) then
							isMassFabricator = true
							focus = u					
						elseif is_paused and (u:IsIdle() or u:GetWorkProgress() == 0) then
						 	table.insert(unpause, u)
						end
					else
						isConstruction = true
					end

					if focus then
						local id = focus:GetEntityId()

						project = self.projects[id]
						if not project then
							--LOG("Adding new project " .. id)
							project = Project(focus)
							project.isConstruction = isConstruction
							project.isMassFabricator = isMassFabricator
							
							-- map positions
							local pos = focus:GetPosition()
							if(not self.ProjectPositions[pos[1]]) then
								self.ProjectPositions[pos[1]] = {}
							end
					
							self.ProjectPositions[pos[1]][pos[3]] = focus
							project.Position = pos

							self.projects[id] = project
						end
						--LOG("Entity " .. u:GetEntityId() .. " is an assister")
						project:AddAssister(eco, u)
					end
				end
			end
		end

		if unpause then
			setPause(unpause, 'pause', false)
		end

		for _, p in self.projects do
			p:LoadFinished(eco)
		end

		return self.projects
	end,

	addPlugin = function(self, name)
		name = name .. 'Plugin'
		local plugin = import(modPath .. 'modules/throttler/' .. name .. '.lua')[name](self.eco)
		table.insert(self.plugins, plugin)
	end,

	manageEconomy = function(self)
		--should throttle be activated?
		local gametime = GetGameTimeSeconds()
		if gametime < throttleActivationTimer then 
			return false
		else
			if activationMSG_Not_Printed then
				print("Throttle activated!") 
				activationMSG_Not_Printed = false
			end
		end

		local eco
		local all_projects = {}
		self.pause_list = {}
		self.eco = Economy()
		
		eco = self.eco

		for _, p in self:LoadProjects(eco) do
			table.insert(all_projects, p)
		end

		if throttlerDisabled then
			return false
		end

		--print ("n_projects " .. table.getsize(all_projects))
		--LOG("NEW BALANCE ROUND")

		import(modPath .. 'modules/throttler/Project.lua').throttleIndex = 0
		import(modPath .. 'modules/throttler/Project.lua').firstAssister = true
		LOG("start: " .. eco.energyActual .. " mass:".. eco.massActual)
		for _, plugin in self.plugins do
			local pause = false
			
			plugin:resetCycle()
			for _, p in all_projects do
				plugin:add(p)
	 		end

	 		plugin:sort()

			--print ("n_plugin_projects " .. table.getsize(plugin.projects))
	 		for _, p in plugin.projects do
		 		local ratio_inc

	 			if p.throttle < 1 then
					if not pause then
						local last_ratio = p.throttle
						plugin:throttle(eco, p)
						if p.throttle > 0 and p.throttle < 1 then
							--LOG("ADJUST THIS SHIT")
							p:adjust_throttle(eco) -- round throttle to nearest assister
							--LOG("ADJUSTED TO " .. p.throttle)
						end

						if p.throttle == 1 then
							pause = true
						end

						ratio_inc = p.throttle - last_ratio
						eco.energyActual = eco.energyActual + p.energyRequested * (1-ratio_inc)
						eco.massActual = eco.massActual + p.massRequested * (1-ratio_inc)
					end

					if pause then
						p:SetEnergyDrain(0)
					end
				end
	 		end
		end
		--LOG("end: " .. eco.energyActual .. " mass:".. eco.massActual)

		table.sort(all_projects, function(a, b) return a.index < b.index end)
		--LOG(repr(all_projects)) --printing of a table?

		--preemptive pausing of future assisters, add preemtive projects too? not possible because blueprint cant be retrieved from command queue?
		local engineers = Units.Get(categories.ENGINEER)
		for _, e in engineers do
			if not e:IsDead() then
				local is_idle = e:IsIdle()
				local focus = e:GetFocus()
				local pause = false
	
				if not (focus) then
				-- engineer isn't focusing, walking towards mex?
					local queue = e:GetCommandQueue()
					local p = queue[1].position
	
					if(queue[1].type == 'Guard' or queue[1].type == 'Repair') then
						--print("guarding engineer found")
						if(self.ProjectPositions[p[1]] and self.ProjectPositions[p[1]][p[3]]) then
							local unitID = self.ProjectPositions[p[1]][p[3]]:GetEntityId()
							local project = self.projects[unitID]

							if (VDist3(p, e:GetPosition()) < 15) and (project.throttle > 0) then -- 10 -> buildrange of engineer maybe?
								pause = true
								--print("close range assister that needs to be paused found")
							end
						end
					--elseif queue[1].type == "BuildMobile" then
						--LOG(repr(queue))
					end
				end

				if pause then
					if not self.pause_list['pause'] then self.pause_list['pause'] = {pause={}, no_pause={}} end
					table.insert(self.pause_list['pause']['pause'], e)
				end
			end
		end

		for _, p in all_projects do
			p:pause(self.pause_list)
		end


		for toggle_key, modes in self.pause_list do
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


