local modPath = '/mods/EM/'
local ThrottlerPlugin = import(modPath .. 'modules/throttler/ThrottlerPlugin.lua').ThrottlerPlugin

StoragePlugin = Class(ThrottlerPlugin) {
	-- __init = function(self, eco)
	-- 	-- eco['massStored'] = eco['massStored'] - 1000
	-- 	-- eco['energyStored']  = eco['energyStored'] - 2000
	-- end,

	_sortProjects = function(a, b)
		-- local av = a['prio'] * 100000 + a['massRatio']*100 - (a['timeLeft'])
		-- local bv = b['prio'] * 100000 + b['massRatio']*100 - (b['timeLeft'])
		local av = a['massProportion']
		local bv = b['massProportion']

		if a['energyPayoffSeconds'] > 0 then
			av = av + 10000 - a['energyPayoffSeconds'] 
		end
		if b['energyPayoffSeconds'] > 0 then
			bv = bv + 10000 - b['energyPayoffSeconds'] 
		end
		if a['massPayoffSeconds'] > 0 then
			av = av - a['massPayoffSeconds'] 
		end
		if b['massPayoffSeconds'] > 0 then
			bv = bv - b['massPayoffSeconds'] 
		end

		--print(av .. " - " .. bv)
		return av > bv
	end,

	add = function(self, project)
		for _, t in types do
			if project[t .. 'minStorage'] > 0 then
				table.insert(self.projects, project)
				break
			end
		end
	end,
	throttle = function(self, eco, project)
		local types = {'mass', 'energy'}

		for _, t in types do
			local net = eco[t .. 'Income'] - eco[t .. 'Actual'] - project[t .. 'Requested']
			local newStorage = eco[t .. 'Stored'] - net
			local minStorage = project[t .. 'minStorage'] * eco[t .. 'Max']
			if(newStorage < minStorage) then
				local diff = minStorage - newStorage
				project:SetTypeDrain(t, diff)
			end
		end
	end,
}
