local modPath = '/mods/EM/'
local modulesPath = modPath .. 'modules/'

local econData = import(modulesPath .. 'units.lua').econData
local pauser = import(modulesPath .. 'pause.lua')
local isPaused = pauser.isPaused
local throttler = import(modPath .. 'throttler/throttler.lua')

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
    massConsumed = 0,
    energyConsumed =0,
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
    isMexUpgrade = false,

    energyUpkeep =0,
    throttle = {},
    index = 0,
    unit = nil,
    assisters = {},
    isConstruction = false,
    Position = nil,
    prio = 0,
    inactivityTicks = 0,

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
        self.massProductionActual = econData(unit).massProduced
        if not self.massProductionActual then self.massProductionActual = 0 end
        self.energyProduction = Eco.ProductionPerSecondEnergy
        self.energyProductionActual = econData(unit).energyProduced
        self.energyUpkeep = Eco.energyUpkeep
    end,

    MassPerEnergy = function(self)
        local massProd = self.massProduction
        if massProd then
            if self.massProductionActual > massProd then 
                massProd = self.massProductionActual 
            end
        else
            massProd = 0
        end
        local energyDrain = self.energyRequested 
        
        if energyDrain then
            return massProd / energyDrain
        else
            return 0
        end
    end,

    ResourceProportion = function(self, a, b)
        local prod = self[a .. 'Production']
        if prod then
            local prodActual = self[a .. 'ProductionActual']
            if prodActual > prod then
                prod = prodActual
            end
        else
            prod = 0
        end
        local cost = self[b .. 'CostRemaining']
        if cost then
            return prod / cost
        else
            return 0
        end
    end,

    LoadFinished = function(self, eco)
        self.workLeft = 1 - self.workProgress
        self.timeLeft = self.workLeft * self.buildTime
        self.workTimeLeft = (self.timeLeft / self.buildRate) 
        self.minTimeLeft = self.workTimeLeft * self:CalcMaxThrottle(eco)
        self.massCostRemaining = self.workLeft * self.massBuildCost
        self.energyCostRemaining = self.workLeft * self.energyBuildCost

        --mass storages
        if EntityCategoryContains(categories.MASSSTORAGE*categories.STRUCTURE, self.unit) then
			local mexMassProduction=0
            for _, mp in throttler.manager.mexPositions do
                local pos2 = mp.position
	    		if pos2 then
		    		if VDist3(self.Position,pos2)<3 then
                        mexMassProduction=mp.massProduction
	                	break
	    			end
				end
	    	end

	        if mexMassProduction==18 then
	        	self.massProduction=2.25
        	elseif mexMassProduction==6 then
	        	self.massProduction=0.75
	        end
        end
        --

        for _, t in {'mass', 'energy'} do
            self[t .. 'Drain'] = self[t .. 'BuildCost'] / (self.buildTime / self.buildRate)
            self[t .. 'CostRemaining'] = self[t .. 'BuildCost'] * self.workLeft
            
            --power and mass production
            if self[t .. 'Production'] then
                if self[t .. 'Production'] > 0 then
                    self[t .. 'PayoffSeconds'] = self[t .. 'CostRemaining'] / self[t .. 'Production'] + self.workTimeLeft
                    self[t .. 'ReversePayoff'] = self[t .. 'Production'] / (self.timeLeft * self[t .. 'Production'] + self[t .. 'CostRemaining'] + self.energyUpkeep * 1.296) * 10000
                end
            else
                self[t .. 'PayoffSeconds'] = 0
            end
            --

        end

        --must be calculated after all assisters have been added
        self.massProportion = self.massRequested / (self.massRequested + self.energyRequested)
        self.energyProportion = self.energyRequested / (self.massRequested + self.energyRequested)
        local inactivityTicks = throttler.manager.ProjectMetaData[self.id].lastAccess
        local GameTick = GameTick()
        if inactivityTicks then 
            inactivityTicks = GameTick-inactivityTicks
            if inactivityTicks > 600 then
                inactivityTicks = 600
            end
        end
        self.inactivityTicks = inactivityTicks
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
        local sortPrio = self.prio / 100 + 1

        if self.workProgress < 1 then
            sortPrio = sortPrio * ((self.workProgress + 1) + (self.massProportion + 1) * (self.workProgress + 1.5)) 
        end

        sortPrio = sortPrio * (self:MassPerEnergy() + 1) * 100 - self.energyMinStorage * 1000

        if self.energyPayoffSeconds > 0 then
            sortPrio = sortPrio + math.max(0, 140 - self.energyPayoffSeconds)
        end
        
        return sortPrio - self.inactivityTicks / 10 
    end,

    mMultiPriority = function(self)
        local sortPrio = self.prio / 100 + 1

        if self.massReversePayoff > 0 then
            sortPrio = sortPrio * self.massReversePayoff 
        else
            if self.workProgress < 1 then
                sortPrio = sortPrio * ((self.workProgress + 1) + (self.energyProportion + 1) * (self.workProgress + 1.5)) 
            end
            sortPrio = sortPrio * (self:ResourceProportion("energy","mass") + 1) * 100 - self.massMinStorage * 1000 
        end

        return sortPrio - self.inactivityTicks / 10 
    end,

    ---*outdated
    --mass production
    mProdPriority = function(self)
        return (self.massPayoffSeconds) / self.prio
    end,
    --

    mCalculatePriority = function(self)
        local sortPrio = self.prio / 100 + 1

        if self.workProgress < 1 then
            sortPrio = sortPrio * ((self.workProgress + 1) + (self.energyProportion + 1) * (self.workProgress + 1.5)) 
        end

        sortPrio = sortPrio * (self:ResourceProportion("energy","mass") + 1) * 100 - self.massMinStorage * 1000

        return sortPrio
    end,
    ---*outdated

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
            self.massConsumed = self.massConsumed + data.massConsumed
            self.energyConsumed = self.energyConsumed + data.energyConsumed
        end
        
        isMexUpgrade = EntityCategoryContains(categories.MASSEXTRACTION, u)
        table.bininsert(self.assisters, {energyRequested=data.energyRequested, unit=u}, self._sortAssister)
    end,

    SetThrottleRatio = function(self, ratio)
        if self.index == 0 then
            self.index = throttleIndex
            throttleIndex = throttleIndex + 1
        end

        if ratio > self.throttle then
            self.throttle = ratio
            return ratio
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
        return self:SetThrottleRatio(ratio)
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
            if (currEnergyRequested + a.energyRequested) <= maxEnergyRequested then
                currEnergyRequested = currEnergyRequested + a.energyRequested
            end
        end

        self:SetEnergyDrain(currEnergyRequested)
    end,

    pause = function(self, pause_list)
        local maxEnergyRequested = (1-self.throttle) * self.energyRequested
        local currEnergyRequested = 0
        local countAssisters = 0
        for _, a in self.assisters do
            local u = a.unit
            local is_paused = isPaused(u)

            if EntityCategoryContains(categories.MASSFABRICATION*categories.STRUCTURE, u) then
                key = 'toggle_4'
            else
                key = 'pause'
            end

            if not pause_list[key] then pause_list[key] = {pause={}, no_pause={}} end

            local constructionLifeSupport = (self.isConstruction and (self.timeLeft < 0.5 or self.workProgress == 1 or (self.workProgress < 0.01 and not self.isMexUpgrade and not EntityCategoryContains(categories.STRUCTURE, u))))
            if (currEnergyRequested + a.energyRequested) <= maxEnergyRequested or (self.isConstruction and firstAssister) or constructionLifeSupport then
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
            countAssisters = countAssisters +1
        end
    end,
})