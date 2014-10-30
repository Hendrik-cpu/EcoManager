local modPath = '/mods/EM/'
local isPaused = import(modPath .. 'modules/throttler.lua').isPaused
local econData = import(modPath .. 'modules/units.lua').econData

throttleIndex = 0
firstAssister = true

--bininsert
do
   local fcomp_default = function( a,b ) return a < b end
   function table.bininsert(t, value, fcomp)
      local fcomp = fcomp or fcomp_default
      local iStart,iEnd,iMid,iState = 1,table.getsize(t),1,0
      while iStart <= iEnd do
         iMid = math.floor( (iStart+iEnd)/2 )
         if fcomp( value,t[iMid] ) then
            iEnd,iState = iMid - 1,0
         else
            iStart,iState = iMid + 1,1
         end
      end
      table.insert( t,(iMid+iState),value )
      return (iMid+iState)
   end
end

Project = Class({
	id = nil,
	buildCostMass = 0,
	buildlCostEnergy = 0,
	buildTime = 0,
	progress = 0,
	buildRate = 0,
	energyRequested = 0,
	massRequested = 0,
	throttle = {},
	index = nil,
	unit = nil,
	assisters = {},

	__init = function(self, unit)
		local bp = unit:GetBlueprint()
		self.id = unit:GetEntityId()
		self.unit = unit
		self.assisters = {}
		self.throttle = 0
		self.buildTime = bp.Economy.BuildTime
	end,

	GetConsumption = function(self)
		return {mass=self.massRequested, energy=energyRequested}
	end,

	_sortAssister = function(a, b)
		return a.unit:GetBuildRate() > b.unit:GetBuildRate()
	end,

	AddAssister = function(self, eco, u)
		local data = econData(u)

		if table.getsize(data) == 0 then
			return
		end

		self.buildRate = self.buildRate + u:GetBuildRate()
		self.progress = math.max(self.progress, u:GetWorkProgress())
		self.energyRequested = self.energyRequested + data.energyRequested
		self.massRequested = self.massRequested + data.massRequested

		if not isPaused(u) then
			--[[
			eco.massActual = eco.massActual + data.massConsumed
			eco.energyActual = eco.energyActual + data.energyConsumed
			]]
			eco.massActual = eco.massActual - data.massConsumed
			eco.energyActual = eco.energyActual - data.energyConsumed
		end

		table.bininsert(self.assisters, {energyRequested=data.energyRequested, unit=u}, self._sortAssister)
	end,

	SetThrottleRatio = function(self, ratio)
		if not self.index then
			self.index = throttleIndex
			throttleIndex = throttleIndex + 1
		end

		if ratio > self.throttle then
			self.throttle = ratio
		end
	end,

	SetDrain = function(self, energy, mass)
		local ratio = 1-math.min(1, math.min(energy / self.energyRequested,  mass / self.massRequested))
		self:SetThrottleRatio(ratio)
	end,

	SetEnergyDrain = function(self, energy)
		return self:SetDrain(energy, self.massRequested)
	end,

	SetMassDrain = function(self, mass)
		return self:SetDrain(self.energyRequested, mass)
	end,

	pause = function(self, pause_list)
		--print ("n_assisters " .. table.getsize(self.assisters))
		local maxEnergyRequested = (1-self.throttle) * self.energyRequested
		local currEnergyRequested = 0
		local key = nil

		--LOG("Checking pause for project " .. self.id .. " Max use is " .. maxEnergyRequested)

		for _, a in self.assisters do
			local u = a.unit
			local is_paused = isPaused(u)

			if EntityCategoryContains(categories.MASSFABRICATION*categories.STRUCTURE, u) then
				key = 'toggle_4'
			else
				key = 'pause'
			end

			if not pause_list[key] then pause_list[key] = {pause={}, no_pause={}} end

			--LOG("Assister " .. u:GetEntityId() .. " requesting " .. a.energyRequested .. " is_paused " .. tostring(is_paused))
			if currEnergyRequested + a['energyRequested'] <= maxEnergyRequested or firstAssister then
				if is_paused then
					table.insert(pause_list[key]['no_pause'], u)
				end

				currEnergyRequested = currEnergyRequested + a['energyRequested']
				firstAssister = false
			else
				if not is_paused then
					--LOG("Pausing assister by using key " .. key)
					table.insert(pause_list[key]['pause'], u)
				end
			end
		end
	end,
})
