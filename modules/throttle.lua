local modPath = '/mods/EM/'

local boolstr = import(modPath .. 'modules/utils.lua').boolstr
local getEconomy = import(modPath ..'modules/economy.lua').getEconomy
local getUnits = import(modPath .. 'modules/units.lua').getUnits
local unitData = import(modPath .. 'modules/units.lua').unitData
local econData = import(modPath .. 'modules/units.lua').econData
local addListener = import(modPath .. 'modules/init.lua').addListener
local addCommand = import(modPath .. 'modules/commands.lua').addCommand
local round = import(modPath .. 'modules/utils.lua').round
local Pause = import(modPath .. 'modules/pause.lua').Pause
local CanUnpauseUnits = import(modPath .. 'modules/pause.lua').CanUnpauseUnits

local throttledEnergyText = import(modPath .. 'modules/autoshare.lua').throttledEnergyText

local throttle_min_storage = 'auto'

local constructionCategories = {
	{name="Mass fabrication", category = categories.STRUCTURE * categories.MASSFABRICATION, toggle=4, priority = 1},
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
	{name="Mass fabrication", category = categories.STRUCTURE * categories.MASSFABRICATION, toggle=4, priority = 1}
}

function SetPaused(units, state)
	Pause(units, state, 'throttle')
end

function init()
	addListener(throttleEconomy, 0.6, 'em_throttle')
	addCommand('t', throttleCommand)
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

function sortUsers(a, b)
	local av = a['prio'] * 100000 - a['buildTime']  / a['buildRate']
	local bv = b['prio'] * 100000 - b['buildTime'] / b['buildRate']

	return av > bv
end

function getResourceUsers(res)
	local all_units = CanUnpauseUnits(getUnits(), 'throttle')
	local users = {}
	local unpause = {}

	for _, u in all_units do
		if(not u:IsDead()) then
			local focus
			local cats = {}
			local econ_data = econData(u)

			if(EntityCategoryContains(categories.ENGINEER, u) or EntityCategoryContains(categories.MASSEXTRACTION, u) or
				(EntityCategoryContains(categories.FACTORY, u) and not (EntityCategoryContains(categories.AIR * categories.TECH3, u)))) then
				focus = u:GetFocus()
				if(focus) then
					cats = constructionCategories
				elseif(GetIsPaused({u}) and (u:IsIdle() or u:GetWorkProgress() == 0)) then  --idling
					table.insert(unpause, u)
				end
			else
				cats = consumptionCategories
				focus = u
			end

			if(focus) then
				local toggle
				local priority = 1

				for _, c in cats do
					if(EntityCategoryContains(c['category'], focus)) then
						priority = c['priority']
						if(c['toggle']) then
							toggle = c['toggle']
						end

						local is_paused = isPaused({unit=u, toggle=toggle})
						local bp = focus:GetBlueprint()
						local id = focus:GetEntityId()

						if(not is_paused and econ_data['energyConsumed']) then
							res['net_income'] = math.min(res['income'], res['net_income'] + econ_data['energyConsumed'])
						end

						if(not users[id]) then
							local bp = focus:GetBlueprint()
							user = {
								unit = focus,
								assisters = {},
								prio = priority,
								toggle = toggle,
								workProgress = 0,
								buildRate = 0,
								buildTime = bp.Economy.BuildTime,
								buildCostEnergy = bp.Economy.BuildCostEnergy
							}
							users[id] = user
						end

						local energy_use
						if(is_paused) then
							energy_use = econ_data['energyRequested'] or 0
							res['throttle_current'] = res['throttle_current'] + energy_use + 100
						else
							energy_use = econ_data['energyConsumed']
						end
						res['throttle_total'] = res['throttle_total'] + energy_use


						table.insert(users[id]['assisters'], {unit=u, energyUse=energy_use or 0, isPaused=is_paused})

						users[id]['workProgress'] = math.max(users[id]['workProgress'], u:GetWorkProgress())
						users[id]['buildRate'] = users[id]['buildRate'] + u:GetBuildRate()
						break
					end
				end

			end
				--print ("workProgress " .. users[id]['workProgress'] .. " buildRate " .. users[id]['buildRate'])
		end
	end

	local sorted = {}
	for _, u in users do
		table.insert(sorted, u)
	end

	table.sort(sorted, sortUsers)
	--LOG(repr(sorted))

	if(unpause) then
		Pause(unpause, false, 'unpause')
	end

	return sorted
end

function throttleEconomy()
	--LOG("THROTTLE")
	local tps = GetSimTicksPerSecond()
	local eco = getEconomy()
	local res
	local res_users


	res = {
		income = eco['ENERGY']['income']*tps,
		pre_net_income = eco['ENERGY']['net_income']*tps,
		net_income = eco['ENERGY']['net_income']*tps,
		use = eco['ENERGY']['use_actual']*tps,
		ratio = eco['ENERGY']['ratio'],
		stored = math.max(0, eco['ENERGY']['stored']),
		max = eco['ENERGY']['max'],
		throttle_total = 0,
		throttle_current = 0
	}

	if(res['use'] > res['income'] and res['ratio'] >= 0.95) then --overflow from allies
		res['net_income'] = res['income']
	end

	res_users = getResourceUsers(res)

	--LOG(repr(res))

	throttledEnergyText(res['throttle_current'])

	local first = false -- maybe not use this
	local pausing = false
	local pause_list = {}

	local gametime = GetGameTimeSeconds()
	
	for _, u in res_users do
		local progress_left = 1-u['workProgress']
		local lasts_for = math.min(1.5, progress_left*u['buildTime']/u['buildRate'])
		local min_storage = throttle_min_storage
		local toggle_key = 'pause'

		if(u['toggle'] ~= nil) then
			toggle_key = 'toggle_' .. u['toggle']
		end

		if(not pause_list[toggle_key]) then
			pause_list[toggle_key] = {on={}, off={}}
		end

		
		if(throttle_min_storage == 'auto') then
			if(gametime < 180) then -- no throttling first 3 minutes of game
				min_storage = 0
			elseif(u['prio'] == 1) then -- massfabs are on >60% storage in automode
				min_storage = 0.6
			elseif(res['income'] > 500) then  -- minimum 5% storage when energy income > 500 (around t2 stage / shields)
				min_storage = 0.05
			else
				min_storage = 0.01 -- 1% storage until energy income is high enough
			end
		end

		for _, a in u['assisters'] do
			if((min_storage > 0 or u['prio'] == 1) and not pausing) then
				local new_income = res['net_income'] - a['energyUse']
				local new_stored = res['stored']

				if(new_income < 0) then
					new_stored = new_stored - math.abs(new_income*lasts_for)
				end

				if(new_stored < min_storage*res['max'] and not first) then
					pausing = true
					--LOG("PAUSING!")
				else
					res['net_income'] = new_income
					res['stored'] = new_stored
				end
			end
			
			if(pausing) then
				if(not a['isPaused']) then
					table.insert(pause_list[toggle_key]['on'], a['unit'])
				end
			else
				if(a['isPaused']) then
					table.insert(pause_list[toggle_key]['off'], a['unit'])
				end
			end
			--LOG("pausing " .. boolstr(pausing) .. " income " .. res['net_income'] .. " stored " .. res['stored'] .. " energyRequested " .. a['energyRequested'])
			first = false
		end

	end

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