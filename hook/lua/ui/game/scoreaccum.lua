local originalUpdateScoreData = UpdateScoreData
local modFolder = 'EM/SupremeEconomyEM'

function UpdateScoreData(newData) 
  originalUpdateScoreData(newData)
  
  import('/mods/' .. modFolder .. '/mciscore.lua').UpdateScoreData(newData)
end
