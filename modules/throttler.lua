local modPath = '/mods/EM/'
local addListener = import(modPath .. 'modules/init.lua').addListener
local EcoManager = import(modPath .. 'modules/throttler/EcoManager.lua').EcoManager

function isPaused(u)
	local is_paused
	if EntityCategoryContains(categories.MASSFABRICATION*categories.STRUCTURE, u) then
		is_paused = GetScriptBit({u}, 4)
	else
		is_paused = GetIsPaused({u})
	end

	return is_paused
end

function setPause(units, toggle, pause)
	if toggle == 'pause' then
		SetPaused(units, pause)
	else
		local bit = GetScriptBit(units, toggle)
		local is_paused = bit

		if toggle == 0  then
			is_paused = not is_paused
		end

		if pause ~= is_paused then
			ToggleScriptBit(units, toggle, bit)
		end
	end
end





function init()
	manager = EcoManager()
	addListener(EcoManager.manageEconomy, 0.2)
end
