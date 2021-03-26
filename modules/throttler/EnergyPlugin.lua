local modPath = '/mods/EM/'
local ThrottlerPlugin = import(modPath .. 'modules/throttler/ThrottlerPlugin.lua').ThrottlerPlugin

EnergyPlugin = Class(ThrottlerPlugin) {
	constructionCategories = {
		fabs = {name="T2/T3 Mass fabrication", category = (categories.TECH2 + categories.TECH3) * categories.STRUCTURE * categories.MASSFABRICATION, priority = 1, storage = 0.2},
		para = {name="Paragon", category = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.EXPERIMENTAL, priority = 3},
		lan3 = {name="T3 Land Units",  category = categories.LAND * categories.TECH3 * categories.MOBILE, priority = 30},
		lan2 = {name="T2 Land Units",  category = categories.LAND * categories.TECH2 * categories.MOBILE, priority = 50},
		lan1 = {name="T1 Land Units",  category = categories.LAND * categories.TECH1 * categories.MOBILE, priority = 80},
		air3 = {name="T3 Air Units",   category = categories.AIR * categories.TECH3 * categories.MOBILE, priority = 30, storage = 0.2},
		air2 = {name="T2 Air Units",   category = categories.AIR * categories.TECH2 * categories.MOBILE, priority = 30},
		air1 = {name="T1 Air Units",   category = categories.AIR * categories.TECH1 * categories.MOBILE, priority = 30},
		nav3 = {name="T3 Naval Units", category = categories.NAVAL * categories.TECH3 * categories.MOBILE, priority = 30},
		nav2 = {name="T2 Naval Units", category = categories.NAVAL * categories.TECH2 * categories.MOBILE, priority = 50},
		nav1 = {name="T1 Naval Units", category = categories.NAVAL * categories.TECH1 * categories.MOBILE, priority = 80},
		exp = {name="Experimental unit", category = categories.MOBILE * categories.EXPERIMENTAL, priority = 90},
		acu = {name="ACU upgrades", category = categories.LAND * categories.MOBILE * categories.COMMAND, priority = 100},
		scu = {name="SCU upgrades", category = categories.LAND * categories.MOBILE * categories.SUBCOMMANDER, priority = 50},
		mex = {name="Mass Extractors T2/T3", category = categories.STRUCTURE * (categories.TECH2 + categories.TECH3) * categories.MASSEXTRACTION, priority = 5, storage = 0.02},
		stor = {name="Energy Storage", category = categories.STRUCTURE * categories.ENERGYSTORAGE, priority = 97},
		prod = {name="Energy Production", category = categories.STRUCTURE * categories.ENERGYPRODUCTION, priority = 100},
		build = {name="Building", category = categories.STRUCTURE - categories.MASSEXTRACTION - categories.MASSFABRICATION, priority = 40},
	},

	_sortProjects = function(a, b)
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
		local net = eco:energyNet(project.energyMinStorage * eco.energyMax, project.prio, 1)
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
