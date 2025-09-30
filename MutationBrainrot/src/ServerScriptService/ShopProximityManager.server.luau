local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Создаем RemoteEvent для UI
local ShopUIEvent = Instance.new("RemoteEvent")
ShopUIEvent.Name = "ShopUIEvent"
ShopUIEvent.Parent = ReplicatedStorage

print("✅ ShopUIEvent создан")

-- Обработка запросов открытия/закрытия
ShopUIEvent.OnServerEvent:Connect(function(player, action)
    if action == "openShop" then
        ShopUIEvent:FireClient(player, "toggleShop", {isOpen = true})
        print("🛒 " .. player.Name .. " открыл магазин")
    elseif action == "closeShop" then
        ShopUIEvent:FireClient(player, "toggleShop", {isOpen = false})
        print("🛒 " .. player.Name .. " закрыл магазин")
    end
end)

-- Автоматическая проверка расстояния
local function setupShopBlock()
    local shopBlock = workspace:FindFirstChild("ShopBlock")
    
    if not shopBlock then
        -- Создаем ShopBlock если не найден
        shopBlock = Instance.new("Part")
        shopBlock.Name = "ShopBlock"
        shopBlock.Size = Vector3.new(10, 10, 10)
        shopBlock.Position = Vector3.new(0, 5, 0)
        shopBlock.Anchored = true
        shopBlock.BrickColor = BrickColor.new("Bright yellow")
        shopBlock.Material = Enum.Material.Neon
        shopBlock.Parent = workspace
        print("✅ ShopBlock создан автоматически")
    else
        print("✅ ShopBlock найден")
    end
    
    return shopBlock
end

local shopBlock = setupShopBlock()
local playersNearShop = {}

-- Проверка расстояния на сервере
RunService.Heartbeat:Connect(function()
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local distance = (character.HumanoidRootPart.Position - shopBlock.Position).Magnitude
            local isInRange = distance <= 15
            
            if isInRange and not playersNearShop[player] then
                playersNearShop[player] = true
                ShopUIEvent:FireClient(player, "toggleShop", {isOpen = true})
            elseif not isInRange and playersNearShop[player] then
                playersNearShop[player] = nil
                ShopUIEvent:FireClient(player, "toggleShop", {isOpen = false})
            end
        end
    end
end)

print("✅ Серверная система управления магазином готова!")