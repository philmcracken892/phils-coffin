local RSGCore = exports['rsg-core']:GetCoreObject()
local deployedCoffins = {}


RSGCore.Functions.CreateUseableItem("coffin", function(source, item)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then
        print("Debug: Player not found for source ", src)
        return
    end

    local hasItem = Player.Functions.GetItemByName("coffin")
    if not hasItem or hasItem.amount <= 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Error",
            description = "You don't have a coffin!",
            type = 'error'
        })
        return
    end

    if deployedCoffins[src] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Error",
            description = "You already have a coffin placed!",
            type = 'error'
        })
        return
    end

    deployedCoffins[src] = true
    TriggerClientEvent('rsg-coffin:client:openCoffinMenu', src)
    Player.Functions.RemoveItem("coffin", 1)
    TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items["coffin"], "remove")
end)


RegisterNetEvent('rsg-coffin:server:returnCoffin', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then
        print("Debug: Player not found for source ", src)
        return
    end

    if not deployedCoffins[src] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Error",
            description = "You haven't placed a coffin!",
            type = 'error'
        })
        return
    end

    if not RSGCore.Shared.Items["coffin"] then
        print("Error: 'coffin' item not found in RSGCore.Shared.Items")
        return
    end

    Player.Functions.AddItem("coffin", 1)
    TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items["coffin"], "add")
    deployedCoffins[src] = nil
end)


RegisterServerEvent('rsg-coffin:server:addBody', function(npchash, npclabel, npclooted)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then
        print("Debug: Player not found for source ", src)
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    local maxBodies = Config.MaxBodiesStored
    
   
    local currentCount = MySQL.prepare.await("SELECT COUNT(*) as count FROM `phils_coffin_inventory` WHERE citizenid = ?", { citizenid })
    
    if currentCount >= maxBodies then
        TriggerClientEvent('ox_lib:notify', src, { 
            title = 'Coffin Full', 
            description = 'Coffin can only hold ' .. maxBodies .. ' bodies.', 
            type = 'error', 
            duration = 5000 
        })
        return
    end

    
    local success, err = pcall(function()
        MySQL.insert('INSERT INTO `phils_coffin_inventory`(citizenid, animalhash, animallabel, animallooted) VALUES(?, ?, ?, ?)', {
            citizenid,
            tostring(npchash),
            npclabel,
            npclooted and 1 or 0
        })
    end)

    if success then
        TriggerClientEvent('ox_lib:notify', src, { 
            title = 'Body Stored', 
            description = npclabel .. ' stored in coffin.', 
            type = 'success', 
            duration = 5000 
        })
    else
        print("Debug: Failed to store body: ", err)
        TriggerClientEvent('ox_lib:notify', src, { 
            title = 'Error', 
            description = 'Failed to store body!', 
            type = 'error', 
            duration = 5000 
        })
    end
end)


RSGCore.Functions.CreateCallback('rsg-coffin:server:getCoffinInventory', function(source, cb)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then 
        print("Debug: Player not found for getCoffinInventory callback")
        return cb({}) 
    end
    
    local citizenid = Player.PlayerData.citizenid
    local success, inventory = pcall(function()
        return MySQL.query.await('SELECT * FROM `phils_coffin_inventory` WHERE citizenid = ?', { citizenid })
    end)
    
    if success then
        cb(inventory or {})
    else
        print("Debug: Error getting coffin inventory: ", inventory)
        cb({})
    end
end)


RSGCore.Functions.CreateCallback('rsg-coffin:server:getBodyCount', function(source, cb)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then 
        print("Debug: Player not found for getBodyCount callback")
        return cb(0) 
    end
    
    local citizenid = Player.PlayerData.citizenid
    local success, result = pcall(function()
        return MySQL.prepare.await("SELECT COUNT(*) as count FROM `phils_coffin_inventory` WHERE citizenid = ?", { citizenid })
    end)
    
    if success then
        cb(result or 0)
    else
        print("Debug: Error getting body count: ", result)
        cb(0)
    end
end)


RegisterServerEvent('rsg-coffin:server:removeBody', function(bodyId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then 
        print("Debug: Player not found for removeBody")
        return 
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    local success, result = pcall(function()
        return MySQL.query.await('SELECT * FROM `phils_coffin_inventory` WHERE id = ? AND citizenid = ?', { bodyId, citizenid })
    end)
    
    if success and result and result[1] then
        local bodyData = result[1]
        
       
        local deleteSuccess = pcall(function()
            MySQL.update('DELETE FROM `phils_coffin_inventory` WHERE id = ? AND citizenid = ?', { bodyId, citizenid })
        end)
        
        if deleteSuccess then
            TriggerClientEvent('rsg-coffin:client:takeOutBody', src, bodyData.animalhash, bodyData.animallooted)
        else
            TriggerClientEvent('ox_lib:notify', src, { 
                title = 'Error', 
                description = 'Failed to remove body from database!', 
                type = 'error', 
                duration = 5000 
            })
        end
    else
        TriggerClientEvent('ox_lib:notify', src, { 
            title = 'Error', 
            description = 'Body not found!', 
            type = 'error', 
            duration = 5000 
        })
    end
end)


RegisterServerEvent('rsg-coffin:server:sellBodies', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then
        print("Debug: Player not found for source ", src)
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    local success, bodies = pcall(function()
        return MySQL.query.await('SELECT * FROM `phils_coffin_inventory` WHERE citizenid = ?', { citizenid })
    end)
    
    if not success or not bodies or #bodies == 0 then
        TriggerClientEvent('ox_lib:notify', src, { 
            title = 'No Bodies', 
            description = 'No bodies to sell in the coffin.', 
            type = 'error', 
            duration = 5000 
        })
        return
    end

    local pricePerBody = Config.PricePerBody
    local totalPrice = #bodies * pricePerBody
    
   
    local deleteSuccess = pcall(function()
        MySQL.update('DELETE FROM `phils_coffin_inventory` WHERE citizenid = ?', { citizenid })
    end)
    
    if deleteSuccess then
        Player.Functions.AddMoney('cash', totalPrice)
        TriggerClientEvent('ox_lib:notify', src, { 
            title = 'Bodies Sold', 
            description = 'Sold ' .. #bodies .. ' bodies for $' .. totalPrice, 
            type = 'success', 
            duration = 5000 
        })
        TriggerClientEvent('rsg-coffin:client:bodiesSold', src)
    else
        TriggerClientEvent('ox_lib:notify', src, { 
            title = 'Error', 
            description = 'Failed to sell bodies!', 
            type = 'error', 
            duration = 5000 
        })
    end
end)


AddEventHandler('playerDropped', function(reason)
    local src = source
    if deployedCoffins[src] then
        deployedCoffins[src] = nil
        print("Debug: Cleaned up deployed coffin for disconnected player ", src)
    end
end)


AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
   
    deployedCoffins = {}
end)