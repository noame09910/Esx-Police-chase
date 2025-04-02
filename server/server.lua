ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Initialize state variables
GlobalState.currentChaseId = 0
GlobalState.activePoliceOfficers = {}

-- Function to get chase ID from state key
local function getChaseId(key)
    local chaseId = string.match(key, "^(%d+):ActivePoliceChases")
    return tonumber(chaseId)
end

-- Update active police officers
Citizen.CreateThread(function()
    while true do
        local activePoliceOfficers = {}
        local xPlayers = ESX.GetPlayers()
        
        for i=1, #xPlayers do
            local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
            if xPlayer and xPlayer.job.name == 'police' and xPlayer.job.onDuty then
                activePoliceOfficers[xPlayer.source] = true
            end
        end
        
        GlobalState.activePoliceOfficers = activePoliceOfficers
        Citizen.Wait(5000) -- Update every 5 seconds
    end
end)

-- Register a new chase
RegisterNetEvent("esx_policechase:registerNewChase")
AddEventHandler("esx_policechase:registerNewChase", function(targetNetId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if xPlayer and xPlayer.job.name == 'police' and xPlayer.job.onDuty then
        local targetEntity = NetworkGetEntityFromNetworkId(targetNetId)
        if DoesEntityExist(targetEntity) then
            local targetPed = GetPedInVehicleSeat(targetEntity, -1)
            if targetPed ~= 0 then
                local targetPlayer = NetworkGetEntityOwner(targetPed)
                if targetPlayer then
                    -- Increment chase ID
                    local chaseId = (GlobalState.currentChaseId or 0) + 1
                    GlobalState.currentChaseId = chaseId
                    
                    -- Set chase state
                    GlobalState[chaseId..":ActivePoliceChases:targetNetId"] = targetNetId
                    GlobalState[chaseId..":ActivePoliceChases:targetPlayer"] = targetPlayer
                    GlobalState[chaseId..":ActivePoliceChases:startTime"] = os.time()
                    GlobalState[chaseId..":ActivePoliceChases:inPoliceRadius"] = true
                    GlobalState[chaseId..":ActivePoliceChases:currentPosition"] = GetEntityCoords(targetEntity)
                    
                    -- Notify target player
                    TriggerClientEvent("esx_policechase:chaseStarted", targetPlayer)
                    
                    -- Notify all police officers
                    local xPlayers = ESX.GetPlayers()
                    for i=1, #xPlayers do
                        local xPolice = ESX.GetPlayerFromId(xPlayers[i])
                        if xPolice and xPolice.job.name == 'police' and xPolice.job.onDuty then
                            TriggerClientEvent('ox_lib:notify', xPolice.source, { 
                                title = "מערכת מרדפים", 
                                description = "מרדף חדש התחיל! בדוק את המפה שלך.", 
                                icon = "fa-car-on",
                                iconColor = '#228b22',
                                position = "top",
                                style = {
                                    backgroundColor = '#141517',
                                    color = '#909296'
                                }
                            })
                            TriggerClientEvent('esx_policechase:createBlip', xPolice.source, targetNetId)
                        end
                    end
                    
                    -- Start chase monitoring
                    StartChaseMonitoring(chaseId, targetNetId, targetPlayer)
                end
            end
        end
    end
end)

-- Monitor active chase
function StartChaseMonitoring(chaseId, targetNetId, targetPlayer)
    Citizen.CreateThread(function()
        local lastSeenTime = os.time()
        local startTime = os.time()
        local pitEligible = false
        local pitTimer = Config.pitTimer
        
        -- Set PIT maneuver eligibility after timer
        Citizen.SetTimeout(pitTimer, function()
            pitEligible = true
            -- Notify police officers that PIT is now allowed
            local xPlayers = ESX.GetPlayers()
            for i=1, #xPlayers do
                local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
                if xPlayer and xPlayer.job.name == 'police' and xPlayer.job.onDuty then
                    TriggerClientEvent('ox_lib:notify', xPlayer.source, { 
                        title = "מערכת מרדפים", 
                        description = "ניתן לבצע תמרון PIT על הרכב הנמלט!", 
                        icon = "fa-car-burst",
                        iconColor = '#228b22',
                        position = "top",
                        style = {
                            backgroundColor = '#141517',
                            color = '#909296'
                        }
                    })
                end
            end
        end)
        
        while true do
            Citizen.Wait(1000)
            
            -- Check if target entity still exists
            if not NetworkDoesNetworkIdExist(targetNetId) then
                EndChase(chaseId, targetPlayer, "הרכב הנמלט נעלם")
                break
            end
            
            local targetEntity = NetworkGetEntityFromNetworkId(targetNetId)
            if not DoesEntityExist(targetEntity) then
                EndChase(chaseId, targetPlayer, "הרכב הנמלט נעלם")
                break
            end
            
            -- Update target position
            local targetPos = GetEntityCoords(targetEntity)
            GlobalState[chaseId..":ActivePoliceChases:currentPosition"] = targetPos
            
            -- Check if any police officers are nearby
            local policeNearby = false
            local xPlayers = ESX.GetPlayers()
            for i=1, #xPlayers do
                local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
                if xPlayer and xPlayer.job.name == 'police' and xPlayer.job.onDuty then
                    local playerPed = GetPlayerPed(xPlayer.source)
                    if DoesEntityExist(playerPed) then
                        local policePos = GetEntityCoords(playerPed)
                        local distance = #(targetPos - policePos)
                        
                        if distance < 100.0 then
                            policeNearby = true
                            lastSeenTime = os.time()
                            break
                        end
                    end
                end
            end
            
            -- Update police radius state
            if policeNearby and not GlobalState[chaseId..":ActivePoliceChases:inPoliceRadius"] then
                GlobalState[chaseId..":ActivePoliceChases:inPoliceRadius"] = true
                -- Notify target that police are nearby
                TriggerClientEvent('ox_lib:notify', targetPlayer, { 
                    title = "מערכת מרדפים", 
                    description = "המשטרה קרובה אליך!", 
                    icon = "fa-triangle-exclamation",
                    iconColor = '#C53030',
                    position = "top",
                    style = {
                        backgroundColor = '#141517',
                        color = '#909296'
                    }
                })
            elseif not policeNearby and GlobalState[chaseId..":ActivePoliceChases:inPoliceRadius"] then
                GlobalState[chaseId..":ActivePoliceChases:inPoliceRadius"] = false
                -- Notify police that target is escaping
                local xPlayers = ESX.GetPlayers()
                for i=1, #xPlayers do
                    local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
                    if xPlayer and xPlayer.job.name == 'police' and xPlayer.job.onDuty then
                        TriggerClientEvent('ox_lib:notify', xPlayer.source, { 
                            title = "מערכת מרדפים", 
                            description = "הרכב הנמלט מתרחק! מהר לפני שהוא יברח!", 
                            icon = "fa-person-running",
                            iconColor = '#C53030',
                            position = "top",
                            style = {
                                backgroundColor = '#141517',
                                color = '#909296'
                            }
                        })
                    end
                end
            end
            
            -- Check if target has escaped (not seen for timeUntilDisappear)
            if os.time() - lastSeenTime > Config.timeUntilDisappear / 1000 then
                EndChase(chaseId, targetPlayer, "הרכב הנמלט הצליח לברוח!")
                break
            end
            
            -- Check if chase has been going on too long (optional)
            if os.time() - startTime > 15 * 60 then -- 15 minutes max chase time
                EndChase(chaseId, targetPlayer, "המרדף נמשך זמן רב מדי ובוטל")
                break
            end
        end
    end)
end

-- End an active chase
function EndChase(chaseId, targetPlayer, reason)
    -- Clear chase state
    GlobalState[chaseId..":ActivePoliceChases:targetNetId"] = nil
    GlobalState[chaseId..":ActivePoliceChases:targetPlayer"] = nil
    GlobalState[chaseId..":ActivePoliceChases:startTime"] = nil
    GlobalState[chaseId..":ActivePoliceChases:inPoliceRadius"] = nil
    GlobalState[chaseId..":ActivePoliceChases:currentPosition"] = nil
    
    -- Notify target player
    TriggerClientEvent("esx_policechase:currentlyBeingChased", targetPlayer, false)
    TriggerClientEvent("esx_policechase:endChase", targetPlayer)
    
    -- Notify all police officers
    local xPlayers = ESX.GetPlayers()
    for i=1, #xPlayers do
        local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
        if xPlayer and xPlayer.job.name == 'police' and xPlayer.job.onDuty then
            TriggerClientEvent('ox_lib:notify', xPlayer.source, { 
                title = "מערכת מרדפים", 
                description = reason or "המרדף הסתיים", 
                icon = "fa-flag-checkered",
                iconColor = '#C53030',
                position = "top",
                style = {
                    backgroundColor = '#141517',
                    color = '#909296'
                }
            })
            TriggerClientEvent("esx_policechase:endChase", xPlayer.source)
        end
    end
end

-- Event when a police officer sees a chased vehicle
RegisterNetEvent("esx_policechase:seenActiveChasedVehicle")
AddEventHandler("esx_policechase:seenActiveChasedVehicle", function(targetNetId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if xPlayer and xPlayer.job.name == 'police' and xPlayer.job.onDuty then
        -- Find the chase ID for this target
        local chaseId = nil
        for id = 1, GlobalState.currentChaseId do
            if GlobalState[id..":ActivePoliceChases:targetNetId"] == targetNetId then
                chaseId = id
                break
            end
        end
        
        if chaseId then
            -- Update the chase state to indicate the target is in police radius
            GlobalState[chaseId..":ActivePoliceChases:inPoliceRadius"] = true
        end
    end
end)

-- Event to manually end a chase (e.g., when suspect is arrested)
RegisterNetEvent("esx_policechase:endChaseManually")
AddEventHandler("esx_policechase:endChaseManually", function(targetNetId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if xPlayer and xPlayer.job.name == 'police' and xPlayer.job.onDuty then
        -- Find the chase ID for this target
        local chaseId = nil
        for id = 1, GlobalState.currentChaseId do
            if GlobalState[id..":ActivePoliceChases:targetNetId"] == targetNetId then
                chaseId = id
                break
            end
        end
        
        if chaseId then
            local targetPlayer = GlobalState[chaseId..":ActivePoliceChases:targetPlayer"]
            EndChase(chaseId, targetPlayer, "החשוד נעצר")
        end
    end
end)

-- Helper function to get chase ID from state key
function getChaseId(key)
    local chaseId = string.match(key, "^(%d+):ActivePoliceChases")
    return tonumber(chaseId)
end

-- Player disconnection handling
AddEventHandler('playerDropped', function()
    local source = source
    
    -- Check if this player is being chased
    for id = 1, GlobalState.currentChaseId do
        if GlobalState[id..":ActivePoliceChases:targetPlayer"] == source then
            EndChase(id, source, "החשוד התנתק מהשרת")
        end
    end
    
    -- Remove from active police officers if applicable
    if GlobalState.activePoliceOfficers[source] then
        local activePoliceOfficers = GlobalState.activePoliceOfficers
        activePoliceOfficers[source] = nil
        GlobalState.activePoliceOfficers = activePoliceOfficers
    end
end)

RegisterNetEvent("esx_policechase:confirmChaseStart")
AddEventHandler("esx_policechase:confirmChaseStart", function()
    local source = source
    -- Find the chase where this player is the target
    for id = 1, GlobalState.currentChaseId do
        if GlobalState[id..":ActivePoliceChases:targetPlayer"] == source then
            -- Notify all police officers that the chase is confirmed
            local xPlayers = ESX.GetPlayers()
            for i=1, #xPlayers do
                local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
                if xPlayer and xPlayer.job.name == 'police' and xPlayer.job.onDuty then
                    TriggerClientEvent('ox_lib:notify', xPlayer.source, { 
                        title = "מערכת מרדפים", 
                        description = "החשוד זוהה והמרדף החל!", 
                        icon = "fa-person-running",
                        iconColor = '#228b22',
                        position = "top",
                        style = {
                            backgroundColor = '#141517',
                            color = '#909296'
                        }
                    })
                end
            end
            break
        end
    end
end)

