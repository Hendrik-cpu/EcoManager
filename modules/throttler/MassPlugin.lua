local modPath = '/mods/EM/'
local ThrottlerPlugin = import(modPath .. 'modules/throttler/ThrottlerPlugin.lua').ThrottlerPlugin

MassPlugin = Class(ThrottlerPlugin) {
	constructionCategories = {
		--{name="Mass Extractors T1", category = categories.STRUCTURE * categories.TECH1 * categories.MASSEXTRACTION, priority = 90},
		{name="Mass Extractors T2", category = categories.STRUCTURE * categories.TECH2 * categories.MASSEXTRACTION, priority = 90, storage = 0.01},
		{name="Mass Storage", category = categories.STRUCTURE * categories.MASSSTORAGE, priority = 90, storage = 0.01},
		{name="Mass Extractors T3", category = categories.STRUCTURE * categories.TECH3 * categories.MASSEXTRACTION, priority = 90, storage = 0.01},
	},
	
	_sortProjects = function(a, b)

		--handles buildables
		local av = a.mCalculatePriority(a)
		local bv = b.mCalculatePriority(b)

		--handles mass production
		if a.massPayoffSeconds > 0 then
			av = av + math.max(0, 140 - a.massPayoffSeconds)
		end
		if b.massPayoffSeconds > 0 then
			bv = bv + math.max(0, 140 - b.massPayoffSeconds)
		end

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
			project.massMinStorage = category['storage']
			table.insert(self.projects, project)
		end
	end,

	throttle = function(self, eco, project)
		local net = eco:massNet(0)
		local new_net

		local new_net = net - math.min(project.massRequested, project.massCostRemaining)
		if new_net < 0 then -- next project will stall eco
			-- allow stall untill stalling 50% of eco:
			project:SetMassDrain(math.max(0, net))
		end
	end,
}
