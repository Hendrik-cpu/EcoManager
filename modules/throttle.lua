local modPath = '/mods/EM/'
local boolstr = import(modPath .. 'modules/utils.lua').boolstr
local addListener = import(modPath .. 'modules/init.lua').addListener
local addEventListener = import(modPath .. 'modules/events.lua').addEventListener

local getOptions = import(modPath .. 'modules/utils.lua').getOptions
local getUnits = import(modPath .. 'modules/units.lua').getUnits
local unitData = import(modPath .. 'modules/units.lua').unitData
local econData = import(modPath .. 'modules/units.lua').econData
local getEconomy = import(modPath ..'modules/economy.lua').getEconomy
local round = import(modPath .. 'modules/utils.lua').round

local addCommand = import(modPath .. 'modules/commands.lua').addCommand

local throttledEnergyText = import(modPath .. 'modules/autoshare.lua').throttledEnergyText

local constructionCategories = {
	{name="Paragon", category = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.EXPERIMENTAL, lasts_for=3, priority = 5},
	{name="T3 Land Units",  category = categories.LAND * categories.TECH3 * categories.MOBILE, priority = 60},
	{name="T2 Land Units",  category = categories.LAND * categories.TECH2 * categories.MOBILE, priority = 70},
	--{name="T1 Land Units",  category = categories.LAND * categories.TECH1 * categories.MOBILE, priority = 80},
	{name="T3 Air Units",   category = categories.AIR * categories.TECH3 * categories.MOBILE, priority = 10},
	{name="T2 Air Units",   category = categories.AIR * categories.TECH2 * categories.MOBILE, priority = 70},	
	{name="T1 Air Units",   category = categories.AIR * categories.TECH1 * categories.MOBILE, priority = 80},
	{name="T3 Naval Units", category = categories.NAVAL * categories.TECH3 * categories.MOBILE, priority = 60},
	{name="T2 Naval Units", category = categories.NAVAL * categories.TECH2 * categories.MOBILE, priority = 70},
	{name="T1 Naval Units", category = categories.NAVAL * categories.TECH1 * categories.MOBILE, priority = 80},
	{name="Experimental unit", category = categories.MOBILE * categories.EXPERIMENTAL, off=3, priority = 81},
	{name="ACU/SCU upgrades", category = categories.LAND * categories.MOBILE * (categories.COMMAND + categories.SUBCOMMANDER), off=2, priority = 90},
	{name="Mass Extractors", category = categories.STRUCTURE * categories.MASSEXTRACTION, priority = 91},
	{name="Energy Storage", category = categories.STRUCTURE * categories.ENERGYSTORAGE, priority = 99},
	{name="Energy Production", category = categories.STRUCTURE * categories.ENERGYPRODUCTION, priority = 100},
	{name="Building", category = categories.STRUCTURE - categories.MASSEXTRACTION, priority = 85},
}

local consumptionCategories = {
	--{name="Shields", category = categories.STRUCTURE * categories.SHIELD, toggle=0, off=3, on=18, priority = 99},
	--{name="Stealth Generator", category = categories.STRUCTURE * categories.OVERLAYCOUNTERINTEL, toggle=5, priority = 99},
	--{name="OMNI", category = categories.STRUCTURE * categories.OMNI, toggle=3, priority = 98},
	--{name="Radar Stations", category = categories.STRUCTURE * categories.RADAR, toggle=3, priority = 97},
	--{name="Optics (eye/perimeter)", category = categories.STRUCTURE * categories.OPTICS, toggle=3, priority = 96},
	{name="Mass fabrication", category = categories.STRUCTURE * categories.MASSFABRICATION, toggle=4, priority = 1},
}

local excluded = {}

local throttle_min_storage = 'auto'

function SetPaused(units, state)
	import(modPath .. 'modules/pause.lua').Pause(units, state, 'throttle')
end
--[[
function GetIsPaused(units)
	import(modPath .. 'modules/pause.lua').IsPaused(units)
end
]]

function addExclusion(units)
	for _, u in units do
		excluded[u:GetEntityId()] = u
	end
end

function delExclusion(units) 
	for _, u in units do
		excluded[u:GetEntityId()] = nil
	end
end

function getExcluded()
	return excluded
end

function sortResourceUsers(a, b)
	return a['priority'] > b['priority']
end

function sortPausedUsers(a, b)
	return a['priority'] > b['priority']
end

