local modPath = '/mods/EM/'
local isPaused = import(modPath .. 'modules/throttler.lua').isPaused
local Project = import(modPath .. 'modules/throttler/Project.lua').Project

local getUnits = import(modPath .. 'modules/units.lua').getUnits
local econData = import(modPath .. 'modules/units.lua').econData

EcoManager = Class({
	eco = nil,
	projects = {},

	LoadProjects = function(self, eco)
		local unpause = {}

		self.projects = {}
		units = getUnits() -- FIXME: Filter out ENGINEER and FACTORY here?
		LOG("Scanning " .. table.getsize(units) .. " units for projects")

		--print "Load projects"
		for _, u in units do
			local project

			if not u:IsDead() then
				local focus = u:GetFocus()

				if not focus then
					local is_paused = isPaused(u)
					if EntityCategoryContains(categories.MASSFABRICATION, u) then
						data = econData(u)
						if data.energyRequested == 0 and not isPaused(u) then
							focus = u
						end
					elseif is_paused and u:IsIdle() or u:GetWorkProgress() == 0 then
						table.insert(unpause, u)
					end
				end

				if focus then
					local id = focus:GetEntityId()

					project = self.projects[id]
					if not project then
						LOG("Adding new project " .. id)

						project = Project(focus)
						self.projects[id] = project
					end

					LOG("Entity " .. u:GetEntityId() .. " is an assister")

					project:AddAssister(eco, u)
				end
			end
		end

		if unpause then
			import(modPath .. 'modules/throttler.lua').setPause(unpause, 'pause', false)
		end

		return self.projects
	end,
})
