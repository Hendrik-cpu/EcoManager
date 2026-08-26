-- shim.lua — FA engine surface for the em-harness.
-- Models exactly what the EcoManager core touches; nothing speculative.
-- Fallback-free on purpose: an unshimmed call must crash loudly, not lie.

-- ---- Lua 5.0-isms ------------------------------------------------------
math.mod = math.fmod
function table.getsize(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	return n
end

-- ---- logging -----------------------------------------------------------
Log = {}
function LOG(s) Log[#Log + 1] = tostring(s); io.write("  [LOG] ", tostring(s), "\n") end
-- print: keep native (test output), mod uses it for chat messages

-- ---- FA Class system ---------------------------------------------------
-- Class({...}) -> class | Class(Base)({...}) -> derived class
-- Instances index the class table (so `self.x = nil` falls back to defaults,
-- which live code relies on).
local function buildClass(spec, bases)
	local class = {}
	for _, b in ipairs(bases) do
		for k, v in pairs(b) do
			if k ~= "__index" then class[k] = v end
		end
	end
	for k, v in pairs(spec) do class[k] = v end
	class.__index = class
	return setmetatable(class, {
		__call = function(cls, ...)
			local inst = setmetatable({}, cls)
			if inst.__init then inst:__init(...) end
			return inst
		end,
	})
end

function Class(a)
	if getmetatable(a) and getmetatable(a).__call then
		-- Class(Base) {...}
		local base = a
		return function(spec) return buildClass(spec, { base }) end
	end
	return buildClass(a, {})
end

-- ---- category algebra --------------------------------------------------
local Cat = {}
Cat.__index = Cat
local function mkcat(pred) return setmetatable({ pred = pred }, Cat) end
Cat.__mul = function(a, b) return mkcat(function(s) return a.pred(s) and b.pred(s) end) end
Cat.__add = function(a, b) return mkcat(function(s) return a.pred(s) or b.pred(s) end) end
Cat.__sub = function(a, b) return mkcat(function(s) return a.pred(s) and not b.pred(s) end) end

categories = setmetatable({}, {
	__index = function(t, k)
		local c = mkcat(function(s) return s[k] == true end)
		rawset(t, k, c)
		return c
	end,
})

function EntityCategoryContains(cat, unit)
	return cat.pred(unit.cats) and true or false
end

-- ---- sim state ---------------------------------------------------------
Sim = { units = {}, byId = {}, tick = 1000, seconds = 600, nextId = 1,
        ecoTotals = nil, pauseLog = {}, selected = {} }

function ResetSim()
	Sim.units, Sim.byId, Sim.pauseLog, Sim.selected = {}, {}, {}, {}
	Sim.nextId = 1
end

function GameTick() return Sim.tick end
function GetGameTimeSeconds() return Sim.seconds end
function GetSimTicksPerSecond() return 10 end
function GetSelectedUnits() return Sim.selected end
function GetEconomyTotals()
	assert(Sim.ecoTotals, "scenario must set Sim.ecoTotals")
	-- Economy.Init mutates the table (per-tick -> per-second); hand out a copy
	local c = {}
	for k, v in pairs(Sim.ecoTotals) do
		c[k] = { MASS = v.MASS, ENERGY = v.ENERGY }
	end
	return c
end

function VDist3(a, b)
	local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

Hotkeys = {}
function IN_AddKeyMapTable(t)
	for k, v in pairs(t) do Hotkeys[k] = v.action end
end

-- ---- units -------------------------------------------------------------
local UnitM = {}
UnitM.__index = UnitM
function UnitM:GetEntityId() return self.id end
function UnitM:IsDead() return self.dead == true end
function UnitM:GetPosition() return self.pos end
function UnitM:GetBlueprint() return self.bp end
function UnitM:GetWorkProgress() return self.workProgress or 0 end
function UnitM:GetBuildRate() return self.buildRate or 0 end
function UnitM:GetEconData()
	local e = self.econ or {}
	return { energyRequested = e.energyRequested or 0, massRequested = e.massRequested or 0,
	         energyConsumed = e.energyConsumed or 0, massConsumed = e.massConsumed or 0,
	         massProduced = e.massProduced or 0, energyProduced = e.energyProduced or 0 }
end
function UnitM:IsIdle() return self.idle == true end
function UnitM:GetCommandQueue() return self.queue or {} end
function UnitM:GetFocus()
	if self.focusId then return Sim.byId[self.focusId] end
	return nil
end

-- spec: {cats={'STRUCTURE',...}, bp=, pos=, econ=, focus=unit, workProgress=,
--        buildRate=, idle=, queue=, paused=}
function MakeUnit(spec)
	local u = setmetatable({}, UnitM)
	u.id = Sim.nextId
	Sim.nextId = Sim.nextId + 1
	u.cats = {}
	for _, c in ipairs(spec.cats or {}) do u.cats[c] = true end
	u.bp = spec.bp or { Economy = {}, General = {}, Description = "mock" }
	u.bp.Economy = u.bp.Economy or {}
	u.bp.General = u.bp.General or {}
	u.pos = spec.pos or { 0, 0, 0 }
	u.econ = spec.econ
	u.workProgress = spec.workProgress
	u.buildRate = spec.buildRate
	u.idle = spec.idle
	u.queue = spec.queue
	u.paused = spec.paused or false
	u.bitNormal = {}
	if spec.focus then u.focusId = spec.focus.id end
	table.insert(Sim.units, u)
	Sim.byId[u.id] = u
	return u
end

function GetIsPaused(units) return units[1].paused end
function SetPaused(units, pause)
	for _, u in ipairs(units) do
		u.paused = pause
		table.insert(Sim.pauseLog, { id = u.id, pause = pause })
	end
end

-- script bits: bitNormal[bit] defaults true (normal = running).
-- ToggleScriptBit(units, bit, state) sets the normal-flag; GetScriptBit
-- reports the inverse (bit set == production off == "paused").
function GetScriptBit(units, bit)
	local u = units[1]
	return u.bitNormal[bit] == false
end
function ToggleScriptBit(units, bit, state)
	for _, u in ipairs(units) do
		u.bitNormal[bit] = state
		table.insert(Sim.pauseLog, { id = u.id, pause = not state, toggle = bit })
	end
end

-- ---- virtual modules (engine + /mods/common) ---------------------------
__virtual_modules = {
	["/mods/common/units.lua"] = {
		Get = function(cat)
			local out = {}
			for _, u in ipairs(Sim.units) do
				if not cat or EntityCategoryContains(cat, u) then
					table.insert(out, u)
				end
			end
			return out
		end,
		Data = function(u) return {} end,
	},
	["/lua/user/prefs.lua"] = {
		GetFromCurrentProfile = function() return {} end,
		SetToCurrentProfile = function() end,
		SavePreferences = function() end,
	},
	["/mods/EM/controlPannel/controlPannel.lua"] = {
		hideButtons = function() end,
		debugProjectStats = function() end,
	},
}
