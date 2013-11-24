local modPath = '/mods/EM/'

local GetScore = import(modPath .. 'modules/score.lua').GetScore

local current_command = nil
local old_selection = {}
local all_units = {}
local auto_select = false
local last_reset = 0
local last_clean = 0
local current_army = nil
local commandmode = import('/lua/ui/game/commandmode.lua')

function SelectBegin()
	auto_select = true
	old_selection = GetSelectedUnits() or {}
	current_command = commandmode.GetCommandMode()
end

function SelectEnd()
	SelectUnits(old_selection)
	commandmode.StartCommandMode(current_command[1], current_command[2])
	auto_select = false
end

function IsAutoSelection()
	return auto_select == true
end

function AddSelectedUnits()
	for _, unit in (GetSelectedUnits() or {}) do
		all_units[unit:GetEntityId()] = unit
	end
end

function UpdateAllUnits()
	local army = GetFocusArmy()
	local score = GetScore()
	local unitcount = score[army].general.currentunits.count

	if(unitcount > table.getsize(all_units) or (current_army ~= army)) then
		local current_tick = GameTick()

		if(current_tick - 50 > last_reset or current_army ~= army) then -- score updates slowly
			--print("ALLUNITS RESET")
			SelectBegin()
			UISelectionByCategory("ALLUNITS", false, false, false, false)
			AddSelectedUnits()
			SelectEnd()
			last_reset = current_tick

			current_army = army
		end
	end

	for _, unit in all_units do
		if not unit:IsDead() and unit:GetFocus() and not unit:GetFocus():IsDead() then
			all_units[unit:GetFocus():GetEntityId()] = unit:GetFocus()
		end
	end
end

function GetAllUnits()
	local current_tick = GameTick()

	if(last_clean < GameTick()) then
		for id, unit in all_units do
			if unit:IsDead() then
				all_units[id] = nil
			end
		end

		last_clean = current_tick
	end

	return all_units
end

