-- globals --
local offset
-- functions --
function dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
end


function Draw2DText(text, x, y)
    local string = CreateVarString(10, "LITERAL_STRING", text)
    SetTextColor(255, 255, 255, 255)
    SetTextFontForCurrentCommand(0)
    SetTextScale(0.3, 0.3)
    SetTextDropshadow(1, 0, 0, 0, 255)
    SetTextCentre(true)
    DisplayText(string, x, y)
end

function getTargetBarrel()
    local pos = GetEntityCoords(PlayerPedId())
    local entityWorld = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 1.0, 0.0)
    local result = GetClosestObjectOfType(entityWorld.x,entityWorld.y,entityWorld.z,1.0,GetHashKey("P_BARREL01AX"),true,false,true)
    if result == 0 then
        result = GetClosestObjectOfType(entityWorld.x,entityWorld.y,entityWorld.z,1.0,GetHashKey("P_BARREL04B"),true,false,true)
    end
    return result
end

function spawnBarrel(pumpjack)
    print("spawnBarrel invoked by "..pumpjack)
    local pumpPos = GetEntityCoords(pumpjack)
    local barrelPos = GetOffsetFromEntityInWorldCoords(pumpjack,0.0,5.0,-0.5)
    local hash = GetHashKey("P_BARREL01AX")
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        RequestModel(hash)
        print("Waiting for model "..hash)
        Citizen.Wait(100)
    end
    if offset ~= nil then
        offset = offset + 1.0
        local rand = math.random(1,2)
        if rand == 1 then
            barrelPos = GetOffsetFromEntityInWorldCoords(pumpjack,offset,5.0,0.0)
        elseif rand == 2 then
            barrelPos = GetOffsetFromEntityInWorldCoords(pumpjack,0.0,5.0 + offset,0.0)
        end
    end
    local barrel = CreateObject(hash,barrelPos.x,barrelPos.y,barrelPos.z,true,false,true)
    PlaceObjectOnGroundProperly(barrel,true)
end

function processOil(barrel, npc, h)
    local unf = barrel
    local time = OilConfig.ProcessTime
    local chance = OilConfig.ProcessChance
    local pos = npc
    local rand = math.random()
    if rand <= chance then
        DeleteEntity(barrel)
        TriggerEvent("redemrp_notification:start", "Your oil is being processed.", 2)
        Citizen.Wait(time)
        TriggerEvent("redemrp_notification:start", "Your oil was lost in processing.", 2)
    else
        DeleteEntity(barrel)
        TriggerEvent("redemrp_notification:start", "Your oil is being processed.", 2)
        Citizen.Wait(time)
        --spawn new barrel--
        local newPos = GetObjectOffsetFromCoords(pos.x,pos.y,pos.z,h,0.0,1.5,1.5)
        local hash = GetHashKey("P_BARREL04B")
        print(newPos)
        RequestModel(hash)
        while not HasModelLoaded(hash) do
            RequestModel(hash)
            print("Waiting for model "..hash)
            Citizen.Wait(100)
        end
        local newBarrel = CreateObject(hash,newPos.x,newPos.y,newPos.z,true,false,true)
        PlaceObjectOnGroundProperly(newBarrel)
        TriggerEvent("redemrp_notification:start", "Your oil has been processed.", 2)
    end
end

function sellOil(barrel)
    DeleteEntity(barrel)
    TriggerServerEvent("fd_oil:SellOil")
end

-- events --
RegisterNetEvent("fd_oil:DowsingForOil")
AddEventHandler("fd_oil:DowsingForOil", function(spots)
    local playerPed = PlayerPedId()
    local playerPos = GetEntityCoords(playerPed)
    local r = OilConfig.Radius
    for k,v in pairs(spots) do
        local distance = Vdist2(playerPos.x,playerPos.y,playerPos.z,v[1].x,v[1].y,v[1].z)
        if distance <= r then
            if v[2] >= 1.5 then
                TriggerEvent("redemrp_notification:start", "You found some oil! It seems pretty rich!", 2)
            else
                TriggerEvent("redemrp_notification:start", "You found some oil! It seems not that rich", 2)
            end
        else
            TriggerEvent("redemrp_notification:start", "You didn't find any oil", 2)
        end
    end
end)

