local modPath = '/mods/EM/'
local addListener = import(modPath .. 'modules/init.lua').addListener

states = {}
local pause_prios = {
	mexes={pause=80, unpause=50},
	ecomanager={pause=70},
	user={pause=100},
	unpause={pause=90, unpause=90},
}

function init()
	--addListener(DoPause, 0.1)
end

function isPaused(unit)
	local is_paused
	if EntityCategoryContains(categories.MASSFABRICATION*categories.STRUCTURE, unit) then
		is_paused = GetScriptBit({unit}, 4)
	else
		is_paused = GetIsPaused({unit})
	end

	return is_paused
end

function resetPauseStates()
	states = {}
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

-- function Pause(units, pause, module)

-- 	local prio = getPrio(module, pause)
-- 	local paused = {}
-- 	local unpaused = {}

-- 	for _, u in units do
-- 		local id = u:GetEntityId()
-- 		if userLocked(u) then continue end

-- 		if not states[id] or states[id]['module'] == module or prio >= states[id]['prio'] then
-- 			if pause and not states[id]['paused'] then
-- 				table.insert(paused, u)
-- 			elseif(not pause) then
-- 				table.insert(unpaused, u)
-- 			end
-- 			states[id] = {unit=u,prio=prio,module=module,focusType=focusType, paused=pause}
-- 		end
-- 	end 
-- 	SetPaused(paused, true)
-- 	SetPaused(unpaused, false)
-- end

function Pause(units, pause, module, toggle, all)
	
	units = changables(units, pause, module), pause

	if toggle == 'pause' or all then
		SetPaused(units, pause)
	end
	if toggle ~= 'pause' then
		local bit = GetScriptBit(units, toggle)
		local is_paused = bit 
	
		if toggle == 0 then 
			is_paused = not is_paused 
		end

		if pause ~= is_paused then
			ToggleScriptBit(units, toggle, bit)
		end
	end
end

-- function Toggle(units, toggle, pause, module)
-- 	ToggleScriptBit(changables(units, pause, module), toggle, pause)
-- end


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

-- function isUnlocked(u, changeObsolete)
-- 	local id = u:GetEntityId()
-- 	local pauseState = isPaused(u)
-- 	changeObsolete = pauseState == pause

-- 	--a change of focus resets the user introduced state
-- 	local focus = u:GetFocus()
-- 	local focusType = nil
-- 	if focus then focusType = focus:GetBlueprint().General.UnitName	end
-- 	if states[id] and states[id].focusType and states[id].focusType ~= focusType then states[id] = nil end

-- 	return states[id] and not states[id].paused == pauseState or changeObsolete
-- end

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

	local notChangedByUser = states[id] and states[id].state == pauseState
	local canChangeState = notChangedByUser and not states[id] or states[id]['module'] == module or prio >= states[id]['prio'] and not changeObsolete
	if update and canChangeState then
		states[id] = {unit=u,prio=prio,module=module,focusType=focusType, state=pause}
	end
	return canChangeState
end

function CanUnpauseUnits(units, module)
	local id
	local prio = pause_prios[module]['unpause'] or pause_prios[module]['pause']
	local filtered = {}

	for _, u in units do
		if not u:IsDead() then
			id = u:GetEntityId()
			if not states[id] or module == states[id]['module'] or states[id]['prio'] <= prio or u:IsIdle() or u:GetWorkProgress() == 0 then
				table.insert(filtered, u)
			end
		end
	end

	return filtered
end

function CanUnpause(unit, module)
	local id = unit:GetEntityId()
	id = nil -- XXX
	local prio = pause_prios[module]['unpause'] or pause_prios[module]['pause']

	return not states[id] or module == states[id]['module'] or states[id]['prio'] <= prio or unit:IsIdle() or unit:GetWorkProgress() == 0
end
