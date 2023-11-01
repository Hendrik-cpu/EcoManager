local modPath = '/mods/EM/'
local modulesPath = modPath .. 'modules/'
local round = import(modulesPath .. 'math.lua').round

--local getCurrentThrottle = import(modulesPath .. 'throttle.lua').getCurrentThrottle

local oldCreateUI = CreateUI
function CreateUI()
    oldCreateUI()

    for _, t in {'mass', 'energy'} do
        GUI[t].overflow = UIUtil.CreateText(GUI.energy, '', 18, UIUtil.bodyFont)
        GUI[t].overflow:SetDropShadow(true)
    end
end

function unum(n, decimals, unit)
    local units = {"", "k", "m", "g"}
    local pos = 1

    local value = math.abs(n)

    if value > 9999 then
        while value >= 1000 do
            if unit and units[pos] == unit then break end
            value = value / 1000
            pos = pos + 1
        end
    end

    if decimals then
        value = round(value, decimals)
    end

    local str = string.format("%s%g", n < 0 and '-' or '+', value)

    if pos > 1 then
        return str .. units[pos]
    else
        return str
    end
end

--- Build a beat function for updating the UI suitable for the current options.
--
-- The UI must be constructed first.
function ConfigureBeatFunction()
    -- Create an update function for each resource type...

    --- Get a `getRateColour` function.
    --
    -- @param warnFull Should the returned getRateColour function use warning colours for fullness?
    local function getGetRateColour(warnFull)
        local getRateColour
        -- Flags to make things blink.
        local blinkyFlag = true

        if warnFull then
            return function(rateVal, storedVal, maxStorageVal)
                local fractionFull = storedVal / maxStorageVal

                if rateVal < 0 then
                    if storedVal > 0 then
                        return 'yellow'
                    else
                        return 'red'
                    end
                end

                -- Positive rate, check if we're wasting money (and flash irritatingly if so)
                if fractionFull >= 1 then
                    -- Display flashing gray-white if high on resource.
                    blinkyFlag = not blinkyFlag
                    if blinkyFlag then
                        return 'ff404040'
                    else
                        return 'ffffffff'
                    end
                end

                return 'ffb7e75f'
            end
        else
            return function(rateVal, storedVal, maxStorageVal)
                local fractionFull = storedVal / maxStorageVal

                if rateVal < 0 then
                    if storedVal <= 0 then
                        return 'red'
                    end

                    if fractionFull < 0.2 then
                        -- Display flashing gray-white if low on resource.
                        blinkyFlag = not blinkyFlag
                        if blinkyFlag then
                            return 'ff404040'
                        else
                            return 'ffffffff'
                        end
                    end

                    return 'yellow'
                end

                return 'ffb7e75f'
            end
        end
    end

    local function getResourceUpdateFunction(rType, vState, GUI)
        -- Closure copy
        local resourceType = rType
        local viewState = vState

        local storageBar = GUI.storageBar
        local curStorage = GUI.curStorage
        local maxStorage = GUI.maxStorage
        local incomeTxt = GUI.income
        local expenseTxt = GUI.expense
        local rateTxt = GUI.rate
        local warningBG = GUI.warningBG

        local reclaimDelta = GUI.reclaimDelta
        local reclaimTotal = GUI.reclaimTotal

        local overflowTxt = GUI.overflow

        local warnOnResourceFull = resourceType == "MASS"
        local getRateColour = getGetRateColour(warnOnResourceFull)

        local ShowUIWarnings
        if not Prefs.GetOption('econ_warnings') then
            ShowUIWarnings = function() end
        else
            if warnOnResourceFull then
                ShowUIWarnings = function(effVal, storedVal, maxStorageVal)
                    if storedVal / maxStorageVal > 0.8 then
                        if effVal > 2.0 then
                            warningBG:SetToState('red')
                        elseif effVal > 1.0 then
                            warningBG:SetToState('yellow')
                        elseif effVal < 1.0 then
                            warningBG:SetToState('hide')
                        end
                    else
                        warningBG:SetToState('hide')
                    end
                end
            else
                ShowUIWarnings = function(effVal, storedVal, maxStorageVal)
                    if storedVal / maxStorageVal < 0.2 then
                        if effVal < 0.25 then
                            warningBG:SetToState('red')
                        elseif effVal < 0.75 then
                            warningBG:SetToState('yellow')
                        elseif effVal > 1.0 then
                            warningBG:SetToState('hide')
                        end
                    else
                        warningBG:SetToState('hide')
                    end
                end
            end
        end

        -- The quantity of the appropriate resource that had been reclaimed at the end of the last
        -- tick (captured into the returned closure).
        local lastReclaim = 0

        -- Finally, glue all the bits together into a a resource-update function.
        return function()
            local econData = GetEconomyTotals()
            local simFrequency = GetSimTicksPerSecond()

            local totalReclaimed = math.ceil(econData.reclaimed[resourceType])

            -- Reclaimed this tick
            local thisTick = totalReclaimed - lastReclaim

            -- The quantity we'd gain if we reclaimed at this rate for a full second.
            local rate = thisTick * simFrequency

            reclaimDelta:SetText('+'..rate)
            reclaimTotal:SetText(totalReclaimed)

            lastReclaim = totalReclaimed

            -- Extract the economy data from the economy data.
            local maxStorageVal = econData.maxStorage[resourceType]
            local storedVal = econData.stored[resourceType]
            local incomeVal = econData.income[resourceType]

            local average
            if storedVal > 0.5 then
                average = math.min(econData.lastUseActual[resourceType] * simFrequency, 99999999)
            else
                average = math.min(econData.lastUseRequested[resourceType] * simFrequency, 99999999)
            end
            local incomeAvg = math.min(incomeVal * simFrequency, 99999999)

            -- Update the UI
            storageBar:SetRange(0, maxStorageVal)
            storageBar:SetValue(storedVal)
            curStorage:SetText(math.ceil(storedVal))
            maxStorage:SetText(math.ceil(maxStorageVal))

            incomeTxt:SetText(string.format("+%d", math.ceil(incomeAvg)))
            expenseTxt:SetText(string.format("-%d", math.ceil(average)))

            local rateVal = math.ceil(incomeAvg - average)
            local rateStr = string.format('%+d', math.min(math.max(rateVal, -99999999), 99999999))

            local effVal
            if average == 0 then
                effVal = math.ceil(incomeAvg) * 100
            else
                effVal = math.ceil((incomeAvg / average) * 100)
            end

            -- CHOOSE RATE or EFFICIENCY STRING
            if States[viewState] == 2 then
                rateTxt:SetText(string.format("%d%%", math.min(effVal, 100)))
            else
                rateTxt:SetText(string.format("%+s", rateStr))
            end

            rateTxt:SetColor(getRateColour(rateVal, storedVal, maxStorageVal))

            -- if resourceType == 'ENERGY' then
            --     local overflow = -getCurrentThrottle()
            --     if overflow ~= 0 then
            --         local color = overflow < 0 and 'red' or 'ffb7e75f'
            --         overflowTxt:Show()
            --         overflowTxt:SetText(unum(overflow, 1))
            --         overflowTxt:SetColor(color)
            --     else
            --         overflowTxt:Hide()
            --     end
            -- end

            if not UIState then
                return
            end

            ShowUIWarnings(effVal, storedVal, maxStorageVal)
        end
    end

    local massUpdateFunction = getResourceUpdateFunction('MASS', 'massViewState', GUI.mass)
    local energyUpdateFunction = getResourceUpdateFunction('ENERGY', 'energyViewState', GUI.energy)

    _BeatFunction = function()
        massUpdateFunction()
        energyUpdateFunction()
    end
end
