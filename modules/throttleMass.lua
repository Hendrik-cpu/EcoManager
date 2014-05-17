local modPath = '/mods/EM/'
local getUnits = import(modPath .. 'modules/units.lua').getUnits
local addListener = import(modPath .. 'modules/init.lua').addListener
local getEconomy = import(modPath ..'modules/economy.lua').getEconomy
local unitsPauseList={}
local excluded = {}
local logEnabled=false
local massStorageThreshold=0
local massInvestmentMultiplier=1
local minNetIncome=0
local addCommand = import(modPath .. 'modules/commands.lua').addCommand
local Pause = import(modPath .. 'modules/pause.lua').Pause
local CanUnpause = import(modPath .. 'modules/pause.lua').CanUnpause

function init()
	addCommand('mt', setMassStorageThreshold)
	addListener(manageAssistedUpgrade, 0.6, 'em_mexOpti')
end
function SetPaused(units, state)
	Pause(units, state, 'throttlemass')
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
function setMassStorageThreshold(args)
	local str = string.lower(args[2])
	massStorageThreshold=tonumber(str)/100
	print("Mass throttle: Storage threshold set to" , massStorageThreshold)
end
function ILOG(str)
	if logEnabled then
		LOG(str)
	end
end

local mexCappedMsgPrinted=false
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

	-- map mexes to positions
	for _, m in mexes do
		local pos = m:GetPosition()
		if(not mexPositions[pos[1]]) then
			mexPositions[pos[1]] = {}
		end

		mexPositions[pos[1]][pos[3]] = m
	end


	-- find upgrading mexes, check if eco is capped
	local AllMEXT3Capped=false
	if table.getsize(mexes)>0 then 
		AllMEXT3Capped=true
	end

	engineers = EntityCategoryFilterDown(categories.ENGINEER,AllUnits)
	for _, m in mexes do
		if not m:IsIdle() then --and not excluded[m:GetEntityId()] 
			table.insert(engineers,m)
		end

		local data=m:GetEconData()
		if data['massProduced']~=27 then
			AllMEXT3Capped =false
		end

	end

	if AllMEXT3Capped and not mexCappedMsgPrinted then
		local minutes=math.floor(GetGameTimeSeconds()/60)
		print("All Mexes upgraded to t3 and capped at", minutes .. ":" .. GetGameTimeSeconds()-minutes*60)
		mexCappedMsgPrinted=true
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
	local combinedMassDrain=0
	for k, engineers in assisting do
		local combinedBuildRate = 0
		local lastE
		local br
		for _, e in engineers do
			br = e:GetBuildRate()
			if(not br) then
				br = e:GetBlueprint().Economy.BuildRate
			end

			local eco=e:GetEconData()
			combinedMassDrain = combinedMassDrain + eco['massRequested']
			combinedBuildRate = combinedBuildRate + br
			lastE=e
		end

		local bp = k:GetBlueprint()
		
		local massProduction
		if k:IsInCategory("MASSSTORAGE") then
			massProduction=0.88 
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
		ILOG("user choose the >", massOptions,"< algorithm") 

		local pausedByMe=getUnitsPauseList()
		local pausedByMeForPower=getUnitsPauseList()
		--local pausedByClickOrAssist=import(modPath .. 'modules/throttle.lua').getExcluded()
		local pausedByClickOrAssist = {}
		
		--energy efficiency for mass cost left
		if (massOptions== 'optimizeEnergy') then
			table.sort(sortTable, function(a, b) return a['massTimeEfficiency'] < b['massTimeEfficiency'] end)
			optimizeECO(eco, pausedByMe,pausedByClickOrAssist,sortTable,combinedMassDrain)	
		end

	end

	ILOG("finished")
end

