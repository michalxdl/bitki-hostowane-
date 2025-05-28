ESX = exports["es_extended"]:getSharedObject()

local BitkaID = 1
local Bitki = {}
local inSpheres = {}
local buckety = {}
local cantStart = {}
local cacheVehicles = {}
local PlayersSearching = {}
for i=1, #Config.Zones, 1 do
    inSpheres[i] = {}
end
for i = 1, 25000 do
    SetRoutingBucketPopulationEnabled(i, false)
end

local QUEUE = {
    looting = {},
    noLooting = {}
}

RegisterServerEvent('michalxdl-arenki:enter', function(zoneId)
    local bag = Player(source).state
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        local job = xPlayer.job
        if bag.customORG and bag.customORG.name then
            job = {name = bag.customORG.name, grade = 0, label = bag.customORG.label}
        end
        if not job.name:find("org") then return end 

        inSpheres[zoneId][source] = {
            source = source,
            job = job,
        }

        -- Assign the player to a unique routing bucket based on their organization
        local bucket = tonumber(job.name:match("%d+")) or source -- Fallback to source ID if no number in org name
        SetPlayerRoutingBucket(source, bucket)
        if GetPedInVehicleSeat(GetVehiclePedIsIn(GetPlayerPed(source)), -1) == GetPlayerPed(source) then
            SetEntityRoutingBucket(GetVehiclePedIsIn(GetPlayerPed(source)), bucket)
        end
    end
end)

RegisterServerEvent('michalxdl-arenki:exit', function(zoneId)
    if zoneId and inSpheres[zoneId] then
        inSpheres[zoneId][source] = nil
    end
    PlayersSearching[source] = nil

    -- Reset the player's routing bucket to the default (0)
    if Player(source).state.inBitka == nil then
        if GetPlayerRoutingBucket(source) ~= 0 then
            SetPlayerRoutingBucket(source, 0)
            if GetPedInVehicleSeat(GetVehiclePedIsIn(GetPlayerPed(source)), -1) == GetPlayerPed(source) then
                SetEntityRoutingBucket(GetVehiclePedIsIn(GetPlayerPed(source)), 0)
            end
        end
    end
end)


AddEventHandler('playerDropped', function()
    local src = source
    local zone = Player(src).state.currentSphere
    PlayersSearching[src] = nil
    if zone then
        inSpheres[zone][src] = nil
    end
end)

RegisterCommand('slotleave', function(source, args, RawCommand)
    if Player(source).state.customORG then
        if cantStart[Player(source).state.customORG.name] then
            return
        end
    end
    Player(source).state:set("customORG", false, true)
    local xPlayer = ESX.GetPlayerFromId(source)
    local job = xPlayer.job
    local zoneId = Player(source).state.currentSphere
    if not zoneId then return end
    inSpheres[zoneId][source] = nil
    if not job.name:find("org") then return end 
    inSpheres[zoneId][source] = {
        source = source,
        job = job,
    }
end, false)

RegisterServerEvent("michalxdl-arenki:joinkurwa")
AddEventHandler("michalxdl-arenki:joinkurwa", function(org)
    local sPlayer = ESX.GetPlayerFromId(source)
    if cantStart[org.name] then
        return
    end
    Player(source).state:set("customORG", org, true)
    PlayersSearching[source] = nil
    if Player(source).state.currentSphere then
        inSpheres[Player(source).state.currentSphere][source] = {
            source = source,
            job = org,
        }
    end
    sPlayer.showNotification("/slotleave aby opuścić nie swoją ekipę")
end)

RegisterServerEvent("michalxdl-arenki:inviteNewPlayer")
AddEventHandler("michalxdl-arenki:inviteNewPlayer", function(target, skin)
    local source = source
    if not GetPlayerName(target) then return end
    if Player(target).state.inBitka then return end
    local sPlayer = ESX.GetPlayerFromId(source)
    if not string.find(sPlayer.job.name, "org") then return end
    if cantStart[sPlayer.job.name] then
        return
    end
    if source == target then return end
    sPlayer.showNotification("Zaprosiłeś do bitki: ["..target.."]")
    TriggerClientEvent('michalxdl-arenki:showInvite', target, source, GetPlayerName(source), {name = sPlayer.job.name, grade = 0, label = sPlayer.job.label}, skin)
end)

RegisterServerEvent("michalxdl-arenki:kickPlayer")
AddEventHandler("michalxdl-arenki:kickPlayer", function(target)
    local source = source
    if not GetPlayerName(target) then return end
    local sPlayer = ESX.GetPlayerFromId(source)
    local tPlayer = ESX.GetPlayerFromId(target)
    local bag = Player(target).state
    if bag.inBitka then 
        sPlayer.showNotification("Osoba jest w trakcie bitki.")
        return 
    end
    if not bag.customORG then return end
    if sPlayer.job.name == bag.customORG.name then
        if cantStart[sPlayer.job.name] then
            return
        end
        Player(target).state:set("customORG", nil, true)
        tPlayer.showNotification("Zostałeś wyrzucony z bitki przez: ["..source.."] "..sPlayer.job.name)
        sPlayer.showNotification("Wyrzuciłeś z bitki: ["..target.."]")
        if string.find(tPlayer.job.name, "org") then
            inSpheres[Player(target).state.currentSphere][target] = {
                source = target,
                job = tPlayer.job,
            }
        else
            inSpheres[Player(target).state.currentSphere][target] = nil
        end
    end
end)

