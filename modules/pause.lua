states = {}
toggleStates = {}

local pause_prios = {
	mexes={pause=80, unpause=50},
	ecomanager={pause=70},
	user={pause=100},
	unpause={pause=90, unpause=90},
}

function isPaused(unit)
	local is_paused
	if EntityCategoryContains(categories.MASSFABRICATION*categories.STRUCTURE, unit) then
		is_paused = GetScriptBit({unit}, 4)
	else
		is_paused = GetIsPaused({unit})
	end

	return is_paused
end

function resetPauseStates(modules)
	local unpause = {}
	for id, s in states do
		if (not modules or modules and modules[s.module]) and not s.unit:IsDead() then
			table.insert(unpause,s.unit)
			states[id] = nil
		end
	end
	SetPaused(unpause, false)

	local toggle = {}
	for id, s in toggleStates do
		if (not modules or modules and modules[s.module]) and not s.unit:IsDead() then
			if toggle[s.toggle] then 
				table.insert(toggle[s.toggle],s.unit)
			else
				toggle[s.toggle] = {s.unit}
			end
			toggleStates[id] = nil
		end
	end
	for tkey, units in pairs(toggle) do
		ToggleScriptBit(units, tkey, true)
	end
end

function getPrio(module, pause)
	local prio
	if pause then
		prio = pause_prios[module]['pause']
	else
		prio = pause_prios[module]['unpause'] or pause_prios[module]['pause']
	end

	if not prio then
		prio = 50
	end
	return prio
end

function Pause(units, pause, module)
	local changables = {}
	for _, u in units do
		local id = u:GetEntityId()
		if canPause(u, module, pause, true) then
			table.insert(changables, u)
		end
	end
	SetPaused(changables, pause)
end

function Toggle(units, pause, module, toggle)
	local changables = {}
	for _, u in units do
		local id = u:GetEntityId()
		if canToggle(u, module, pause, true, toggle) then
			table.insert(changables, u)
		end
	end
	ToggleScriptBit(changables, 4, not pause)
end

function canInvertState(u, module)
	local pauseState = isPaused(u)
	return canPause(u, module, not pauseState) and canToggle(u, module, not pauseState)
end

function canToggle(u, module, pause, update, toggle)
	local id = u:GetEntityId()
	if toggleStates[id] and toggleStates[id].unit:IsDead() then 
		toggleStates[id] = nil
		return true
	end

	local pauseState = isPaused(u)
	local prio = getPrio(module, not pauseState)

	-- local changedByUser = toggleStates[id] and toggleStates[id].state ~= pauseState
	-- if changedByUser and update then
	-- 	module = "user"
	-- 	prio = getPrio(module, not pauseState)
	-- 	toggleStates[id] = {unit=u,prio=prio,module=module, state=pauseState, toggle = toggle}
	-- end
	--not changedByUser and
	local canChangeState =  not toggleStates[id] or toggleStates[id]['module'] == module or prio >= toggleStates[id]['prio']
	if update and canChangeState then
		toggleStates[id] = {unit=u,prio=prio,module=module, state=pause, toggle = toggle}
	end
	return canChangeState
end

function canPause(u, module, pause, update)
	local id = u:GetEntityId()
	if states[id] and states[id].unit:IsDead() then 
		states[id] = nil 
		return true
	end

	local pauseState = isPaused(u)
	local prio = getPrio(module, not pauseState)
	local changeObsolete = update and pauseState == pause

	--a change of focus resets the user introduced state, if there is a >1 second break
	local focus = u:GetFocus()
	local focusType = nil
	local gameTick = GameTick()
	if focus then focusType = focus:GetBlueprint().General.UnitName	end
	if states[id] and states[id].module == "user" and states[id].focusType and states[id].focusType ~= focusType then 
		if states[id].lastFocusChange and (gameTick-states[id].lastFocusChange) / 10 > 1 then
			states[id] = nil
		elseif states[id].lastFocusChange then
		end
		if states[id] then 
			states[id].lastFocusChange = gameTick
		end
	end

	local canChangeState = not states[id] or states[id]['module'] == module or prio >= states[id]['prio'] and not changeObsolete
	if update then
		if canChangeState then
			states[id] = {unit=u,prio=prio,module=module, state=pause}
		end
		if states[id] then states[id].focusType=focusType end
	end
	return canChangeState
end