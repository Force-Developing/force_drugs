ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

RegisterServerEvent('force_drugsGiveReward')
AddEventHandler('force_drugsGiveReward', function(rewardItem, randomAmount)
    local player = ESX.GetPlayerFromId(source)

    player.addInventoryItem(rewardItem, math.random(5, randomAmount))
end)
