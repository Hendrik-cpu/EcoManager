local modPath = '/mods/EM/'
local ThrottlerPlugin = import(modPath .. 'modules/throttler/ThrottlerPlugin.lua').ThrottlerPlugin

local MASSFAB_RATIO = 0.4

EnergyPlugin = Class(ThrottlerPlugin) {
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

	_sortProjects = function(a, b) --sort algorithm selector
		
		--handles mass fabricators vs. mass fabricators
		if b.isMassFabricator and a.isMassFabricator then --could actually add mexes too since there is a working priority
			--print("massfabs detected!")
			--print("u consume " .. b.energyRequested .. " energy and i consume " .. a.energyRequested .. "energy. We are both mass fabricators :)")
			local diff = (b.energyRequested / math.max(b.massProducedActual,b.massProduction)) - (a.energyRequested / math.max(a.massProducedActual,b.massProduction)) 
			--print(a.massProducedActual*10 .. " - " .. b.massProducedActual * 10)
			if diff > 0 then
				return true
			elseif diff == 0 then
				return a.prio > b.prio
			else
				return false
			end
		end

		--handles buildables
		local av = a.CalculatePriority(a)
		local bv = b.CalculatePriority(b)
		--print(a.massRequested.. " - " .. a.energyRequested .. " | " .. b.massRequested .. " - " .. b.energyRequested)
		--print("prio: " .. a.prio  .. "-" .. b.prio .. "|massProportion: " .. a.massProportion .. "-" .. b.massProportion .. "|workprogress: " .. a.workProgress .. "|" .. b.workProgress .. "|Calc: " .. av .. "|" .. bv) 

		--handles power production
		if a.energyPayoffSeconds > 0 then
			av = av + 10000 - a.energyPayoffSeconds 
		end
		if b.energyPayoffSeconds > 0 then
			bv = bv + 10000 - b.energyPayoffSeconds 
		end

		--print(av .. " vs " .. bv)  
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
			project.energyMinStorage = category['storage']
			project.massRatio = 0
			if project.energyRequested > 0 and project.massProduction > 0 then
				project.massRatio = project.massProduction / project.energyRequested
			end

			table.insert(self.projects, project)
		end
	end,

	throttle = function(self, eco, project)
		local net = eco:energyNet(project.energyMinStorage * eco.energyMax)
		local new_net
		--local StallingMass = eco.massStored < 1
		--StallingMass = StallingMass and (eco.massIncome - eco.massRequested) < 0

		-- if eco.energyMax > 0 then
		-- 	if (eco.energyStored / eco.energyMax) >= 0.90 then
		-- 		project:SetEnergyDrain(project.energyRequested)
		-- 		return false
		-- 	end
		-- end

		-- if project.prio == 100 then
		-- 	project.energyRequested = project.energyRequested * 5
		-- end

		local new_net = net - math.min(project.energyRequested, project.energyCostRemaining)
		--print("Net: " .. net .. "|Energy Income: " .. eco.energyIncome .. "|Energy Actual: " .. eco.energyActual)
		--if project.isMassFabricator then
			-- local minStorage = (project.energyMinStorage * eco.energyMax)
			-- new_net = new_net - ((eco.energyMax - minStorage) * 0.1) --* MASSFAB_RATIO
			-- --print("unit ID: " .. project.id .. "|New Net: " .. new_net .. "|Net: " .. net .. "|min storage: " .. (project.energyMinStorage * eco.energyMax) .. "|stored: " .. eco.energyStored)
			-- if new_net <0 then
			-- 	net=0
			-- end
		--end

		--LOG("NET " .. net .. " ENERGY REQUESTED " .. project.energyRequested .. " DIFF " .. new_net .. " MASS RATIO " .. project.massRatio)

		if new_net < 0 then
			project:SetEnergyDrain(math.max(0, net))
			--LOG("Throttle set to " .. project.throttle)
		end
	end,
}
