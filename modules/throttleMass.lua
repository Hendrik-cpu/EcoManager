local modPath = '/mods/EM/'
local getUnits = import(modPath .. 'modules/units.lua').getUnits
local addListener = import(modPath .. 'modules/init.lua').addListener
local getEconomy = import(modPath ..'modules/economy.lua').getEconomy
local unitsPauseList={}
local excluded = {}
local logEnabled=true
local massStorageThreshold=0.5
local addCommand = import(modPath .. 'modules/commands.lua').addCommand

function init()
	addCommand('mt', setMassStorageThreshold)
	addListener(manageAssistedUpgrade, 6, 'em_mexOpti')
end
function setMassStorageThreshold(value)
	massStorageThreshold=value
	print("Mass throttle: Storage threshold set to", value)
end

function getUnitsPauseList()
	local units={}
	for k, m in unitsPauseList do
		if(m:IsDead()) then
			unitsPauseList[k] = nil
		else
			units[m:GetEntityId()]=m
		end
	end
	return units
end
function ILOG(str)
	if logEnabled then
		LOG(str)
	end
end

function manageAssistedUpgrade()
	ILOG("started")
	local eco = getEconomy()
	-- create table
	local AllUnits={}
	local mexPositions = {}
	for _, u in getUnits() do 
		table.insert(AllUnits,u) 
	end

	local mexes=EntityCategoryFilterDown(categories.MASSEXTRACTION,AllUnits)
	--local storages=EntityCategoryFilterDown(categories.MASSSTORAGE,AllUnits)

	-- map mexes to positions
	for _, m in mexes do
		local pos = m:GetPosition()

		if(not mexPositions[pos[1]]) then
			mexPositions[pos[1]] = {}
		end

		mexPositions[pos[1]][pos[3]] = m
	end


	-- find upgrading mexes
	engineers = EntityCategoryFilterDown(categories.ENGINEER,AllUnits)
	for _, m in mexes do
		if not m:IsIdle() then --and not excluded[m:GetEntityId()] 
			table.insert(engineers,m)
		end
	end

	-- find the mex assisting and grab id from there
	assisting = {}
	for _, e in engineers do
		if not e:IsDead() then 
			local m
			local is_idle = e:IsIdle()
			local focus = e:GetFocus()
			local assist = true

			if(focus) then
				m = focus
			else -- engineer isn't focusing, walking towards mex?
				local queue = e:GetCommandQueue()
				local p = queue[1].position


				
--[[
				LOG(repr(queue))
				LOG(repr(mexPositions))
]]

				if(queue[1].type == 'Guard') then
					if(mexPositions[p[1]] and mexPositions[p[1]][p[3]]) then
						local mex = mexPositions[p[1]][p[3]]
						m = mex:GetFocus()

						if(m and VDist3(p, e:GetPosition()) > 10) then -- 10 -> buildrange of engineer maybe?
							assist = false
						end
					end
				end
			end
			
			if m and (m:IsInCategory("MASSEXTRACTION") or m:IsInCategory("MASSSTORAGE")) and assist then --and not excluded[e:GetEntityId()]
				if not m:IsInCategory("MASSSTORAGE") or  e:GetWorkProgress() > 0.05 then
					if (not assisting[m]) then
						assisting[m] = {}
					end
					table.insert(assisting[m], e)
				end 
			end	
		end
	end

	--gather economical data for sort list
	local assistersExist=false
	local sortTable={}
	local counter=0
	for k, engineers in assisting do
		local combinedBuildRate = 0
		local lastE
		local br
		for _, e in engineers do
			br = e:GetBuildRate()
			if(not br) then
				br = e:GetBlueprint().Economy.BuildRate
			end

			combinedBuildRate = combinedBuildRate + br
			lastE=e
		end

		local bp = k:GetBlueprint()
		
		local massProduction
		if k:IsInCategory("MASSSTORAGE") then
			massProduction=0.75 
		else
			massProduction=bp.Economy.ProductionPerSecondMass
		end

		local workProgress=lastE:GetWorkProgress()
		local buildTimeRemaining=bp.Economy.BuildTime-(workProgress*bp.Economy.BuildTime)
		local timeRemaining=buildTimeRemaining/combinedBuildRate
		local massEfficiency=bp.Economy.BuildCostMass*(1-workProgress)/massProduction
		local energyEfficiency=bp.Economy.BuildCostEnergy*(1-workProgress)/massProduction
		local massTimeEfficiency=massEfficiency+timeRemaining
		local energyTimeEfficiency=energyEfficiency+timeRemaining

		table.insert(sortTable, {unit=k,timeRemaining=timeRemaining,massTimeEfficiency=massTimeEfficiency,energyTimeEfficiency=energyTimeEfficiency})
		assistersExist=true
	end


	-- decide if stuff needs to be paused
	if assistersExist  then
		local options = import(modPath .. 'modules/utils.lua').getOptions(true)
		local massOptions=options['em_mexOpti']
		LOG("user choose the >", massOptions,"< algorithm") 

		local pausedByMe=getUnitsPauseList()
		local pausedByClickOrAssist=import(modPath .. 'modules/throttle.lua').getExcluded()
		
		--time
		if (massOptions== 'optimizeTime' or massOptions == 'auto') then
			table.sort(sortTable, function(a, b) return a['timeRemaining'] < b['timeRemaining'] end)
			optimizeECO(eco, pausedByMe,pausedByClickOrAssist,sortTable, "MASS")			
			

		--mass efficiency for mass cost left
		elseif (massOptions== 'optimizeMass') then
			table.sort(sortTable, function(a, b) return a['massTimeEfficiency'] < b['massTimeEfficiency'] end)
			optimizeECO(eco, pausedByMe,pausedByClickOrAssist,sortTable,"MASS")	

		--energy efficiency for mass cost left
		elseif (massOptions== 'optimizeEnergy') then
			table.sort(sortTable, function(a, b) return a['energyTimeEfficiency'] < b['energyTimeEfficiency'] end)
			optimizeECO(eco, pausedByMe,pausedByClickOrAssist,sortTable,"ENERGY")	

		-- this is an old/atlernative version i might prefer
		elseif massOptions == 'simple' then
				table.sort(sortTable, function(a, b) return a['timeRemaining'] < b['timeRemaining'] end)

				ILOG("using older simple algorithm")
				local unitsUnPauseList={}
				local m0 = sortTable[1]

				local bp=m0.unit:GetBlueprint()

				local netIncome=eco['MASS']['net_income']
				local massStored=eco['MASS']['stored']
				local massCost=bp.Economy.BuildCostMass
				local progress=assisting[m0.unit][1]:GetWorkProgress()
				local massCostRemaining=massCost*(1-progress)

				if massStored<(massCostRemaining) then
					-- create unpause list
					for _, e in assisting[m0.unit] do
						table.insert(unitsUnPauseList, e)
					end

					-- pausing
					unitsPauseList={}
					for i = 2, table.getsize(sortTable) do 
						
						local m = sortTable[i].unit
						for _, e in assisting[m] do
							table.insert(unitsPauseList, e)
						end
					end
					SetPaused(unitsPauseList, true)

					-- unpausing
					SetPaused(unitsUnPauseList, false)
				elseif massStored>(massCostRemaining) and netIncome > 0 then  
				 	SetPaused(unitsPauseList, false)
				 	return
				end
		end
	end

	ILOG("finished")
