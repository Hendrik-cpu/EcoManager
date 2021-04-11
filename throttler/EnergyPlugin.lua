local modPath = '/mods/EM/'
local ThrottlerPlugin = import(modPath .. 'throttler/ThrottlerPlugin.lua').ThrottlerPlugin

EnergyPlugin = Class(ThrottlerPlugin) {
	constructionCategories = {
		fabs = {name="T2/T3 Mass fabrication", category = (categories.TECH2 + categories.TECH3) * categories.STRUCTURE * categories.MASSFABRICATION, priority = 1},
		para = {name="Paragon", category = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.EXPERIMENTAL, priority = 3},
		lan3 = {name="T3 Land Units",  category = categories.LAND * categories.TECH3 * categories.MOBILE, priority = 30},
		lan2 = {name="T2 Land Units",  category = categories.LAND * categories.TECH2 * categories.MOBILE, priority = 40},
		lan1 = {name="T1 Land Units",  category = categories.LAND * categories.TECH1 * categories.MOBILE, priority = 50},
		air3 = {name="T3 Air Units",   category = categories.AIR * categories.TECH3 * categories.MOBILE, priority = 30},
		air2 = {name="T2 Air Units",   category = categories.AIR * categories.TECH2 * categories.MOBILE, priority = 30},
		air1 = {name="T1 Air Units",   category = categories.AIR * categories.TECH1 * categories.MOBILE, priority = 30},
		nav3 = {name="T3 Naval Units", category = categories.NAVAL * categories.TECH3 * categories.MOBILE, priority = 30},
		nav2 = {name="T2 Naval Units", category = categories.NAVAL * categories.TECH2 * categories.MOBILE, priority = 40},
		nav1 = {name="T1 Naval Units", category = categories.NAVAL * categories.TECH1 * categories.MOBILE, priority = 50},
		exp = {name="Experimental unit", category = categories.MOBILE * categories.EXPERIMENTAL, priority = 60},
		acu = {name="ACU upgrades", category = categories.LAND * categories.MOBILE * categories.COMMAND, priority = 90},
		scu = {name="SCU upgrades", category = categories.LAND * categories.MOBILE * categories.SUBCOMMANDER, priority = 50},
		mex = {name="Mass Extractors T2/T3", category = categories.STRUCTURE * (categories.TECH2 + categories.TECH3) * categories.MASSEXTRACTION, priority = 30},
		stor = {name="Energy Storage", category = categories.STRUCTURE * categories.ENERGYSTORAGE, priority = 97},
		power = {name="Energy Production", category = categories.STRUCTURE * categories.ENERGYPRODUCTION, priority = 100},
		build = {name="Building", category = categories.STRUCTURE - categories.MASSEXTRACTION - categories.ENERGYSTORAGE - categories.ENERGYPRODUCTION - categories.MASSFABRICATION, priority = 40},
	},

	_sortProjects = function(a, b)
		return a.energyFinalFactor > b.energyFinalFactor 
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
			-- project.prio = category.priority
			-- project.energyMinStorage = category.storage
			if category == self.constructionCategories.fabs and project.isConstruction then
				project.prio = self.constructionCategories.build.priority
				project.energyMinStorage = self.constructionCategories.build.storage
			else
				project.prio = category.priority
				project.energyMinStorage = category.storage
			end
			project.energyFinalFactor = project.energyFinalFactor * project.prio - project.energyMinStorage * 10000 --- project.lastRatio
			table.insert(self.projects, project)
		end
	end,

	throttle = function(self, eco, project)
		local a = eco.energyMinStored
		local b = eco.energyMax
		local c = project.energyMinStorage
		local net = eco:energyNet((b-a)*c+a, project.prio, 1)
		local new_net

		local new_net = net - math.min(project.energyRequested, project.energyCostRemaining) 
		if new_net < 0 then
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
