-- BuildServer (Script в ServerScriptService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local remoteEvent = ReplicatedStorage:WaitForChild("BuildBlockEvent")
local inventoryEvent = ReplicatedStorage:WaitForChild("InventoryEvent")

-- Хранение данных игроков
local playerData = {}
local inventoryStore = DataStoreService:GetDataStore("PlayerInventory")

-- Загрузка инвентаря игрока
local function loadPlayerInventory(player)
    playerData[player] = {
        Stone = 10,
        Wood = 25,
        Glass = 5,
        Metal = 2,
        Brick = 15,
        Gold = 1
    }
    
    -- Отправляем данные на клиент
    inventoryEvent:FireClient(player, "initInventory", playerData[player])
end


-- Проверка есть ли у игрока предмет
local function hasItem(player, itemName, amount)
    amount = amount or 1
    return playerData[player] and playerData[player][itemName] and playerData[player][itemName] >= amount
end

-- Использование предмета
local function useItem(player, itemName, amount)
    amount = amount or 1
    if hasItem(player, itemName, amount) then
        playerData[player][itemName] = playerData[player][itemName] - amount
        inventoryEvent:FireClient(player, "itemUsed", itemName, playerData[player][itemName])
        return true
    end
    return false
end

-- Обработчик событий инвентаря
inventoryEvent.OnServerEvent:Connect(function(player, action, itemName)
    if action == "selectItem" then
        if hasItem(player, itemName) then
            inventoryEvent:FireClient(player, "itemSelected", itemName, playerData[player][itemName])
        else
            inventoryEvent:FireClient(player, "error", "Недостаточно " .. itemName)
        end
    elseif action == "checkItem" then
        return hasItem(player, itemName)
    end
end)

-- Обработчик строительства
remoteEvent.OnServerEvent:Connect(function(player, action, blockType, position)
    if action == "buildBlock" then
        -- Проверяем есть ли у игрока нужный предмет
        if hasItem(player, blockType, 1) then
            -- Создаем блок
            local newBlock = Instance.new("Part")
            newBlock.Size = Vector3.new(4, 4, 4)
            newBlock.Position = position
            newBlock.Anchored = true
            newBlock.CanCollide = true
            
            -- Настраиваем материал и цвет в зависимости от типа
            if blockType == "Stone" then
                newBlock.Material = Enum.Material.Slate
                newBlock.Color = Color3.fromRGB(120, 120, 120)
            elseif blockType == "Wood" then
                newBlock.Material = Enum.Material.Wood
                newBlock.Color = Color3.fromRGB(139, 69, 19)
            elseif blockType == "Glass" then
                newBlock.Material = Enum.Material.Glass
                newBlock.Transparency = 0.3
            elseif blockType == "Metal" then
                newBlock.Material = Enum.Material.Metal
                newBlock.Color = Color3.fromRGB(200, 200, 200)
            elseif blockType == "Brick" then
                newBlock.Material = Enum.Material.Brick
                newBlock.Color = Color3.fromRGB(150, 100, 100)
            elseif blockType == "Gold" then
                newBlock.Material = Enum.Material.Neon
                newBlock.Color = Color3.fromRGB(255, 215, 0)
            end
            
            newBlock.Parent = workspace
            
            -- Уменьшаем количество предметов
            useItem(player, blockType, 1)
            
            print("✅ Игрок " .. player.Name .. " построил блок: " .. blockType)
        else
            inventoryEvent:FireClient(player, "error", "Недостаточно " .. blockType)
            print("❌ У игрока " .. player.Name .. " нет предмета: " .. blockType)
        end
    end
end)

-- Обработчик подключения игрока
game.Players.PlayerAdded:Connect(function(player)
    loadPlayerInventory(player)
    print("📦 Загружен инвентарь для: " .. player.Name)
end)

-- Обработчик отключения игрока
game.Players.PlayerRemoving:Connect(function(player)
    playerData[player] = nil
    print("💾 Сохранен инвентарь для: " .. player.Name)
end)

print("✅ Серверный скрипт строительства и инвентаря запущен")