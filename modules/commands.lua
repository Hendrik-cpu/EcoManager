local command_table = {}
local hotkeys = {}

function addCommand(command, f)
	command_table[string.lower(command)] = f
end

function runCommand(args)
	local command = string.lower(args[1])

	if command_table[command] then
		command_table[command](args)
		return true
	end

	return false
end

function addHotkey(hotkey, f)
	LOG('ui_lua import("' .. f .. "()")
	IN_AddKeyMapTable({[hotkey] = {action = 'ui_lua import("' .. f .. "()"},})
	hotkeys[hotkey] = f
end

function printCommands()
	local str = "Commmands: \n"
	for cmd,_ in command_table do
		str = str .. "  " .. cmd .. "\n"
	end
	str = str .. "Hotkeys: \n"
	for hk,func in hotkeys do
		str = str .. "  " .. hk .. " = " .. func .. "\n"
	end
	print(str)
	LOG(str)
end

function init(isReplay, parent)
	addCommand("info", printCommands)
end
