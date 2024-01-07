states = {}
toggleStates = {}

local pause_prios = {
	mexes={pause=80, unpause=50},
	ecomanager={pause=70},
	user={pause=100},
	unpause={pause=90, unpause=90},
	unknownModule={pause=80, unpause=50},
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
		prio = pause_prios[module]['unpause'] or pause_prios[module]['pause']
	else
		prio = pause_prios[module]['pause']
	end

	if not prio then
		prio = 50
	end
	return prio
end


local unitFirstRegistered = {}
function Toggle(units, pause, module, toggle)
	local changables = {}
	for _, u in units do
		local id = u:GetEntityId()

		local registeredUnit = unitFirstRegistered[id]
		local firstAccess = nil
		if registeredUnit then
			if not unitFirstRegistered[id].unit:IsDead() then 
				firstAccess = unitFirstRegistered[id].firstAccess
			end
		else
			unitFirstRegistered[id] = {unit = u, firstAccess = GameTick()}
		end
		if firstAccess and GameTick() - firstAccess > 5 then
			if canToggle(u, module, pause, true, toggle) then
				table.insert(changables, u)
			end
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
	-- local changedByUser = toggleStates[id] and toggleStates[id].state ~= pauseState
	-- if changedByUser and update then
	-- 	toggleStates[id] = {unit=u,prio=100,module="user", state=pauseState, toggle = toggle}
	-- end
	local prio = getPrio(module, not pauseState)

	--not changedByUser and
	local canChangeState = not toggleStates[id] or toggleStates[id]['module'] == module or prio >= toggleStates[id]['prio']
	if update and canChangeState then
		toggleStates[id] = {unit=u,prio=prio,module=module, state=pause, toggle = toggle}
	end
	return canChangeState
end

function cleanStates()
	for id, state in states do
		if state.unit:IsDead() then --or ((GameTick() - state.lastAccess) > 20 and state.unit:GetFocus() == nil) then --2 seconds
			states[id] = nil
		end
	end
end

function canPause(u, module, pause, update)
	local id = u:GetEntityId()
	if states[id] and states[id].unit:IsDead() then 
		states[id] = nil 
		return true
	end

	local pauseState = isPaused(u)
	local prio = getPrio(module, pause)
	local changeObsolete = update and pauseState == pause

	local canChangeState = not states[id] or states[id]['module'] == module or prio >= states[id]['prio'] and not changeObsolete
	if update then
		if canChangeState then
			states[id] = {unit=u,prio=prio,module=module, state=pause, lastAccess=GameTick()}
		end
	end
	return canChangeState
end

function Pause(units, pause, requestingModule)
	-- local changables = {}
	-- for _, u in units do
	-- 	local id = u:GetEntityId()
	-- 	if canPause(u, requestingModule, pause, true) then
	-- 		table.insert(changables, u)
	-- 	end
	-- end
	-- SetPaused(changables, pause)
	setPauseStates(units, pause, requestingModule)
end
function setPauseStates(units, pause, requestingModule)
	local changables = {}
	for _, u in units do

			local unitID = u:GetEntityId()
			local unitState = nil
			if states[unitID] and states[unitID].unit:IsDead() then
				states[unitID] = nil
			else
				unitState = states[unitID]
			end

			local requestingModulePrio = getPrio(requestingModule, pause)
			local changeState = false

			--LOG(tostring(pause))
			if not unitState and not pause then
				--if unpause command is issued but pause state was never registered, that means it was paused by a unregistered third party script, let's give it a prio only second to the user
				--probably a mex duo to new implementation of eco manager function into FAF
				--LOG("if unpause command is issued but pause state was never registered, that means it was paused by a unregistered third party script, let's give it a prio only second to the user probably a mex duo to new implementation of eco manager function into FAF")
				unitState =  {unit = u, module = "unknownModule", state = true}
				states[unitID] = unitState
			end

			local currentPrio = getPrio(unitState.module, pause)
			if not unitState then
				--there is no information about the pause state or it belonged to a different unit, state can be altered for sure!
				--LOG("there is no information about the pause state or it belonged to a different unit, state can be altered for sure!")
				changeState = true
			else 
				--so we have information about a previous pause state, let's see if it can be altered
				--LOG("so we have information about a previous pause state, let's see if it can be altered")
				if unitState.module == requestingModule then 
					--if the module is the same, state can be altered!
					--LOG("if the module is the same, state can be altered! --> " .. unitState.module .. " == " .. requestingModule)
					changeState = true
				else 
					--so it was a different module, let's check the prio of the lock
					--LOG("so it was a different module, let's check the prio of the lock --> Previous module: " .. unitState.module .. "Prio: " .. currentPrio)
					if requestingModulePrio > currentPrio then
						--requesting module has a higher prio, let's change the state
						--LOG("requesting module has a higher prio, let's change the state --> Requesting prio: " .. requestingModulePrio .. " is higher than previous " .. currentPrio .. "by module: " .. unitState.module)
						changeState = true
					end
				end
			end

			if changeState then
				states[unitID] = {unit=u,module=requestingModule, state=pause}
				table.insert(changables, u)
				--LOG("Unit" .. unitID .. " state changed to paused = " .. tostring(pause))
				--LOG("Unit" .. unitID .. " changed state to paused = " .. pause .. " by request of " .. requestingModule .. "(" .. unitState.prio .. ")" .. " previously owned by " .. unitState.module .. "(" .. unitState.prio .. ")")
			end
			
	end
	SetPaused(changables, pause)
end