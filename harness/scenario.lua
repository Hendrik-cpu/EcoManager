-- scenario.lua — behavioral regression convictions for the EcoManager core.
-- Runs the REAL mod modules against scripted economies.
-- Returns the number of failed checks (0 = green).

local failed = 0
local function check(name, ok, detail)
	if ok then
		print("CHECK OK   " .. name)
	else
		failed = failed + 1
		print("CHECK FAIL " .. name .. (detail and (" — " .. tostring(detail)) or ""))
	end
end

-- ---- build the sim -----------------------------------------------------
ResetSim()

-- T3 mex being upgraded (the project unit)
local upgN = MakeUnit {
	cats = { "STRUCTURE", "TECH3", "MASSEXTRACTION" },
	bp = { Economy = { BuildTime = 2875, BuildCostMass = 4400, BuildCostEnergy = 15000,
	                   ProductionPerSecondMass = 18, ProductionPerSecondEnergy = 0,
	                   MaintenanceConsumptionPerSecondEnergy = 0 },
	       General = { UnitName = "T3 Mex" }, Description = "T3 mass extractor" },
	pos = { 10, 0, 10 }, workProgress = 0.4,
}
-- T2 mex doing the upgrading (assister, focuses upgN)
local mexA = MakeUnit {
	cats = { "STRUCTURE", "TECH2", "MASSEXTRACTION", "ECONOMIC" },
	bp = { Economy = { BuildTime = 850, BuildCostMass = 900, BuildCostEnergy = 5400,
	                   ProductionPerSecondMass = 6 },
	       General = { UnitName = "T2 Mex" }, Description = "T2 mass extractor" },
	pos = { 10, 0, 10 }, workProgress = 0.4, buildRate = 12, focus = upgN,
	econ = { energyRequested = 100, massRequested = 15, energyConsumed = 100, massConsumed = 15 },
}
-- T2 pgen under construction (project unit)
local pgenU = MakeUnit {
	cats = { "STRUCTURE", "TECH2", "ENERGYPRODUCTION" },
	bp = { Economy = { BuildTime = 750, BuildCostMass = 1200, BuildCostEnergy = 9000,
	                   ProductionPerSecondEnergy = 500, ProductionPerSecondMass = 0,
	                   MaintenanceConsumptionPerSecondEnergy = 0 },
	       General = { UnitName = "T2 Pgen" }, Description = "T2 power generator" },
	pos = { 20, 0, 20 }, workProgress = 0.2,
}
-- ACU building the pgen (assister)
local acu = MakeUnit {
	cats = { "ENGINEER", "COMMAND", "MOBILE" },
	bp = { Economy = {}, General = { UnitName = "ACU" }, Description = "commander" },
	pos = { 21, 0, 20 }, workProgress = 0.2, buildRate = 10, focus = pgenU,
	econ = { energyRequested = 80, massRequested = 8, energyConsumed = 80, massConsumed = 8 },
}
-- an idle engineer (exercises the engineer sweep's no-focus path)
local idleEng = MakeUnit {
	cats = { "ENGINEER", "TECH1", "MOBILE" },
	bp = { Economy = {}, General = { UnitName = "T1 Eng" }, Description = "engineer" },
	pos = { 30, 0, 30 }, idle = true,
}

-- healthy economy (per-tick values; Economy.Init multiplies by tps=10)
local function totals(t)
	return {
		income = { MASS = t.massIncome / 10, ENERGY = t.energyIncome / 10 },
		lastUseRequested = { MASS = t.massReq / 10, ENERGY = t.energyReq / 10 },
		lastUseActual = { MASS = t.massActual / 10, ENERGY = t.energyActual / 10 },
		stored = { MASS = t.massStored, ENERGY = t.energyStored },
		maxStorage = { MASS = t.massMax, ENERGY = t.energyMax },
		net_income = { MASS = 0, ENERGY = 0 },
	}
end

Sim.ecoTotals = totals { massIncome = 50, massReq = 30, massActual = 30,
	massStored = 2000, massMax = 3000,
	energyIncome = 3000, energyReq = 1500, energyActual = 1500,
	energyStored = 9000, energyMax = 10000 }

-- ---- init the real mod stack ------------------------------------------
local throttler = import("/mods/EM/throttler/throttler.lua")
throttler.init()
local manager = throttler.manager

check("init: manager exists", manager ~= nil)
check("init: both plugins registered", manager.plugins.mass ~= nil and manager.plugins.energy ~= nil)

-- hotkey integrity (regression: string-injection paths / codex trap)
local hk = 0
local bad = nil
for key, action in pairs(Hotkeys) do
	hk = hk + 1
	if not string.match(action, '^ui_lua import%("/mods/EM/[%w/%._]+%.lua"%)%.[%w_]+%(%)$') then
		bad = key .. " -> " .. action
	end
end
check("hotkeys: 9 registered", hk == 9, hk)
check("hotkeys: all actions well-formed", bad == nil, bad)

-- ---- scenario 1: healthy economy — nothing gets paused -----------------
manager:manageEconomy()
local pausedAny = false
for _, e in ipairs(Sim.pauseLog) do
	if e.pause then pausedAny = true end
end
check("healthy: tick completes, projects loaded", manager.countProjects == 2, manager.countProjects)
check("healthy: nothing paused", not pausedAny)

-- ---- scenario 2: energy stall — throttle path executes (r1: pio typo) --
Sim.pauseLog = {}
Sim.ecoTotals = totals { massIncome = 50, massReq = 30, massActual = 30,
	massStored = 2000, massMax = 3000,
	energyIncome = 100, energyReq = 2000, energyActual = 2000,
	energyStored = 0, energyMax = 10000 }

manager:manageEconomy() -- crashes here if project.pio / project.priority typos return

local throttled = false
for _, plugin in pairs(manager.plugins) do
	for _, p in pairs(plugin.projects) do
		if p.throttle and type(p.throttle) == "number" and p.throttle > 0 then throttled = true end
	end
end
pausedAny = false
for _, e in ipairs(Sim.pauseLog) do
	if e.pause then pausedAny = true end
end
check("stall: some project throttled", throttled)
check("stall: some assister paused", pausedAny)

-- ---- scenario 3: mode switches (r2: massProductionOnly global leak) ----
throttler.changeMassMode() -- 1 -> 2 (throttle all)
check("mode2: instance massProductionOnly false (not a global leak)",
	manager.plugins.mass.massProductionOnly == false,
	tostring(manager.plugins.mass.massProductionOnly))
check("mode2: no global massProductionOnly leaked", rawget(_G, "massProductionOnly") == nil)

-- r-fabs: ToggleMexMode cycling with energy in mode 1 (no fabs category)
local okAll = true
local errAll = nil
for i = 1, 4 do
	local ok, err = pcall(throttler.ToggleMexMode)
	if not ok then okAll = false; errAll = err end
end
check("ToggleMexMode: 4 cycles survive without fabs category", okAll, errAll)

-- ---- scenario 4: pause arbitration (user > ecomanager) -----------------
local pauser = import("/mods/EM/modules/pause.lua")
local guineaPig = MakeUnit {
	cats = { "STRUCTURE", "TECH1", "ENERGYPRODUCTION" },
	bp = { Economy = {}, General = { UnitName = "pgen" }, Description = "t1 pgen" },
	pos = { 40, 0, 40 },
}
pauser.Pause({ guineaPig }, true, "ecomanager")
check("arbiter: ecomanager can pause fresh unit", guineaPig.paused == true)
pauser.Pause({ guineaPig }, false, "user")
check("arbiter: user unpause overrides", guineaPig.paused == false)
pauser.Pause({ guineaPig }, true, "ecomanager")
check("arbiter: ecomanager cannot re-pause over user", guineaPig.paused == false)

-- ---- scenario 5: dead-unit hygiene ------------------------------------
mexA.dead = true
local ok5, err5 = pcall(function() manager:manageEconomy() end)
check("dead unit: tick survives", ok5, err5)
mexA.dead = false

print(string.format("\nscenario: %d checks failed", failed))
return failed