function sortCategory(a, b)
	if(a['massProduced'] or b['massProduced']) then
		local a_ratio, b_ratio

		if(a['massProduced'] > 0) then
			a_ratio = a['energyRequested'] / a['massProduced']
		else
			a_ratio = 0
		end

		if(b['massProduced'] > 0) then
			b_ratio = b['energyRequested'] / b['massProduced']
		else 
			b_ratio = 0
		end

		return a_ratio < b_ratio
	else
		return a['energyRequested'] < b['energyRequested']
	end
end

function getResourceUsers(res)
	local data_types = {'energyRequested', 'energyConsumed', 'massConsumed', 'massProduced'}
	local all_units = getUnits()
	local units = {}
	local res_units = {}

	for _, u in all_units do
		if(not u:IsDead()) then
			local uses_resources = false
			local econ_data = econData(u)
			local bp = u:GetBlueprint()
			local id = u:GetEntityId()
			local pausedByMassThrottle=import(modPath .. 'modules/throttleMass.lua').getUnitsPauseList()

			if(econ_data['energyRequested'] ~= 0) then
				uses_resources = true
			end

			--if(uses_resources and not excluded[id]) then 
			if(uses_resources and not excluded[id] and not pausedByMassThrottle[id]) then 
				local cats = {}
				local category
				local focus

				if(EntityCategoryContains(categories.ENGINEER, u) or EntityCategoryContains(categories.MASSEXTRACTION, u) or
				   (EntityCategoryContains(categories.FACTORY, u) and not (EntityCategoryContains(categories.AIR * categories.TECH3, u)))) then
					if(u:GetFocus()) then
						cats = constructionCategories
						focus = u:GetFocus()
					elseif(u:IsIdle() or u:GetWorkProgress() == 0) then  --idling
						focus = u
						cats = {{name="Idling constructor", category = categories.ENGINEER+categories.FACTORY, priority = 99}}
						econ_data = {massConsumed=0, energyRequested=0, energyConsumed=0}
					end
				else
					cats = consumptionCategories
					focus = u
				end

				for _, c in  cats do
					local key = c.name

					if(EntityCategoryContains(c.category, focus)) then
						local is_paused
						local data = {massConsumed=0, massProduced=0, energyRequested=0, energyConsumed=0}

						if(not units[key]) then
							units[key] = {}
						end

						for _, t in data_types do
							if(not econ_data[t]) then
								econ_data[t] = 0
							end

							data[t] = data[t] + econ_data[t]
						end
						
						data['unit'] = u
						data['description']  = bp.Description
						data['priority'] = c['priority']
						data['toggle'] = c['toggle']
						data['lasts_for'] = c['lasts_for'] or nil
						data['on'] = c['on'] or data['off'] or data['lasts_for']
						data['off'] = c['off'] or data['on']
						data['is_paused'] = isPaused(data)
						data['constructor'] = EntityCategoryContains(categories.ENGINEER, u) or EntityCategoryContains(categories.FACTORY, u)
						
						if(not data['is_paused']) then
							res['income'] = res['income'] + econ_data['energyConsumed']
						end

						if(data['is_paused']) then
							res['throttle_total'] = res['throttle_total'] + econ_data['energyRequested']
							res['throttle_current'] = res['throttle_current'] + econ_data['energyRequested']
						else
							res['throttle_total'] = res['throttle_total'] + econ_data['energyRequested']
						end

						table.insert(units[key], data)
						break
					end
				end
			end
		end
	end

	for name, cat_units in units do
		table.sort(cat_units, sortCategory)
		for _, data in cat_units do
			table.insert(res_units, data)
		end
	end

	table.sort(res_units, sortResourceUsers)

	return res_units
end

function isPaused(data) 
	local is_paused

	if(data['toggle'] ~= nil) then
		local bit = true

		if(data['toggle'] == 0) then
			bit = not bit
		end

		is_paused = GetScriptBit({data['unit']}, data['toggle']) == bit
	else
		is_paused = GetIsPaused({data['unit']})
	end

	return is_paused
end

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

function throttleEconomy()
	local units
	local eco = getEconomy()
	local res
	local lasts_for
	local tps = GetSimTicksPerSecond()

	local pausing = {}
	local paused_prio = 0
	local max_prio = 0

	res = {
		use = eco['ENERGY']['avg_use_requested'],
		ratio = eco['ENERGY']['ratio'],
		stored = math.max(0, (eco['ENERGY']['stored'])),
		throttle_total = 0,
		throttle_current = 0
	}

	if(eco['ENERGY']['net_income'] < 0) then
		res['income'] = eco['ENERGY']['net_income']*tps
	else
		res['income'] = ((eco['ENERGY']['net_income']*2 + eco['ENERGY']['avg_net_income'])/3)*tps
	end

	res_units = getResourceUsers(res)

