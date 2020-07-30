-- globals --
local currentSpots = {}

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

function round(x, decimals)
    local n = 10^(decimals or 0)
    x = x * n
    if x >= 0 then x = math.floor(x + 0.5) else x = math.ceil(x - 0.5) end
    return x / n
end

function spawnOil()
    local randomNums = {}
    -- flush table --
    for k in pairs(currentSpots) do
        currentSpots[k] = nil
    end
    -- generate new spots --
    for i=1, OilConfig.ActiveSpots do
        local rand = math.random(1,#OilConfig.Spots)
        currentSpots[i] = {OilConfig.Spots[rand],math.random() + math.random(0,2)}
    end
    -- clear duplicate spots --
    for i=1, #currentSpots do
        for j=2, #currentSpots do
            if currentSpots[i][1] == currentSpots[j][1] then
                currentSpots[j][1] = OilConfig.Spots[math.random(1,#OilConfig.Spots)]
            end
        end
    end
    for i=1, #currentSpots do
        print(currentSpots[i][1],currentSpots[i][2])
    end
end

-- events --
RegisterServerEvent("fd_oil:CheckForOil")
AddEventHandler("fd_oil:CheckForOil", function(pumpjack,pumpPos)
    math.randomseed(os.time())
    print("callback received")
    local src = source
    local srcPos = pumpPos
    local r = OilConfig.Radius
    local bool = false
    local richness
    for k,v in ipairs(currentSpots) do
        local distance = #(srcPos-v[1])
        print(distance)
        if distance <= r then
            bool = true
            richness = v[2]
        end
    end
    print(src,bool,richness,pumpjack)
    TriggerClientEvent("fd_oil:CheckForOil",src,{bool,richness},pumpjack)
end)

RegisterServerEvent("RegisterUsableItem:dowsing_rod")
AddEventHandler("RegisterUsableItem:dowsing_rod", function()
    local src = source
    TriggerClientEvent("fd_oil:DowsingForOil",src,currentSpots)
end)

RegisterServerEvent("fd_oil:DowsingForOil")
AddEventHandler("fd_oil:DowsingForOil", function()
    local src = source
    TriggerClientEvent("fd_oil:DowsingForOil",src,currentSpots)
end)

RegisterServerEvent("fd_oil:SellOil")
AddEventHandler("fd_oil:SellOil", function()
    print("sellOil triggered")
    local src = source
    local payout = math.random(OilConfig.Price[1],OilConfig.Price[2]) + math.random()
    local roundPay = round(payout,2)
    TriggerEvent("redemrp:getPlayerFromdId",src,function(user)
        user.addMoney(roundPay)
    end)
end)

-- Threads --
Citizen.CreateThread(function()
    while true do
        spawnOil()
        Citizen.Wait(OilConfig.ActiveTimer) -- Resets oil spots based on config definition
    end
end)

