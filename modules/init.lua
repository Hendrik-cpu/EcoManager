local modPath = '/mods/EM/'

local WAIT_SECONDS = 0.1
local current_tick = 0
local watch_tick = nil
local listeners = {}

local mThread = nil

function currentTick()
	return current_tick
end

local listenersCount = 0
function addListener(callback, wait, option, key, timer)
	if not key then
		key = "k" .. listenersCount
		listenersCount = listenersCount + 1 
	end
	listeners[key] = {callback=callback, wait=wait, option=option, timer=timer, activated = false}

end
function removeListener(key)
	listeners[key] = nil
end

function mainThread()
	local options

	while true do
		for key, l in pairs(listeners) do

			if not l.timer or l.activated then

				local current_second = current_tick * WAIT_SECONDS

				if not options or math.mod(current_tick, 10) == 0 then
					options = import(modPath .. 'modules/utils.lua').getOptions(true)
					--options = import(modPath .. 'modules/prefs.lua').getPrefs()
				end

				if math.mod(current_second*10, l['wait']*10) == 0 and (not l.option or options[l.option] ~= 0) then
					l['callback']()
				end

			else
				if GetGameTimeSeconds() > l.timer then
					l.activated = true
					print(key .. ' thread has automatically been activated by its activation timer!')
				end
			end
		end

		current_tick = current_tick + 1
		WaitSeconds(WAIT_SECONDS)
	end
end

function watchdogThread()
	while true do
		if watch_tick == current_tick then -- main thread has died
			LOG("EM: mainThread crashed! Restarting...")
			if mThread then
				KillThread(mThread)
			end

			mThread = ForkThread(mainThread)
		end

		watch_tick = current_tick

		WaitSeconds(1)
	end
end

function setup(isReplay, parent)
	local mods = {'options','mexes','buildoverlay', 'commands','controlPannel/controlPannel', 'SupremeEconomyEM/resourceusage','SupremeEconomyEM/mexes'}

	if not isReplay then
		table.insert(mods, 'ecocommands');
		table.insert(mods, 'throttler/throttler');
	end

	for _, m in mods do
		import(modPath .. 'modules/' .. m .. '.lua').init(isReplay, parent)
	end
end

function initThreads()
	ForkThread(mainThread)
	ForkThread(watchdogThread)
end

function init(isReplay, parent)
	setup(isReplay, parent)
	ForkThread(initThreads)
end