local AdditionalOrders=0
function optimizeECO(eco, pausedByMe,pausedByClickOrAssist,sortTable,mProdMassDrain)
	local unitsUnPauseList={}
	local resM=eco["MASS"]
	local massNetIncome=(resM['income'] - eco['MASS']['use_requested'])*GetSimTicksPerSecond()+mProdMassDrain
	local massStorageMax=resM['max']
	local originalMassStored=resM['stored']-massStorageMax*massStorageThreshold
	local massStorageRel=originalMassStored/massStorageMax
	local resE=eco["ENERGY"]
	local powerNetIncome=resE['net_income']*GetSimTicksPerSecond()
	local powerStored=resE['stored']
	local powerStoredRel=powerStored/resE['max']
	
	local lastJ=0
	local StallingOnPower=false

	local OrdersCount=table.getsize(sortTable)
	local massStored=originalMassStored
	for j = 1, OrdersCount do

		local m0 = sortTable[j]
		local bp=m0.unit:GetBlueprint()
		local massCost=bp.Economy.BuildCostMass
		local powerCost=bp.Economy.BuildCostEnergy

		local progress=assisting[m0.unit][1]:GetWorkProgress()
		
		local massCostRemaining=massCost*(1-progress)
		local energyCostRemaining=powerCost*(1-progress)

		LOG("j " .. j .. " mexID " .. m0.unit:GetEntityId())

		for _, e in assisting[m0.unit] do
			local id = e:GetEntityId()
			if GetIsPaused({e}) then
				if pausedByMe[id] and CanUnpause(e) then
					table.insert(unitsUnPauseList, e)
					ILOG("I paused this engineer",e:GetEntityId(),", unpausing it")
				else
					ILOG("I didn't pause this engineer",e:GetEntityId(),", not gonna unpause it")
				end 
			end
		end

		--print ("massStored:", massStored, "massCostRemaining:",massCostRemaining,"massNetIncome:",massNetIncome, "StallingOnPower:",StallingOnPower, "drain:",massCostRemaining/m0.timeRemaining)
		massNetIncome=massNetIncome-(massCostRemaining/m0.timeRemaining)	
		powerNetIncome=powerNetIncome-(energyCostRemaining/m0.timeRemaining)

		massStored=massStored-massCostRemaining
		StallingOnPower=powerStored<(powerNetIncome*2*-1) or powerStored<100

		LOG(repr(eco['MASS']))
		LOG("massNetIncome " .. massNetIncome .. " massStored " .. massStored .. " massCostRemaining " .. massCostRemaining)

		--break if stalling mass or energy

		if massStored > massCostRemaining then
			---ILOG("we have enough resources, going to unpause more mexes")
			massStored = massStored - massCostRemaining
			LOG("stored > cost unpausing")
		elseif (massStored < massCostRemaining and massNetIncome<0) or StallingOnPower then
			LOG("massStored < massCost and massNetIncome < 0, lastJ=j where j is " .. j)
			lastJ=j
			break
		end
		lastJ=j
	end


	LOG("originalMassStored < 500: " .. originalMassStored)
	if lastJ > 1 and originalMassStored < 500 then
		lastJ=lastJ-1
		LOG("TRUE .. lastJ is now " .. lastJ)
	end
	


--[[
	--add additional upgrade orders if threshold has not been reached last cycle - if energy is not the problem
	local orgNetMassIncome=resM['net_income']*GetSimTicksPerSecond()
	--print (originalMassStored,orgNetMassIncome, (originalMassStored/orgNetMassIncome*-1))
	if (originalMassStored/orgNetMassIncome*-1)<3 then --threshold hardcoded 
		AdditionalOrders=0
	else
		AdditionalOrders=AdditionalOrders+1
	end
	]]

	-- local AddOrders=AdditionalOrders--math.floor(AdditionalOrders/3)
	-- if not StallingOnPower then
	-- 	if lastJ+AddOrders>OrdersCount then
	-- 		lastJ=OrdersCount
	-- 	else 
	-- 		lastJ=lastJ+AddOrders
	-- 	end
	-- end

	--keep min % in store if enabled
	 if resM['stored']/massStorageMax<massStorageThreshold then
	 	lastJ=0
	 end

	--pausing
	local lastUnitsPauseList=unitsPauseList
	unitsPauseList={}

	LOG("and now lastJ is " .. lastJ)
	local size=table.getsize(sortTable)
	if lastJ+1<=size then
		for i = lastJ+1, size do 
			local m = sortTable[i].unit
			LOG("PAUSING " .. m:GetEntityId())
			for _, e in assisting[m] do
				table.insert(unitsPauseList, e)
			end
		end
	end

	-- check if unit switched focus and needs to be unpaused
	local scheduledForPausingNextCycle=getUnitsPauseList()
	for _, u in lastUnitsPauseList do
		local id = u:GetEntityId()
		if not scheduledForPausingNextCycle[id] then
			--LOG("Unit has slipped out of my control, I will unpause")
			if pausedByMe[id] and CanUnpause(u) then
				
				table.insert(unitsUnPauseList, u) --This apparently does not work? WHY?
			end
		end
	end
		
	-- execute pausing and unpausing
	SetPaused(unitsPauseList, true)	
	SetPaused(unitsUnPauseList, false)
	
end