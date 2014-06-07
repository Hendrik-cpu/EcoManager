local modPath = '/mods/EM/'

local addListener = import(modPath .. 'modules/init.lua').addListener
local getUnits = import(modPath .. 'modules/units.lua').getUnits
local getAssisting = import(modPath .. 'modules/units.lua').getAssisting
local econData = import(modPath .. 'modules/units.lua').econData

local RegisterChatFunc = import('/lua/ui/game/gamemain.lua').RegisterChatFunc
local FindClients = import('/lua/ui/game/chat.lua').FindClients
local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local ItemList = import('/lua/maui/itemlist.lua').ItemList
local Group = import('/lua/maui/group.lua').Group
local UIUtil = import('/lua/ui/uiutil.lua')

local channel = 'Overlay'

local msgProtocol = {'id', 'progress', 'eta', 'eff', 'silo', 'x', 'y', 'z'}

local overlays = {}

function effColor(eff)
	local color

	if(eff == 1) then
		color = 'white'
	else	
		r = math.min(510-eff*255, 255)
		g = math.min(eff*255, 255)
		b = 0

		color = 'ff'..string.format("%02x%02x%02x", r, g, b)
	end

	return color
end

function round(num, idp)
	if(not idp) then
		return tonumber(string.format("%." .. (idp or 0) .. "f", num))
	else
  		local mult = 10^(idp or 0)
		return math.floor(num * mult + 0.5) / mult
  	end
end

function getConstructions()
	--local units = getUnits()
	local units = getUnits()
	local array = {mr='massRequested', mc='massConsumed', er='energyRequested', ec='energyConsumed'}
	local cs = {}

	for _, u in units do
		local focus = nil
		--[[
		local focus = u:GetFocus()

		if(not focus and u:GetWorkProgress() > 0) then
			-- XXX: add support for enhancements
			focus = u
		end

		if(EntityCategoryContains(categories.SILO * (categories.ANTIMISSILE + categories.NUKE), u)) then -- always overlay on nukes
			focus = u
		end
		]]
		if(u:IsInCategory('COMMAND') and not u:GetFocus() and u:GetWorkProgress() > 0) then
			local queue = u:GetCommandQueue()

			if(queue[1] and queue[1].type == 'Script') then -- Enhancement
				focus = u
			end
		elseif(EntityCategoryContains(categories.SILO * (categories.ANTIMISSILE + categories.NUKE), u)) then -- always overlay on nukes
			focus = u
		end

		if(focus) then
			local id = focus:GetEntityId()
			--local econData = econData(u)


			if(not cs[id]) then
				cs[id] = {unit=focus, assisters={}, progress=0, current={}, total={}}

				for k,v in array do
					cs[id]['current'][k] = 0
					cs[id]['total'][k] = 0
				end
			end

			if(u:GetWorkProgress() > 0) then
				local econData = u:GetEconData()
				table.insert(cs[id]['assisters'], u)
				cs[id]['progress'] = math.max(cs[id]['progress'], u:GetWorkProgress())

				for k,v in array do
					if(econData[v]) then
						cs[id]['current'][k] = cs[id]['current'][k] + econData[v]
						cs[id]['total'][k] = cs[id]['total'][k] + econData[v]
					end
				end
			end
		end
	end

	return cs
end

--function createBuildtimeOverlay(unit, buildtime)

function createBuildtimeOverlay(data)
	local worldView = import('/lua/ui/game/worldview.lua').viewLeft
	local overlay = Bitmap(worldView)

	overlay.id = data.id

	--overlay.data = data

	--overlay:SetSolidColor('99000000')
	--overlay:SetSolidColor('66000000')
	overlay.Width:Set(28)
	overlay.Height:Set(32)
	overlay:SetNeedsFrameUpdate(true)
	overlay.OnFrame = function(self, delta)
		local data = overlays[overlay.id]

		if(not data) then
			overlay:Destroy()
			print "destroy"
		else
			local pos

			if(data.eta and math.mod(GameTick(), 5) == 0) then
				overlay.eta:SetText(formatBuildtime(math.max(0, data.eta-GetGameTimeSeconds())))
			end

			if(data.unit and false) then
				pos = data.unit:GetPosition()
			else 
				pos = data.pos
			end

			pos = worldView:Project(pos) 
			LayoutHelpers.AtLeftTopIn(overlay, worldView, pos.x - overlay.Width() / 2, pos.y - overlay.Height() / 2 + 1)
		end
	end

	overlay.eta = UIUtil.CreateText(overlay, '?:??', 10, UIUtil.bodyFont)
	overlay.eta:SetColor('white')
    overlay.eta:SetDropShadow(true)
	LayoutHelpers.AtCenterIn(overlay.eta, overlay, -9, 0)

	overlay.progress = UIUtil.CreateText(overlay, '0%', 9, UIUtil.bodyFont)
	overlay.progress:SetColor('white')
    overlay.progress:SetDropShadow(true)
	LayoutHelpers.AtCenterIn(overlay.progress, overlay, 10, 0)
	
    overlay.silo = Bitmap(overlay)
    overlay.silo:SetSolidColor('black')
	overlay.silo.Width:Set(12)
	overlay.silo.Height:Set(12)

	overlay.silo.text = UIUtil.CreateText(overlay.silo, '0', 11, UIUtil.bodyFont)
	overlay.silo.text:SetColor('red')
    overlay.silo.text:SetDropShadow(true)

	LayoutHelpers.AtCenterIn(overlay.silo, overlay, 0, 0)
	LayoutHelpers.AtCenterIn(overlay.silo.text, overlay.silo, 0, 0)

	return overlay
