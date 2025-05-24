local RSGCore = exports['rsg-core']:GetCoreObject()
local deployedCoffin = nil
local deployedOwner = nil
local isInteracting = false
local currentCoffinData = nil

local CHECK_RADIUS = 2.0
local COFFIN_PROPS = {
    {
        label = "Coffin",
        model = `p_coffin01x`,
        offset = vector3(0.0, -0.1, 0.0)
    }
}


local function RegisterCoffinTargeting()
    local models = {}
    for _, coffin in ipairs(COFFIN_PROPS) do
        table.insert(models, coffin.model)
    end

    exports['ox_target']:addModel(models, {
        {
            name = 'pickup_coffin',
            event = 'rsg-coffin:client:pickupCoffin',
            icon = "fas fa-hand",
            label = "Pick Up Coffin",
            distance = 2.0,
            canInteract = function(entity)
                return not isInteracting and deployedOwner == GetPlayerServerId(PlayerId())
            end
        },
        {
            name = 'store_body',
            event = 'rsg-coffin:client:addBody',
            icon = "fas fa-circle-down",
            label = "Store Body",
            distance = 2.0,
            canInteract = function(entity)
                return not isInteracting and deployedOwner == GetPlayerServerId(PlayerId())
            end
        },
        ---{
            --name = 'retrieve_body',
            --event = 'rsg-coffin:client:getCoffinInventory',
           -- icon = "fas fa-circle-up",
            --label = "Retrieve Body",
            --distance = 2.0,
            --canInteract = function(entity)
               -- return not isInteracting and deployedOwner == GetPlayerServerId(PlayerId())
            ---end
        --},
        {
            name = 'sell_body',
            event = 'rsg-coffin:client:sellBodies',
            icon = "fas fa-dollar-sign",
            label = "Sell Bodies",
            distance = 2.0,
            canInteract = function(entity)
                return not isInteracting and deployedOwner == GetPlayerServerId(PlayerId())
            end
        }
    })
end


local function ShowCoffinMenu()
    if not lib then
        lib.notify({
            title = "Error",
            description = "ox_lib is not loaded!",
            type = 'error'
        })
        return
    end
    ExecuteCommand('closeInv')
    local coffinOptions = {}
    for i, coffin in ipairs(COFFIN_PROPS) do
        table.insert(coffinOptions, {
            title = coffin.label,
            description = "Place a " .. coffin.label,
            icon = 'fas fa-hand',
            onSelect = function()
                TriggerEvent('rsg-coffin:client:placeCoffin', i)
            end
        })
    end

    lib.registerContext({
        id = 'coffin_selection_menu',
        title = 'Select Coffin Style',
        options = coffinOptions
    })

    lib.showContext('coffin_selection_menu')
end


RegisterNetEvent('rsg-coffin:client:placeCoffin', function(coffinIndex)
    if deployedCoffin then
        lib.notify({
            title = "Coffin Already Placed",
            description = "You already have a coffin placed.",
            type = 'error'
        })
        return
    end

    local coffinData = COFFIN_PROPS[coffinIndex]
    if not coffinData then return end

    local coords = GetEntityCoords(PlayerPedId())
    local heading = GetEntityHeading(PlayerPedId())
    local forward = GetEntityForwardVector(PlayerPedId())

    local offsetDistance = 1.0
    local coffinX = coords.x + forward.x * offsetDistance
    local coffinY = coords.y + forward.y * offsetDistance
    local coffinZ = coords.z

    RequestModel(coffinData.model)
    local timeout = 5000
    local startTime = GetGameTimer()
    while not HasModelLoaded(coffinData.model) do
        Wait(100)
        if GetGameTimer() - startTime > timeout then
            lib.notify({
                title = "Error",
                description = "Failed to load coffin model.",
                type = 'error'
            })
            return
        end
    end

    TaskStartScenarioInPlace(PlayerPedId(), GetHashKey('WORLD_HUMAN_CROUCH_INSPECT'), -1, true, false, false, false)
    Wait(2000)

    local coffinObject = CreateObject(coffinData.model, coffinX, coffinY, coffinZ, true, false, false)
    PlaceObjectOnGroundProperly(coffinObject)
    SetEntityHeading(coffinObject, heading)
    FreezeEntityPosition(coffinObject, true)

    SetModelAsNoLongerNeeded(coffinData.model) 

    deployedCoffin = coffinObject
    currentCoffinData = coffinData
    deployedOwner = GetPlayerServerId(PlayerId())

    Wait(500)
    ClearPedTasks(PlayerPedId())
end)


