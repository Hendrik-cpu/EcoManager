
local EcoIsPaused=false
local massMinStorage=0
local energyMinStorage=0
function PauseEcoM10_E90()
	if EcoIsPaused then
		massMinStorage=0
		energyMinStorage=0
		EcoIsPaused=false
		print("Mass upgrades have been unpaused.")
	else
		massMinStorage=0.10
		energyMinStorage=0.90
		preventM_Stall=0
		preventE_Stall=0
		EcoIsPaused=true
		print("Mass upgrades have been paused and will resume when storages are filling up (10%m/90%e).")
	end
end
function PauseEcoM80_E90()
	if EcoIsPaused then
		massMinStorage=0
		energyMinStorage=0
		EcoIsPaused=false
		print("Mass upgrades have been unpaused.")
	else
		massMinStorage=0.8
		energyMinStorage=0.9
		preventM_Stall=0
		preventE_Stall=0
		EcoIsPaused=true
		print("Mass upgrades have been paused and will resume when storages are filling up (80%m/90%e).")
	end
end

Economy = Class({
	data = {},
	
	__init = function(self)
		self:Init()

		return self
	end,

	Init = function(self, data)
		local mapping = {maxStorage="Max", stored="Stored", income="Income", lastUseRequested="Requested", lastUseActual="Actual",  net_income="net_income"}
		local per_tick = {income=true, lastUseRequested=true, lastUseActual=true}
		local types = {'MASS', 'ENERGY'}

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
			
			if self[prefix .. 'Stored'] < 1 then
				self[prefix .. 'Actual'] = math.min(self[prefix .. 'Actual'], self[prefix .. 'Income']) -- mex bug
			end

		end
		self:setStallFactor()

		--set energy min storage
		if energyMinStorage == 0 then
			local energyMin = self.energyIncome --* (GetGameTimeSeconds() / 4000 + 1)
			if self.energyMax > 5100 then 
				energyMin = math.max(energyMin,5100)
			end

			local minEnergyStorageLimit = self.energyMax * 0.6
			if energyMin > minEnergyStorageLimit then
				energyMin = minEnergyStorageLimit
			end
			self.energyMinStored = energyMin
		else
			self.energyMinStored = energyMinStorage * self.energyMax
		end

		--set mass min storage
		--local massMin = self.massIncome --* (GetGameTimeSeconds() / 4000 + 1)
		if massMinStorage == 0 then
			self.massMinStored = self.massActual
		else
			self.massMinStored = massMinStorage * self.massMax
		end
	end,

	net = function(self, type, Min, drainSec)

		local stored = self[type .. 'Stored'] - Min
		local maxStored = self[type .. 'Max']
		local drain = self[type .. 'Income'] - self[type .. 'Actual'] 

		-- if maxStored / drain < drainSecMinimum then
		-- 	drainSecMinimum = maxStored / drain
		-- 	if drainSecMinimum < 0 then 
		-- 		drainSecMinimum = 5
		-- 	end
		-- end

		if stored > 0 then
			stored = stored / drainSec
		end

		return drain + stored
	end,

	massNet = function(self, massMin, prio, buffer)
		if prio == 100 then 
			massMin = 0
		else
			massMin = math.max(self['massMinStored'],massMin)
		end
		return self:net('mass', massMin, buffer)
	end,

	energyNet = function(self, energyMin, prio, buffer)
		if prio == 100 then 
			energyMin = 0
		else
			energyMin = math.max(self['energyMinStored'],energyMin)
		end
		return self:net('energy', energyMin, buffer)
	end,

	setStallFactor = function(self)
		for _, t in {'mass', 'energy'} do
			local stallFactor = 1
			local requested = self[t .. 'Actual']
			local income = self[t .. 'Income']
			if requested > 0 and requested > income and self[t .. 'Stored'] < 1 then
				stallFactor = income / requested
				self[t .. 'Stall'] = true
			end
			self[t .. 'StallFactor'] = stallFactor
		end
		self['StallFactor'] = math.min(self.massStallFactor, self.energyStallFactor)
		--print('Stall Factor mass: ' .. self.massStallFactor .. ' | Stall Factor energy: ' .. self.energyStallFactor)
	end,
})
