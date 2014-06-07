local modPath = '/mods/EM/'

local oldAvatarUpdate = AvatarUpdate

function AvatarUpdate()
    options.gui_scu_manager = 0
    oldAvatarUpdate()

    local buttons = import(modPath .. 'modules/scumanager.lua').buttonGroup
    local showing = false
    if controls.idleEngineers then
        local subCommanders = EntityCategoryFilterDown(categories.SUBCOMMANDER, GetIdleEngineers())
        if table.getsize(subCommanders) > 0 then
            local show = false
            for i, unit in subCommanders do
                if not unit.SCUType then
                    show = true
                    break
                end
            end
            if show then
                buttons:Show()
                buttons.Right:Set(function() return controls.collapseArrow.Right() - 2 end)
                buttons.Top:Set(function() return controls.collapseArrow.Bottom() end)
                showing = true
            end
        end
    end
    if not showing and false then
        buttons:Hide()
    end
end