local modPath = '/mods/EM/'
local ThrottlerPlugin = import(modPath .. 'modules/throttler/ThrottlerPlugin.lua').ThrottlerPlugin

EnergyPlugin = Class(ThrottlerPlugin) {
	constructionCategories = {
		{name="T2/T3 Mass fabrication", category = (categories.TECH2 + categories.TECH3) * categories.STRUCTURE * categories.MASSFABRICATION, priority = 1, storage = 0.8},
		--{name="T2 Mass fabrication", category = categories.TECH2 * categories.STRUCTURE * categories.MASSFABRICATION, priority = 1, storage = 0.8},
		{name="Paragon", category = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.EXPERIMENTAL, priority = 3},
		{name="T3 Land Units",  category = categories.LAND * categories.TECH3 * categories.MOBILE, priority = 30},
		{name="T2 Land Units",  category = categories.LAND * categories.TECH2 * categories.MOBILE, priority = 50},
		{name="T1 Land Units",  category = categories.LAND * categories.TECH1 * categories.MOBILE, priority = 80},
		{name="T3 Air Units",   category = categories.AIR * categories.TECH3 * categories.MOBILE, priority = 30, storage = 0.5},
		{name="T2 Air Units",   category = categories.AIR * categories.TECH2 * categories.MOBILE, priority = 30},
		{name="T1 Air Units",   category = categories.AIR * categories.TECH1 * categories.MOBILE, priority = 30},
		{name="T3 Naval Units", category = categories.NAVAL * categories.TECH3 * categories.MOBILE, priority = 30},
		{name="T2 Naval Units", category = categories.NAVAL * categories.TECH2 * categories.MOBILE, priority = 50},
		{name="T1 Naval Units", category = categories.NAVAL * categories.TECH1 * categories.MOBILE, priority = 80},
		{name="Experimental unit", category = categories.MOBILE * categories.EXPERIMENTAL, priority = 90},
		{name="ACU upgrades", category = categories.LAND * categories.MOBILE * categories.COMMAND, priority = 100},
		{name="SCU upgrades", category = categories.LAND * categories.MOBILE * categories.SUBCOMMANDER, priority = 50},
		--{name="Mass Extractors T1", category = categories.STRUCTURE * categories.TECH1 * categories.MASSEXTRACTION, priority = 99},
		{name="Mass Extractors T2/T3", category = categories.STRUCTURE * (categories.TECH2 + categories.TECH3) * categories.MASSEXTRACTION, priority = 5, storage = 0.02},
		{name="Energy Storage", category = categories.STRUCTURE * categories.ENERGYSTORAGE, priority = 97},
		{name="Energy Production", category = categories.STRUCTURE * categories.ENERGYPRODUCTION, priority = 100},
		{name="Building", category = categories.STRUCTURE - categories.MASSEXTRACTION, priority = 40},
	},

	_sortProjects = function(a, b) --sort algorithm selector
		return a:eCalculatePriority() > b:eCalculatePriority()
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
			project.prio = category['priority']
			project.energyMinStorage = category['storage']
			project.massRatio = 0
			if project.energyRequested > 0 and project.massProduction > 0 then
				project.massRatio = project.massProduction / project.energyRequested
			end

			table.insert(self.projects, project)
		end
	end,

	throttle = function(self, eco, project)
		local net = eco:energyNet(project.energyMinStorage * eco.energyMax, project.prio)
		local new_net

		-- if project.prio == 100 then
		-- 	project.energyRequested = project.energyRequested * 5
		-- end

		local new_net = net - math.min(project.energyRequested, project.energyCostRemaining) 
		if new_net < 0 and (UnpausedCount > 0 or project.workLeft == 1) then
			project:SetEnergyDrain(math.max(0, net))
		else
			UnpausedCount = UnpausedCount + 1
		end
	end,

	resetCycle = function(self)
		self.projects = {}
		UnpausedCount = 0
	end,
}
