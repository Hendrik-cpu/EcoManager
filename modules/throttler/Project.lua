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

    throttle = {},
    index = 0,
    unit = nil,
    assisters = {},
    isConstruction = false,
    Position = nil,
    prio = 0,
    --CountAssisers = 0,

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
        --self.MinSecondsToCompletion = math.max(self.massCostRemaining / eco.massIncome, self.timeLeft, self.energyCostRemaining / eco.energyIncome)  

        --mass storages
        if EntityCategoryContains(categories.MASSSTORAGE*categories.STRUCTURE, self.unit) then
			local mexMassProduction=0
            for _, mp in import(modPath .. 'modules/throttler/throttler.lua').manager.mexPositions do
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
                end
            else
                self[t .. 'PayoffSeconds'] = 0
            end
            --

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
        local sortPrio = self.prio / 100 + 1

        if self.workProgress < 1 then
            sortPrio = sortPrio * ((self.workProgress + 1) + (self.massProportion + 1) * (self.workProgress + 1.5)) 
        end

        sortPrio = sortPrio * (self:MassPerEnergy() + 1) * 100 - self.energyMinStorage * 1000

        --power production
        --local sortPrio = self:MassPerEnergy() - self.energyMinStorage * 100000
        if self.energyPayoffSeconds > 0 then
            --print("pgen")
            sortPrio = sortPrio + math.max(0, 140 - self.energyPayoffSeconds)
        end
        --

        print(self.energyRequested .. " | " ..  sortPrio)
        --print(self.energyConsumed .. "/" .. self.energyRequested)
        return sortPrio
    end,

    --mass production
    mProdPriority = function(self)

        --print(self.MinSecondsToCompletion)
        --print("Assisers: " .. self.CountAssisers .. " | BuildPower: " .. self.buildRate .. " | PayOffSeconds: " .. self.massPayoffSeconds .. " | MassProduction: " .. self.massProduction)
        return (self.massPayoffSeconds) / self.prio
        --return (self.buildRate*-1)
    end,
    --

    mCalculatePriority = function(self)
        local sortPrio = self.prio / 100 

        if self.workProgress < 1 then
            sortPrio = sortPrio * (self.workProgress + 1) + (self.energyProportion * 100) * (self.workProgress + 1.5) 
        end

        sortPrio = sortPrio + self:ResourceProportion("energy","mass") - self.massMinStorage * 100000

        return sortPrio
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
            self.massConsumed = self.massConsumed + data.massConsumed
            self.energyConsumed = self.energyConsumed + data.energyConsumed
        end
        
        table.bininsert(self.assisters, {energyRequested=data.energyRequested, unit=u}, self._sortAssister)
        --self.CountAssisers = self.CountAssisers +1 
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
            countAssisters = countAssisters +1
        end
    end,
})
