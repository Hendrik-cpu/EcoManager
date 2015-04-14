modPath = "/mods/EM/"

local oldOnCommandIssued = OnCommandIssued

function EndCommandMode(isCancel)
    modeData.isCancel = isCancel or false
    for i,v in endBehaviors do
        v(commandMode, modeData)
    end

    if commandMode == 'build' and modeData.isCancel then
        ClearBuildTemplates()
    end

    commandMode = false
    modeData = false
    issuedOneCommand = false
end

function OnCommandIssued(command)
	oldOnCommandIssued(command)

    if(command.CommandType == "Guard" and command.Target.EntityId) then
		local bp = string.sub(command.Blueprint, 4)

		if(bp == '1103' or bp == '1202') then
			if(EntityCategoryFilterDown(categories.ENGINEER, command.Units)) then
				local options = import(modPath .. 'modules/utils.lua').getOptions(true)
				if(options['em_mexes'] == 'click') then
                    import(modPath .. 'modules/mexes.lua').upgradeMexById(command.Target.EntityId)
				end
			end
		end
	end
end
