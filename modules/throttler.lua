local modPath = '/mods/EM/'
local getEconomy = import(modPath ..'modules/economy.lua').getEconomy
local addListener = import(modPath .. 'modules/init.lua').addListener
local getUnits = import(modPath .. 'modules/units.lua').getUnits
local econData = import(modPath .. 'modules/units.lua').econData

local EnergyPlugin = import(modPath .. 'modules/throttler/EnergyPlugin.lua').EnergyPlugin
local StoragePlugin = import(modPath .. 'modules/throttler/StoragePlugin.lua').StoragePlugin

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

local Economy = Class({
	--[[
	massIncome = 0,
	energyIncome = 0,
	massRequested = 0,
	energyRequested = 0,
	massActual = 0,
	energyActual = 0,
	massStored = 0,
	energyStored = 0,
	massMax = 0,
	energyMax = 0,
	massRatio = 0,
	energyRatio = 0,
	]]

	data = {},

	__init = function(self)
		self:Init()

		return self
	end,

	Init = function(self, data)
		local types = {'MASS', 'ENERGY'}
		local mapping = {maxStorage="Max", stored="Stored", income="Income", lastUseRequested="Requested", lastUseActual="Actual", ratio="ratio", net_income="net_income"}
		local per_tick = {income=true, lastUseRequested=true, lastUseActual=true}
		
		tps = GetSimTicksPerSecond()
		data = GetEconomyTotals()

		for _, t in types do
			local prefix = string.lower(t)

			for k, m in mapping do
				if(per_tick[k]) then -- convert data in tick -> seconds
					data[k][t] = data[k][t] * tps
				end

				self[prefix .. m] = data[k][t]
			end

			self[prefix .. "Ratio"] = data['stored'][t] / data['maxStorage'][t]

			if(self[prefix .. 'Stored'] < 1) then
				self[prefix .. 'Actual'] = math.min(self[prefix .. 'Actual'], self[prefix .. 'Income']) -- mex bug
			end

			--self[prefix .. "Net"] = data['income'][t] - data['lastUseActual'][t] + data['stored'][t] / 5

		end
	end,

	net = function(self, type)
		local stored = self['net' .. Stored]
		if(stored > 0) then
			stored = stored / 5
		end

		return self[type .. 'Income'] - self[type .. 'Actual'] + stored
	end,

	massNet = function(self)
		return self:net('mass')
	end,
	energyNet = function(self)
		return self:net('energy')
	end,
})

local throttleIndex = 0

local Project = Class({
	id = nil,
	buildCostMass = 0,
	buildlCostEnergy = 0,
	buildTime = 0,
	progress = 0,
	buildRate = 0,
	energyRequested = 0,
	massRequested = 0,
	throttle = {},
	unit = nil,
	assisters = {},

	__init = function(self, unit)
		local bp = unit:GetBlueprint()
		self.id = unit:GetEntityId()
		self.unit = unit
		self.assisters = {}
		self.throttle = {ratio=0}
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

		if(table.getsize(data) == 0) then
			return
		end
		
		self.buildRate = self.buildRate + u:GetBuildRate()
		self.progress = math.max(self.progress, u:GetWorkProgress())
		self.energyRequested = self.energyRequested + data.energyRequested
		self.massRequested = self.massRequested + data.massRequested

		if(not GetIsPaused({u})) then
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
		if(not self.throttle) then
			self.throttle = {index=throttleIndex}
			throttleIndex = throttleIndex + 1
		end

		if(ratio > self.throttle.ratio) then
			self.throttle.ratio = ratio
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
		local maxEnergyRequested = (1-self.throttle.ratio) * self.energyRequested
		local currEnergyRequested = 0

		LOG("ID " .. self.id .. " max " .. maxEnergyRequested)

		for _, a in self.assisters do
			local u = a.unit
			local is_paused = GetIsPaused({u})

			--LOG("max " .. maxEnergyRequested .. " currEnergy " .. currEnergyRequested)
			if(currEnergyRequested + a['energyRequested'] <= maxEnergyRequested) then
				if(is_paused) then
					table.insert(pause_list['pause']['off'], u)
				end

				currEnergyRequested = currEnergyRequested + a['energyRequested']
			else
				if(not is_paused) then
					table.insert(pause_list['pause']['on'], u)
				end
			end
		end
	end,
})

local EcoManager = Class({
	eco = nil,
	projects = {},

	LoadProjects = function(self, eco)
		self.projects = {}
		units = getUnits()

		--print "Load projects"
		for _, u in units do
			local project

			if(not u:IsDead()) then
				local focus = u:GetFocus()

				if(focus) then
					local id = focus:GetEntityId()
					project = self.projects[id]
					if(not project) then
						project = Project(focus)
						self.projects[id] = project
					end
				
					project:AddAssister(eco, u)
				end
			end
		end

		return self.projects
	end,
})

function setPause(units, toggle, pause) 
	if(toggle == 'pause') then
		SetPaused(units, pause)
	else
		local bit = GetScriptBit(units, toggle)
		local is_paused = bit

		if(toggle == 0)  then
			is_paused = not is_paused
		end

		if(pause ~= is_paused) then
			ToggleScriptBit(units, toggle, bit)
		end
	end
end

function manageEconomy()
	local eco = Economy()
	local all_projects = manager:LoadProjects(eco)
	local projects = all_projects
	local pause_list = {pause={on={}, off={}}}

	--print ("n_projects " .. table.getsize(all_projects))

	LOG("NEW BALANCE ROUND")
	plugins = {MinStorage(eco), EnergyPlugin()}
	for _, plugin in plugins do
		local pause = false

		plugin.projects = {}
		for _, p in projects do
			plugin:add(p)
	 	end
	 	
	 	plugin:sort()

	 	LOG(repr(plugin.projects))

		--print ("n_plugin_projects " .. table.getsize(plugin.projects))	 	
	 	for _, p in plugin.projects do
	 		local ratio_inc

	 		if(p.throttle.ratio < 1) then
		 		if(not pause) then
	 				local last_ratio = p.throttle.ratio
		 			plugin:throttle(eco, p)
	 				ratio_inc = p.throttle.ratio - last_ratio
		 			if(p.throttle.ratio < 1) then
		 				--table.insert(projects, p)
		 			else
			 			pause = true -- plugin throttles all from here
		 			end
		 		
		 			eco.energyActual = eco.energyActual + p.energyRequested * (1-ratio_inc)
		 			eco.massActual = eco.massActual + p.massRequested * (1-ratio_inc)
		 		end

		 		if(pause) then
			 		p:SetEnergyDrain(0)
		 			--projects[p.id] = nil
		 		end
		 	end
	 	end
	end

	for _, p in all_projects do
		p:pause(pause_list)
	end

	--LOG(repr(pause_list))
	
	for toggle_key, modes in pause_list do
		local toggle = toggle_key

		if(toggle ~= 'pause') then
			toggle = tonumber(string.sub(toggle, 8))
		end

		for mode, units in modes do
			setPause(units, toggle, mode == 'on')
		end
	end
end

function init()
	manager = EcoManager()
	addListener(manageEconomy, 1)
end