local modPath = '/mods/EM/'
local addListener = import(modPath .. 'modules/init.lua').addListener

local pause_prios = {
	mexes={pause=80, unpause=50},
	throttle={pause=90, unpause=60},
	throttlemass={pause=70},
	user={pause=100},
	unpause={pause=90, unpause=90},
}

local states = {}
--local current_states = {}

function init()
	--addListener(DoPause, 0.1)
end

function Pause(units, pause, module)
	local prio
	local paused = {}
	local unpaused = {}

	if(pause) then
		prio = pause_prios[module]['pause']
	else
		prio = pause_prios[module]['unpause'] or pause_prios[module]['pause']
	end

	if(not prio) then
		prio = 50
	end

	for _, u in units do
		local id = u:GetEntityId()

		if(not states[id] or states[id]['paused'] ~= pause) then
			if(not states[id] or states[id]['module'] == module or prio >= states[id]['prio']) then
				if(pause and not states[id]['paused']) then
					if(not states[id]) then
						states[id] = {unit=u,prio=prio,module=module}
					end

					states[id]['paused'] = pause
					table.insert(paused, u)
				elseif(not pause) then
					table.insert(unpaused, u)
					states[id] = nil
				end


			end
		end
	end

	SetPaused(paused, true)
	SetPaused(unpaused, false)
end

function CanUnpause(unit, module)
	local id
	local prio = pause_prios[module]['unpause'] or pause_prios[module]['pause']

	return (not states[id] or module == states[id]['module'] or states[id]['prio'] <= prio or (u:IsIdle() or u:GetWorkProgress() == 0))
end

function CanUnpauseUnits(units, module)
	local id
	local prio = pause_prios[module]['unpause'] or pause_prios[module]['pause']
	local filtered = {}

	for _, u in units do
		if(not u:IsDead()) then
			id = u:GetEntityId()
			if(not states[id] or module == states[id]['module'] or states[id]['prio'] <= prio or (u:IsIdle() or u:GetWorkProgress() == 0)) then
				table.insert(filtered, u)
			end
		end
	end

	return filtered
end


--[[
function IsPaused(units, module)
	for _, u in units do
		local id = u:GetEntityId()

		if(not states[id]) then
			states[id] = {unit=u,prio=0,module=nil, paused=GetIsPaused({u})}
		end
		
		if(states[id]['paused']) then
			return true
		end
	end

	return false
end
]]

--[[
function IsPaused(unit, module)
	local id = unit:GetEntityId()

	return states[id] and states[id]['paused']

	local paused_prio = false
	local state_prio = 0

	if(statos[id]) then
		pausedule) then -- state for a specific module
			return states[id][module]
		end

		for module, state in states[id] do -- find highest prio state
			local prio
			if(state) then
				prio = pause_prios[module]['pause']
			else 
				prio = pause_prios[module]['unpause'] or pause_prios[module]['pause']
			end
			
			if(prio > state_prio) then
				state_prio = prio
				paused = state
			end
		end
	end

	return paused
	return current_states[id]



end
]]

--[[
function DoPause()
	local paused = {}
	local unpaused = {}

	

	for id, state in states do
		local unit = state['unit']
		local pause = state['pause']

		if(pause and not current_states[id]) then
			table.insert(paused, unit)
		elseif(not pause and not current_states[id]) then
			table.insert(unpaused, unit)
		end

		current_states[id] = pause
	end

	SetPaused(paused, true)
	SetPaused(unpaused, false)
end
]]

--[[
function DoPause()
	local paused = {}
	local unpaused = {}

	for id, modules in states do
		local pause
		local state_prio
		local unit = modules['unit']

		for module, state in modules do
			if(module ~= 'unit') then
				if(state) then 
					prio = pause_prios[module]['pause']
				else
					prio = pause_prios[module]['unpause'] or pause_prios[module]['pause']
				end

				if(prio > state_prio) then
					state_prio = prio
					pause = state
				end
			end
		end

		if(pause and not current_states[id]) then
			table.insert(paused, unit)
		elseif(not pause and not current_states[id]) then
			table.insert(unpaused, unit)
		end

		current_states[id] = pause
	end

	SetPaused(paused, true)
	SetPaused(unpaused, false)
end
]]

