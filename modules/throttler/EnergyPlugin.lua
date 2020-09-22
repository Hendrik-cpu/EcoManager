local modPath = '/mods/EM/'
local ThrottlerPlugin = import(modPath .. 'modules/throttler/ThrottlerPlugin.lua').ThrottlerPlugin

local MASSFAB_RATIO = 0.4

EnergyPlugin = Class(ThrottlerPlugin) {
	constructionCategories = {
		{name="T3 Mass fabrication", category = categories.TECH3 * categories.STRUCTURE * categories.MASSFABRICATION, toggle=4, priority = 0},
		{name="T2 Mass fabrication", category = categories.STRUCTURE * categories.MASSFABRICATION, toggle=4, priority = 1},
		{name="Paragon", category = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.EXPERIMENTAL, lasts_for=3, priority = 5},
		{name="T3 Land Units",  category = categories.LAND * categories.TECH3 * categories.MOBILE, priority = 30},
		{name="T2 Land Units",  category = categories.LAND * categories.TECH2 * categories.MOBILE, priority = 30},
		{name="T1 Land Units",  category = categories.LAND * categories.TECH1 * categories.MOBILE, priority = 30},
		{name="T3 Air Units",   category = categories.AIR * categories.TECH3 * categories.MOBILE, priority = 10},
		{name="T2 Air Units",   category = categories.AIR * categories.TECH2 * categories.MOBILE, priority = 10},
		{name="T1 Air Units",   category = categories.AIR * categories.TECH1 * categories.MOBILE, priority = 10},
		{name="T3 Naval Units", category = categories.NAVAL * categories.TECH3 * categories.MOBILE, priority = 30},
		{name="T2 Naval Units", category = categories.NAVAL * categories.TECH2 * categories.MOBILE, priority = 30},
		{name="T1 Naval Units", category = categories.NAVAL * categories.TECH1 * categories.MOBILE, priority = 30},
		{name="Experimental unit", category = categories.MOBILE * categories.EXPERIMENTAL, off=3, priority = 40},
		{name="ACU/SCU upgrades", category = categories.LAND * categories.MOBILE * (categories.COMMAND + categories.SUBCOMMANDER), off=2, priority = 50},
		{name="Mass Extractors", category = categories.STRUCTURE * categories.MASSEXTRACTION, priority = 20},
		{name="Energy Storage", category = categories.STRUCTURE * categories.ENERGYSTORAGE, priority = 98},
		{name="Energy Production", category = categories.STRUCTURE * categories.ENERGYPRODUCTION, priority = 100},
		{name="Building", category = categories.STRUCTURE - categories.MASSEXTRACTION, priority = 25},
	},

	_sortProjects = function(a, b)
		-- local av = a['prio'] * 100000 + a['massRatio']*100 - (a['timeLeft'])
		-- local bv = b['prio'] * 100000 + b['massRatio']*100 - (b['timeLeft'])
		local av = (a['massProportion'] + a['prio'] / 100) / 2 + a['workProgress'] * 2
		local bv = (b['massProportion'] + b['prio'] / 100) / 2 + b['workProgress'] * 2

		if a['energyPayoffSeconds'] > 0 then
			av = av + 10000 - a['energyPayoffSeconds'] 
		end
		if b['energyPayoffSeconds'] > 0 then
			bv = bv + 10000 - b['energyPayoffSeconds'] 
		end
		--print(av .. "<>" .. bv)
		return av > bv
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
			project.massRatio = 0
			if project.energyRequested > 0 and project.massProduction > 0 then
				project.massRatio = project.massProduction / project.energyRequested
			end

			table.insert(self.projects, project)
		end
	end,

	throttle = function(self, eco, project)
		local net = eco:energyNet()
		local new_net
		local StallingMass = eco.massStored <= 0 
		StallingMass = StallingMass and (eco.massIncome - eco.massRequested) < 0

		if eco.energyMax > 0 then
			if eco.energyStored / eco.energyMax >= 0.90 and StallingMass then
				project:SetEnergyDrain(project.energyRequested)
				do return end
			end
		end

		-- if project.prio == 100 then
		-- 	project.energyRequested = project.energyRequested * 5
		-- end

		local new_net = net - math.min(project.energyRequested, project.energyCostRemaining)
		--print("Net: " .. net .. "|Energy Income: " .. eco.energyIncome .. "|Energy Actual: " .. eco.energyActual)
		if project.prio <= 1 then
			local MinStorage = (project.energyMinStorage * eco.energyMax)
			new_net = new_net - (MinStorage / 5) --* MASSFAB_RATIO
			--print("unit ID: " .. project.id .. "|New Net: " .. new_net .. "|Net: " .. net .. "|min storage: " .. (project.energyMinStorage * eco.energyMax) .. "|stored: " .. eco.energyStored)
			if new_net <0 then
				net=0
			end
		end

		--LOG("NET " .. net .. " ENERGY REQUESTED " .. project.energyRequested .. " DIFF " .. new_net .. " MASS RATIO " .. project.massRatio)

		if new_net < 0 then
			project:SetEnergyDrain(math.max(0, net))
			--LOG("Throttle set to " .. project.throttle)
		end
	end,
}
