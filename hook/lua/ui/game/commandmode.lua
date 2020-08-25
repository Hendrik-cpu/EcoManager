local modPath = '/mods/EM/'
local queuePause = import(modPath .. 'modules/mexes.lua').queuePause
local Select = import('/lua/ui/game/selection.lua')

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

function UpgradeMex(mex, bp)
	Select.Hidden(function()
        SelectUnits({mex})
        IssueBlueprintCommand("UNITCOMMAND_Upgrade", bp, 1, false)
        queuePause(mex)
    end)
end

local lastAssist = {mex=nil, order=nil}
function AssistMex(command)
    local units = EntityCategoryFilterDown(categories.ENGINEER, command.Units)
    if not units[1] then return end
    local mex = GetUnitById(command.Target.EntityId)
    if not mex or IsDestroyed(mex) then return end
    local eco = mex:GetEconData()
    local bp = mex:GetBlueprint()
    local is_capped = eco.massProduced == bp.Economy.ProductionPerSecondMass * 1.5
    if is_capped and mex:IsInCategory('TECH3') then return end

    local focus = mex:GetFocus()
    local prefix = string.sub(command.Blueprint, 0, 3)
    local cap = false

    local order
    local last_order = not command.Clear and lastAssist.mex == mex and lastAssist.order

    if (is_capped or last_order == 'cap') and not focus and mex:IsInCategory('TECH2') then
        order = 't3'
    elseif not is_capped and (last_order == 't2' or not mex:IsInCategory('TECH1')) then
        order = 'cap'
    elseif not focus and mex:IsInCategory('TECH1') then
        order = 't2'
    end

    if not order then
        lastAssist = {}
    else
        if order == 'cap' then
            SimCallback({Func = 'CapMex', Args = {target = command.Target.EntityId}}, true)
        else
            local options = import(modPath .. 'modules/utils.lua').getOptions(true)
            if options['em_mexes'] ~= 'click' then return end
            local postfix = order == 't2' and '1202' or '1302'
            UpgradeMex(mex, prefix .. postfix)
        end

        lastAssist.order = order
        lastAssist.mex = mex
    end
end