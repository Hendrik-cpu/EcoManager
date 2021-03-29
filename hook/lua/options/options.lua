table.insert(options.ui.items,
    {
        title = "EM: Show MEX-overlay",
        key = 'em_mexoverlay',
        type = 'toggle',
        default = 1,
        custom = {
            states = {
                {text = "<LOC _Off>", key = 0 },
                {text = "<LOC _On>", key = 1 },
            },
        },
    })

table.insert(options.gameplay.items,
    {
        title = "EM: MEX upgrade-pause",
        key = 'em_mexes',
        type = 'toggle',
        default = 0,
        custom = {
            states = {
                {text = "<LOC _Off>", key = 0 },
                {text = "On click", key = 'click' },
                {text = "Auto", key = 'auto' },
            },
        },
    })
-- table.insert(options.gameplay.items,
--     {
--         title = "EM: Throttle energy",
--         key = 'energy',
--         type = 'toggle',
--         default = 0,
--         custom = {
--             states = {
--                 {text = "<LOC _Off>", key = 0 },
--                 {text = "<LOC _On>", key = 1 },
--                 {text = "Throttle only Mass Fabricators", key = 2 },
--             },
--         },
--     })

-- table.insert(options.gameplay.items,
--     {
--         title = "EM: Throttle mass",
--         key = 'mass',
--         type = 'toggle',
--         default = 0,
--         custom = {
--             states = {
--                 {text = "<LOC _Off>", key = 0 },
--                 {text = "<LOC _On>", key = 1 },
--                 {text = "Throttle only Mass Production", key = 2 },
--             },
--         },
--     })