RegisterNetEvent("fd_oil:CheckForOil")
AddEventHandler("fd_oil:CheckForOil", function(result,pumpjack)
    print(result)
    if result[1] == true then
        local pumpPos = GetEntityCoords(pumpjack)
        local richMult = 1/result[2]
        local barrelTime = OilConfig.CollectTime * richMult
        print(barrelTime)
        Citizen.Wait(barrelTime)
        spawnBarrel(pumpjack)
        TriggerServerEvent("fd_oil:CheckForOil",pumpjack,pumpPos)
    else
        TriggerEvent("redemrp_notification:start", "Your well has dried up", 2)
    end
end)
-- Threads --
Citizen.CreateThread(function()
    local sleep = 10
    local playerPed = PlayerPedId()
    local isCarrying = false
    while true do
        local barrel = getTargetBarrel()
        if barrel ~= 0 then
            NetworkRequestControlOfEntity(barrel)
            while not NetworkHasControlOfEntity(barrel) do
                Citizen.Wait(10)
            end
            if IsControlJustPressed(1,0x760A9C6F) then -- pressed g
                print(isCarrying,barrel)
                if not isCarrying then
                    AttachEntityToEntity(barrel,playerPed,GetPedBoneIndex(playerPed,11816), 0.0, 1.0, 0, 0, 0, 0, true, true, false, false, 1, true,true,true)
                    --AttachEntityToEntity(barrel, playerPed, GetPedBoneIndex(playerPed,11816), 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
                    isCarrying = true
                else
                    DetachEntity(barrel,true,true)
                    isCarrying = false
                end
            end
        end
        Citizen.Wait(sleep)
    end
end)

Citizen.CreateThread(function()
    local sleep = 1000
    local processNPCs = OilConfig.ProcessNpcs
    local processPoints = OilConfig.ProcessSpots
    local playerPed = PlayerPedId()
    while true do
        local playerPos = GetEntityCoords(playerPed)
        for i=1, #processNPCs do
            local pos = processNPCs[i][1]
            local heading = processNPCs[i][2]
            local dist = #(playerPos-pos)
            local loadingDock = processPoints[i]
            if dist <= 5.0 then
                sleep = 10
                if dist <= 2.0 then
                    Draw2DText("Press G to Process Oil",0.5,0.85)
                    if IsControlJustPressed(1,0x760A9C6F) then -- pressed g
                        print(loadingDock)
                        local toBeProc = GetClosestObjectOfType(loadingDock.x,loadingDock.y,loadingDock.z,25.0,GetHashKey("P_BARREL01AX"),true,false,true)
                        while toBeProc ~= 0 do
                            print("ToBeProc = ",toBeProc)
                            processOil(toBeProc,pos,heading)
                            Citizen.Wait(sleep)
                            toBeProc = GetClosestObjectOfType(loadingDock.x,loadingDock.y,loadingDock.z,25.0,GetHashKey("P_BARREL01AX"),true,false,true)
                        end
                    end
                end
            end
        end
        Citizen.Wait(sleep)
    end
end)

---- Blips ----
Citizen.CreateThread(function()
        Wait(0)
        for k,v in pairs(OilConfig.ProcessNpcs) do
            local blip = N_0x554d9d53f696d002(1664425300, v[1])
            SetBlipSprite(blip, -272216216, 1)
            SetBlipScale(blip, 0.2)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, "Oil Refinery")
	    end
        for k,v in pairs(OilConfig.SellNpcs) do
            local blip = N_0x554d9d53f696d002(1664425300, v[1])
            SetBlipSprite(blip, -426139257, 1)
            SetBlipScale(blip, 0.2)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, "Oil Export")
        end
end)

Citizen.CreateThread(function()
    local sleep = 1000
    local sellNPCs = OilConfig.SellNpcs
    local sellPoints = OilConfig.SellSpots
    local playerPed = PlayerPedId()
    while true do
        local playerPos = GetEntityCoords(playerPed)
        for i=1, #sellNPCs do
            local pos = sellNPCs[i][1]
            local heading = sellNPCs[i][2]
            local dist = #(playerPos-pos)
            local loadingDock = sellPoints[i]
            if dist <= 5.0 then
                sleep = 10
                if dist <= 1.0 then
                    Draw2DText("Press G to Sell Oil",0.5,0.85)
                    if IsControlJustPressed(1,0x760A9C6F) then -- pressed g
                        print(loadingDock)
                        local toBeSold = GetClosestObjectOfType(loadingDock.x,loadingDock.y,loadingDock.z,25.0,GetHashKey("P_BARREL04B"),true,true,true)
                        while toBeSold ~= 0 do
                            sleep = 3500
                            print("ToBeSold = ",toBeSold)
                            sellOil(toBeSold)
                            Citizen.Wait(sleep)
                            toBeSold = GetClosestObjectOfType(loadingDock.x,loadingDock.y,loadingDock.z,25.0,GetHashKey("P_BARREL04B"),true,true,true)
                        end
                    end
                end
            end
        end
        Citizen.Wait(sleep)
    end
end)

