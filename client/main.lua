ESX = exports["es_extended"]:getSharedObject()

local PlayerData = {}
local isInOrg = false
local isInZone = false
local invited = nil
local currentBitka = nil
local zonesBlips = {}
local dead = false
local greenZone = false
local started = false
local LastVeh = nil
local LastSeat = nil
local Blips = {}
local function RefreshBlips()
    for k, v in pairs(zonesBlips) do
        RemoveBlip(v)
    end
    zonesBlips = {}
    if isInOrg then
        for i=1, #Config.Zones, 1 do
            if Config.Zones[i].radius ~= 420.0 then return end
            local sphere = AddBlipForRadius(Config.Zones[i].coords.x, Config.Zones[i].coords.y, Config.Zones[i].coords.z, Config.Zones[i].radius)
            SetBlipColour(sphere, 1)
            SetBlipAlpha(sphere, 100)
            zonesBlips[i] = sphere
            --
            
            local blip = AddBlipForCoord(Config.Zones[i].coords)
            SetBlipSprite(blip, 668)
            SetBlipColour(blip, 1)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
			AddTextComponentSubstringPlayerName('Hostowane Bitki')
			EndTextCommandSetBlipName(blip)
            zonesBlips[i] = blip
        end
    end
end

local uiVisible = true

RegisterCommand('hideui', function()
    if uiVisible then
        SendNUIMessage({
            type = "HideUI"
        })
        uiVisible = false
    else
        SendNUIMessage({
            type = "ShowUI"
        })
        uiVisible = true
    end
end, false)




Citizen.CreateThread(function()
    while not ESX.IsPlayerLoaded() do
        Citizen.Wait(100)
    end
    PlayerData = ESX.GetPlayerData()
    LocalPlayer.state:set('currentSphere', nil, true)
    LocalPlayer.state:set('inBitka', nil, true)
    LocalPlayer.state:set('bitkaTeam', nil, true)
    SetupZones()
    if PlayerData.job and PlayerData.job.name:find("org") then
        isInOrg = true
    else
        isInOrg = false
    end
    RefreshBlips()
end)

RegisterNetEvent('michalxdl-arenki:checkPlayersInVehicle')
AddEventHandler('michalxdl-arenki:checkPlayersInVehicle', function(info)
    local allInVehicle = true
    for i=1, #info.jobPlayers, 1 do
        local playerPed = GetPlayerPed(GetPlayerFromServerId(info.jobPlayers[i].id))
        if not IsPedInAnyVehicle(playerPed, false) then
            allInVehicle = false
            break
        end
    end
    TriggerServerEvent('michalxdl-arenki:checkPlayersInVehicleResponse', info, allInVehicle)
end)

RegisterKeyMapping('hudshowbitka', 'Ukryj/Pokaż Hud Bitka', 'MOUSE_BUTTON', 'MOUSE_MIDDLE')
    
RegisterCommand("hudshowbitka", function()
        SendNUIMessage({
            action = 'HideUI',
        })
        LocalPlayer.state.showhud = false
    if not LocalPlayer.state.showhud then
        SendNUIMessage({
            action = 'openScoreboard',
        })
        SendNUIMessage({
            action = 'updateScoreboard',
            team = team,
            newValue = value
        })
        LocalPlayer.state.showhud = true
    end

end)

RegisterNetEvent('michalxdl-arenki:pedaljuzszuka')
AddEventHandler('michalxdl-arenki:pedaljuzszuka', function()
    local elements = {
        {label = "Opuść Kolejkę", value = "quit"}
    }

    ESX.UI.Menu.Open(
        'default', 
        GetCurrentResourceName(), 
        'juzcwelszukaigojebacogln', 
        {
            title = "Szukanie Bitki...",
            align = 'center',
            elements = elements
        }, 
        function(data, menu)
            if data.current.value == "quit" then
                ExecuteCommand('hostedout')
                menu.close()
            end
        end, 
        function(data, menu)
            menu.close()
        end
    )
end)


RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
    if PlayerData.job and PlayerData.job.name:find("org") then
        isInOrg = true
    else
        isInOrg = false
    end
    RefreshBlips()
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    PlayerData.job = job
    if PlayerData.job and PlayerData.job.name:find("org") then
        isInOrg = true
    else
        isInOrg = false
    end
    RefreshBlips()
    if LocalPlayer.state.currentSphere then
        TriggerServerEvent('michalxdl-arenki:enter', LocalPlayer.state.currentSphere)
    end
