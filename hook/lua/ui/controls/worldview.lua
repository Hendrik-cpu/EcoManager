local oldWorldView = WorldView
local oldDisplayPing = WorldView.DisplayPing

WorldView = Class(oldWorldView)
{
	DisplayPing = function(self, pingData)
		oldDisplayPing(self, pingData)

		local PingGroup = self.Markers[pingData.Owner][pingData.ID]

		if(PingGroup) then
			local oldEvent = PingGroup.Marker.HandleEvent
			PingGroup.Marker.HandleEvent = function(marker, event)
				oldEvent(marker, event)
            	
            	if event.Type == 'ButtonPress' then
            		if(PingGroup.data.Owner ~= GetArmiesTable().focusArmy - 1) then -- not owner, do it anyway
                		if event.Modifiers.Right and event.Modifiers.Ctrl then
							local data = {Action = 'delete', ID = PingGroup.data.ID, Owner = PingGroup.data.Owner}
							Ping.UpdateMarker(data)
						end
					end
				end
			end
		end
	end
}
