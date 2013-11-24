local modPath = '/mods/EM/'
local triggerEvent = import('/mods/EM/modules/events.lua').triggerEvent

function SetPaused(units, state)
    import(modPath .. 'modules/pause.lua').Pause(units, state, 'user')
end

function CreateExtraControls(controlType)
    if controlType == 'construction' or controlType == 'templates' then
        Tooltip.AddCheckboxTooltip(controls.extraBtn1, 'construction_infinite')
        controls.extraBtn1.OnClick = function(self, modifiers)
            return Checkbox.OnClick(self, modifiers)
        end
        controls.extraBtn1.OnCheck = function(self, checked)
            for i,v in sortedOptions.selection do
                if checked then
                    v:ProcessInfo('SetRepeatQueue', 'true')
                else
                    v:ProcessInfo('SetRepeatQueue', 'false')
                end
            end
        end
        local allFactories = true
        local currentInfiniteQueueCheckStatus = true

        for i,v in sortedOptions.selection do
            if not v:IsRepeatQueue() then
                currentInfiniteQueueCheckStatus = false
            end

            if not v:IsInCategory('FACTORY') then
                allFactories = false
            end
        end

        if allFactories then
            controls.extraBtn1:SetCheck(currentInfiniteQueueCheckStatus, true)
            controls.extraBtn1:Enable()
        else
            controls.extraBtn1:Disable()
        end

        Tooltip.AddCheckboxTooltip(controls.extraBtn2, 'construction_pause')
        controls.extraBtn2.OnCheck = function(self, checked)
            --triggerEvent('toggle_pause', sortedOptions.selection, checked)
            SetPaused(sortedOptions.selection, checked)
        end
        if pauseEnabled then
            controls.extraBtn2:Enable()
        else
            controls.extraBtn2:Disable()
        end
        controls.extraBtn2:SetCheck(GetIsPaused(sortedOptions.selection),true)
    elseif controlType == 'selection' then
        Tooltip.AddCheckboxTooltip(controls.extraBtn1, 'save_template')
        local validForTemplate = true
        local faction = false
        for i,v in sortedOptions.selection do
            if not v:IsInCategory('STRUCTURE') then
                validForTemplate = false
                break
            end
            if i == 1 then
                local factions = import('/lua/factions.lua').Factions
                for _, factionData in factions do
                    if v:IsInCategory(factionData.Category) then
                        faction = factionData.Category
                        break
                    end
                end
            elseif not v:IsInCategory(faction) then
                validForTemplate = false
                break
            end
        end
        if validForTemplate then
            controls.extraBtn1:Enable()
            controls.extraBtn1.OnClick = function(self, modifiers)
                Templates.CreateBuildTemplate()
            end
        else
            controls.extraBtn1:Disable()
        end
        Tooltip.AddCheckboxTooltip(controls.extraBtn2, 'construction_pause')
        controls.extraBtn2.OnCheck = function(self, checked)
            --triggerEvent('toggle_pause', sortedOptions.selection, checked)
            SetPaused(sortedOptions.selection, checked)
            --pause(sortedOptions.selection, checked, 'user')
        end
        if pauseEnabled then
            controls.extraBtn2:Enable()
        else
            controls.extraBtn2:Disable()
        end
        controls.extraBtn2:SetCheck(GetIsPaused(sortedOptions.selection),true)
    else
        controls.extraBtn1:Disable()
        controls.extraBtn2:Disable()
    end
end
