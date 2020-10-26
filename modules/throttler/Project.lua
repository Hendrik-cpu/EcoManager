local modPath = '/mods/EM/'
local isPaused = import(modPath .. 'modules/throttler/ecomanager.lua').isPaused
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
    id = -1,
    buildTime = 0,
    workProgress = 0,
    workLeft = 0,
    buildRate = 0,
    massBuildCost = 0,
    energyBuildCost = 0,
    massRequested = 0,
    energyRequested = 0,
    massDrain = 0,
    energyDrain = 0,
    massCostRemaining = 0,
    energyCostRemaining = 0,
    massProduction = 0,
    energyProduction = 0,
    massPayoffSeconds = 0,
    energyPayoffSeconds = 0,
    massProportion = 0,
    energyProportion = 0,

    massMinStorage = 0,
    energyMinStorage = 0,
    isMassFabricator = false,

    throttle = {},
    index = 0,
    unit = nil,
    assisters = {},
    isConstruction = false,
    Position = nil,

    __init = function(self, unit)
        local Eco = unit:GetBlueprint().Economy
        self.id = unit:GetEntityId()
        self.unit = unit
        self.assisters = {}
        self.throttle = 0
        self.buildTime = Eco.BuildTime
        self.massBuildCost = Eco.BuildCostMass
        self.energyBuildCost = Eco.BuildCostEnergy
        self.massProduction = Eco.ProductionPerSecondMass
        self.massProductionActual = unit:GetEconData().massProduced
        self.energyProduction = Eco.ProductionPerSecondEnergy
        self.energyProductionActual = unit:GetEconData().energyProduced
        self.energyUpkeep = Eco.energyUpkeep

    end,

    LoadFinished = function(self, eco)
        self.workLeft = 1 - self.workProgress
        self.timeLeft = self.workLeft * self.buildTime
        self.workTimeLeft = (self.timeLeft / self.buildRate) 
        self.minTimeLeft = self.workTimeLeft * self:CalcMaxThrottle(eco)

        if EntityCategoryContains(categories.MASSSTORAGE*categories.STRUCTURE, self.unit) then
			local mexMassProduction=0
            for _, mp in import(modPath .. 'modules/throttler/ecomanager.lua').mexPositions do
                local pos2 = mp.position
	    		if pos2 then
		    		if VDist3(self.Position,pos2)<3 then
                        mexMassProduction=mp.massProduction
	                	break
	    			end
				end
	    	end

	        if mexMassProduction==18 then
	        	self.massProductionActual=2.25
        	elseif mexMassProduction==6 then
	        	self.massProductionActual=0.75
	        end
        end

        for _, t in {'mass', 'energy'} do
            self[t .. 'Drain'] = self[t .. 'BuildCost'] / (self.buildTime / self.buildRate)
            self[t .. 'CostRemaining'] = self[t .. 'BuildCost'] * self.workLeft
            
            if self[t .. 'ProductionActual'] then
                if self[t .. 'ProductionActual'] > 0 then
                    self[t .. 'PayoffSeconds'] = self[t .. 'CostRemaining'] / self[t .. 'ProductionActual'] + self.minTimeLeft
                end
            else
                self[t .. 'PayoffSeconds'] = 0
            end
        end

        --must be calculated after all assisters have been added
        self.massProportion = self.massRequested / (self.massRequested + self.energyRequested)
        self.energyProportion = self.energyRequested / (self.massRequested + self.energyRequested)

    end,
    
    CalcMaxThrottle = function(self, eco)
        local maxThrottleE = 0
        local maxThrottleM = 0
        if eco.energyIncome > self.energyRequested then
            maxThrottleE = 1
        else
            maxThrottleE = eco.energyIncome / self.energyRequested
        end
        if eco.massIncome > self.massRequested then 
            maxThrottleM = 1
        else
            maxThrottleM = eco.massIncome / self.massRequested
        end
        return math.min(maxThrottleE,maxThrottleM)
    end,

    eCalculatePriority = function(self)
        return self.prio / 100 * (self.workProgress + 1) + self.massProportion * (self.workProgress + 1.5) - self.energyMinStorage * 100000
    end,

    mCalculatePriority = function(self)
        return self.prio / 100 * (self.workProgress + 1) + self.energyProportion * (self.workProgress + 1.5)
    end,

    GetConsumption = function()
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
        self.workProgress = math.max(self.workProgress, u:GetWorkProgress())
        self.energyRequested = self.energyRequested + data.energyRequested
        self.massRequested = self.massRequested + data.massRequested

        if not isPaused(u) then
            eco.massActual = eco.massActual - data.massConsumed
            eco.energyActual = eco.energyActual - data.energyConsumed
        end

        table.bininsert(self.assisters, {energyRequested=data.energyRequested, unit=u}, self._sortAssister)
    end,

    SetThrottleRatio = function(self, ratio)
        if self.index == 0 then
            self.index = throttleIndex
            throttleIndex = throttleIndex + 1
        end

        if ratio > self.throttle then
            self.throttle = ratio
        end
    end,

    SetTypeDrain = function(self, type, value)
        if type == "mass" then
            self:SetMassDrain(value)
        elseif type == "energy" then
            self:SetEnergyDrain(value)
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

    adjust_throttle = function(self)
        local maxEnergyRequested = (1-self.throttle) * self.energyRequested
        local currEnergyRequested = 0

        for _, a in self.assisters do
            local u = a.unit
            --local is_paused = isPaused(u)

            if (currEnergyRequested + a.energyRequested) <= maxEnergyRequested then
                currEnergyRequested = currEnergyRequested + a.energyRequested
            end
        end

        self:SetEnergyDrain(currEnergyRequested)
    end,

    pause = function(self, pause_list)
        local maxEnergyRequested = (1-self.throttle) * self.energyRequested
        local currEnergyRequested = 0
        for _, a in self.assisters do
            local u = a.unit
            local is_paused = isPaused(u)

            if EntityCategoryContains(categories.MASSFABRICATION*categories.STRUCTURE, u) then
                key = 'toggle_4'
            else
                key = 'pause'
            end

            if not pause_list[key] then pause_list[key] = {pause={}, no_pause={}} end

            if (currEnergyRequested + a.energyRequested) <= maxEnergyRequested or (self.isConstruction and firstAssister) then
                if is_paused then
                    table.insert(pause_list[key]['no_pause'], u)
                end
                currEnergyRequested = currEnergyRequested + a.energyRequested
                if self.isConstruction then
                    firstAssister = false
                end
            else
                if not is_paused then
                    table.insert(pause_list[key]['pause'], u)
                end
            end
        end
    end,
})