RegisterNetEvent('rsg-coffin:client:pickupCoffin', function()
    if not deployedCoffin then
        lib.notify({
            title = "No Coffin",
            description = "There's no coffin to pick up.",
            type = 'error'
        })
        return
    end

    if deployedOwner ~= GetPlayerServerId(PlayerId()) then
        lib.notify({
            title = "Not Yours",
            description = "You cannot pick up someone else's coffin.",
            type = 'error'
        })
        return
    end

    if isInteracting then
        lib.notify({
            title = "Cannot Pick Up",
            description = "You can't pick up the coffin while interacting with it.",
            type = 'error'
        })
        return
    end

    local ped = PlayerPedId()
    LocalPlayer.state:set('inv_busy', true, true)
    TaskStartScenarioInPlace(ped, GetHashKey('WORLD_HUMAN_CROUCH_INSPECT'), -1, true, false, false, false)
    Wait(2000)

    if deployedCoffin and DoesEntityExist(deployedCoffin) then
        DeleteObject(deployedCoffin)
        deployedCoffin = nil
        currentCoffinData = nil
        TriggerServerEvent('rsg-coffin:server:returnCoffin')
        deployedOwner = nil
    end

    ClearPedTasks(ped)
    LocalPlayer.state:set('inv_busy', false, true)

    lib.notify({
        title = 'Coffin Picked Up',
        description = 'You have retrieved your coffin.',
        type = 'success'
    })
end)

-- Add body to coffin
RegisterNetEvent('rsg-coffin:client:addBody', function()
    if not deployedCoffin then
        lib.notify({ title = 'No Coffin', description = 'You must place a coffin first!', type = 'error', duration = 5000 })
        return
    end

    local ped = PlayerPedId()
    local holding = Citizen.InvokeNative(0xD806CD2A4F2C2996, ped)
    if not holding or holding == 0 then
        lib.notify({ title = 'No Body', description = 'You are not holding a body!', type = 'error', duration = 5000 })
        return
    end

    local holdinghash = GetEntityModel(holding)
    local holdinglooted = Citizen.InvokeNative(0x8DE41E9902E85756, holding)
    local pedType = Citizen.InvokeNative(0xFF059E1E4C01E63C, holding)
    local entityExists = DoesEntityExist(holding)
    local isAPed = IsEntityAPed(holding)
    local notPlayer = holding ~= ped
    local isHumanPed = pedType == 4

    if entityExists and isAPed and notPlayer and isHumanPed then
        local modelhash = holdinghash
        local modellabel = "Body"
        local modellooted = holdinglooted
        local deleted = DeleteThis(holding, modellabel)
        if deleted then
            TriggerServerEvent('rsg-coffin:server:addBody', modelhash, modellabel, modellooted)
            RSGCore.Functions.TriggerCallback('rsg-coffin:server:getBodyCount', function(count)
                --lib.notify({ title = 'Body Count', description = count .. '/' .. Config.MaxBodiesStored .. ' bodies in coffin.', type = 'inform', duration = 5000 })
            end)
        end
    else
        local errorMsg = pedType == 28 and "You cannot store animals in the coffin!" or "Held entity is not a valid human NPC!"
        lib.notify({ title = 'Invalid Body', description = errorMsg, type = 'error', duration = 5000 })
    end
end)

function DeleteThis(holding, modellabel)
    local attempts = 0
    while not NetworkRequestControlOfEntity(holding) and attempts < 5 do
        Wait(100)
        attempts = attempts + 1
    end
    if attempts >= 5 then
        lib.notify({ title = 'Error', description = 'Failed to gain control of body!', type = 'error', duration = 5000 })
        return false
    end
    SetEntityAsMissionEntity(holding, true, true)
    Wait(100)
    lib.progressBar({
        duration = Config.StoreTime,
        label = 'Storing ' .. modellabel .. ' in coffin',
        useWhileDead = false,
        canCancel = false
    })
    DeleteEntity(holding)
    Wait(500)
    local entitycheck = Citizen.InvokeNative(0xD806CD2A4F2C2996, PlayerPedId())
    return entitycheck == 0 or not DoesEntityExist(entitycheck)
end


