local oldWorldView = WorldView

WorldView = Class(oldWorldView)
{
	DisplayPing = function(self, pingData)
		---------------------------------------------------
		--BEGIN CODE FOR PING SOURCE IDENTIFICATION
		--Duck_42
		---------------------------------------------------
		local function IndicatePingSource(pingOwner)
			--Get the scoreborad object from the appropriate lua file
			local scoreBoardControls = import('/lua/ui/game/score.lua').controls
			local timesToFlash = 8
			local flashInterval = 0.4
			
			if playersPinging[pingOwner + 1] then
				pingLoopsRemaining[pingOwner + 1] = timesToFlash
			else
				pingLoopsRemaining[pingOwner + 1] = timesToFlash
				while pingLoopsRemaining[pingOwner + 1] > 0 do
					for _, line in scoreBoardControls.armyLines do
						--Find the line associated with the ping owner...yes, pingOwner + 1 is correct
						if line.armyID == (pingOwner + 1) then
							--Switch their faction icon on and off 
							line.faction:Hide()
							WaitSeconds(flashInterval)
							line.faction:Show()
							WaitSeconds(flashInterval)
							pingLoopsRemaining[pingOwner + 1] =  pingLoopsRemaining[pingOwner + 1] - 1
						end
					end
				end
				playersPinging[pingOwner + 1] = false
			end
		end
		if not pingData.Marker and not pingData.Renew then
			ForkThread(function() IndicatePingSource(pingData.Owner) end)
		end
		---------------------------------------------------
		--END CODE FOR PING SOURCE IDENTIFICATION
		---------------------------------------------------
		
        if not self:IsHidden() and pingData.Location then
            local coords = self:Project(Vector(pingData.Location[1], pingData.Location[2], pingData.Location[3]))
            if not pingData.Renew then
                local function PingRing(Lifetime)
                    local pingBmp = Bitmap(self, UIUtil.UIFile(pingData.Ring))
                    pingBmp.Left:Set(function() return self.Left() + coords.x - pingBmp.Width() / 2 end)
                    pingBmp.Top:Set(function() return self.Top() + coords.y - pingBmp.Height() / 2 end)
                    pingBmp:SetRenderPass(UIUtil.UIRP_PostGlow)
                    pingBmp:DisableHitTest()
                    pingBmp.Height:Set(0)
                    pingBmp.Width:Set(pingBmp.Height)
                    pingBmp.Time = 0
                    pingBmp.data = pingData
                    pingBmp:SetNeedsFrameUpdate(true)
                    pingBmp.OnFrame = function(ping, deltatime)
                        local camZoomedIn = true
                        if GetCamera(self._cameraName):GetTargetZoom() > ((GetCamera(self._cameraName):GetMaxZoom() - GetCamera(self._cameraName):GetMinZoom()) * .4) then
                            camZoomedIn = false
                        end
                        local coords = self:Project(Vector(ping.data.Location[1], ping.data.Location[2], ping.data.Location[3]))
                        ping.Left:Set(function() return self.Left() + coords.x - ping.Width() / 2 end)
                        ping.Top:Set(function() return self.Top() + coords.y - ping.Height() / 2 end)
                        ping.Height:Set(function() return ((ping.Time / Lifetime) * (self.Height()/4)) end)
                        ping:SetAlpha(math.max((1 - (ping.Time / Lifetime)), 0))
                        if not camZoomedIn then
                            ping.Width:Set(ping.Height)
                            LayoutHelpers.ResetRight(ping)
                            LayoutHelpers.ResetBottom(ping)
                            ping:SetTexture(UIUtil.UIFile(pingData.Ring))
                            ping:Show()
                        else
                            ping:Hide()
                        end
                        ping.Time = ping.Time + deltatime
                        if ping.data.Lifetime and ping.Time > Lifetime then
                            ping:SetNeedsFrameUpdate(false)
                            ping:Destroy()
                        end
                    end
                end
                table.insert(self._pingAnimationThreads, ForkThread(function()
                    local Arrow = false
                    if not self._disableMarkers then
                        Arrow = self:CreateCameraIndicator(self, pingData.Location, pingData.ArrowColor)
                    end
                    for count = 1, pingData.Lifetime do
                        PingRing(1)
                        WaitSeconds(.2)
                        PingRing(1)
                        WaitSeconds(1)
                    end
                    if Arrow then Arrow:Destroy() end
                end))
            end
            
            --If this ping is a marker, create the edit controls for it.
            if not self._disableMarkers and pingData.Marker then
                if not self.Markers then self.Markers = {} end
                if not self.Markers[pingData.Owner] then self.Markers[pingData.Owner] = {} end
                if self.Markers[pingData.Owner][pingData.ID] then
                    return
                end
                local PingGroup = Group(self, 'ping gruop')
                PingGroup.coords = coords
                PingGroup.data = pingData
                PingGroup.Marker = Bitmap(self, UIUtil.UIFile('/game/ping_marker/ping_marker-01.dds'))
                LayoutHelpers.AtCenterIn(PingGroup.Marker, PingGroup)
                PingGroup.Marker.TeamColor = Bitmap(PingGroup.Marker)
                PingGroup.Marker.TeamColor:SetSolidColor(PingGroup.data.Color)
                PingGroup.Marker.TeamColor.Height:Set(12)
                PingGroup.Marker.TeamColor.Width:Set(12)
                PingGroup.Marker.TeamColor.Depth:Set(function() return PingGroup.Marker.Depth() - 1 end)
                LayoutHelpers.AtCenterIn(PingGroup.Marker.TeamColor, PingGroup.Marker)
                
                PingGroup.Marker.HandleEvent = function(marker, event)
                    if event.Type == 'ButtonPress' then
                        if event.Modifiers.Right and event.Modifiers.Ctrl then
                            if PingGroup.data.Owner == GetArmiesTable().focusArmy - 1 or true then
                                local data = {Action = 'delete', ID = PingGroup.data.ID, Owner = PingGroup.data.Owner}
                                Ping.UpdateMarker(data)
                            end
                        elseif event.Modifiers.Left then
                            PingGroup.Marker:DisableHitTest()
                            PingGroup:SetNeedsFrameUpdate(false)
                            marker.drag = Dragger()
                            local moved = false
                            GetCursor():SetTexture(UIUtil.GetCursor('MOVE_WINDOW'))
                            marker.drag.OnMove = function(dragself, x, y)
                                PingGroup.Left:Set(function() return  (x - (PingGroup.Width()/2)) end)
                                PingGroup.Top:Set(function() return  (y - (PingGroup.Marker.Height()/2)) end)
                                moved = true
                                dragself.x = x
                                dragself.y = y
                            end
                            marker.drag.OnRelease = function(dragself)
                                PingGroup:SetNeedsFrameUpdate(true)
                                if moved then
                                    PingGroup.NewPosition = true
                                    ForkThread(function()
                                        WaitSeconds(.1)
                                        local data = {Action = 'move', ID = PingGroup.data.ID, Owner = PingGroup.data.Owner}
                                        data.Location = UnProject(self, Vector2(dragself.x, dragself.y))
                                        for _, v in data.Location do
                                            local var = v
                                            if var != v then
                                                PingGroup.NewPosition = false
                                                return
                                            end
                                        end
                                        Ping.UpdateMarker(data)
                                    end)
                                end
                            end
                            marker.drag.OnCancel = function(dragself)
                                PingGroup:SetNeedsFrameUpdate(true)
                                PingGroup.Marker:EnableHitTest()
                            end
                            PostDragger(self:GetRootFrame(), event.KeyCode, marker.drag)
                            return true
                        end
                    end
                end
                
                PingGroup.BGMid = Bitmap(PingGroup, UIUtil.UIFile('/game/ping-info-panel/bg-mid.dds'))
                LayoutHelpers.AtCenterIn(PingGroup.BGMid, PingGroup, 17)
                PingGroup.BGMid.Depth:Set(function() return PingGroup.Marker.Depth() - 2 end)
                
                PingGroup.Name = UIUtil.CreateText(PingGroup, PingGroup.data.Name, 14, UIUtil.bodyFont)
                PingGroup.Name:DisableHitTest()
                PingGroup.Name:SetDropShadow(true)
                PingGroup.Name:SetColor('ff00cc00')
                LayoutHelpers.AtCenterIn(PingGroup.Name, PingGroup.BGMid)
                
                PingGroup.BGRight = Bitmap(PingGroup, UIUtil.UIFile('/game/ping-info-panel/bg-right.dds'))
                LayoutHelpers.AtVerticalCenterIn(PingGroup.BGRight, PingGroup.BGMid, 1)
                PingGroup.BGRight.Left:Set(function() return math.max(PingGroup.Name.Right(), PingGroup.BGMid.Right()) end)
                PingGroup.BGRight.Depth:Set(PingGroup.BGMid.Depth)
                
                PingGroup.BGLeft = Bitmap(PingGroup, UIUtil.UIFile('/game/ping-info-panel/bg-left.dds'))
                LayoutHelpers.AtVerticalCenterIn(PingGroup.BGLeft, PingGroup.BGMid, 1)
                PingGroup.BGLeft.Right:Set(function() return math.min(PingGroup.Name.Left(), PingGroup.BGMid.Left()) end)
                PingGroup.BGLeft.Depth:Set(PingGroup.BGMid.Depth)
                
                if PingGroup.Name.Width() > PingGroup.BGMid.Width() then
                    PingGroup.StretchLeft = Bitmap(PingGroup, UIUtil.UIFile('/game/ping-info-panel/bg-stretch.dds'))
                    LayoutHelpers.AtVerticalCenterIn(PingGroup.StretchLeft, PingGroup.BGMid, 1)
                    PingGroup.StretchLeft.Left:Set(PingGroup.BGLeft.Right)
                    PingGroup.StretchLeft.Right:Set(PingGroup.BGMid.Left)
                    PingGroup.StretchLeft.Depth:Set(function() return PingGroup.BGMid.Depth() - 1 end)
                    
                    PingGroup.StretchRight = Bitmap(PingGroup, UIUtil.UIFile('/game/ping-info-panel/bg-stretch.dds'))
                    LayoutHelpers.AtVerticalCenterIn(PingGroup.StretchRight, PingGroup.BGMid, 1)
                    PingGroup.StretchRight.Left:Set(PingGroup.BGMid.Right)
                    PingGroup.StretchRight.Right:Set(PingGroup.BGRight.Left)
                    PingGroup.StretchRight.Depth:Set(function() return PingGroup.BGMid.Depth() - 1 end)
                end
                
                PingGroup.Height:Set(5)
                PingGroup.Width:Set(5)
                PingGroup.Left:Set(function() return PingGroup.coords.x - PingGroup.Height() / 2 end)
                PingGroup.Top:Set(function() return PingGroup.coords.y - PingGroup.Width() / 2 end)
                PingGroup:SetNeedsFrameUpdate(true)
                PingGroup.OnFrame = function(pinggrp, deltaTime)
                    pinggrp.coords = self:Project(Vector(PingGroup.data.Location[1], PingGroup.data.Location[2], PingGroup.data.Location[3]))
                    PingGroup.Left:Set(function() return self.Left() + (PingGroup.coords.x - PingGroup.Height() / 2) end)
                    PingGroup.Top:Set(function() return self.Top() + (PingGroup.coords.y - PingGroup.Width() / 2) end)    
                    if pinggrp.NewPosition then
                        pinggrp:Hide()
                        pinggrp.Marker:Hide()
                        pinggrp.Name:Hide()
                    else
                        if pinggrp.Top() < self.Top() or pinggrp.Left() < self.Left() or pinggrp.Right() > self.Right() or pinggrp.Bottom() > self.Bottom() then
                            pinggrp:Hide()
                            pinggrp.Name:Hide()
                            pinggrp.Marker:Hide()
                        else
                            if self.PingVis then
                                pinggrp:Show()
                            end
                            pinggrp.Name:Show()
                            pinggrp.Marker:Show()
                        end
                    end
                end
                PingGroup:Hide()
                PingGroup:DisableHitTest()
                PingGroup.Marker:DisableHitTest()
                self.Markers[pingData.Owner][pingData.ID] = PingGroup
            end
        end
    end,
    
}
