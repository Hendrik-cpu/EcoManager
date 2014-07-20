local modPath = '/mods/EM/'

local runCommand = import(modPath .. 'modules/commands.lua').runCommand

local oldCreateChatEdit = import('/lua/ui/game/chat.lua').CreateChatEdit
local oldOnEnterPressed

function CreateChatEdit() 
	local group = oldCreateChatEdit()

	oldOnEnterPressed= group.edit.OnEnterPressed

	group.edit.OnEnterPressed = function(self, text)
		if(string.len(text) > 1 and string.sub(text, 1, 1) == "/") then
			local args = {}

			for w in string.gfind(string.sub(text, 2), "%S+") do
				table.insert(args, w)
			end

			if(runCommand(args)) then
				return
			end
		end

		return oldOnEnterPressed(self, text)
	end

	return group
end

function ActivateChat(modifiers)
    if GetFocusArmy() != -1 then
        if type(ChatTo()) != 'number' then
            if modifiers.Shift then
                ChatTo:Set('allies')
            else
                ChatTo:Set('all')
            end
        end
    end
    ToggleChat()
end

function ToggleChat()
	if GUI.bg:IsHidden() then
		GUI.bg:Show()
		GUI.chatEdit.edit:AcquireFocus()
		if not GUI.bg.pinned then
			GUI.bg:SetNeedsFrameUpdate(true)
			GUI.bg.curTime = 0
		end
		for i, v in GUI.chatLines do
			v:SetNeedsFrameUpdate(false)
			v:Show()
			v.OnFrame = nil
		end
	else
		GUI.bg:Hide()
		GUI.chatEdit.edit:AbandonFocus()
		GUI.bg:SetNeedsFrameUpdate(false)
	end
end

function ReceiveChatFromSim(sender, msg)
	sender = sender or "nil sender"
	if msg.ConsoleOutput then
		print(LOCF("%s %s", sender, msg.ConsoleOutput))
		return
	end
	if not msg.Chat then
		return
	end
	if type(msg) == 'string' then
		msg = { text = msg }
	elseif type(msg) != 'table' then
		msg = { text = repr(msg) }
	end
	local armyData = GetArmyData(sender)
	if not armyData and GetFocusArmy() != -1 and not SessionIsReplay() then
		return
	end
	local towho = LOC(ToStrings[msg.to].text) or LOC(ToStrings['private'].text)
	local tokey = ToStrings[msg.to].colorkey or ToStrings['private'].colorkey
	if msg.Observer then
		towho = LOC("<LOC lobui_0592>to observes:")
		tokey = "link_color"
	end
	if msg.Observer and armyData.faction then
		armyData.faction = table.getn(FactionsIcon) - 1
	end
	if type(msg.to) == 'number' and SessionIsReplay() then
		towho = string.format("%s %s:", LOC(ToStrings.to.text), GetArmyData(msg.to).nickname)
	end
	local name = sender .. ' ' .. towho

	if msg.echo then
		if msg.from and SessionIsReplay() then
			name = string.format("%s %s %s:", msg.from, LOC(ToStrings.to.text), GetArmyData(msg.to).nickname)
			--name = string.format("%s %s:", LOC(ToStrings.to.text), sender)
			--name = msg.from.." "..name
		else
			name = string.format("%s %s:", LOC(ToStrings.to.caps), sender)
		end
	end
	local tempText = WrapText({text = msg.text, name = name})
	-- if text wrap produces no lines (ie text is all white space) then add a blank line
	if table.getn(tempText) == 0 then
		tempText = {""}
	end
	local entry = {
					name = name,
					tokey = tokey,
					color = (armyData.color or "ffffffff"),
					armyID = (armyData.ArmyID or 1),
					faction = (armyData.faction or (table.getn(FactionsIcon)-1))+1,
					text = msg.text,
					wrappedtext = tempText,
					new = true
				}

	if msg.camera then
		entry.camera = msg.camera
	end
	table.insert(chatHistory, entry)
	if ChatOptions[entry.armyID] then
		if table.getsize(chatHistory) == 1 then
			GUI.chatContainer:CalcVisible()
		else
			GUI.chatContainer:ScrollToBottom()
		end
	end
	if SessionIsReplay() then
		PlaySound(Sound({Bank = 'Interface', Cue = 'UI_Diplomacy_Close'}))
	end
end