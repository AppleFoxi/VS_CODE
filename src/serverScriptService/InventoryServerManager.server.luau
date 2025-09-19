-- InventoryServerManager (ServerScriptService)
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local inventoryStore = DataStoreService:GetDataStore("PlayerInventory")
local remoteEvent = Instance.new("RemoteEvent")
remoteEvent.Name = "InventoryEvent"
remoteEvent.Parent = ReplicatedStorage

-- Загрузка данных игрока
local function loadPlayerData(player)
    local success, data = pcall(function()
        return inventoryStore:GetAsync(player.UserId) or {
            Stone = {count = 10, max = 50},
            Wood = {count = 25, max = 100},
            Glass = {count = 5, max = 20},
            Metal = {count = 2, max = 10}
        }
    end)
    
    return success and data or {
        Stone = {count = 10, max = 50},
        Wood = {count = 25, max = 100},
        Glass = {count = 5, max = 20},
        Metal = {count = 2, max = 10}
    }
end

-- Сохранение данных игрока
local function savePlayerData(player, data)
    pcall(function()
        inventoryStore:SetAsync(player.UserId, data)
    end)
end

-- Обработка запросов от клиента
remoteEvent.OnServerEvent:Connect(function(player, action, itemName, amount)
    local playerData = loadPlayerData(player)
    
    if action == "selectItem" then
        -- Проверяем можно ли выбрать предмет
        if playerData[itemName] and playerData[itemName].count > 0 then
            remoteEvent:FireClient(player, "itemSelected", itemName, playerData[itemName].count)
        end
    elseif action == "useItem" then
        -- Использование предмета
        if playerData[itemName] and playerData[itemName].count >= amount then
            playerData[itemName].count = playerData[itemName].count - amount
            savePlayerData(player, playerData)
            remoteEvent:FireClient(player, "itemUsed", itemName, playerData[itemName].count)
        end
    end
end)

-- Сохраняем данные при выходе игрока
Players.PlayerRemoving:Connect(savePlayerData)

print("✅ Серверный инвентарь запущен")