--	print ('current ' .. res['throttle_current'] .. ' total ' .. res['throttle_total'])

	throttledEnergyText(res['throttle_current'])



	for _, data in res_units do
		if(not data['unit']:IsDead()) then
			local id = data['unit']:GetEntityId()
			local lasts_for 
			local min_lasts_for
			local min_rate = throttle_min_storage

			local new_income = res['income'] - data['energyRequested']
			local toggle_key

			local energy_use

			if(data['is_paused']) then
				energy_use = data['energyRequested']
			else
				energy_use = data['energyConsumed']
			end

			new_income = res['income'] - energy_use

			if(not max_prio) then
				max_prio = data['priority']
			end

			if(data['is_paused']) then
				min_lasts_for = data['on'] or 3
			else
				min_lasts_for = data['off'] or 3
			end

			if(throttle_min_storage == 'auto') then
				if(eco['ENERGY']['income']*tps < 1000) then
					min_lasts_for = 0.2
					min_rate = 0.01
				else
					min_rate = 0.08
				end
			end

			if(data['toggle'] ~= nil) then
				toggle_key = 'toggle_' .. data['toggle']
			else
				toggle_key = 'pause'
			end

			if(not pausing[toggle_key]) then
				pausing[toggle_key] = {on={}, off={}}
			end

			if(data['priority'] == 1) then -- fabs shouldn't draw more than 60%
				min_rate = 0.6
				min_lasts_for = 1
			end

			if(GetGameTimeSeconds() < 180 or (throttle_min_storage == 0 and data['priority'] > 1)) then -- disabled, unpause all except fabs
				lasts_for = 1000
			elseif(throttle_min_storage == 'auto' and data['priority'] == 100) then -- dont touch power in auto mode
				lasts_for = 1000
			elseif(res['ratio'] < min_rate) then
				if(new_income < 0) then
					lasts_for = 0
				else 
					local deficit = (min_rate - res['ratio']) *  eco['ENERGY']['max']

					if(res['stored'] < 1) then
						lasts_for = 0
					else
						lasts_for = (new_income / deficit) * 10
					end
				end
			elseif(new_income < 0)  then
				lasts_for = math.abs((res['stored']-min_rate*eco['ENERGY']['max']) / new_income)
			else
				lasts_for = 1000
			end

			if(lasts_for > min_lasts_for*1.05 and data['priority'] >= paused_prio) then
				if(data['is_paused']) then
					table.insert(pausing[toggle_key]['off'], data['unit'])
					data['is_paused'] = false
				end
			elseif(energy_use ~= 0 and (lasts_for < min_lasts_for or data['priority'] < paused_prio)) then
				if(not data['is_paused']) then
					table.insert(pausing[toggle_key]['on'], data['unit'])
					data['is_paused'] = true
				end
			end

			if(data['is_paused']) then
				if(data['priority'] > paused_prio) then
					paused_prio = data['priority']
				end
			else
				res['income']  = res['income'] - energy_use

				if(data['priority'] == 100) then -- high prio, some extra energy allocated 
					res['stored'] = res['stored'] - energy_use
				end
			end
		end
	end

	for toggle_key, modes in pausing do
		local toggle = toggle_key

		if(toggle ~= 'pause') then
			toggle = tonumber(string.sub(toggle, 8))
		end

		for mode, units in modes do
			setPause(units, toggle, mode == 'on')
		end
	end

end

function throttleCommand(args)
	local str = string.lower(args[2])
	
	if(str == 'on' or str == 'off') then
		local getPrefs = import(modPath .. 'modules/prefs.lua').getPrefs
		local savePrefs = import(modPath .. 'modules/prefs.lua').savePrefs

		prefs = getPrefs()
		prefs['em_throttle'] = str
		savePrefs()

		if(str == 'off') then
			print "Energy throttle disabled"
			return
		end
    elseif(string.lower(args[2]) == 'auto') then
        throttle_min_storage = 'auto'
    else
		throttle_min_storage = math.min(math.max(0, tonumber(args[2])/100), 1)
	end

	local thres

	if(throttle_min_storage == 0) then
		print ("Throttling disabled (except massfabs)")
	elseif(throttle_min_storage ~= 'auto')  then
		thres = round(throttle_min_storage*100)
		print ("Throttling energy when storage < " .. thres .. " percent")
	else
		print ("Throttling energy using auto mode")
	end
end

function onPause(units, checked)
	if(checked) then
		addExclusion(units)
	else
		delExclusion(units)
	end
end

function init()
	addEventListener('toggle_pause', onPause)
	addListener(throttleEconomy, 0.6, 'em_throttle')
	addCommand('t', throttleCommand)
end