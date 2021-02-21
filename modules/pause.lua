local modPath = '/mods/EM/'
local addListener = import(modPath .. 'modules/init.lua').addListener

local pause_prios = {
	mexes={pause=80, unpause=50},
	ecomanager={pause=90, unpause=60},
	--throttlemass={pause=70},
	user={pause=100},
	unpause={pause=90, unpause=90},
}

local states = {}
--local current_states = {}

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

function Pause(units, pause, module)
	local prio
	local paused = {}
	local unpaused = {}

	if pause then
		prio = pause_prios[module]['pause']
	else
		prio = pause_prios[module]['unpause'] or pause_prios[module]['pause']
	end

	if not prio then
		prio = 50
	end

	local cPaused = 0
	local cUnpaused = 0
	for _, u in units do
		local id = u:GetEntityId()
		local focus = u:GetFocus()
		local focusID = nil
		if focus then 
			focusID = focus:GetEntityId()
		end

		if states[id] and states[id].focusID and states[id].focusID ~= focusID then
			states[id] = nil
		end

		if not states[id] or states[id]['paused'] ~= pause then
			if not states[id] or states[id]['module'] == module or prio >= states[id]['prio'] then
				if pause and not states[id]['paused'] then
					-- if not states[id] then
					--  	states[id] = {unit=u,prio=prio,module=module,focusID=focusID}
					-- end
					cPaused = cPaused +1
					--states[id]['paused'] = pause
					table.insert(paused, u)
				elseif(not pause) then
					table.insert(unpaused, u)
					--states[id] = {unit=u,prio=prio,module=module,focusID=focusID}
					cUnpaused = cUnpaused +1
				end
			end
		end
		states[id] = {unit=u,prio=prio,module=module,focusID=focusID}
	end
	SetPaused(paused, true)
	SetPaused(unpaused, false)
end

function CanUnpause(unit, module)
	local id = unit:GetEntityId()
	id = nil -- XXX
	local prio = pause_prios[module]['unpause'] or pause_prios[module]['pause']

	return not states[id] or module == states[id]['module'] or states[id]['prio'] <= prio or unit:IsIdle() or unit:GetWorkProgress() == 0
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
