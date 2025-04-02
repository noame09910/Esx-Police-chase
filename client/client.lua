ESX = nil

local policeChaseModeActive, policeChaseActive, lastChanged = false, false, 0

local mainKeybind = lib.addKeybind({
    name = 'police_chasemode',
    description = 'Toggle Police Chase Mode',
    defaultKey = '6',
    disabled = true,
    onPressed = function(self)
        if (GetGameTimer() - lastChanged) < 3000 then return end

        if policeChaseActive then
            lib.notify({
                id = 'policeChaseMode:disable',
                title = 'מערכת מרדפים',
                description = '.לא ניתן להשתמש בעת מרדף פעיל',
                duration = 2500,
                position = 'top',
                style = {
                    backgroundColor = '#141517',
                    color = '#909296'
                },
                icon = 'power-off',
                iconColor = '#C53030'
            })
            return
        end

        lastChanged = GetGameTimer()

        if policeChaseModeActive then
            lib.notify({
                id = 'policeChaseMode:disable',
                title = 'מערכת מרדפים',
                description = '.כיבית את מערכת המרדפים',
                duration = 2500,
                position = 'top',
                style = {
                    backgroundColor = '#141517',
                    color = '#909296'
                },
                icon = 'power-off',
                iconColor = '#C53030'
            })
        else
            lib.notify({
                id = 'policeChaseMode:disable',
                title = 'מערכת מרדפים',
                description = '.הדלקת את מערכת המרדפים',
                duration = 2500,
                position = 'top',
                style = {
                    backgroundColor = '#141517',
                    color = '#909296'
                },
                icon = 'power-off',
                iconColor = '#228b22'
            })
        end
        policeChaseModeActive = not policeChaseModeActive
    end,
})

RegisterNetEvent("esx_policechase:chaseStarted")
AddEventHandler("esx_policechase:chaseStarted", function()
    currentlyBeingChased = true
    lib.notify({
        title = "מערכת מרדפים",
        description = "המשטרה החלה במרדף אחריך!",
        type = 'error',
        icon = "fa-person-running",
        iconColor = '#C53030',
        position = "top",
        style = {
            backgroundColor = '#141517',
            color = '#909296'
        }
    })
    -- Confirm to the server that we received the chase notification
    TriggerServerEvent("esx_policechase:confirmChaseStart")
end)

-- Update the existing "esx_policechase:currentlyBeingChased" event handler:
RegisterNetEvent("esx_policechase:currentlyBeingChased")
AddEventHandler("esx_policechase:currentlyBeingChased", function(state)
    currentlyBeingChased = state
    if not state then
        lib.notify({
            title = "מערכת מרדפים",
            description = "המרדף הסתיים.",
            type = 'info',
            icon = "fa-flag-checkered",
            iconColor = '#228b22',
            position = "top",
            style = {
                backgroundColor = '#141517',
                color = '#909296'
            }
        })
    end
end)



Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end

    while ESX.GetPlayerData().job == nil do
        Citizen.Wait(100)
    end

    ESX.PlayerData = ESX.GetPlayerData()

    if ESX.PlayerData.job.name == "police" and ESX.PlayerData.job.onDuty then
        mainKeybind:disable(false)
    end
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    local startTimer = GetGameTimer()
    while ESX.GetPlayerData().job.name == ESX.PlayerData.job.name and GetGameTimer() - startTimer < 2500 do
       Wait(10)
    end
    ESX.PlayerData = ESX.GetPlayerData()

    if ESX.PlayerData.job.name == "police" and ESX.PlayerData.job.onDuty then
        mainKeybind:disable(false)
    else
        mainKeybind:disable(true)
    end
end)

