local modPath = '/mods/EM/'
local ThrottlerPlugin = import(modPath .. 'throttler/ThrottlerPlugin.lua').ThrottlerPlugin


MassPlugin = Class(ThrottlerPlugin) {
	constructionCategories = {},

	massProductionOnly = true, --now obsolete? Might remove later
	massProductionPriorityMultiplier = 1,

	_sortProjects = function(a, b)
		return a.massFinalFactor > b.massFinalFactor
	end,

	setThrottleMode = function (self, throttleMode)
		self.throttleMode = throttleMode
		if throttleMode == 0 then
			LOG('Mass throttle is turned off.')
		elseif throttleMode == 1 then
			massProductionOnly = true
			self.constructionCategories = {
				-- mex1 = {name="Mass Extractors T1", category = categories.STRUCTURE * categories.TECH1 * categories.MASSEXTRACTION, priority = 50, massProduction = true},
				mex2 = {name="Mass Extractors T2", category = categories.STRUCTURE * categories.TECH2 * categories.MASSEXTRACTION, priority = 50, massProduction = true},
				mstor = {name="Mass Storage", category = categories.STRUCTURE * categories.MASSSTORAGE, priority = 50, massProduction = true},
				mex3 = {name="Mass Extractors T3", category = categories.STRUCTURE * categories.TECH3 * categories.MASSEXTRACTION, priority = 50, massProduction = true},
				fabs = {name="T2/T3 Mass fabrication", category = (categories.TECH2 + categories.TECH3) * categories.STRUCTURE * categories.MASSFABRICATION, priority = 50, massProduction = true},
			}
			LOG('Mass throttle is set to throttle only mass production.')
		elseif throttleMode == 2 then -- throttle all
			massProductionOnly = false
			self.constructionCategories = {
				-- mex1 = {name="Mass Extractors T1", category = categories.STRUCTURE * categories.TECH1 * categories.MASSEXTRACTION, priority = 50, massProduction = true},
				mex2 = {name="Mass Extractors T2", category = categories.STRUCTURE * categories.TECH2 * categories.MASSEXTRACTION, priority = 50, massProduction = true},
				mstor = {name="Mass Storage", category = categories.STRUCTURE * categories.MASSSTORAGE, priority = 50, massProduction = true},
				mex3 = {name="Mass Extractors T3", category = categories.STRUCTURE * categories.TECH3 * categories.MASSEXTRACTION, priority = 50, massProduction = true},
				fabs = {name="T2/T3 Mass fabrication", category = (categories.TECH2 + categories.TECH3) * categories.STRUCTURE * categories.MASSFABRICATION, priority = 50, massProduction = true},
		
				para = {name="Paragon", category = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.EXPERIMENTAL, priority = 50},
				land1 = {name="T1 Land Units",  category = categories.LAND * categories.TECH1 * categories.MOBILE, priority = 40},
				land2 = {name="T2 Land Units",  category = categories.LAND * categories.TECH2 * categories.MOBILE, priority = 40},
				land3 = {name="T3 Land Units",  category = categories.LAND * categories.TECH3 * categories.MOBILE, priority = 40},
				air1 = {name="T1 Air Units",   category = categories.AIR * categories.TECH1 * categories.MOBILE, priority = 70},
				air2 = {name="T2 Air Units",   category = categories.AIR * categories.TECH2 * categories.MOBILE, priority = 80},
				air3 = {name="T3 Air Units",   category = categories.AIR * categories.TECH3 * categories.MOBILE, priority = 90},
				nav1 = {name="T1 Naval Units", category = categories.NAVAL * categories.TECH1 * categories.MOBILE, priority = 40},
				nav2 = {name="T2 Naval Units", category = categories.NAVAL * categories.TECH2 * categories.MOBILE, priority = 40},
				nav3 = {name="T3 Naval Units", category = categories.NAVAL * categories.TECH3 * categories.MOBILE, priority = 40},
				exp = {name="Experimental unit", category = categories.MOBILE * categories.EXPERIMENTAL, priority = 80},
				acu = {name="ACU upgrades", category = categories.LAND * categories.MOBILE * categories.COMMAND, priority = 99},
				scu = {name="SCU upgrades", category = categories.LAND * categories.MOBILE * categories.SUBCOMMANDER, priority = 40},
				estor = {name="Energy Storage", category = categories.STRUCTURE * categories.ENERGYSTORAGE, priority = 2},
				eprod = {name="Energy Production", category = categories.STRUCTURE * categories.ENERGYPRODUCTION, priority = 1},
				nukes = {name="Nukes", category = categories.NUKE, priority = 99},
				tml = {name="TML", category = categories.STRUCTURE * categories.TACTICALMISSILEPLATFORM, priority = 91},
				def = {name="Defense", category = categories.STRUCTURE * categories.DEFENSE, priority = 80},
				build = {name="Building", category = categories.STRUCTURE - categories.MASSEXTRACTION - categories.ENERGYSTORAGE - categories.ENERGYPRODUCTION - categories.MASSFABRICATION - categories.DEFENSE, priority = 30},
			}
			LOG('Mass throttle is set to throttle everything.')
		end
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

			if self.massProductionOnly and not category.massProduction then
				category = nil
			end

			if category and project.massRequested > 0 then
				if category.massProduction then
					project.prio = self.massProductionPriorityMultiplier * category['priority']
				else
					project.prio = category['priority']
				end

				project.massMinStorage = category['storage']
				project.massFinalFactor = project.massFinalFactor * project.prio  - project.massMinStorage * 10000 --- project.lastRatio

				table.insert(self.projects, project)
			end
		end
	end,

	throttle = function(self, eco, project)
		local prio = project.priority
		local net = eco:massNet(0, prio, 5)
		local new_net

		local new_net = net - math.min(project.massRequested, project.massCostRemaining)
		if new_net < 0 and (self.UnpausedCount > 0 or self.massProductionOnly == false) then
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