end

function optimizeECO(eco, pausedByMe,pausedByClickOrAssist,sortTable, resType)
	local unitsUnPauseList={}
	local res=eco[resType]
	local netIncome=res['net_income']
	local resStored=res['stored']
	local resStorageRel=resStored/res['max']

	local lastJ=0
	for j = 1, table.getsize(sortTable) do

		local m0 = sortTable[j]
		local bp=m0.unit:GetBlueprint()
		local resCost
		if resType == "MASS" then
			resCost = bp.Economy.BuildCostMass
		else
			resCost = bp.Economy.BuildCostEnergy
		end 

		local progress=assisting[m0.unit][1]:GetWorkProgress()
		local massCostRemaining=resCost*(1-progress)

		for _, e in assisting[m0.unit] do
			local id = e:GetEntityId()
			if GetIsPaused({e}) then
				if pausedByMe[id] and not pausedByClickOrAssist[id] then
					table.insert(unitsUnPauseList, e)
					ILOG("I paused this engineer",e:GetEntityId(),", unpausing it")
				else
					ILOG("I didn't pause this engineer",e:GetEntityId(),", not gonna unpause it")
				end 
			end
		end

		netIncome=netIncome-(massCostRemaining/m0.timeRemaining/10)
		---ILOG("mass stored:", resStored, "mass cost remaining:", massCostRemaining, "net income:", netIncome, "mass storage relative:", resStorageRel)
		if resStored > massCostRemaining then
			---ILOG("we have enough resources, going to unpause more mexes")
			resStored = resStored - massCostRemaining
		elseif resStored < massCostRemaining and netIncome<0  and resStorageRel < massStorageThreshold then  
			--ILOG("resources are going down, I stop here")
			lastJ=j
			break
		end
		lastJ=j
	end

	--pausing
	local lastUnitsPauseList=unitsPauseList
	unitsPauseList={}

	local size=table.getsize(sortTable)
	if lastJ+1<=size then
		for i = lastJ+1, size do 
			local m = sortTable[i].unit
			for _, e in assisting[m] do
				table.insert(unitsPauseList, e)
			end
		end
	end

	-- check if unit switched focus and needs to be unpaused
	local scheduledForPausingNextCycle=getUnitsPauseList()
	for _, u in lastUnitsPauseList do
		if not scheduledForPausingNextCycle[u:GetEntityId()] then
			LOG("Unit has slipped out of my control, I will unpause")
			table.insert(unitsUnPauseList, u) --This apparently does not work? WHY?
		end
	end
		
	-- execute pausing and unpausing
	SetPaused(unitsPauseList, true)	
	SetPaused(unitsUnPauseList, false)
	
end
