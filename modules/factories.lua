local modPath = '/mods/EM/'


local SelectBegin = import(modPath .. 'modules/allunits.lua').SelectBegin
local SelectEnd = import(modPath .. 'modules/allunits.lua').SelectEnd

function resetOrderQueue(factory)
	local queue = SetCurrentFactoryForQueueDisplay(factory)

	for i = 1, table.getsize(queue) do
		local count = queue[i].count

		if(i == 1) then
			count = count - 1
		end
		DecreaseBuildCountInQueue(i, count)
	end
end

function resetOrderQueues()
	local factories = GetSelectedUnits()
	local old = GetSelectedUnits()

	if(factories) then
		SelectBegin()

		for _, factory in factories do
			resetOrderQueue(factory)
		end
		SelectEnd()
	end
end

function init(isReplay, parent)
	local path = modPath .. 'modules/factories.lua'
	IN_AddKeyMapTable({['Ctrl-Y'] = {action =  'ui_lua import("' .. path .. '").resetOrderQueues()'},})
end
