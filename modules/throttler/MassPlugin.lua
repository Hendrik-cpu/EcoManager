local modPath = '/mods/EM/'
local ThrottlerPlugin = import(modPath .. 'modules/throttler/ThrottlerPlugin.lua').ThrottlerPlugin

MassPlugin = Class(ThrottlerPlugin) {
	constructionCategories = {
		{name="T3 Mass fabrication", category = categories.TECH3 * categories.STRUCTURE * categories.MASSFABRICATION, priority = 1, storage = 0.8},
		{name="T2 Mass fabrication", category = categories.STRUCTURE * categories.MASSFABRICATION, priority = 2, storage = 0.8},
		{name="Paragon", category = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.EXPERIMENTAL, lasts_for=3, priority = 3},
		{name="T3 Land Units",  category = categories.LAND * categories.TECH3 * categories.MOBILE, priority = 30},
		{name="T2 Land Units",  category = categories.LAND * categories.TECH2 * categories.MOBILE, priority = 30},
		{name="T1 Land Units",  category = categories.LAND * categories.TECH1 * categories.MOBILE, priority = 35},
		{name="T3 Air Units",   category = categories.AIR * categories.TECH3 * categories.MOBILE, priority = 30, storage = 0.5},
		{name="T2 Air Units",   category = categories.AIR * categories.TECH2 * categories.MOBILE, priority = 30},
		{name="T1 Air Units",   category = categories.AIR * categories.TECH1 * categories.MOBILE, priority = 30},
		{name="T3 Naval Units", category = categories.NAVAL * categories.TECH3 * categories.MOBILE, priority = 30},
		{name="T2 Naval Units", category = categories.NAVAL * categories.TECH2 * categories.MOBILE, priority = 30},
		{name="T1 Naval Units", category = categories.NAVAL * categories.TECH1 * categories.MOBILE, priority = 35},
		{name="Experimental unit", category = categories.MOBILE * categories.EXPERIMENTAL, priority = 40},
		--{name="ACU upgrades", category = categories.LAND * categories.MOBILE * categories.COMMAND, priority = 97},
		{name="SCU upgrades", category = categories.LAND * categories.MOBILE * categories.SUBCOMMANDER, priority = 50},
		{name="Mass Extractors T1", category = categories.STRUCTURE * categories.TECH1 * categories.MASSEXTRACTION, priority = 99},
		{name="Mass Extractors T2/T3", category = categories.STRUCTURE * (categories.TECH2 + categories.TECH3) * categories.MASSEXTRACTION, priority = 5},
		{name="Energy Storage", category = categories.STRUCTURE * categories.ENERGYSTORAGE, priority = 98},
		{name="Energy Production", category = categories.STRUCTURE * categories.ENERGYPRODUCTION, priority = 100},
		{name="Building", category = categories.STRUCTURE - categories.MASSEXTRACTION, priority = 40},
	},
	
	_sortProjects = function(a, b)
		return a.massPayoffSeconds < b.massPayoffSeconds
	end,

	add = function(self, project)
		if EntityCategoryContains(categories.MASSEXTRACTION, project.unit) then
			table.insert(self.projects, project)
		end
	end,

	throttle = function(self, eco, project)
		for _, t in {'mass', 'energy'} do
			local net = eco:net(t)
			local new_net = net - project[t .. 'Requested']

			if new_net < 0 then
				if t == 'energy' then
					project:SetEnergyDrain(math.max(0, net))
				else
					project:SetMassDrain(math.max(0, net))
				end
			end
		end

	end,
}
