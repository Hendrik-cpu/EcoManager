local modPath = '/mods/EM/'
local ThrottlerPlugin = import(modPath .. 'modules/throttler/ThrottlerPlugin.lua').ThrottlerPlugin

--todo:
--min storage = 


MassPlugin = Class(ThrottlerPlugin) {
	constructionCategories = {
		{name="Mass Extractors T1", category = categories.STRUCTURE * categories.TECH1 * categories.MASSEXTRACTION, priority = 1000, massProduction = true},
		{name="Mass Extractors T2", category = categories.STRUCTURE * categories.TECH2 * categories.MASSEXTRACTION, priority = 1, massProduction = true},
		{name="Mass Storage", category = categories.STRUCTURE * categories.MASSSTORAGE, priority = 1, storage = 0.01, massProduction = true},
		{name="Mass Extractors T3", category = categories.STRUCTURE * categories.TECH3 * categories.MASSEXTRACTION, priority = 1, massProduction = true},
		{name="T2/T3 Mass fabrication", category = (categories.TECH2 + categories.TECH3) * categories.STRUCTURE * categories.MASSFABRICATION, priority = 0.5, massProduction = true},
	},
	MassProductionRequestedMass = 0,

	_sortProjects = function(a, b)
		return a:mProdPriority() < b:mProdPriority()
	end,

	add = function(self, project)
		local category
		local u = project.unit

		cats = self.constructionCategories
		for _, c in cats do
			if EntityCategoryContains(c.category, u) then
				category = c
				break
			end
		end

		if category then
			project.isMassProduction = category['massProduction']
			project.prio = category['priority']
			project.massMinStorage = category['storage']
			table.insert(self.projects, project)
		end
	end,

	throttle = function(self, eco, project)
		local prio = project.priority
		if UnpausedCount == 0 then 
			prio = 100 
		end

		local net = eco:massNet(0, prio)
		local new_net

		if project.isMassProduction then 
			self.MassProductionRequestedMass = self.MassProductionRequestedMass + math.min(project.massRequested, project.massCostRemaining)
		end

		local new_net = net - math.min(project.massRequested, project.massCostRemaining) --+ 0.2 * eco.massIncome -- allow stall untill stalling 50% of eco except that used by mass prod
		if new_net < 0 and UnpausedCount > 0 then -- this project will stall eco
			project:SetMassDrain(math.max(0, net))
		else
			UnpausedCount = UnpausedCount + 1
		end
	end,
	resetCycle = function(self)
		self.projects = {}
		self.MassProductionRequestedMass = 0
		UnpausedCount = 0
	end,
}
