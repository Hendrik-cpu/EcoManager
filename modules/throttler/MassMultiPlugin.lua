local modPath = '/mods/EM/'
local ThrottlerPlugin = import(modPath .. 'modules/throttler/ThrottlerPlugin.lua').ThrottlerPlugin

MassMultiPlugin = Class(ThrottlerPlugin) {
	constructionCategories = {
		{name="Mass Extractors T1", category = categories.STRUCTURE * categories.TECH1 * categories.MASSEXTRACTION, priority = 1000, massProduction = true},
		{name="Mass Extractors T2", category = categories.STRUCTURE * categories.TECH2 * categories.MASSEXTRACTION, priority = 1, massProduction = true},
		{name="Mass Storage", category = categories.STRUCTURE * categories.MASSSTORAGE, priority = 1, storage = 0.01, massProduction = true},
		{name="Mass Extractors T3", category = categories.STRUCTURE * categories.TECH3 * categories.MASSEXTRACTION, priority = 1, massProduction = true},
		{name="T2/T3 Mass fabrication", category = (categories.TECH2 + categories.TECH3) * categories.STRUCTURE * categories.MASSFABRICATION, priority = 0.5, massProduction = true},

		{name="Paragon", category = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.EXPERIMENTAL, priority = 50},
		{name="T1 Land Units",  category = categories.LAND * categories.TECH1 * categories.MOBILE, priority = 40},
		{name="T2 Land Units",  category = categories.LAND * categories.TECH2 * categories.MOBILE, priority = 40},
		{name="T3 Land Units",  category = categories.LAND * categories.TECH3 * categories.MOBILE, priority = 40},
		{name="T1 Air Units",   category = categories.AIR * categories.TECH1 * categories.MOBILE, priority = 70},
		{name="T2 Air Units",   category = categories.AIR * categories.TECH2 * categories.MOBILE, priority = 80},
		{name="T3 Air Units",   category = categories.AIR * categories.TECH3 * categories.MOBILE, priority = 90},
		{name="T1 Naval Units", category = categories.NAVAL * categories.TECH1 * categories.MOBILE, priority = 40},
		{name="T2 Naval Units", category = categories.NAVAL * categories.TECH2 * categories.MOBILE, priority = 40},
		{name="T3 Naval Units", category = categories.NAVAL * categories.TECH3 * categories.MOBILE, priority = 40},
		{name="Experimental unit", category = categories.MOBILE * categories.EXPERIMENTAL, priority = 80},
		{name="ACU upgrades", category = categories.LAND * categories.MOBILE * categories.COMMAND, priority = 100},
		{name="SCU upgrades", category = categories.LAND * categories.MOBILE * categories.SUBCOMMANDER, priority = 40},
		{name="Energy Storage", category = categories.STRUCTURE * categories.ENERGYSTORAGE, priority = 2},
		{name="Energy Production", category = categories.STRUCTURE * categories.ENERGYPRODUCTION, priority = 1},
		{name="Building", category = categories.STRUCTURE - categories.MASSEXTRACTION - categories.DEFENSE, priority = 30},
		{name="Defense", category = categories.STRUCTURE * categories.DEFENSE, priority = 80},
	},

	MassProductionOnly = true,

	_sortProjects = function(a, b)
		return a:mProdPriority() < b:mProdPriority()
	end,

	add = function(self, project)
		if project.massRequested > 0 then 
			local category
			local u = project.unit

			cats = self.constructionCategories
			for _, c in cats do
				if EntityCategoryContains(c.category, u) then
					category = c
					break
				end
			end

			if self.MassProductionOnly and not category.massProduction then
				category = nil
			end

			if category then
				project.prio = category['priority']
				project.massMinStorage = category['storage']
				table.insert(self.projects, project)
			end
		end
	end,

	throttle = function(self, eco, project)
		local prio = project.priority
		local net = eco:massNet(0, prio, 5)
		local new_net

		local new_net = net - math.min(project.massRequested, project.massCostRemaining)
		if new_net < 0 and self.UnpausedCount > 0 then
			project:SetMassDrain(math.max(0, net))
		else
			self.UnpausedCount = self.UnpausedCount + 1
		end
	end,
	
	resetCycle = function(self)
		self.projects = {}
		self.UnpausedCount = 0
	end,
}