end)

propfix = function ()
    for j,v in ipairs(GetGamePool('CObject')) do
        if GetEntityType(v) == 3 then
            if IsEntityAttachedToEntity(v, PlayerPedId()) then
                DeleteEntity(v)
            end
        end
    end
    TriggerEvent("propfix")
end

local cooldown = false

local function OpenBitkiReadyMenu()
    -- if cooldown then
    --     ESX.ShowNotification('Nie możesz tak często otwierać menu bitek')
    --     return
    -- end
    -- cooldown = true
    -- Citizen.CreateThread(function()
    --     Wait(3000)
    --     cooldown = false
    -- end)
    local serverId = GetPlayerServerId(PlayerId())
    ESX.TriggerServerCallback('michalxdl-arenki:getPlayers', function(cb)
        if cb then
            local myPlayers = {}
            local elements = {
                -- {label = '<span style="font-weight: bold;">Drużyna</span>'}
            }
            local isLooting = false
            
            -- table.insert(elements, {label = 'Lootowanie - ' .. (isLooting and '<span style="color: green">Tak</span>' or '<span style="color: red">Nie</span>'), value = 'isLooting'})
            table.insert(elements, {label = '<span style="font-weight: bold;">Wyrzuć Członka</span>', value = 'kick'})
            table.insert(elements, {label = '<span style="font-weight: bold;">Zaproś Gracza (Spoza Organizacji)</span>', value = 'invite'})
            table.insert(elements, {label = '<span style="font-weight: bold;">Zaproś Gracza (Szukam Drużyny)</span>', value = 'invite2'})
            table.insert(elements, {label = '<span style="font-weight: bold;">Uruchom wyszukiwanie Bitki</span>', value = 'confirm'})
            table.insert(elements, {label = '<span style="font-weight: bold;">---CZŁONKOWIE---</span>'})
            -- table.insert(elements, player)
            for _, player in pairs(cb.players) do
                table.insert(elements, player)
                table.insert(myPlayers, player)
            end
            ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'bitki_settings_menu', {
                title = 'Menu Bitek',
                align = 'center',
                elements = elements
            }, function(data, menu)
                local newData = data.current
                if data.current.value == 'isLooting' then
                    isLooting = not isLooting
                    newData.label = 'Lootowanie - ' .. (isLooting and '<span style="color: green">Tak</span>' or '<span style="color: red">Nie</span>')
                    newData.state = isLooting
                    menu.update({value = data.current.value}, newData)
                    menu.refresh()
                end
                if data.current.value == 'invite' then
                    ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'invite', {
                        title = "ID"
                    }, function(data2, menu2)
                        menu.close()
                        menu2.close()
                        local id = tonumber(data2.value)
                        if not id then return end
                        TriggerEvent('skinchanger:getSkin', function(skin)
                            TriggerServerEvent("michalxdl-arenki:inviteNewPlayer", id, skin)
                        end)
                    end, function(data2, menu2)
                        menu2.close()
                    end)
                end
                if data.current.value == 'invite2' then
                    OpenInviteMenuList(cb.searchPlayers)
                end
                if data.current.value == 'kick' then
                    ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'kick', {
                        title = "ID"
                    }, function(data2, menu2)
                        menu.close()
                        menu2.close()
                        local id = tonumber(data2.value)
                        if not id then return end
                        TriggerServerEvent("michalxdl-arenki:kickPlayer", id)
                    end, function(data2, menu2)
                        menu2.close()
                    end)
                end
                if data.current.value == 'confirm' then
                    if #myPlayers >= Config.MinPlayers then
                        local info = {
                            isLooting = isLooting,
                            job = PlayerData.job.name,
                            jobLabel = PlayerData.job.label,
                            jobPlayers = myPlayers,
                            zone = LocalPlayer.state.currentSphere
                        }
                        TriggerServerEvent('michalxdl-arenki:addToQueue', info)
                        ESX.UI.Menu.CloseAll()
                    else
                        ESX.ShowNotification('W twojej drużynie musi być minimum '..Config.MinPlayers..' osób')
                    end
                end
            end, function(data, menu)
                menu.close()
            end)
        end
    end, LocalPlayer.state.currentSphere)
end

