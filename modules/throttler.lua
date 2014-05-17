local modPath = '/mods/EM/'
local getEconomy = import(modPath ..'modules/economy.lua').getEconomy
local addListener = import(modPath .. 'modules/init.lua').addListener
local getUnits = import(modPath .. 'modules/units.lua').getUnits
local econData = import(modPath .. 'modules/units.lua').econData

local EnergyThrottle = Class({
	units = nil,
	eco = nil,

	run = function(self, eco, units)
		self.units = units
		self.eco = eco

	end,
	sortUnits = function(a, b)
		local av = a['prio'] * 100000 - ((1-a['workProgress'])*a['buildTime']  / a['buildRate']) + a['massRatio']*100
		local bv = b['prio'] * 100000 - ((1-b['workProgress'])*b['buildTime'] / b['buildRate']) + b['massRatio']*100

		return av > bv
	end,
})

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

	Init = function(self, data)
		local types = {'MASS', 'ENERGY'}
		local mapping = {maxStorage="Max", stored="Stored", income="Income", lastUseRequested="Requested", lastUseActual="Actual", ratio="ratio", net_income="net_income"}
		local per_tick = {income=true, lastUseRequested=true, lastUseActual=true}
		
		tps = GetSimTicksPerSecond()
		data = GetEconomyTotals()

		for _, t in types do
			local prefix = string.lower(t)
			for k, m in mapping do
				self.data[prefix .. m] = data[k][t]
				if(per_tick[k]) then
					self.data[prefix .. m] = self.data[prefix .. m] * tps
				end
			end

			self.data[prefix .. "Ratio"] = data['stored'][t] / data['maxStorage'][t]
			self.data[prefix .. "Net"] = data['income'][t] - data['lastUseActual'][t]
		end
	end,
})

local Project = Class({
	buildCostMass = 0,
	buildlCostEnergy = 0,
	buildTime = 0,

	progress = 0,
	assisters = {},
	buildrate = 0,
	energyRequested = 0,
	massRequested = 0,
	throttle = {},
	
	GetConsumption = function(self)
		return {mass=self.massRequested, energy=energyRequested}
	end,

	AddAssister = function(self, u)
		local data = econData(u)
		self.buildrate = self.buildrate + u:GetBuildRate()
		self.progress = math.max(self.progress, u:GetWorkProgress())
		self.energyRequested = self.energyRequested + data['energyRequested']
		self.massRequested = self.massRequested + data['massRequested']

		table.insert(self.assisters, u)
	end,

	RequestThrottle = function(self, prio, energy, mass)
		if(not self.throttle or self.throttle.prio < prio) then
			local ratio = math.min(1, math.max(energy / energyRequested,  mass / massRequested))

			self.throttle = {prio=prio, ratio}
		end
	end,

	Throttle = function(self, eco)
		if(not self.throttle) then
			return
		end
	end,

})

local EcoManager = Class({
	eco = nil,
	projects = {},

	LoadProjects = function(self)
		self.projects = {}
		units = getUnits()
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

					project:AddAssister(u)
				end
			end
		end
	end,

	UpdateEco = function(self)
		local data = getEconomy()

		self.eco = data
	end,
	Balance = function(self)
		self.UpdateEco()
	end
})

function manageEconomy()
	local eco = Economy()
	eco:Init()
	manager:LoadProjects()
	LOG("MANAGER")
	LOG(repr(manager.projects))

	
	--manager:Balance()
end

function init()
	manager = EcoManager()

	--manager:Add(EnergyThrottle())
	addListener(manageEconomy, 0.6)
end


