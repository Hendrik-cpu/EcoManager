Economy = Class({
	data = {},
	energyMin = 1000,
	massMin = 0,

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

			--set min storage
			self.energyMin = data['maxStorage'][t] * 0.01
			if self.energyMin > 40 then 
				self.energyMin = math.max(self.energyMin,5100)
			end

			local newMin = data['stored'][t] - self.energyMin
			if newMin <= 0 then
				newMin = 0
			end
			self[prefix .. 'minStored'] = newMin
		end
	end,

	net = function(self, type)
		local stored = self[type .. 'minStored']
		local maxStored = self[type .. 'Max']
		local drain = self[type .. 'Income'] - self[type .. 'Actual']

		local drainSecMinimum = 5
		if maxStored / drain < drainSecMinimum then
			drainSecMinimum = maxStored / drain
			if drainSecMinimum < 0 then 
				drainSecMinimum = 5
			end
		end

		if stored > 0 then
			stored = stored / drainSecMinimum
		end

		return drain + stored
	end,

	massNet = function(self)
		return self:net('mass')
	end,

	energyNet = function(self)
		return self:net('energy')
	end,
})