OpenInviteMenuList = function(list)
    local elements = {}
    for k,v in pairs(list) do
        if v.src ~= GetPlayerServerId(PlayerId()) then
            table.insert(elements, {label = '['..v.src..'] '..v.name.."</span>", value = v.src})
        end
    end
    table.insert(elements, {label = '<span style="color: red">Anuluj</span>', value = 'cancel'})
    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'invite-list', {
        title = 'Zapraszanie do bitki',
        align = 'center',
        elements = elements
    }, function(data, menu)
        menu.close()
        if data.current.value == "cancel" then return end
        local id = tonumber(data.current.value)
        if id then
            TriggerEvent('skinchanger:getSkin', function(skin)
                TriggerServerEvent("michalxdl-arenki:inviteNewPlayer", id, skin)
            end)
        end
    end, function(data, menu)
        menu.close()
    end)
end

RegisterNetEvent('michalxdl-arenki:OpenBitkiReadyMenu')
AddEventHandler('michalxdl-arenki:OpenBitkiReadyMenu', function()
    OpenBitkiReadyMenu()
end)

local zones = {}

if Config.Debug then
    Citizen.CreateThread(function()
        while true do
            Wait(1)
            for k, v in pairs(zones) do
                v:marker()
            end
        end
    end)
end

local function insideLoop(zone)
    if isInZone then return end
    isInZone = true
    CreateThread(function()
        while isInZone do -- and isInOrg 
            Citizen.Wait(1)
            if #(GetEntityCoords(PlayerPedId()) - zone.coords) > zone.radius - 500.0  or #(GetEntityCoords(PlayerPedId()) - zone.coords) > zone.radius + 100.0  then
                zone:marker()
            else
                Wait(1000)
            end
        end
    end)
end

local function onEnter(self)
    Citizen.CreateThread(function()
        if not greenZone then
            greenZone = true
            while greenZone do
                Wait(1000)
                propfix()
                if not currentBitka then
                    ESX.TextUI('Aby rozpocząć hostowaną Bitkę, kliknij F4 lub wpisz komendę /hosted')
                    SetLocalPlayerAsGhost(true)
                    -- DisablePlayerFiring(PlayerId(), true)
                else
                    ESX.HideUI()
                    SetLocalPlayerAsGhost(false)
                    -- DisablePlayerFiring(PlayerId(), false)
                end
            end
            ESX.HideUI()
            SetLocalPlayerAsGhost(false)
            -- DisablePlayerFiring(PlayerId(), false)
        end
    end)
    -- if not isInOrg then return end
    Wait(1000)
    TriggerServerEvent('michalxdl-arenki:enter', self.id)
    LocalPlayer.state:set('currentSphere', self.id, true)
    insideLoop(self)
end

local function onExit(self)
    -- if not isInOrg then return end
    isInZone = false
    LocalPlayer.state:set('currentSphere', nil, true)
    TriggerServerEvent('michalxdl-arenki:exit', self.id)
    if ESX.UI.Menu.GetOpened('default', GetCurrentResourceName(), 'bitki_menu') ~= nil then
        ESX.UI.Menu.CloseAll()
    end
    ESX.HideUI()
    Wait(500)
    greenZone = false
    if currentBitka ~= nil then
        if not isInZone and started then
            ESX.HideUI()
            if not LocalPlayer.state.dead then
                SetEntityHealth(PlayerPedId(), 0)
            end
            ESX.HideUI()
            Wait(500)
        end
    end
end

