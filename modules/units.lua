local modPath = '/mods/EM/'
local boolstr = import(modPath .. 'modules/utils.lua').boolstr
local addListener = import(modPath .. 'modules/init.lua').addListener
local GetScore = import(modPath .. 'modules/score.lua').GetScore
local GetAllUnits = import(modPath .. 'modules/allunits.lua').GetAllUnits

local SelectBegin = import(modPath .. 'modules/allunits.lua').SelectBegin
local SelectEnd = import(modPath .. 'modules/allunits.lua').SelectEnd

local units = {}
local assisting = {}

local econ_cache = {}

function econData(unit)
	local id = unit:GetEntityId()
	local econ = unit:GetEconData()

	if(econ['energyRequested'] ~= 0) then
		if(unit:GetFocus() and GetIsPaused({unit})) then
			-- upgrading paused unit but still use energy (i.e. mex), use cached value
		else
			econ_cache[id] = econ
		end
	end

	if(not econ_cache[id]) then
		local bp = unit:GetBlueprint()

		if(bp.Economy) then

			if(bp.Economy.ProductionPerSecondMass > 0) then
				econ['massProduced'] = bp.Economy.ProductionPerSecondMass
			end
	
			if(bp.Economy.MaintenanceConsumptionPerSecondEnergy > 0) then
				econ['energyRequested'] = bp.Economy.MaintenanceConsumptionPerSecondEnergy
			end

			if(bp.Economy.MaintenanceConsumptionPerSecondMass > 0) then
				econ['massRequested'] = bp.Economy.MaintenanceConsumptionPerSecondMass
			end
		end

		if(econ['energyRequested'] and econ['energyRequested'] ~= 0) then
			econ_cache[id] = econ
		end
	end

	
	return econ_cache[id] or {}
end

function unitData(unit)
	local id = unit:GetEntityId()
	local data = {}
	local bp = unit:GetBlueprint()
	
	data = {
		id=id,
		is_paused=GetIsPaused({unit}),
		is_idle=unit:IsIdle(),
		health=unit:GetHealth(),
		econ=unit:GetEconData(),
		progress=unit:GetWorkProgress(),
	}

	if(bp.Economy.ProductionPerSecondMass > 0 and data['econ']['massProduced'] > bp.Economy.ProductionPerSecondMass) then
		data['bonus'] = data['econ']['massProduced'] / bp.Economy.ProductionPerSecondMass
	else 
		data['bonus'] = 1
	end

	if(not data['is_idle']) then
		local left = 1-data['progress']
		local ubp = __blueprints[bp.General.UpgradesTo]
		local focus = unit:GetFocus()

		data['assisting'] = 0
		data['build_rate'] = bp.Economy.BuildRate
					
		if(focus) then
			focus = focus:GetEntityId();

			if(assisting[focus]) then
				data['assisting'] = table.getsize(assisting[focus]['engineers'])
				data['build_rate'] = data['build_rate'] + assisting[focus]['build_rate']
			end
		end
		
		data['build_time'] = ubp.Economy.BuildTime / data['build_rate']
		data['time_left'] = left*data['build_time']
		data['mass_usage'] = ubp.Economy.BuildCostMass / data['build_time']
		data['mass_left'] = left*ubp.Economy.BuildCostMass
		data['energy_usage'] = ubp.Economy.BuildCostEnergy / data['build_time']
		data['energy_left'] = left*ubp.Economy.BuildCostEnergy
		data['payback']  = data['mass_left'] / (ubp.Economy.ProductionPerSecondMass*data['bonus'])
	end

	return data
end

function getAssisting(unit)
	return assisting[unit:GetEntityId()]
end
function updateAssisting()
	local engineers = EntityCategoryFilterDown(categories.ENGINEER, getUnits())

	assisting = {}

	-- find the mex assisting and grab id from there

	for _, e in engineers do
		local m = e:GetFocus()
		local is_paused =GetIsPaused({e})
		--[[
		if(e:IsIdle()) then
			LOG("engineer is idle")
		else
			LOG("engineer is not idle")
		end
		]]

		if not e:IsDead() and m and not is_paused then
			local id = m:GetEntityId()
			
			local is_idle = m:IsIdle()
			local is_focus = m:GetFocus() ~= nil
			
			

			if(not assisting[id]) then
				assisting[id] = {engineers={}, build_rate=0}
				assisting[id]['engineers'] = {}
				assisting[id]['build_rate'] = 0
				
				--str = "FOUND assist for " .. id .. " MEX PAUSED " .. boolstr(is_paused) .. " MEX IDLE " .. boolstr(is_idle) .. " MEX FOCUS " .. boolstr(is_focus)				
				--LOG(str)
				--[[
				DLOG(repr(mexData(m)))
				]]
			end

			is_idle = e:IsIdle()
			is_focus = e:GetFocus() ~= nil

			--str = "ENGINEER " .. id .. " PAUSED " .. boolstr(is_paused) .. " IDLE " .. boolstr(is_idle) .. " FOCUS " .. boolstr(is_focus)				
			--LOG(str)

			if(not assisting[id]) then
				assisting[id] = {engineers={}, build_rate=0}
			end

			table.insert(assisting[id]['engineers'], e)
			assisting[id]['build_rate'] = assisting[id]['build_rate'] + e:GetBuildRate()

			table.insert(assisting[id], e)
		end
	end
end

function updateUnits()
	local new_units = {}
		
	for id, u in GetAllUnits() do
		table.insert(new_units, u)
	end

	units = new_units

	updateAssisting()
end

function getUnits()
	return cleanUnitList(units)
end

function cleanUnitList(units)
	for i, u in units do
		if u:IsDead() then
			units[i] = nil
		end
	end

	return units
end

function init()
	updateUnits()
	addListener(updateUnits, 1)
end