-- Commands --
RegisterCommand("checkForOil", function(src,args,raw)
    local player = PlayerPedId()
    local playerPos = GetEntityCoords(player)
    TriggerServerEvent("fd_oil:DowsingForOil")
end)

RegisterCommand("spawnObj", function(src,args,raw)
    local player = PlayerPedId()
    local spawnPos = GetOffsetFromEntityInWorldCoords(player,0.0,1.0,0.0)
    local obj = GetHashKey(args[1])

    RequestModel(obj)
    while not HasModelLoaded(obj) do
        Wait(0)
    end
    CreateObject(obj,spawnPos.x,spawnPos.y,spawnPos.z,true,false,true)
end)

RegisterNetEvent('ranch:checkForOil')
AddEventHandler('ranch:checkForOil', function()
	local player = PlayerPedId()
    local playerPos = GetEntityCoords(player)
	local playerPed = PlayerPedId()
	TaskStartScenarioInPlace(playerPed, GetHashKey('WORLD_HUMAN_CROUCH_INSPECT'), 10000, true, false, false, false)
    exports['progressBars']:startUI(10000, "Prospecting For Oil")
    Citizen.Wait(10000)
    ClearPedTasksImmediately(PlayerPedId())
    TriggerServerEvent("fd_oil:DowsingForOil")
end)

--PUMP MENU PICK UP--
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(1)
		local x, y, z = table.unpack(GetEntityCoords(PlayerPedId()))
		
		
		local pump = DoesObjectOfTypeExistAtCoords(x, y, z, 1.5, GetHashKey("p_enginefactory01x"), true)
		
		if pump then 
			DrawText("Press G pick up",0.5,0.88)
			if IsControlJustReleased(0, 0x760A9C6F) then -- g
				TriggerEvent("ranch:delOilRig")
			end
		end
	end
end)

--PUMP PLACEMENT--
local prop1 = nil 
RegisterNetEvent('ranch:Oilrig')
AddEventHandler('ranch:Oilrig', function()
local pumpPos = GetOffsetFromEntityInWorldCoords(player,0.0,5.0,0.0)
if pump ~= 0 then
		DeleteObject(pump)
        SetEntityAsMissionEntity(pump)
		TriggerEvent("ranch:delOilRig")		
        pump = 0
    end
    local playerPed = PlayerPedId()
    TaskStartScenarioInPlace(playerPed, GetHashKey('WORLD_HUMAN_CROUCH_INSPECT'), 3000, true, false, false, false)
    exports['progressBars']:startUI(3000, "Placing Rig")
    Citizen.Wait(3000)
    ClearPedTasksImmediately(PlayerPedId())
    local x,y,z = table.unpack(GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 2.0, -1.55))
    prop1 = CreateObject(GetHashKey("p_enginefactory01x"), x, y, z, true, false, true)
    SetEntityHeading(prop1, GetEntityHeading(PlayerPedId()))
    PlaceObjectOnGroundProperly(prop1)
    pump = prop1
	TriggerServerEvent("fd_oil:CheckForOil",pump,pumpPos)
	
end)
--PUMP MENU--
AddEventHandler('ranch:OilRigMenu', function()
local _source = source
		
            local playerPed = PlayerPedId()
			Citizen.Wait(0)
            ClearPedTasksImmediately(PlayerPedId())
			WarMenu.OpenMenu('rig')
            TaskStartScenarioInPlace(playerPed, GetHashKey('WORLD_HUMAN_CROUCH_INSPECT'), -1, true, false, false, false)
       
end)

--PUMP DELETE--
RegisterNetEvent('ranch:delOilRig')
AddEventHandler('ranch:delOilRig', function()
if pump ~= nil then 
DeleteObject(prop1)
end
end)

function DrawText(text,x,y)
    SetTextScale(0.35,0.35)
    SetTextColor(255,255,255,255)--r,g,b,a
    SetTextCentre(true)--true,false
    SetTextDropshadow(1,0,0,0,200)--distance,r,g,b,a
    SetTextFontForCurrentCommand(0)
    DisplayText(CreateVarString(10, "LITERAL_STRING", text), x, y)
end