function SetupZones()
    for i=1, #Config.Zones, 1 do
        if Config.Zones[i].radius == 420.0 then
        local data = Config.Zones[i]
        data.onEnter = onEnter
        data.onExit = onExit
        zones[#zones + 1] = Spheres.create(data)
        else
        local data = Config.Zones[i]
        zones[#zones + 1] = Spheres.create(data)
        end
    end
end

RegisterCommand('hosted', function()
    if LocalPlayer.state.customORG then return end
    -- if PlayerData.job.grade >= 3 then
        if currentBitka == nil and isInZone and isInOrg and LocalPlayer.state.currentSphere then
            OpenBitkiReadyMenu()
        end
    -- end
end)


RegisterKeyMapping('hosted', 'Otwórz menu Hostowanej Bitki', 'keyboard', 'F4')

RegisterNetEvent('michalxdl-arenki:startBitka', function(info)
    local jobek = nil
    if LocalPlayer.state.customORG then
        jobek = LocalPlayer.state.customORG
    else
        jobek = {name = PlayerData.job.name}
    end
    if jobek.name ~= info.receiver and jobek.name ~= info.initiator then
        return 
    end
    zones[#zones + 1] = Spheres.create(Config.Zones[info.zone])
    exports['michalxdl']:JoinOrgFrequency()
    ESX.ShowNotification('Trwa bitka: ' .. info.receiverLabel .. ' kontra ' .. info.initiatorLabel)
    dead = false
    currentBitka = info
    SetEntityHealth(PlayerPedId(), 200)
    LocalPlayer.state:set('inBitka', info.id, true)
    FreezeEntityPosition(PlayerPedId(), true)
    local vehicle = GetVehiclePedIsIn(PlayerPedId())
    if vehicle ~= 0 then
        LastVeh = vehicle
        LastColor = GetVehicleColours
        for i= -1, 12 do
            if GetPedInVehicleSeat(vehicle, i) == PlayerPedId() then
                LastSeat = i
            end
        end
        FreezeEntityPosition(vehicle, true)
        SetVehicleEngineHealth(vehicle, 1000.0)
        SetVehicleUndriveable(vehicle, false)
        SetVehicleFixed(vehicle)
        SetVehicleColours(vehicle, Config.Colors[jobek.name], Config.Colors[jobek.name])
    end
    SendNUIMessage({
        type = "ShowUI",
        firstteam = info.receiverLabel,
        secondteam = info.initiatorLabel
    })
    SendNUIMessage({
        type = "Set",
        toSet = "#players1",
        players = #info.receiverPlayers,
    })
    SendNUIMessage({
        type = "Set",
        toSet = "#players2",
        players = #info.initiatorPlayers,
    })
    SendNUIMessage({
        type = "showCountdown",
        team1 = info.receiverLabel,
        team2 = info.initiatorLabel
    })
    Wait(3000)
    FreezeEntityPosition(vehicle, false)
    FreezeEntityPosition(PlayerPedId(), false)
    PlaySoundFrontend(-1, 'Beep_Green',	'DLC_HEIST_HACKING_SNAKE_SOUNDS')
    -- ESX.Scaleform.ShowFreemodeMessage(info.receiverLabel.. " VS "..info.initiatorLabel, 'Kto Wygra?', 1)
    started = true
end)
local ped = PlayerPedId()

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(3000)
        ped = PlayerPedId()
        if LocalPlayer.state.currentSphere then
            if not LocalPlayer.state.inBitka then
                if LocalPlayer.state.dead then
                    TriggerEvent('esx_ambulancejob:revive')
                    ESX.ShowNotification('Otrzymałeś reva z powodu bycie na terenie HOSTOWANIA')
                end
            end
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(4.9) 
        local ped = PlayerPedId()

        if LocalPlayer.state.inBitka then
            local playerCoords = GetEntityCoords(ped)
            local currentZone = nil

            -- Znajdź strefę, w której znajduje się gracz
            for k, v in pairs(Config.Zones) do
                local distance = #(playerCoords - v.coords)
                if distance <= v.radius then
                    currentZone = v
                    break
                end
            end

            -- Jeśli gracz znajduje się w strefie bitwy, narysuj marker
            if currentZone then
                local distanceToBorder = currentZone.radius - #(playerCoords - currentZone.coords)
                if distanceToBorder <= 50.0 then
                    DrawMarker(28, currentZone.coords.x, currentZone.coords.y, currentZone.coords.z, 
                               0.0, 0.0, 0.0, 
                               0.0, 0.0, 0.0, 
                               currentZone.radius, currentZone.radius, currentZone.radius, 
                               255, 0, 0, 100, false, false, 0, false, false, false, false)
                end
            end
        end
    end
end)



local przenikanie = false
Citizen.CreateThread(function()
    while true do
        Wait(888)
        local plrCoords = GetEntityCoords(ped)
        -- if not LocalPlayer.state.inBitka then
            for v in EnumerateVehicles() do
                -- if not LocalPlayer.state.inBitka or przenikanie then
                    if #(plrCoords - GetEntityCoords(v)) < (przenikanie and 20 or 4.5) or LocalPlayer.state.currentSphere then
                        if LocalPlayer.state.currentSphere or (not IsVehicleSeatFree(v, -1) and GetVehicleClass(v) ~= 14) then
                            SetEntityNoCollisionEntity(ped, v, true)
                            SetEntityNoCollisionEntity(v, ped, true)
                            if (LocalPlayer.state.currentSphere and not LocalPlayer.state.inBitka) or przenikanie then
                                SetEntityNoCollisionEntity(GetVehiclePedIsIn(ped), v, true)
                                SetEntityNoCollisionEntity(v, GetVehiclePedIsIn(ped), true)
                                SetEntityAlpha(v, 100)
                            else
                                ResetEntityAlpha(v)
                            end
                        else
                            ResetEntityAlpha(v)
                        end
                    else
                        ResetEntityAlpha(v)
                    end  
                -- else
                --     ResetEntityAlpha(v)
                -- end
            end
        -- end
    end
 end)

function KillBitka(killer)
    if currentBitka ~= nil then
        Wait(500)
        TriggerServerEvent('michalxdl-arenki:kill', currentBitka.id, killer)
    end
end

DrawText = function(text)
    SetTextFont(4)
	SetTextCentre(true)
	SetTextProportional(1)
	SetTextScale(0.45, 0.45)
	SetTextColour(255, 255, 255, 255)
	SetTextDropShadow(0, 0, 0, 0, 255)
	SetTextEdge(1, 0, 0, 0, 255)
	SetTextDropShadow()
	SetTextOutline()

	BeginTextCommandDisplayText('STRING')
	AddTextComponentSubstringPlayerName(text)
	EndTextCommandDisplayText(0.5, 0.825)
end

RegisterNetEvent('michas:addKill', function(toUpdate) 
    SendNUIMessage({
        type = "Update",
        toUpdate = toUpdate
    })
end)

AddEventHandler('esx:onPlayerDeath', function(data)
    if not dead then
        KillBitka(data.killerServerId)
        dead = true
    end
end)

RegisterNetEvent('michalxdl-arenki:exit', function() 
    dead = false
    started = false
    LocalPlayer.state:set('inBitka', nil, true)
    LocalPlayer.state:set('bitkaTeam', nil, true)
    ESX.ShowNotification('Bitka się zakończyła')
    SetVehicleColours(LastVeh, LastColor[1], LastColor[2])
    LastVeh, LastSeat, LastColor = nil, nil, nil
    currentBitka = nil
    for k,v in ipairs(Blips) do
        RemoveBlip(v)
    end
    Blips = {}
end)

RegisterNetEvent('michalxdl-arenki:lootingTime', function(isWin)
    local time = currentBitka.addonLooting and Config.ExtraLootingTime or Config.LootingTime
    ESX.Scaleform.ShowFreemodeMessage(isWin and 'Wygrałeś' or 'Przegrałeś', (isWin and currentBitka.isLooting) and 'Masz ' .. time .. ' sekund na lootowanie' or '', 3)
    if currentBitka.isLooting then
        exports["michalxdl_taskbar"]:taskBar(time * 1000 - 2000, "Czas na lootowanie", true, function(cb) 
            dead = false
            started = false
            LocalPlayer.state:set('inBitka', nil, true)
            LocalPlayer.state:set('bitkaTeam', nil, true)
            ESX.ShowNotification('Bitka się zakończyła')
            -- if Config.Zones[currentBitka.zone].noVehicles then
                Wait(51)
                TriggerServerEvent("michalxdl-arenki:endGame")
            -- else
            --     TaskWarpPedIntoVehicle(PlayerPedId(), LastVeh, LastSeat)
            --     LastVeh, LastSeat = nil, nil
            -- end
            for k,v in ipairs(Blips) do
                RemoveBlip(v)
            end
            Blips = {}
            currentBitka = nil
        end)
    else
        started = false
        dead = false
        LocalPlayer.state:set('inBitka', nil, true)
        LocalPlayer.state:set('bitkaTeam', nil, true)
        ESX.ShowNotification('Bitka się zakończyła')
        -- if Config.Zones[currentBitka.zone].noVehicles then
            Wait(333)
            TriggerServerEvent("michalxdl-arenki:endGame")
        -- else
        --     TaskWarpPedIntoVehicle(PlayerPedId(), LastVeh, LastSeat)
        --     LastVeh, LastSeat = nil, nil
        -- end
        currentBitka = nil
        for k,v in ipairs(Blips) do
            RemoveBlip(v)
        end
        Blips = {}
    end
    SendNUIMessage({
        type = "HideUI",
    })
end)

RegisterNetEvent('michalxdl-arenki:exitCurrentBitka', function()
    -- currentBitka = nil
    -- LocalPlayer.state:set('inBitka', nil, true)
    -- LocalPlayer.state:set('bitkaTeam', nil, true)
    -- dead = false
    -- TriggerEvent("michalxdl-arenki:exit")
    for k,v in ipairs(Blips) do
        RemoveBlip(v)
    end
    Blips = {}
end)
 -- {132, 3, 252} or {3, 252, 78}
RegisterNetEvent('michalxdl-arenki:killers', function(killers)
    local msg = ""
    table.sort(killers, function(a, b)
        return b.kills < a.kills
    end)
    table.sort(killers, function(a, b)
        return b.job < a.job
    end)
    local lastjob = nil
    local changed = false
    local changenow = false
    for i=1, #killers, 1 do
        if not lastjob then
            lastjob = killers[i].job
            msg = '<span style="color:rgb(84, 153, 252); font-weight: bold;">'..killers[i].job..'</span>'
        end
        if lastjob ~= killers[i].job then
            lastjob = killers[i].job
            msg = msg .. "<hr>"..'<span style="color:rgb(3, 252, 78); font-weight: bold;">'..killers[i].job..'</span>'
            changed = true
            changenow = true
        end
        msg = msg .."<br>".. killers[i].text
        changenow = false
    end
    ESX.ShowNotification('~w~ZABÓJCY TEJ GRY <br>'..msg, "error")
    TriggerEvent("okokNotify:Alert", "Zabójstwa", msg, 10000, 'error')
end)

RegisterNetEvent('michalxdl-arenki:fixVeh', function(veh)
    local vehicle = NetworkGetEntityFromNetworkId(veh)
    if vehicle and DoesEntityExist(vehicle) then
        SetVehicleEngineHealth(vehicle, 1000.0)
        SetVehicleUndriveable(vehicle, false)
        SetVehicleFixed(vehicle)
    end
end)

RegisterNetEvent('michalxdl-arenki:TP', function(coords, vehicle)
    przenikanie = true
    RequestCollisionAtCoord(coords)
    FreezeEntityPosition(PlayerPedId(), true)
    if not vehicle then
        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z+0.3)
        SetEntityHeading(PlayerPedId(), coords.w)
    end
    SetLocalPlayerAsGhost(false)
    dead = false
    Wait(1000)
    FreezeEntityPosition(PlayerPedId(), true)
    Wait(5000)
    przenikanie = false
end)

function EnumerateVehicles()
    return EnumerateEntities(FindFirstVehicle, FindNextVehicle, EndFindVehicle)
end

function EnumerateEntities(initFunc, moveFunc, disposeFunc)
    return coroutine.wrap(function()
        local iter, id = initFunc()
        if not id or id == 0 then
        disposeFunc(iter)
        return
        end
    
        local enum = {handle = iter, destructor = disposeFunc}
        setmetatable(enum, entityEnumerator)
    
        local next = true
        repeat
        coroutine.yield(id)
        next, id = moveFunc(iter)
        until not next
    
        enum.destructor, enum.handle = nil, nil
        disposeFunc(iter)
    end)
end

RegisterNetEvent('michalxdl-arenki:showInvite')
AddEventHandler('michalxdl-arenki:showInvite', function(id, name, org, skin)
    local accepted = false

	local elements = {}

	table.insert(elements, { label = "Zaakceptuj", value = true })
	table.insert(elements, { label = "Odrzuć", value = false })

	Citizen.CreateThread(function()		
		local menu = ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'xd', {
			title = 'Zaproszenie do bitki od: '..name,
			align = 'center',
			elements = {
				{ label = '<span style="color: lightgreen">Zaakceptuj</span>', value = true },
				{ label = '<span style="color: lightcoral">Odrzuć</span>', value = false },
			}
		}, function(data, menu)
			menu.close()
			if data.current.value then
                TriggerEvent('skinchanger:getSkin', function(mySkin)
                    TriggerEvent('skinchanger:loadClothes', mySkin, skin)
                end)
				TriggerServerEvent("michalxdl-arenki:joinkurwa", org)
			end
		end)
		Wait(5000)
		menu.close()
	end)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
      return
    end
    if LocalPlayer.state.inBitka or greenZone then
        SetEntityCoords(PlayerPedId(), Config.EndBitkaCoords)
        ESX.HideUI()
    end
end)
  
