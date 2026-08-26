
-- eco-pause: ONE toggle mechanism, presets are just parameter pairs.
local EcoIsPaused=false
local massMinStorage=0
local energyMinStorage=0

local function toggleEcoPause(massMin, energyMin)
	if EcoIsPaused then
		massMinStorage=0
		energyMinStorage=0
		EcoIsPaused=false
		print("Mass upgrades have been unpaused.")
	else
		massMinStorage=massMin
		energyMinStorage=energyMin
		preventM_Stall=0
		preventE_Stall=0
		EcoIsPaused=true
		print("Mass upgrades have been paused and will resume when storages are filling up ("
			.. math.floor(massMin*100) .. "%m/" .. math.floor(energyMin*100) .. "%e).")
	end
end

-- hotkey-visible presets (names are bound in throttler.lua)
function PauseEcoM10_E90() toggleEcoPause(0.10, 0.90) end
function PauseEcoM80_E90() toggleEcoPause(0.80, 0.90) end

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
			-- if self.energyMax > 5100 then 
			-- 	energyMin = math.max(energyMin,5100)
			-- end

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

	-- one rule for both resources: prio 100 ignores min-storage, else floor at the eco-wide min
	resourceNet = function(self, type, min, prio, buffer)
		if prio == 100 then
			min = 0
		else
			min = math.max(self[type .. 'MinStored'], min)
		end
		return self:net(type, min, buffer)
	end,

	massNet = function(self, massMin, prio, buffer)
		return self:resourceNet('mass', massMin, prio, buffer)
	end,

	energyNet = function(self, energyMin, prio, buffer)
		return self:resourceNet('energy', energyMin, prio, buffer)
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
