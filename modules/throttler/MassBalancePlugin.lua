local modPath = '/mods/EM/'
local ThrottlerPlugin = import(modPath .. 'modules/throttler/ThrottlerPlugin.lua').ThrottlerPlugin

MassPlugin = Class(ThrottlerPlugin) {
	constructionCategories = {
		--{name="T2/T3 Mass fabrication", category = (categories.TECH2 + categories.TECH3) * categories.STRUCTURE * categories.MASSFABRICATION, priority = 1, storage = 0.8},
		--{name="Paragon", category = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.EXPERIMENTAL, priority = 3},
		{name="T3 Land Units",  category = categories.LAND * categories.TECH3 * categories.MOBILE, priority = 40},
		{name="T2 Land Units",  category = categories.LAND * categories.TECH2 * categories.MOBILE, priority = 30},
		{name="T1 Land Units",  category = categories.LAND * categories.TECH1 * categories.MOBILE, priority = 20},
		{name="T3 Air Units",   category = categories.AIR * categories.TECH3 * categories.MOBILE, priority = 40},
		{name="T2 Air Units",   category = categories.AIR * categories.TECH2 * categories.MOBILE, priority = 30},
		{name="T1 Air Units",   category = categories.AIR * categories.TECH1 * categories.MOBILE, priority = 20},
		{name="T3 Naval Units", category = categories.NAVAL * categories.TECH3 * categories.MOBILE, priority = 40},
		{name="T2 Naval Units", category = categories.NAVAL * categories.TECH2 * categories.MOBILE, priority = 30},
		{name="T1 Naval Units", category = categories.NAVAL * categories.TECH1 * categories.MOBILE, priority = 20},
		{name="Experimental unit", category = categories.MOBILE * categories.EXPERIMENTAL, priority = 50},
		{name="ACU upgrades", category = categories.LAND * categories.MOBILE * categories.COMMAND, priority = 50},
		{name="SCU upgrades", category = categories.LAND * categories.MOBILE * categories.SUBCOMMANDER, priority = 50},
		--{name="Mass Extractors T1", category = categories.STRUCTURE * categories.TECH1 * categories.MASSEXTRACTION, priority = 99},
		--{name="Mass Extractors T2/T3", category = categories.STRUCTURE * (categories.TECH2 + categories.TECH3) * categories.MASSEXTRACTION, priority = 40},
		{name="Energy Storage", category = categories.STRUCTURE * categories.ENERGYSTORAGE, priority = 1},
		{name="Energy Production", category = categories.STRUCTURE * categories.ENERGYPRODUCTION, priority = 1,
		{name="Building", category = categories.STRUCTURE - categories.MASSEXTRACTION, priority = 40},
	},

	_sortProjects = function(a, b)
		return a:mCalculatePriority() < b:mCalculatePriority()
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
			project.massMinStorage = category['storage']
			table.insert(self.projects, project)
		end
	end,

	throttle = function(self, eco, project)

		local net = eco:massNet(0, project.prio)
		local new_net

		local new_net = net - math.min(project.massRequested, project.massCostRemaining)
		if new_net < 0 then -- this project will stall eco
			project:SetMassDrain(math.max(0, net))
		end
	end,
	
	resetCycle = function(self)
		self.projects = {}
	end,
}