RegisterNetEvent('rsg-coffin:client:getCoffinInventory', function()
    if not deployedCoffin then
        lib.notify({ title = 'No Coffin', description = 'You must place a coffin first!', type = 'error', duration = 5000 })
        return
    end

    RSGCore.Functions.TriggerCallback('rsg-coffin:server:getCoffinInventory', function(results)
        if not results or #results == 0 then
            lib.notify({ title = 'No Bodies', description = 'No bodies in the coffin.', type = 'error', duration = 5000 })
            return
        end

        local options = {}
        for _, body in ipairs(results) do
            table.insert(options, {
                title = body.animallabel .. (body.animallooted == 1 and ' (Looted)' or ' (Not Looted)'),
                description = "Retrieve this body from the coffin",
                icon = 'fas fa-circle-up',
                onSelect = function()
                    TriggerServerEvent('rsg-coffin:server:removeBody', body.id)
                end
            })
        end

        lib.registerContext({
            id = 'coffin_inventory_menu',
            title = 'Coffin Inventory',
            options = options
        })
        lib.showContext('coffin_inventory_menu')
    end)
end)

RegisterNetEvent('rsg-coffin:client:takeOutBody', function(npchash, npclooted)
    if not deployedCoffin or not DoesEntityExist(deployedCoffin) then
        lib.notify({ title = 'Error', description = 'No coffin available to retrieve body from!', type = 'error', duration = 5000 })
        return
    end

    local pos = GetOffsetFromEntityInWorldCoords(deployedCoffin, 0.0, -1.0, 0.0)
    local modelHash = tonumber(npchash)
    
    if not HasModelLoaded(modelHash) then
        RequestModel(modelHash)
        local timeout = 5000
        local startTime = GetGameTimer()
        while not HasModelLoaded(modelHash) do
            Wait(100)
            if GetGameTimer() - startTime > timeout then
                lib.notify({ title = 'Error', description = 'Failed to load body model!', type = 'error', duration = 5000 })
                return
            end
        end
    end

    local npc = CreatePed(modelHash, pos.x, pos.y, pos.z, 0.0, true, true, true)
    Wait(100)
    
    
    SetEntityHealth(npc, 0, 0)
    SetEntityAsMissionEntity(npc, true, true)
    
    if npclooted == 1 then
        Citizen.InvokeNative(0x6BCF5F3D8FFE988D, npc, true)
    end
    
    
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, npc, 0, false)

    RSGCore.Functions.TriggerCallback('rsg-coffin:server:getBodyCount', function(count)
        --lib.notify({ title = 'Body Count', description = count .. '/' .. Config.MaxBodiesStored .. ' bodies in coffin.', type = 'inform', duration = 5000 })
    end)
end)


RegisterNetEvent('rsg-coffin:client:sellBodies', function()
    if not deployedCoffin then
        lib.notify({ title = 'No Coffin', description = 'You must place a coffin first!', type = 'error', duration = 5000 })
        return
    end

    RSGCore.Functions.TriggerCallback('rsg-coffin:server:getBodyCount', function(count)
        if count == 0 then
            lib.notify({ title = 'No Bodies', description = 'No bodies to sell in the coffin.', type = 'error', duration = 5000 })
            return
        end

        local input = lib.inputDialog('Sell Bodies', {
            {
                label = 'Confirm selling all ' .. count .. ' bodies in coffin?',
                type = 'select',
                options = {
                    { value = 'yes', label = 'Yes' },
                    { value = 'no', label = 'No' }
                },
                required = true,
                icon = 'fas fa-circle-question'
            }
        })

        if input and input[1] == 'yes' then
            TriggerServerEvent('rsg-coffin:server:sellBodies')
        end
    end)
end)


RegisterNetEvent('rsg-coffin:client:bodiesSold', function()
    RSGCore.Functions.TriggerCallback('rsg-coffin:server:getBodyCount', function(newCount)
        lib.notify({ title = 'Body Count', description = newCount .. '/' .. Config.MaxBodiesStored .. ' bodies in coffin.', type = 'inform', duration = 5000 })
    end)
end)


AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if deployedCoffin and DoesEntityExist(deployedCoffin) then
        DeleteObject(deployedCoffin)
        deployedCoffin = nil
        deployedOwner = nil
        currentCoffinData = nil
    end
end)


AddEventHandler('playerDropped', function()
    if deployedCoffin and DoesEntityExist(deployedCoffin) then
        DeleteObject(deployedCoffin)
        deployedCoffin = nil
        deployedOwner = nil
        currentCoffinData = nil
    end
end)


CreateThread(function()
    RegisterCoffinTargeting()
end)


RegisterNetEvent('rsg-coffin:client:openCoffinMenu', function()
    ShowCoffinMenu()
end)