end

function mod(a, b)
	return a - math.floor(a/b)*b
end

function formatBuildtime(buildtime)
	return string.format("%.2d:%.2d", buildtime/60, mod(buildtime, 60))
end

function updateBuildtimeOverlay(data)
	local id = data.id

	if not overlays[id] then
		overlays[id] = data
		overlays[id]['bitmap'] = createBuildtimeOverlay(data) 
		overlays[id]['last_tick'] = GameTick()
		overlays[id]['last_progress'] = data['progress']
	end

	for k,v in data do
		overlays[id][k] = v
	end
	
	local bitmap = overlays[id]['bitmap']

	if(data.eta >= 0) then
		bitmap.eta:Show()
		--bitmap.eta:SetText(formatBuildtime(data.eta-GetGameTimeSeconds()))
	else
		bitmap.eta:Hide()
	end

	if(data.progress >= 0) then
		bitmap.progress:Show()
		bitmap.progress:SetText(math.floor(data.progress*100) .. "%")
	else
		bitmap.progress:Hide()
	end

	if(data.silo >= 0) then
		bitmap.silo:Show()
		bitmap.silo.text:SetText(data.silo)
		if(data.silo > 0) then
			bitmap.silo.text:SetColor('green')
		else 
			bitmap.silo.text:SetColor('red')
		end
	else 
		bitmap.silo:Hide()
	end

	if(data.eff >= 0) then
		local color = effColor(data.eff)
		bitmap.progress:SetColor(color)
		bitmap.eta:SetColor(color)
	end

	overlays[id]['last_update'] = GetSystemTimeSeconds()
end

function calcEff(data)
	return math.min(1, math.min(data.mc / data.mr, data.ec / data.er))
end

function checkConstructions()
	local constructions = getConstructions()
	
	for _, c in constructions do
		local u = c['unit']
		local id = u:GetEntityId()
		local bp = u:GetBlueprint()
		local send_msg = false
		local progress = -1
		local eta = -1
		local silo = -1
		local eff = -1
		
		if(table.getsize(c['assisters']) > 0) then
			local tick = GameTick()
			local last_tick
			local last_progress

			progress = 0
			for _, e in c['assisters'] do
				progress = math.max(progress, e:GetWorkProgress())
			end

			if(overlays[id]) then
				last_tick = overlays[id]['last_tick']
				last_progress = overlays[id]['last_progress']

				if(progress > last_progress) then
					eta = math.ceil(GetGameTimeSeconds() + ((tick - last_tick) / 10) * ((1 - progress) / (progress - last_progress)))
				else 
					eta = -1
				end

				overlays[id]['last_tick'] = tick
				overlays[id]['last_progress'] = progress
			end
		end			

		if(EntityCategoryContains(categories.SILO * (categories.ANTIMISSILE + categories.NUKE), u)) then
			local info = u:GetMissileInfo()
			silo = info.nukeSiloStorageCount + info.tacticalSiloStorageCount
			send_msg = true
		end

		if(u:IsInCategory('COMMAND') and not u:GetFocus() and u:GetWorkProgress() > 0) then
			send_msg = true
		end

		if(progress > 0) then
			eff = calcEff(c.current)
		end
	
		local data = {id=u:GetEntityId(), unit=u, pos=u:GetPosition(), eta=eta, progress=progress, silo=silo, eff=eff}
		
		updateBuildtimeOverlay(data)
		if(send_msg) then
			sendOverlayMsg(data)
		end
	end

	for id, o in overlays do -- clean overlays
		if(tonumber(id) >= 0) then
			if(not constructions[id]) then
				o['bitmap']:Destroy()
				overlays[id] = nil
			end
		else
			if(GetSystemTimeSeconds() - o['last_update'] > 2 or o['eta'] == 0) then
				o['bitmap']:Destroy()
				overlays[id] = nil
			end
		end
	end

end

function sendOverlayMsg(data)
	text = ""
	for _, v in {'x', 'y', 'z'} do
		data[v] = data['pos'][v]
	end

	for _, v in msgProtocol do
		local d = data[v]
		
		text = text .. d .. ' '
	end

	msg = { to = 'allies', Overlay = true, text = text}
	SessionSendChatMessage(FindClients(), msg)
end

function processOverlayMsg(player, msg)
	local armies = GetArmiesTable()
	local data = {}
	local me = GetFocusArmy()

	if(GetArmiesTable().armiesTable[me].nickname == player) then
		return 
	end

	i = 1
	for v in string.gfind(msg.text, "%S+") do
		v = tonumber(v)
		
		if(msgProtocol[i]) then
			data[msgProtocol[i]] = v
		end

		i = i + 1
	end

	data['id'] = player .. data['id']
	data['pos'] = Vector(data.x, data.y, data.z)
	data['x'] = nil
	data['y'] = nil
	data['z'] = nil

	ForkThread(function() 
		updateBuildtimeOverlay(data)
	end)
end

function init()
	addListener(checkConstructions, 0.8)
	RegisterChatFunc(processOverlayMsg, 'Overlay')
end