ESX.RegisterServerCallback('michalxdl-arenki:getPlayers', function(source, cb, zoneId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if QUEUE.looting[xPlayer.job.name] or QUEUE.noLooting[xPlayer.job.name] then
        cb(nil)
    end
    if cantStart[xPlayer.job.name] then
        TriggerClientEvent('michalxdl-arenki:pedaljuzszuka', source, info)
        cb()
    end
    if not inSpheres[zoneId] then
        inSpheres[zoneId] = {}
    end
    local data = {
        players = {}
    }
    for key, value in pairs(inSpheres) do
        for _, player in pairs(value) do
            local bag = Player(player.source).state
            if bag.customORG and bag.customORG.name then
                if bag.currentSphere == key and (bag.customORG.name == xPlayer.job.name) and not bag.inBitka and not bag.dead then
                    data.players[player.source] = {
                        label = "["..player.source.."] [SPOZA ORG] "..GetPlayerName(player.source),
                        id = player.source,
                        grade = player.job.grade,
                    }
                end
            else
                if bag.currentSphere == key and (player.job.name == xPlayer.job.name) and not bag.inBitka and not bag.dead then
                    data.players[player.source] = {
                        label = "["..player.source.."] "..GetPlayerName(player.source),
                        id = player.source,
                        grade = player.job.grade,
                    }
                end
            end
        end
    end

    data.searchPlayers = PlayersSearching
    
    cb(data)
end)

local function GenerateMatch(t, zone)
    local team1 = nil
    local team2 = nil
    local tick = 0
    for k, v in pairs(QUEUE[t]) do
        Wait(100)
        tick += 1
        if not team1 then
            team1 = {k, v}
        elseif not team2 and k ~= team1[1] and v.job ~= team1[2].job then
            team2 = {k, v}
        end
        if tick >= 2 then
            break
        end
        if team1 and team2 then
            break
        end
    end
    if team1 and team2 then
        if QUEUE[t][team1[1]] and QUEUE[t][team2[1]] then
            QUEUE[t][team1[1]] = nil
            QUEUE[t][team2[1]] = nil
            Citizen.CreateThread(function ()
                startBitka(team1, team2, t, zone)
            end)
        end
    end
end

Citizen.CreateThread(function ()
    while true do
        Wait(3000)
        for k, v in pairs(QUEUE) do
            GenerateMatch(k)
        end
    end
end)

RegisterCommand("wojna", function(source, args)
    local allow = false
    local xPlayer
    if source == 0 then
        allow = true
    else
        xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer.group == "owner" or xPlayer.group == "manager" then
            allow = true
        end
    end
    if allow then
        if args[1] and args[2] then
            local data = {}
            for _, player in pairs(inSpheres[1]) do
                local bag = Player(player.source).state
                if bag.currentSphere == 1 and player.job.name:find('org') and not bag.inBitka and not bag.dead then
        
                    if not data[player.job.name] then
                        data[player.job.name] = {
                            label = player.job.label,
                            name = player.job.name,
                            players = {},
                            playerCount = 0
                        }
                    end
        
                    if data[player.job.name].playerCount < Config.MaxPlayers then
                        data[player.job.name].playerCount += 1
                        data[player.job.name].players[player.source] = {
                            label = GetPlayerName(player.source),
                            id = player.source,
                            grade = player.job.grade
                        }
                    end
        
                end
            end
            if data[args[1]] and data[args[2]] then
                if data[args[1]].playerCount >= 1 and data[args[2]].playerCount >= 1 then
                    local players = {}
                    for key, value in pairs(data[args[1]].players) do
                        table.insert(players, value)
                    end
                    local team1 = {
                        args[1],
                        {
                            isLooting = true,
                            job = args[1],
                            jobLabel = data[args[1]].label,
                            jobPlayers = ESX.Table.Clone(players),
                            zone = 1
                        }
                        
                    }
                    players = {}
                    for key, value in pairs(data[args[2]].players) do
                        table.insert(players, value)
                    end
                    local team2 = {
                        args[2],
                        {
                            isLooting = true,
                            job = args[2],
                            jobLabel = data[args[2]].label,
                            jobPlayers = ESX.Table.Clone(players),
                            zone = 1
                        }
                        
                    }
                    startBitka(team1, team2, 'nolooting', 1)
                    if xPlayer then
                        xPlayer.showNotification("Bitka rozpoczęta")
                    else
                        print("Bitka rozpoczęta")
                    end
                else
                    if xPlayer then
                        xPlayer.showNotification("Jedna z ekip lub obie nie mają 8 osób")
                    else
                        print("Jedna z ekip lub obie nie mają 8 osób")
                    end
                end

            else
                if xPlayer then
                    xPlayer.showNotification("Podanych ekip nie ma na lotni")
                else
                    print("Podanych ekip nie ma na lotni")
                end
            end
        else
            if xPlayer then
                xPlayer.showNotification("Podaj joby ekip")
            else
                print("Podaj joby ekip")
            end
        end
    end
end)
RegisterServerEvent('michalxdl-arenki:addToQueue', function(info)
    local xPlayer = ESX.GetPlayerFromId(source)
    if cantStart[info.job] then 
        xPlayer.showNotification("~r~Twoja organizacja jest już w kolejce!")
        return 
    end
    if xPlayer.job.name == info.job then
        TriggerClientEvent('michalxdl-arenki:checkPlayersInVehicle', source, info)
    end
end)

RegisterServerEvent('michalxdl-arenki:checkPlayersInVehicleResponse', function(info, allInVehicle)
    if not allInVehicle then
        for i=1, #info.jobPlayers, 1 do
            TriggerClientEvent('esx:showNotification', info.jobPlayers[i].id, "Ktoś z twojej organizacji nie jest w pojeździe przez co nie rozpoczniecie kolejki.")
        end
        return
    end

    local t = info.isLooting and 'looting' or 'noLooting'
    if not QUEUE[t][info.job] then
        QUEUE[t][info.job] = info
        cantStart[info.job] = true
        -- print(info.job, "true")
        for i=1, #info.jobPlayers, 1 do
            TriggerClientEvent('esx:showNotification', info.jobPlayers[i].id, "Dołączyliśćie do kolejki jako "..info.job.. " (Dodani przez "..GetPlayerName(source)..")")
            TriggerClientEvent('esx:showNotification', source, "Jeżeli chcesz opuścić kolejkę wpisz /hostedout")
            TriggerClientEvent("michalxdl-arenki:ficik", info.jobPlayers[i].id, source)
        end
    end
end)




-- CreateThread(function ()
--     while (true) do 
--         Wait(5000)
--         print(json.encode(QUEUE))
--     end
-- end)

RegisterCommand('hostedout', function(source, info)
    local xPlayer = ESX.GetPlayerFromId(source)
    local job = xPlayer.job
    local bag = Player(source).state
    if bag.customORG and bag.customORG.name then
        job = bag.customORG
    end
    for k, v in pairs(QUEUE) do
        if v[job.name] then
            QUEUE[k][job.name] = nil
        end
    end
    if cantStart[job.name] then 
        xPlayer.showNotification('Opuściłeś kolejkę.')
        cantStart[job.name] = nil
    end
end)

local function generateZone()
    math.randomseed(os.time()+math.random(1, 999999999))
    local rand = math.random(1, #Config.Zones)
    return rand
    -- for i=1, #Config.Zones, 1 do
    --     if rand < Config.Zones[i].chance then
    --         return i
    --     end
    -- end
    -- return #Config.Zones
end

function getSeat(ped, veh)
    for i= -1, 12 do
        if GetPedInVehicleSeat(veh, i) == ped then
            return i
        end
    end
    return false
end

function startBitka(team1, team2, t, zone)
    local isLooting = t == 'looting' and true or false
    local data = {}
    local info = {}
    BitkaID += 1
    info.id = BitkaID
    local z = generateZone()
    info.zone = zone or z
    data.id = info.id
    data.killers = {}
    data.isLooting = isLooting
    data.initiator = team1[2].job
    data.initiatorLabel = team1[2].jobLabel
    data.receiverLabel = team2[2].jobLabel
    data.receiver = team2[2].job
    data.initiatorPlayers = ESX.Table.Clone(team1[2].jobPlayers)
    data.receiverPlayers = ESX.Table.Clone(team2[2].jobPlayers)
    data.zone = info.zone
    data.ranking = true
    local initiatorCars = 0 
    local receiverCars = 0 
    local usedCars = {}
    local bucket = 0
    for k,v in pairs(data.initiatorPlayers) do
        if v.id and GetPlayerName(v.id) ~= nil then
            data.bucket = v.id + 5000
            bucket = data.bucket
            break
        end
    end
    if not data.bucket then
        return
    end
    local removed = 0
    local blocked = nil
    for i=1, #data.initiatorPlayers, 1 do
        local index = i - removed
        if data.initiatorPlayers[index].id then
            local player = data.initiatorPlayers[index]
            local bag = Player(player.id).state
            bag.bitkaTeam = nil
            local ped = GetPlayerPed(player.id)
            local vehicle = GetVehiclePedIsIn(ped)
            if vehicle and vehicle ~= 0 then
                if usedCars[vehicle] == nil then
                    initiatorCars += 1
                    usedCars[vehicle] = true
                end
            end
        else
            removed += 1
            table.remove(data.initiatorPlayers, index)
        end
    end
    removed = 0
    for i=1, #data.receiverPlayers, 1 do
        local index = i - removed
        if data.receiverPlayers[index].id then
            local player = data.receiverPlayers[index]
            local bag = Player(player.id).state
            bag.bitkaTeam = nil
            local ped = GetPlayerPed(player.id)
            local vehicle = GetVehiclePedIsIn(ped)
            if vehicle and vehicle ~= 0 then
                if usedCars[vehicle] == nil then
                    receiverCars += 1
                    usedCars[vehicle] = true
                end
            end
        else
            data.aliveReceiver -= 1
            removed += 1
            table.remove(data.receiverPlayers, index)
        end
    end
    Bitki[info.id] = data
    local indexes = {
        team1 = 1,
        team2 = 1
    }
    local rand = math.random(1, 2)
    local initiator = rand == 1 and 'team1' or 'team2'
    local receiver = rand == 1 and 'team2' or 'team1'
    function initiatorInfo(text)
        for i=1, #Bitki[info.id].initiatorPlayers, 1 do
            local player = Bitki[info.id].initiatorPlayers[i].id
            TriggerClientEvent('esx:showNotification', player, text)
        end
    end
    function receiverInfo(text)
        for i=1, #Bitki[info.id].receiverPlayers, 1 do
            local player = Bitki[info.id].receiverPlayers[i].id
            TriggerClientEvent('esx:showNotification', player, text)
        end
    end
    if #Bitki[info.id].initiatorPlayers == 0 or #Bitki[info.id].receiverPlayers == 0 then
        cantStart[Bitki[info.id].initiator] = nil
        cantStart[Bitki[info.id].receiver] = nil
        Bitki[info.id] = nil
        return
    end
    if initiatorCars > Config.MaxCars then
        initiatorInfo("~r~Twoja ekipa ma za dużo aut, popraw to i dołącz do kolejki ponownie! ("..initiatorCars.."/"..Config.MaxCars..")")
        receiverInfo("~r~Przeciwna ekipa ("..data.initiatorLabel..") ma za dużo aut, dołącz ponownie do kolejki. ("..initiatorCars.."/"..Config.MaxCars..")")
        cantStart[Bitki[info.id].initiator] = nil
        cantStart[Bitki[info.id].receiver] = nil
        Bitki[info.id] = nil
        return
    elseif receiverCars > Config.MaxCars then
        initiatorInfo("~r~Przeciwna ekipa ("..data.receiverLabel..") ma za dużo aut, dołącz ponownie do kolejki. ("..receiverCars.."/"..Config.MaxCars..")")
        receiverInfo("~r~Twoja ekipa ma za dużo aut, popraw to i dołącz do kolejki ponownie! ("..receiverCars.."/"..Config.MaxCars..")")
        cantStart[Bitki[info.id].initiator] = nil
        cantStart[Bitki[info.id].receiver] = nil
        Bitki[info.id] = nil
        return
    end
    for i=1, #Bitki[info.id].initiatorPlayers, 1 do
        local player = Bitki[info.id].initiatorPlayers[i].id
        local xPlayer = ESX.GetPlayerFromId(player)
        if xPlayer then
            xPlayer.addInventoryItem("energydrink", 2)
            xPlayer.addInventoryItem("pistol_ammo", 50)
        end
        PlayersSearching[player] = nil
        SetPlayerRoutingBucket(player, bucket)
        local ped = GetPlayerPed(player)
        local vehicle = GetVehiclePedIsIn(ped)
        -- ESX.ShowNotification('Wylosowano arenkę '..Config.Zones[info.zone][label])
        if Config.Zones[info.zone] and not Config.Zones[info.zone].noVehicles then
            if vehicle and vehicle ~= 0 then
                cacheVehicles[player] = {veh = vehicle, seat = getSeat(ped, vehicle), coords = GetEntityCoords(vehicle)}
                local coords = Config.Zones[info.zone][initiator .. 'Position'][1]
                Entity(vehicle).state.LastBucket = GetEntityRoutingBucket(vehicle)
                SetEntityRoutingBucket(vehicle, bucket)
                Entity(vehicle).state.bitka = bucket
                if GetPedInVehicleSeat(vehicle, -1) == GetPlayerPed(player) then
                    SetEntityCoords(vehicle, vec3(coords.x, coords.y, coords.z+0.3))
                    SetEntityHeading(vehicle, coords.w)
                else
                    -- SetEntityCoords(GetPlayerPed(player), vec3(coords.x, coords.y, coords.z+0.3))
                    TriggerClientEvent('michalxdl-arenki:TP', player, coords, true)
                end
            else
                local coords = Config.Zones[info.zone][initiator .. 'Position'][1]
                SetEntityCoords(GetPlayerPed(player), vec3(coords.x, coords.y, coords.z+0.3))
                TriggerClientEvent('michalxdl-arenki:TP', player, coords, true)
            end
        else
            if vehicle and vehicle ~= 0 then
                cacheVehicles[player] = {veh = vehicle, seat = getSeat(ped, vehicle), coords = GetEntityCoords(vehicle)}
                -- local plate = GetVehicleNumberPlateText(vehicle)
                -- MySQL.update('UPDATE owned_vehicles SET state = ? WHERE plate = ?', {'stored', plate:upper()})
                -- DeleteEntity(vehicle)
                SetEntityRoutingBucket(vehicle, 999123)
            end
            local coords = Config.Zones[info.zone][initiator .. 'Position'][1]
            SetEntityCoords(GetPlayerPed(player), vec3(coords.x, coords.y, coords.z+0.3))
            TriggerClientEvent('michalxdl-arenki:TP', player, coords)
        end
        AddBitka(ESX.GetPlayerFromId(player))
        TriggerClientEvent('michalxdl-arenki:startBitka', player, Bitki[info.id])
    end
    for i=1, #Bitki[info.id].receiverPlayers, 1 do
        local player = Bitki[info.id].receiverPlayers[i].id
        local xPlayer = ESX.GetPlayerFromId(player)
        if xPlayer then
            xPlayer.addInventoryItem("energydrink", 2)
            xPlayer.addInventoryItem("pistol_ammo", 50)
        end
        PlayersSearching[player] = nil
        SetPlayerRoutingBucket(player, bucket)
        local ped = GetPlayerPed(player)
        local vehicle = GetVehiclePedIsIn(ped)
        if not Config.Zones[info.zone].noVehicles then
            if vehicle and vehicle ~= 0 then
                cacheVehicles[player] = {veh = vehicle, seat = getSeat(ped, vehicle), coords = GetEntityCoords(vehicle)}
                Entity(vehicle).state.LastBucket = GetEntityRoutingBucket(vehicle)
                SetEntityRoutingBucket(vehicle, bucket)
                Entity(vehicle).state.bitka = bucket
                local coords = Config.Zones[info.zone][receiver .. 'Position'][1]
                if GetPedInVehicleSeat(vehicle, -1) == GetPlayerPed(player) then
                    SetEntityCoords(vehicle, vec3(coords.x, coords.y, coords.z+0.3))
                    SetEntityHeading(vehicle, coords.w)
                else
                    -- SetEntityCoords(GetPlayerPed(player), vec3(coords.x, coords.y, coords.z+0.3))
                    TriggerClientEvent('michalxdl-arenki:TP', player, coords, true)
                end
            else
                local coords = Config.Zones[info.zone][receiver .. 'Position'][1]
                SetEntityCoords(GetPlayerPed(player), vec3(coords.x, coords.y, coords.z+0.3))
                TriggerClientEvent('michalxdl-arenki:TP', player, coords, true)
            end
        else
            if vehicle and vehicle ~= 0 then
                cacheVehicles[player] = {veh = vehicle, seat = getSeat(ped, vehicle), coords = GetEntityCoords(vehicle)}
                -- local plate = GetVehicleNumberPlateText(vehicle)
                -- MySQL.update('UPDATE owned_vehicles SET state = ? WHERE plate = ?', {'stored', plate:upper()})
                -- DeleteEntity(vehicle)
                SetEntityRoutingBucket(vehicle, 999123)
            end
            local coords = Config.Zones[info.zone][receiver .. 'Position'][1]
            SetEntityCoords(GetPlayerPed(player), vec3(coords.x, coords.y, coords.z+0.3))
            TriggerClientEvent('michalxdl-arenki:TP', player, coords)
        end
        AddBitka(ESX.GetPlayerFromId(player))
        TriggerClientEvent('michalxdl-arenki:startBitka', player, Bitki[info.id])
    end
    -- Citizen.CreateThread(function()
    --     Wait(Config.MaxBitkaTime * 1000 * 60)
    --     if Bitki[info.id] then
    --         if Bitki[info.id].aliveInitiator > Bitki[info.id].aliveReceiver then
    --             BitkaLootingTime(info.id, 'initiator')
    --         elseif Bitki[info.id].aliveReceiver > Bitki[info.id].aliveInitiator then
    --             BitkaLootingTime(info.id, 'receiver')
    --         end
    --     end
    -- end)
    Wait(1000)
    local b = Bitki[info.id]
    local APlayers = {}
    local BPlayers = {}
    for k, v in pairs(b.initiatorPlayers) do
        if v.id and GetPlayerName(v.id) ~= nil then
            if not Player(v.id).state.dead then
                table.insert(APlayers, {src = v.id, name = GetPlayerName(v.id), coords = GetEntityCoords(GetPlayerPed(v.id))})
            end
        end
    end

    for k, v in pairs(b.receiverPlayers) do
        if v.id and GetPlayerName(v.id) ~= nil then
            if not Player(v.id).state.dead then
                table.insert(BPlayers, {src = v.id, name = GetPlayerName(v.id), coords = GetEntityCoords(GetPlayerPed(v.id))})
            end
        end
    end

    for k, v in pairs(b.initiatorPlayers) do
        if v.id and GetPlayerName(v.id) ~= nil then
            if not Player(v.id).state.dead then
                TriggerClientEvent("michalxdl-arenki:updateBlips", v.id, APlayers, BPlayers, b.initiator, b.receiver)
            end
        end
    end
    for k, v in pairs(b.receiverPlayers) do
        if v.id and GetPlayerName(v.id) ~= nil then
            if not Player(v.id).state.dead then
                TriggerClientEvent("michalxdl-arenki:updateBlips", v.id, BPlayers, APlayers, b.receiver, b.initiator)
            end
        end
    end
end

function BitkaLootingTime(id, winner)
    cantStart[Bitki[id].initiator] = nil
    cantStart[Bitki[id].receiver] = nil
    if winner == 'initiator' then
        local initiatorResult = MySQL.query.await('SELECT * FROM michalxdl_orgs_ranking WHERE org = @org', {
            ['@org'] = Bitki[id].initiator
        })

        if initiatorResult[1] then
            MySQL.update('UPDATE michalxdl_orgs_ranking SET wins = ? WHERE org = ?', {initiatorResult[1].wins + 1, Bitki[id].initiator})
        else
            MySQL.insert('INSERT INTO `michalxdl_orgs_ranking` (org, wins, loses) VALUES (?, ?, ?)', {
                Bitki[id].initiator, 1, 0
            })
        end

        local receiverResult = MySQL.query.await('SELECT * FROM michalxdl_orgs_ranking WHERE org = @org', {
            ['@org'] = Bitki[id].initiator
        })

        if receiverResult[1] then
            MySQL.update('UPDATE michalxdl_orgs_ranking SET loses = ? WHERE org = ?', {receiverResult[1].loses + 1, Bitki[id].receiver})
        else
            MySQL.insert.await('INSERT INTO `michalxdl_orgs_ranking` (org, wins, loses) VALUES (?, ?, ?)', {
                Bitki[id].receiver, 0, 1
            })
        end

        local stats = {}

        if initiatorResult[1] then
            stats.initiator = {
                wins = initiatorResult[1].wins + 1,
                loses = initiatorResult[1].loses
            }
        else
            stats.initiator = {
                wins = 1,
                loses = 0
            }
        end

        if receiverResult[1] then
            stats.receiver = {
                wins = receiverResult[1].wins,
                loses = receiverResult[1].loses + 1
            }
        else
            stats.receiver = {
                wins = 0,
                loses = 1
            }
        end

        local embed = {
            {
                ["avatar_url"] = "https://cdn.discordapp.com/attachments/1345503542076510363/1348061301070364692/logo_adniejsze.png?ex=67ce176b&is=67ccc5eb&hm=09cec93ba3c3d0eada7194d65704973990d13c2a5081a3f8424a7c4b5d352ce9&",
                ["username"] = "michalxdl",
                ["author"] = {
                    ["name"] = "Bitka: "..Bitki[id].initiatorLabel.." VS "..Bitki[id].receiverLabel,
                },
                ["color"] = "5793266",
                --["title"] = author,
                ["description"] = Bitki[id].initiatorLabel.." (W: "..stats.initiator.wins..", L: "..stats.initiator.loses..", Razem: "..stats.initiator.wins + stats.initiator.loses..", WR: "..string.format("%.2f",(stats.initiator.wins / (stats.initiator.wins + stats.initiator.loses)) * 100) .."%)\n**wygrało bitke z**\n"..Bitki[id].receiverLabel.." (W: "..stats.receiver.wins..", L: "..stats.receiver.loses..", Razem: "..stats.receiver.wins + stats.receiver.loses..", WR: "..string.format("%.2f",(stats.receiver.wins / (stats.receiver.wins + stats.receiver.loses)) * 100) .."%)",
                ["type"]="rich",
                ["footer"] = {
                    ["text"] = os.date() .. " | michalxdl",
                },
            }
        }

    	PerformHttpRequest("https://discord.com/api/webhooks/1347663140506046505/1mEFDQDMHYTUpn5skw3KfjpsSsqnVNmLEwfnzArtzbUua6QlZsj59o0dtg_AWdWjQKxi", function(err, text, headers) end, 'POST', json.encode({username = 'michalxdlGG', avatar_url = 'https://cdn.discordapp.com/attachments/1345503542076510363/1348061301070364692/logo_adniejsze.png?ex=67ce176b&is=67ccc5eb&hm=09cec93ba3c3d0eada7194d65704973990d13c2a5081a3f8424a7c4b5d352ce9&', embeds = embed}), { ['Content-Type'] = 'application/json' })
    else
        local receiverResult = MySQL.query.await('SELECT * FROM michalxdl_orgs_ranking WHERE org = @org', {
            ['@org'] = Bitki[id].receiver
        })

        if receiverResult[1] then
            MySQL.update('UPDATE michalxdl_orgs_ranking SET wins = ? WHERE org = ?', {receiverResult[1].wins + 1, Bitki[id].receiver})
        else
            MySQL.insert('INSERT INTO `michalxdl_orgs_ranking` (org, wins, loses) VALUES (?, ?, ?)', {
                Bitki[id].receiver, 1, 0
            })
        end

        local initiatorResult = MySQL.query.await('SELECT * FROM michalxdl_orgs_ranking WHERE org = @org', {
            ['@org'] = Bitki[id].initiator
        })

        if initiatorResult[1] then
            MySQL.update('UPDATE michalxdl_orgs_ranking SET loses = ? WHERE org = ?', {initiatorResult[1].loses + 1, Bitki[id].initiator})
        else
            MySQL.insert.await('INSERT INTO `michalxdl_orgs_ranking` (org, wins, loses) VALUES (?, ?, ?)', {
                Bitki[id].initiator, 0, 1
            })
        end

        local stats = {}

        if initiatorResult[1] then
            stats.initiator = {
                wins = initiatorResult[1].wins,
                loses = initiatorResult[1].loses + 1
            }
        else
            stats.initiator = {
                wins = 0,
                loses = 1
            }
        end

        if receiverResult[1] then
            stats.receiver = {
                wins = receiverResult[1].wins + 1,
                loses = receiverResult[1].loses
            }
        else
            stats.receiver = {
                wins = 1,
                loses = 0
            }
        end

        local embed = {
            {
                ["avatar_url"] = "https://cdn.discordapp.com/attachments/1345503542076510363/1348061301070364692/logo_adniejsze.png?ex=67ce176b&is=67ccc5eb&hm=09cec93ba3c3d0eada7194d65704973990d13c2a5081a3f8424a7c4b5d352ce9&",
                ["username"] = "michalxdl",
                ["color"] = "5793266",
                ["title"] = "Bitka: "..Bitki[id].initiatorLabel.." VS "..Bitki[id].receiverLabel,
                ["description"] = Bitki[id].receiverLabel.." (W: "..stats.receiver.wins..", L: "..stats.receiver.loses..", Razem: "..stats.receiver.wins + stats.receiver.loses..", WR: "..string.format("%.2f",(stats.receiver.wins / (stats.receiver.wins + stats.receiver.loses)) * 100) .."%)\n**wygrało bitke z**\n"..Bitki[id].initiatorLabel.." (W: "..stats.initiator.wins..", L: "..stats.initiator.loses..", Razem: "..stats.initiator.wins + stats.initiator.loses..", WR: "..string.format("%.2f",(stats.initiator.wins / (stats.initiator.wins + stats.initiator.loses)) * 100) .."%)",
                ["type"]="rich",
                ["footer"] = {
                    ["text"] = os.date() .. " | michalxdl",
                },
            }
        }

        PerformHttpRequest("https://discord.com/api/webhooks/1347663140506046505/1mEFDQDMHYTUpn5skw3KfjpsSsqnVNmLEwfnzArtzbUua6QlZsj59o0dtg_AWdWjQKxi", function(err, text, headers) end, 'POST', json.encode({username = 'michalxdlGG', avatar_url = 'https://cdn.discordapp.com/attachments/1345503542076510363/1348061301070364692/logo_adniejsze.png?ex=67ce176b&is=67ccc5eb&hm=09cec93ba3c3d0eada7194d65704973990d13c2a5081a3f8424a7c4b5d352ce9&', embeds = embed}), { ['Content-Type'] = 'application/json' })
    end

    local winnerName = Bitki[id][winner]
    local winnerLabel = Bitki[id][winner .. 'Label']
    for i=1, #Bitki[id].initiatorPlayers, 1 do
        TriggerClientEvent('michalxdl-arenki:lootingTime', Bitki[id].initiatorPlayers[i].id, winner == 'initiator')
        if winner == 'initiator' then
            TriggerClientEvent('esx_ambulancejob:revive', Bitki[id].initiatorPlayers[i].id)
        end
    end
    for i=1, #Bitki[id].receiverPlayers, 1 do
        TriggerClientEvent('michalxdl-arenki:lootingTime', Bitki[id].receiverPlayers[i].id, winner == 'receiver')
        if winner == 'receiver' then
            TriggerClientEvent('esx_ambulancejob:revive', Bitki[id].receiverPlayers[i].id)
        end
    end

    if Bitki[id].ranking then
        local winnerName = Bitki[id][winner]
        local winnerLabel = Bitki[id][winner .. 'Label']
        local loser = ''
        local loserLabel = ''
        if winner == 'initiator' then
            loser = Bitki[id].receiver
            loserLabel = Bitki[id].receiverLabel
        else
            loser = Bitki[id].initiator
            loserLabel = Bitki[id].initiatorLabel
        end
        --OGOLNIE TO GLOWNIE MASA
        -- exports['michalxdl']:SendLogToDiscord('https://discord.com/api/webhooks/1275650103947952138/9vZxyG8NrxSHFl-N0WV7I39GPg7L9WA0kIMh6NxgqwwxFnpRcDUQicQxBXS9QxuexN0p', Bitki[id].receiverLabel.." VS "..Bitki[id].initiatorLabel, "BITKE WYGRALI "..winnerLabel, 16711680)
        TriggerEvent('bitkiorg:winBitka', winnerName, winnerLabel, loser, loserLabel)
    if Bitki[id].isLooting then
        Wait(Bitki[id].addonLooting and (Config.ExtraLootingTime * 1000) or (Config.LootingTime * 1000))
    else
        Wait(333)
    end
    local killers = {}
    local killersLog = ""
    if Bitki[id] and Bitki[id].killers then 
        for id, killer in pairs(Bitki[id].killers) do
            if GetPlayerName(id) then
                killersLog = killersLog.. killer.org .. ' ' .. GetPlayerName(id) .. ' zabił - <b>' .. killer.count .. '</b>\n'
                table.insert(killers, {text = GetPlayerName(id) .. ' zabił - <b> ' .. killer.count .. ' </b>', job = killer.org, kills = killer.count})
            end
        end
    end    
    if not Bitki[id] then return end
    for i=1, #Bitki[id].initiatorPlayers, 1 do
        local xPlayer = ESX.GetPlayerFromId(Bitki[id].initiatorPlayers[i].id)
        if xPlayer then
            SetPlayerRoutingBucket(Bitki[id].initiatorPlayers[i].id, 99999)
            -- SetEntityCoords(GetPlayerPed(Bitki[id].receiverPlayers[i].id), Config.EndBitkaCoords)
            TriggerClientEvent('michalxdl-arenki:killers', Bitki[id].initiatorPlayers[i].id, killers)
            TriggerClientEvent('esx_ambulancejob:revive', Bitki[id].initiatorPlayers[i].id)
            Player(Bitki[id].initiatorPlayers[i].id).state:set("currentSphere", 1, true)
            local bag = Player(Bitki[id].initiatorPlayers[i].id).state
            local job = xPlayer.job
            if bag.customORG and bag.customORG.name then
                job = {name = bag.customORG.name, grade = 0, label = bag.customORG.label}
            end
            inSpheres[1][Bitki[id].initiatorPlayers[i].id] = {
                source = Bitki[id].initiatorPlayers[i].id,
                job = job,
            }
        end
    end
    for i=1, #Bitki[id].receiverPlayers, 1 do
        local xPlayer = ESX.GetPlayerFromId(Bitki[id].receiverPlayers[i].id)
        if xPlayer then
            SetPlayerRoutingBucket(Bitki[id].receiverPlayers[i].id, 99999)
            -- SetEntityCoords(GetPlayerPed(Bitki[id].receiverPlayers[i].id), Config.EndBitkaCoords)
            TriggerClientEvent('michalxdl-arenki:killers', Bitki[id].receiverPlayers[i].id, killers)
            TriggerClientEvent('esx_ambulancejob:revive', Bitki[id].receiverPlayers[i].id)
            Player(Bitki[id].receiverPlayers[i].id).state:set("currentSphere", 1, true)
            local bag = Player(Bitki[id].receiverPlayers[i].id).state
            local job = xPlayer.job
            if bag.customORG and bag.customORG.name then
                job = {name = bag.customORG.name, grade = 0, label = bag.customORG.label}
            end
            inSpheres[1][Bitki[id].receiverPlayers[i].id] = {
                source = Bitki[id].receiverPlayers[i].id,
                job = job,
            }
        end
    end
    Bitki[id] = nil
end
end

RegisterServerEvent("michalxdl-arenki:endGame")
AddEventHandler("michalxdl-arenki:endGame", function()
    local src = source
    local car = cacheVehicles[src]

    -- Set player and vehicle to a unique routing bucket
    local endGameBucket = 99999

    if car and car.veh ~= 0 then
        -- Przypisz gracza do odpowiedniego bucketu
        SetPlayerRoutingBucket(src, endGameBucket)

        -- Sprawdź, czy pojazd istnieje
        if DoesEntityExist(car.veh) then
            -- Przypisz pojazd do tego samego bucketu
            SetEntityRoutingBucket(car.veh, endGameBucket)

            -- Przenieś pojazd i gracza na odpowiednie koordynaty
            SetEntityCoords(car.veh, car.coords)
            SetEntityCoords(GetPlayerPed(src), car.coords)

            local mit = math.random(1, 10)
            if mit == 7 then
                TriggerClientEvent('esx:showNotification', src, "Twoja teleportacja trwa dłużej niż zazwyczaj, przepraszamy")
            end

            -- Opóźnienie teleportacji dla synchronizacji
            Wait(900)
            SetEntityCoords(GetPlayerPed(src), car.coords)
            SetEntityCoords(car.veh, car.coords)

            -- Przenieś gracza do pojazdu
            TaskWarpPedIntoVehicle(GetPlayerPed(src), car.veh, car.seat)
            Wait(2000)
            TaskWarpPedIntoVehicle(GetPlayerPed(src), car.veh, car.seat)
        else
            -- Jeśli pojazd nie istnieje, przypisz gracza do bucketu i przenieś na zapasowe koordynaty
            SetPlayerRoutingBucket(src, endGameBucket)
            TriggerClientEvent('esx:showNotification', src, "Nie możemy odnaleźć twojego auta, teleportacja na hangar")
            SetEntityCoords(GetPlayerPed(src), Config.EndBitkaCoords)
        end
    end
end)


-- RegisterServerEvent("michalxdl-arenki:endGame")
-- AddEventHandler("michalxdl-arenki:endGame", function()
--     local src = source
--     local car = cacheVehicles[src]
--     if car and car.veh ~= 0 then
--         SetPlayerRoutingBucket(src, 99999)
--         SetEntityCoords(GetPlayerPed(src), car.coords)
--         Wait(math.random(1, 1000))
--         if DoesEntityExist(car.veh) then
--             if car.seat == -1 then
--                 SetEntityRoutingBucket(car.veh, 99999)
--                 SetEntityCoords(car.veh, car.coords)
--             end
--             SetEntityCoords(GetPlayerPed(src), car.coords)
--             Wait(1000)
--             TaskWarpPedIntoVehicle(GetPlayerPed(src), car.veh, car.seat)
--             Wait(3000)
--             TaskWarpPedIntoVehicle(GetPlayerPed(src), car.veh, car.seat)
--         else
--             SetEntityCoords(GetPlayerPed(src), Config.EndBitkaCoords)
--         end
--     else
--         SetEntityCoords(GetPlayerPed(src), Config.EndBitkaCoords)
--     end
-- end)

RegisterServerEvent('michalxdl-arenki:exitCurrentBitka', function(id)
    if Bitki[id] then
        local found = false
        for i=1, #Bitki[id].initiatorPlayers, 1 do
            if Bitki[id].initiatorPlayers[i].id == source then
                table.remove(Bitki[id].initiatorPlayers, i)
                found = true
                break
            end
        end
        if not found then
            for i=1, #Bitki[id].receiverPlayers, 1 do
                if Bitki[id].receiverPlayers[i].id == source then
                    table.remove(Bitki[id].receiverPlayers, i)
                    break
                end
            end
        end
        SetPlayerRoutingBucket(source, 99999)
        TriggerClientEvent('esx_ambulancejob:revive', source, true)
        TriggerClientEvent('michalxdl-arenki:exitCurrentBitka', source)
    end
end)

SendToAll = function(id, msg)
    if not Bitki[id] then print("Brak bitki do SendToAll") return end
    for i=1, #Bitki[id].initiatorPlayers, 1 do
        TriggerClientEvent('esx:showNotification', Bitki[id].initiatorPlayers[i].id, msg)
    end
    for i=1, #Bitki[id].receiverPlayers, 1 do
        TriggerClientEvent('esx:showNotification', Bitki[id].receiverPlayers[i].id, msg)
    end
end

local function BitkaKill(id, player, killer, playerLeft)
    if Bitki[id] then
        if killer then
            local kPlayer = ESX.GetPlayerFromId(killer)
            if kPlayer then
                local kjob = kPlayer.job
                local kbag = Player(killer).state
                if kbag.customORG and kbag.customORG.name then
                    kjob = {name = kbag.customORG.name, grade = 0, label = kbag.customORG.label}
                end
                if not Bitki[id].killers[killer] then
                    Bitki[id].killers[killer] = {
                        count = 0,
                        org = kjob.label
                    }
                end
                Bitki[id].killers[killer].count += 1
                AddKill(kPlayer)
                AddDeath(player)
                SendToAll(id, "["..killer.."] "..GetPlayerName(killer).." zabija ["..player.source.."] "..GetPlayerName(player.source))
            end
        end
        local job = player.job
        local bag = Player(player.source).state
        if bag.customORG then
            if bag.customORG.name then
                job = {name = bag.customORG.name, grade = 0, label = bag.customORG.label}
            else
                print(player.source, "zbugowany ziomal") 
            end
        end

        if isInitiator(id, player.source) then
            for k,v in pairs(Bitki[id].initiatorPlayers) do
                TriggerClientEvent("michas:addKill", v.id, "#players2")
            end
            for k,v in pairs(Bitki[id].receiverPlayers) do
                TriggerClientEvent("michas:addKill", v.id, "#players2")
            end
        end

        if isReceiver(id, player.source) then
            for k,v in pairs(Bitki[id].initiatorPlayers) do
                TriggerClientEvent("michas:addKill", v.id, "#players1")
            end
            for k,v in pairs(Bitki[id].receiverPlayers) do
                TriggerClientEvent("michas:addKill", v.id, "#players1")
            end
        end

        if isInitiator(id, player.source) then
            local aliveInitiator = 0
            for k,v in pairs(Bitki[id].initiatorPlayers) do
                if not playerLeft and GetPlayerName(v.id) then
                    if not Player(v.id).state.dead then
                        aliveInitiator += 1
                    end
                end
            end
            if aliveInitiator <= 0 then
                BitkaLootingTime(id, 'receiver')
                return
            end
        end
        if isReceiver(id, player.source) then
            local aliveReceiver = 0
            for k,v in pairs(Bitki[id].receiverPlayers) do
                if not playerLeft and GetPlayerName(v.id) then
                    if not Player(v.id).state.dead then
                        aliveReceiver += 1
                    end
                end
            end
            if aliveReceiver <= 0 then
                BitkaLootingTime(id, 'initiator')
                return
            end
        end
    end
end

isReceiver = function(id, src)
    if id and Bitki[id] then
        for k,v in pairs(Bitki[id].receiverPlayers) do
            if GetPlayerName(v.id) then
                if v.id == src then
                    return true
                end
            end
        end
    end
    return false
end

isInitiator = function(id, src)
    if id and Bitki[id] then
        for k,v in pairs(Bitki[id].initiatorPlayers) do
            if GetPlayerName(v.id) then
                if v.id == src then
                    return true
                end
            end
        end
    end
    return false
end


AddEventHandler('playerDropped', function()
    local src = source
    local state = Player(src).state
    local inBitka = state.inBitka
    if inBitka and Bitki[inBitka] then
        local xPlayer = ESX.GetPlayerFromId(src)
        for i=1, #Bitki[inBitka].initiatorPlayers, 1 do
            if Bitki[inBitka].initiatorPlayers[i].id == src then
                BitkaKill(inBitka, xPlayer, nil, true)
                table.remove(Bitki[inBitka].initiatorPlayers, i)
                break
            end
        end
        for i=1, #Bitki[inBitka].receiverPlayers, 1 do
            if Bitki[inBitka].receiverPlayers[i].id == src then
                BitkaKill(inBitka, xPlayer, nil, true)
                table.remove(Bitki[inBitka].receiverPlayers, i)
                break
            end
        end
    end
end)


RegisterServerEvent('michalxdl-arenki:kill', function(id, killer)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    BitkaKill(id, xPlayer, killer)
    xPlayer.addInventoryItem("tokenboj", 5)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then
        return
    end
    for _, xPlayer in pairs(ESX.GetExtendedPlayers()) do
        if Player(xPlayer.source).state.inBitka then
            SetEntityCoords(GetPlayerPed(xPlayer.source), Config.EndBitkaCoords)
            FreezeEntityPosition(GetPlayerPed(xPlayer.source), false)
            SetPlayerRoutingBucket(xPlayer.source, 0)
        end
        Player(xPlayer.source).state.inBitka = nil
    end
    local vehicles = ESX.OneSync.GetVehiclesInArea(Config.Zones[1].coords, Config.Zones[1].radius + 100.0)
    for _, v in pairs(vehicles) do
        local vehicle = NetworkGetEntityFromNetworkId(v)
        if Entity(vehicle).state.bitka ~= nil then
            SetEntityRoutingBucket(vehicle, 0)
            Entity(vehicle).state.bitka = nil
            Entity(vehicle).state.LastBucket = nil
        end
    end
    TriggerClientEvent("EasyAdmin:FreezePlayer", -1, false)
end)

AddKill = function(xPlayer)
    if xPlayer then
	    -- MySQL.update('UPDATE users SET kills = kills + 1 WHERE identifier = @identifier AND digit = @digit', {['@identifier'] = xPlayer.identifier, ['@digit'] = xPlayer.getDigit()})
    end
end

AddDeath = function(xPlayer)
    if xPlayer then
	    -- MySQL.update('UPDATE users SET deaths = deaths + 1 WHERE identifier = @identifier AND digit = @digit', {['@identifier'] = xPlayer.identifier, ['@digit'] = xPlayer.getDigit()})
    end
end

AddBitka = function(xPlayer)
    if xPlayer then
	    -- MySQL.update('UPDATE users SET bitki = bitki + 1 WHERE identifier = @identifier AND digit = @digit', {['@identifier'] = xPlayer.identifier, ['@digit'] = xPlayer.getDigit()})
    end
end

RegisterServerEvent("michalxdl-arenki:requestJoin")
AddEventHandler("michalxdl-arenki:requestJoin", function(bool)
    local xPlayer = ESX.GetPlayerFromId(source)
    if type(bool) == "boolean" then 
        Player(source).state:set("szukaorg", bool, true)
        if bool then
            xPlayer.showNotification("Szukasz organizacji na slota.")
            PlayersSearching[source] = {src = source, name = GetPlayerName(source)}
        else
            xPlayer.showNotification("Nie szukasz już organizacji na slota.")
            PlayersSearching[source] = nil
        end
    end
end)

countTable = function(table)
    local count = 0
    for k,v in pairs(table) do
        count += 1
    end
    return count
end


Citizen.CreateThread(function()
    for k,v in ipairs(GetPlayers()) do
        Player(v).state.szukaorg = false
    end
    while true do
        Citizen.Wait(2000)
        for a, b in pairs(Bitki) do
            local APlayers = {}
            local BPlayers = {}
            for k, v in pairs(b.initiatorPlayers) do
                if v.id and GetPlayerName(v.id) ~= nil then
                    if not Player(v.id).state.dead then
                        table.insert(APlayers, {src = v.id, name = GetPlayerName(v.id), coords = GetEntityCoords(GetPlayerPed(v.id))})
                    end
                end
            end

            for k, v in pairs(b.receiverPlayers) do
                if v.id and GetPlayerName(v.id) ~= nil then
                    if not Player(v.id).state.dead then
                        table.insert(BPlayers, {src = v.id, name = GetPlayerName(v.id), coords = GetEntityCoords(GetPlayerPed(v.id))})
                    end
                end
            end

            for k, v in pairs(b.initiatorPlayers) do
                if v.id and GetPlayerName(v.id) ~= nil then
                    TriggerClientEvent("michalxdl-arenki:updateBlips", v.id, APlayers, BPlayers, b.initiator, b.receiver)
                end
            end
            for k, v in pairs(b.receiverPlayers) do
                if v.id and GetPlayerName(v.id) ~= nil then
                    TriggerClientEvent("michalxdl-arenki:updateBlips", v.id, BPlayers, APlayers, b.receiver, b.initiator)
                end
            end
        end
    end
end)