RegisterNetEvent("michalxdl-arenki:updateBlips")
AddEventHandler("michalxdl-arenki:updateBlips", function(myPlayers, otherPlayers, myTeam, otherTeam)
    for k,v in ipairs(Blips) do
        RemoveBlip(v)
    end
    Blips = {}
    for k,v in ipairs(myPlayers) do
        addBlip(v.coords, "[~b~"..myTeam.."~s~] [~b~"..v.src.."~s~", 3)
    end

    for k,v in ipairs(otherPlayers) do
        addBlip(v.coords, "[~r~"..otherTeam.."~s~] [~r~"..v.src.."~s~]", 1)
    end
end)

addBlip = function(coords, name, color)
    local blip = AddBlipForCoord(coords)
    SetBlipSprite(blip, 1)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.85)
    SetBlipColour(blip, color)
    SetBlipCategory(blip, 7)
    SetBlipAsShortRange(blip, false)		
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString('# '..name)
    EndTextCommandSetBlipName(blip)
    Blips[#Blips+1] = blip
end
function Draw3DText(x, y, z, text)
    coords = vector3(x, y, z + 1.0)
    local camCoords = GetFinalRenderedCamCoord()
    local distance = #(coords - camCoords)

    local scale = (1 / distance) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    scale = scale * fov

    SetTextScale(0.0 * scale, 0.55 * scale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    BeginTextCommandDisplayText('STRING')
    SetTextOutline()
    SetTextCentre(true)
    AddTextComponentSubstringPlayerName(text)
    SetDrawOrigin(coords, 0)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(3)
        local letSleep = true
        local dist = #(Config.requestJoinCoords - GetEntityCoords(ped))
        if dist <= 15 then
            letSleep = false
            -- ESX.DrawBigMarker(Config.requestJoinCoords)
            Draw3DText(Config.requestJoinCoords.x, Config.requestJoinCoords.y, Config.requestJoinCoords.z+0.8, '~b~ Nie masz z kim grać? \n ~w~ Znajdź tutaj ekipe do gry!\n ')
            Draw3DText(Config.requestJoinCoords.x, Config.requestJoinCoords.y, Config.requestJoinCoords.z+1.3, '~b~ Masz ekipę? ~w~Wpisz /hosted aby rozpocząć kolejkę!')
            -- ESX.ShowFloatingHelpNotification("Nie masz z kim grac?", vec3(Config.requestJoinCoords.x, Config.requestJoinCoords.y, Config.requestJoinCoords.z+0.8))
            if dist <= 2.3 then
                ESX.ShowHelpNotification("Naciśnij ~INPUT_PICKUP~ aby otworzyć menu.")          
                if IsControlJustReleased(0, 38) then
                    OpenSearchMenu()
                end
            end
        end
        if letSleep then
            Wait(1000)
        end
    end
end)

OpenSearchMenu = function()
    local elements = {
        {label = "Status: ".. (LocalPlayer.state.szukaorg and "<span style='color:green'>Szukasz slota</span>" or "<span style='color:red'>Nie szukasz slota</span>")},
        {label = (LocalPlayer.state.szukaorg and "-> Anuluj <-" or "-> Szukaj Slota <-"), value = "search"}
    }
    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'searchmenubitki', {
        title = 'SLOTY',
        align = 'center',
        elements = elements
    }, function(data, menu)
        menu.close()
        if data.current.value == "search" then
            TriggerServerEvent("michalxdl-arenki:requestJoin", not LocalPlayer.state.szukaorg)
        end
    end, function(data, menu)
        menu.close()
    end)
end
local ficikcwela
function przebieranko(target)
	local id = target
	ESX.TriggerServerCallback("esx_skin:getPlayerSkin", function(cb) 
        if cb.sex == 0 then
            TriggerEvent('esx_skin:getPlayerSkin', function(skin)
                if skin.sex == 0 then
                    TriggerEvent('skinchanger:loadSkin', skin, cb)
                    ESX.ShowNotification('Ustawiono fita osoby hostującej bitkę')
                end
            end)
        end
	end, id)
end

RegisterNetEvent("michalxdl-arenki:ficik")
AddEventHandler("michalxdl-arenki:ficik", function(id)
    przebieranko(id)
end)

function GetTableLength(table)
    local index = 0
    
    for i,v in ipairs(table) do
        index += 1
    end

    return index
end
