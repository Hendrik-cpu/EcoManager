states = {}
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
	local units = {}
	for _, s in states do
		if modules[s.module] then
			table.insert(units, s.unit)
		end
	end
	states = {}
	SetPaused(units, false)
	ToggleScriptBit(units, 4, true)
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
	SetPaused(changables(units, pause, module), pause)
end

function Toggle(units, pause, module, toggle)

	local bit = GetScriptBit(units, toggle)
	local is_paused = bit 

	if toggle == 0 then 
		is_paused = not is_paused 
	end

	if pause ~= is_paused then
		ToggleScriptBit(changables(units, pause, module), toggle, bit)
	end
end

function changables(units, pause, module)
	local prio = getPrio(module, pause)
	local changables = {}
	for _, u in units do
		local id = u:GetEntityId()
		if canChangeState(u, module, pause, true) then
			table.insert(changables, u)
		end
	end
	return changables
end

function canChangeState(u, module, pause, update)
	local id = u:GetEntityId()
	local pauseState = isPaused(u)
	local prio = getPrio(module, not pauseState)
	local changeObsolete = update and pauseState == pause

	--a change of focus resets the user introduced state
	local focus = u:GetFocus()
	local focusType = nil
	if focus then focusType = focus:GetBlueprint().General.UnitName	end
	if states[id] and states[id].focusType and states[id].focusType ~= focusType then states[id] = nil end

	local changedByUser = states[id] and states[id].state ~= pauseState
	if changedByUser then
		module = "user"
		prio = getPrio(module, not pauseState)
		states[id] = {unit=u,prio=prio,module=module, state=pauseState, focusType=focusType}
	end

	local canChangeState = not changedByUser and not states[id] or states[id]['module'] == module or prio >= states[id]['prio'] and not changeObsolete
	if update and canChangeState then
		states[id] = {unit=u,prio=prio,module=module, state=pause, focusType=focusType}
	end
	return canChangeState
end