CreateThread(function()
    while not ESX or not ESX.PlayerData or not ESX.PlayerData.job do
        Wait(20)
    end

    while true do 
        if ESX.PlayerData.job.name == "police" and ESX.PlayerData.job.onDuty then
            local playerPed = PlayerPedId()
            local playerPedVehicle = GetVehiclePedIsIn(playerPed, false)
    
            if policeChaseModeActive then
                if playerPedVehicle ~= 0 then
                    local playerPedCoords = GetEntityCoords(playerPed)
                    local closeVehicles, finalVehicles, currentlySelectedVehicleKey, currentlySelectedVehicleEntity, vehicleSelected = lib.getNearbyVehicles(playerPedCoords, 25.0, false), {}, 1, 0, false
                    if #closeVehicles > 0 then
                        for vehicleKey, vehicleData in pairs(closeVehicles) do
                            if DoesEntityExist(vehicleData.vehicle) and HasEntityClearLosToEntity(playerPed, vehicleData.vehicle) then
                                local pedInVehicle = GetPedInVehicleSeat(vehicleData.vehicle, -1)
                                if pedInVehicle ~= 0 and IsPedAPlayer(pedInVehicle) then
                                    finalVehicles[#finalVehicles + 1] = vehicleData.vehicle 
                                end
                            end
                        end
    
                        currentlySelectedVehicleEntity = finalVehicles[currentlySelectedVehicleKey]
                    end
    
                    while policeChaseModeActive and #finalVehicles > 0 and not vehicleSelected do
                        if #finalVehicles > 0 and DoesEntityExist(currentlySelectedVehicleEntity) then
                            DrawMarker(2, GetEntityCoords(currentlySelectedVehicleEntity) + vector3(0.0, 0.0, 1.1), 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.5, 0.5, 0.5, 255, 0, 0, 255, false, true)
                        end
    
                        finalVehicles = {}
    
                        playerPedCoords = GetEntityCoords(playerPed)
                        closeVehicles = lib.getNearbyVehicles(playerPedCoords, 25.0, false)
                        local resetPreviousSelectedVehicle = true
                        for vehicleKey, vehicleData in pairs(closeVehicles) do
                            if DoesEntityExist(vehicleData.vehicle) and HasEntityClearLosToEntity(playerPed, vehicleData.vehicle) then
                                local pedInVehicle = GetPedInVehicleSeat(vehicleData.vehicle, -1)
                                if pedInVehicle ~= 0 and IsPedAPlayer(pedInVehicle) then
                                    if vehicleData.vehicle == currentlySelectedVehicleEntity then
                                        resetPreviousSelectedVehicle = false
                                        currentlySelectedVehicleKey = #finalVehicles + 1
                                    end
                                    finalVehicles[#finalVehicles + 1] = vehicleData.vehicle 
                                end
                            end
                        end
    
                        if resetPreviousSelectedVehicle and #finalVehicles > 0 then
                            currentlySelectedVehicleKey = 1
                            currentlySelectedVehicleEntity = finalVehicles[currentlySelectedVehicleKey]
                        end
    
                        if IsControlJustPressed(0, 174) then -- left
                            if currentlySelectedVehicleKey > 1 then
                                currentlySelectedVehicleKey = currentlySelectedVehicleKey - 1
                            else 
                                currentlySelectedVehicleKey = #finalVehicles
                            end
                        elseif IsControlJustPressed(0, 175) then -- right
                            if currentlySelectedVehicleKey < #finalVehicles then
                                currentlySelectedVehicleKey = currentlySelectedVehicleKey + 1
                            else 
                                currentlySelectedVehicleKey = 1
                            end
                        elseif IsControlJustPressed(0, 191) then
                            vehicleSelected = true
                        end
    
                        currentlySelectedVehicleEntity = finalVehicles[currentlySelectedVehicleKey]
    
                        Wait(0)
                    end
    
                    if policeChaseModeActive then
                        local currentlySelectedVehicleEntityNetID = NetworkGetNetworkIdFromEntity(currentlySelectedVehicleEntity)
                        if NetworkDoesEntityExistWithNetworkId(currentlySelectedVehicleEntityNetID) then
                            TriggerServerEvent("esx_policechase:registerNewChase", currentlySelectedVehicleEntityNetID)
                            policeChaseActive = true
                            policeChaseModeActive = false
                        end 
                    end
                end
            end
        end

        Wait(0)
    end
end)

local targetBlips = {}
local policeRadarBlips = {}

CreateThread(function()
    while not ESX or not ESX.PlayerData or not ESX.PlayerData.job do
        Wait(20)
    end

    AddStateBagChangeHandler(nil, 'global', function(bagName, key, value, reserved, replicated)
        if ESX.PlayerData.job.name == "police" and ESX.PlayerData.job.onDuty then
            if key:find("ActivePoliceChases") and key:find("targetNetId") then

                if value == nil then
                    local chaseKey = getChaseId(key)
                    local targetNetId = GlobalState[("%s:ActivePoliceChases:targetNetId"):format(chaseKey)]
                    if targetBlips[targetNetId] then
                        RemoveBlip(targetBlips[targetNetId].handle)
                        targetBlips[targetNetId] = nil
                    end
                end
            end

            if key:find("ActivePoliceChases") and key:find("currentPosition") then
                if xPlayer and xPlayer.job.name == 'police' then
                local entityBlip = false
                local chaseKey = getChaseId(key)
                local targetNetId = GlobalState[("%s:ActivePoliceChases:targetNetId"):format(chaseKey)]
    
                if value then
                    if targetNetId and NetworkDoesNetworkIdExist(targetNetId) and NetworkDoesEntityExistWithNetworkId(targetNetId) then
                        local targetVehicle = NetworkGetEntityFromNetworkId(targetNetId)
                        if DoesEntityExist(targetVehicle) then
                            entityBlip = targetVehicle
                        end
                    end
        
                    if entityBlip then
                        if targetBlips[targetNetId] then
                            if targetBlips[targetNetId].type ~= "entity" then
                                RemoveBlip(targetBlips[targetNetId].handle)
                                local handle = AddBlipForEntity(entityBlip)
                                local flashing = targetBlips[targetNetId].flashing
                                targetBlips[targetNetId] = {handle = handle, type = "entity", flashing = flashing}
                            end
                        else
                            local handle = AddBlipForEntity(entityBlip)
                            targetBlips[targetNetId] = {handle = handle, type = "entity", flashing = not GlobalState[("%s:ActivePoliceChases:inPoliceRadius"):format(chaseKey)]}
                        end
                    else
                        if targetBlips[targetNetId] then
                            if targetBlips[targetNetId].type ~= "coords" then
                                RemoveBlip(targetBlips[targetNetId].handle)
                                local handle = AddBlipForCoord(value)
                                local flashing = targetBlips[targetNetId].flashing
                                SetBlipAsFriendly(handle, false)
                                targetBlips[targetNetId] = {handle = handle, type = "coords", flashing = flashing}
                            else
                                SetBlipCoords(targetBlips[targetNetId].handle, value)
                            end
                        else
                            local handle = AddBlipForCoord(value)
                            SetBlipAsFriendly(handle, false)
                            targetBlips[targetNetId] = {handle = handle, type = "coords", flashing = not GlobalState[("%s:ActivePoliceChases:inPoliceRadius"):format(chaseKey)]}
                        end
                    end 
                end
            end
        end
    
            if key:find("ActivePoliceChases") and key:find("inPoliceRadius") then
                local chaseKey = getChaseId(key)
                local targetNetId = GlobalState[("%s:ActivePoliceChases:targetNetId"):format(chaseKey)]
                if value then
                    if targetBlips[targetNetId] and targetBlips[targetNetId].flashing then
                        SetBlipFlashes(targetBlips[targetNetId].handle, false)
                        
                    end
                elseif value == false then
                    if targetBlips[targetNetId] then
                        targetBlips[targetNetId].flashing = true
                        SetBlipFlashes(targetBlips[targetNetId].handle, true)
                        SetBlipFlashInterval(targetBlips[targetNetId].handle, 250)
                    end
                end
            end
        else
            if key:find("ActivePoliceChases") and key:find("inPoliceRadius") then
                local chaseKey = getChaseId(key)
                local targetPlayer = GlobalState[("%s:ActivePoliceChases:targetPlayer"):format(chaseKey)]
                local player = PlayerId()
                local serverId = GetPlayerServerId(player)
                if serverId == targetPlayer then
                    if value == false then
                        CreateThread(function()
                            Wait(1000)
                            print(chaseKey, GlobalState[("%s:ActivePoliceChases:inPoliceRadius"):format(chaseKey)])
                            while GlobalState[("%s:ActivePoliceChases:inPoliceRadius"):format(chaseKey)] == false do
                                for k, v in pairs(GlobalState.activePoliceOfficers) do
                                    if ESX.PlayerData.job.name == "police" and ESX.PlayerData.job.onDuty then
                                    local officerPlayer = GetPlayerFromServerId(k)
                                    if officerPlayer ~= -1 then
                                        if not policeRadarBlips[k] then
                                            local officerPed = GetPlayerPed(officerPlayer)
                                            local handle = AddBlipForEntity(officerPed)
                                            SetBlipSprite(handle, 20)
                                            SetBlipScale(handle, 0.5)
                                            SetBlipShowCone(handle, true)
                                            policeRadarBlips[k] = {handle = handle}
                                        end
                                    elseif policeRadarBlips[k] then
                                        RemoveBlip(policeRadarBlips[k].handle)
                                        policeRadarBlips[k] = nil
                                    end
                                end
                                end
                                
                                Wait(1000)
                            end

                            for k, v in pairs(policeRadarBlips) do
                                RemoveBlip(v.handle)
                            end
                        end)
                    end
                end
            end
        end
    end)

    while true do 
        if ESX.PlayerData.job.name == "police" and ESX.PlayerData.job.onDuty then
            local playerPed = PlayerPedId()
            local playerPedCoords = GetEntityCoords(playerPed)
            local closeVehicles = lib.getNearbyVehicles(playerPedCoords, 75.0, false)
            if GlobalState.currentChaseId ~= nil then
                for chaseId = GlobalState.currentChaseId, 1, -1 do
                    if GlobalState[("%s:ActivePoliceChases:targetNetId"):format(chaseId)] ~= nil then
                        for vehicleKey, vehicleData in pairs(closeVehicles) do
                            if DoesEntityExist(vehicleData.vehicle) and VehToNet(vehicleData.vehicle) == GlobalState[("%s:ActivePoliceChases:targetNetId"):format(chaseId)] and HasEntityClearLosToEntityInFront(playerPed, vehicleData.vehicle) then
                                TriggerServerEvent("esx_policechase:seenActiveChasedVehicle", GlobalState[("%s:ActivePoliceChases:targetNetId"):format(chaseId)])
                            end
                        end
                    end
                end
            end
        end

        Wait(1000)
    end
end)



local currentlyBeingChased = false

RegisterNetEvent("esx_policechase:currentlyBeingChased", function (state)
    currentlyBeingChased = state
end)

exports('IsCurrentlyBeingChased', function ()
    return currentlyBeingChased
end)

----

local chaseBlip = nil

RegisterNetEvent('esx_policechase:createBlip') -- put dick models on evrybody facew
AddEventHandler('esx_policechase:createBlip', function(targetNetId)
    
    if chaseBlip then
        RemoveBlip(chaseBlip)
    end

    
    chaseBlip = AddBlipForEntity(NetworkGetEntityFromNetworkId(targetNetId))
end)

RegisterNetEvent("esx_policechase:endChase")

function getChaseId(key)
    local chaseId = string.match(key, "^(%d+):ActivePoliceChases")
    return tonumber(chaseId)
end

AddEventHandler("esx_policechase:endChase", function ()
    policeChaseActive = false
    if chaseBlip then
        RemoveBlip(chaseBlip)
        chaseBlip = nil
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if policeChaseActive and chaseBlip then
            local blipCoords = GetBlipCoords(chaseBlip)
            local playerCoords = GetEntityCoords(PlayerPedId())
            if #(playerCoords - blipCoords) > 500 then
                policeChaseActive = false
                --מממממ
                local xPlayer = ESX.GetPlayerFromId(playerId)
                if xPlayer and xPlayer.job.name == 'police' then
                    
                    
                    TriggerClientEvent('ox_lib:notify', playerId, { 
                        title = "מערכת מרדפים", 
                        description = "יש שוטר במרדף ! בדוק את המפה שלך ותגיע לעזרתו.", 
                        icon = "fa-car-on",
                        iconColor = '#C53030',
                        position = "top",
                        style = {
                            backgroundColor = '#141517',
                            color = '#909296'
                        }
                    })
                end
                ---מממממ
                TriggerEvent('esx_policechase:endChase')
                TriggerEvent('esx:getSharedObject', function(obj)
                    ESX = obj
                end)
                Citizen.Wait(100) 
               
                if chaseBlip then
                    RemoveBlip(chaseBlip)
                    chaseBlip = nil
                end
            end
        end
    end
end)


