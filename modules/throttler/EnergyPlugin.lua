local modPath = '/mods/EM/'
local ThrottlerPlugin = import(modPath .. 'modules/throttler/ThrottlerPlugin.lua').ThrottlerPlugin

EnergyPlugin = Class(ThrottlerPlugin) {
	first = true,
	constructionCategories = {
		{name="T3 Mass fabrication", category = categories.TECH3 * categories.STRUCTURE * categories.MASSFABRICATION, toggle=4, priority = 0},
		{name="T2 Mass fabrication", category = categories.STRUCTURE * categories.MASSFABRICATION, toggle=4, priority = 1},
		{name="Paragon", category = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.EXPERIMENTAL, lasts_for=3, priority = 5},
		{name="T3 Land Units",  category = categories.LAND * categories.TECH3 * categories.MOBILE, priority = 60},
		{name="T2 Land Units",  category = categories.LAND * categories.TECH2 * categories.MOBILE, priority = 70},
		--{name="T1 Land Units",  category = categories.LAND * categories.TECH1 * categories.MOBILE, priority = 80},
		{name="T3 Air Units",   category = categories.AIR * categories.TECH3 * categories.MOBILE, priority = 10},
		{name="T2 Air Units",   category = categories.AIR * categories.TECH2 * categories.MOBILE, priority = 70},	
		{name="T1 Air Units",   category = categories.AIR * categories.TECH1 * categories.MOBILE, priority = 80},
		{name="T3 Naval Units", category = categories.NAVAL * categories.TECH3 * categories.MOBILE, priority = 60},
		{name="T2 Naval Units", category = categories.NAVAL * categories.TECH2 * categories.MOBILE, priority = 70},
		{name="T1 Naval Units", category = categories.NAVAL * categories.TECH1 * categories.MOBILE, priority = 80},
		{name="Experimental unit", category = categories.MOBILE * categories.EXPERIMENTAL, off=3, priority = 81},
		{name="ACU/SCU upgrades", category = categories.LAND * categories.MOBILE * (categories.COMMAND + categories.SUBCOMMANDER), off=2, priority = 90},
		{name="Mass Extractors", category = categories.STRUCTURE * categories.MASSEXTRACTION, priority = 91},
		{name="Energy Storage", category = categories.STRUCTURE * categories.ENERGYSTORAGE, priority = 99},
		{name="Energy Production", category = categories.STRUCTURE * categories.ENERGYPRODUCTION, priority = 100},
		{name="Building", category = categories.STRUCTURE - categories.MASSEXTRACTION, priority = 85},
	},
	_sortProjects = function(a, b)
		local av = a['prio'] * 100000 - ((1-a['progress'])*a['buildTime']  / a['buildRate']) + a['massRatio']*100
		local bv = b['prio'] * 100000 - ((1-b['progress'])*b['buildTime'] / b['buildRate']) + b['massRatio']*100

		return av > bv
	end,
	add = function(self, project)
		local category
		local u = project.unit

		cats = self.constructionCategories
		for _, c in cats do
			if(EntityCategoryContains(c.category, u)) then
				category = c
				break
			end
		end

		if(category) then
			project.prio = category['priority']
			project.massRatio = 0
			if(project.energyRequested > 0 and project.massProduced > 0) then
				project.massRatio = project.massProduced / project.energyRequested
			end

			table.insert(self.projects, project)
		end
	end,
	throttle = function(self, eco, project)
		local net = eco:energyNet()

		LOG("NET " .. net .. " ENERGY REQUESTED " .. project.energyRequested .. " DIFF " .. (net - project.energyRequested))
		if(self.first and false) then
			LOG("FIRST PROJECT")
			self.first = false
			return
		end

		if(net - project.energyRequested < 0) then
			project:SetEnergyDrain(math.max(0, net))
		end
		--LOG("Throttle set to " .. project.throttle.ratio)
	end,
}