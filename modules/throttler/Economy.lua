Economy = Class({
	data = {},

	__init = function(self)
		self:Init()

		return self
	end,

	Init = function(self, data)
		local types = {'MASS', 'ENERGY'}
		local mapping = {maxStorage="Max", stored="Stored", income="Income", lastUseRequested="Requested", lastUseActual="Actual",  net_income="net_income"}
		local per_tick = {income=true, lastUseRequested=true, lastUseActual=true}

		tps = GetSimTicksPerSecond()
		data = GetEconomyTotals()

		for _, t in types do
			local prefix = string.lower(t)

			for k, m in mapping do
				if per_tick[k] then -- convert data in tick -> seconds
					data[k][t] = data[k][t] * tps
				end

				self[prefix .. m] = data[k][t]
			end

			self[prefix .. "Ratio"] = data['stored'][t] / data['maxStorage'][t]
			self[prefix .. "Ratio"] = data['stored'][t] / data['maxStorage'][t]
			
			if self[prefix .. 'Stored'] < 1 and (self[prefix .. 'Income'] - self[prefix .. 'Requested'] < 0) then
				self[prefix .. 'Stall'] = true 
			end

			if self[prefix .. 'Stored'] < 1 then
				self[prefix .. 'Actual'] = math.min(self[prefix .. 'Actual'], self[prefix .. 'Income']) -- mex bug
			end

			--set min storage´
			local Max = self[prefix .. 'Max']

			local energyMin = self[prefix .. 'Income'] --* (GetGameTimeSeconds() / 4000 + 1)
			if Max > 5100 then 
				energyMin = math.max(energyMin,5100)
			end

			local minStorageLimit = Max * 0.6
			if energyMin > minStorageLimit then
				energyMin = minStorageLimit
			end
			--print(energyMin)

			self['energyMinStored'] = energyMin
		end
	end,

	net = function(self, type, Min)

		local stored = self[type .. 'Stored'] - Min
		local maxStored = self[type .. 'Max']
		local drain = self[type .. 'Income'] - self[type .. 'Actual']

		local drainSecMinimum = 2
		-- if maxStored / drain < drainSecMinimum then
		-- 	drainSecMinimum = maxStored / drain
		-- 	if drainSecMinimum < 0 then 
		-- 		drainSecMinimum = 5
		-- 	end
		-- end

		if stored > 0 then
			stored = stored / drainSecMinimum
		end

		return drain + stored
	end,

	massNet = function(self, massMin)
		return self:net('mass', massMin)
	end,

	energyNet = function(self, energyMin, prio)
		if prio == 100 then 
			energyMin = 0
		else
			energyMin = math.max(self['energyMinStored'],energyMin)
		end
		return self:net('energy', energyMin)
	end,
})
