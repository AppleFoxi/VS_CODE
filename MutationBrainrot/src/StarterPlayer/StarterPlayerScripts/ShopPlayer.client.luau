local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- Ждем пока игрок заспавнится
print("⏳ Ожидаем спавна игрока...")
while not player.Character do
    RunService.Heartbeat:Wait()
end
print("✅ Игрок заспавнился")

local playerGui = player:WaitForChild("PlayerGui")
print("✅ PlayerGui загружен")

local ShopUIEvent = ReplicatedStorage:FindFirstChild("ShopUIEvent")

-- Ждем создания RemoteEvent
if not ShopUIEvent then
    wait(2)
    ShopUIEvent = ReplicatedStorage:WaitForChild("ShopUIEvent")
end

-- Находим существующий фрейм магазина в PlayerGui
local function findShopFrame()
    -- Даем дополнительное время на копирование GUI из StarterGui
    wait(1)
    
    -- Ищем в PlayerGui (актуальная копия которую видит игрок)
    for _, gui in ipairs(playerGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            for _, child in ipairs(gui:GetChildren()) do
                if child:IsA("Frame") then
                    print("✅ Найден фрейм в PlayerGui: " .. child.Name)
                    return child
                end
            end
        end
    end
    warn("❌ Фрейм не найден в PlayerGui")
    return nil
end

-- Настройка анимаций для фрейма
local function setupShopAnimations(shopFrame)
    -- Сохраняем оригинальные параметры
    local originalSize = shopFrame.Size
    local originalPosition = shopFrame.Position
    local originalAnchorPoint = shopFrame.AnchorPoint or Vector2.new(0, 0)
    
    print("🔄 Настройка анимаций для фрейма...")
    
    -- Функция открытия магазина
  local function openShop()
    if shopFrame.Visible then return false end
    
    shopFrame.Visible = true
    shopFrame.Size = UDim2.new(0, 10, 0, 10)
    shopFrame.Position = UDim2.new(
        originalPosition.X.Scale, 
        originalPosition.X.Offset + originalSize.X.Offset/2 - 5,
        originalPosition.Y.Scale,
        originalPosition.Y.Offset + originalSize.Y.Offset/2 - 5
    )
    
    local tween = TweenService:Create(shopFrame, TweenInfo.new(0.3), {
        Size = originalSize,
        Position = originalPosition
    })
    tween:Play()
    
    return true
end
    
    -- Функция закрытия магазина
    local function closeShop()
        if not shopFrame.Visible then
            return false
        end
        
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        
        local sizeTween = TweenService:Create(shopFrame, tweenInfo, {
            Size = UDim2.new(0, 10, 0, 10)
        })
        
        local positionTween = TweenService:Create(shopFrame, tweenInfo, {
            Position = UDim2.new(0.5, 0, 0.5, 0)
        })
        
        sizeTween:Play()
        positionTween:Play()
        
        sizeTween.Completed:Connect(function()
            shopFrame.Visible = false
            shopFrame.Size = originalSize
            shopFrame.Position = originalPosition
            shopFrame.AnchorPoint = originalAnchorPoint
            print("🔒 Фрейм полностью скрыт")
        end)
        
        print("🛒 Магазин ЗАКРЫТ")
        return true
    end
    
    -- Сразу закрываем фрейм при запуске
    print("🚪 Закрываем фрейм при старте...")
    shopFrame.Visible = false
    shopFrame.Size = originalSize
    shopFrame.Position = originalPosition
    shopFrame.AnchorPoint = originalAnchorPoint
    
    return {
        open = openShop,
        close = closeShop
    }
end

-- Основная логика (после спавна игрока)
local shopFrame = findShopFrame()
local shopAnimations = nil
local isShopOpen = false

if shopFrame then
    print("✅ Фрейм найден, настраиваем анимации...")
    shopAnimations = setupShopAnimations(shopFrame)
    print("🎉 Анимации настроены успешно!")
else
    warn("⚠️ Магазин не будет работать - фрейм не найден")
    return
end

-- Обработка событий от сервера
ShopUIEvent.OnClientEvent:Connect(function(action, data)
    if not shopAnimations then return end
    
    if action == "toggleShop" then
        if data.isOpen and not isShopOpen then
            local success = shopAnimations.open()
            if success then
                isShopOpen = true
            end
        elseif not data.isOpen and isShopOpen then
            local success = shopAnimations.close()
            if success then
                isShopOpen = false
            end
        end
    end
end)

-- Поиск ShopBlock в Workspace
local function findShopBlock()
    return workspace:FindFirstChild("ShopBlock")
end

-- Проверка расстояния до ShopBlock
local function checkShopDistance()
    local character = player.Character
    local shopBlock = findShopBlock()
    
    if not character or not shopBlock then 
        return false 
    end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return false end
    
    local distance = (humanoidRootPart.Position - shopBlock.Position).Magnitude
    return distance <= 15
end

-- Автоматическое открытие/закрытие при приближении
local lastCheckResult = false
local debounce = false

RunService.Heartbeat:Connect(function()
    if not shopAnimations or debounce then return end
    debounce = true
    
    local isInRange = checkShopDistance()
    
    if isInRange and not lastCheckResult then
        ShopUIEvent:FireServer("openShop")
        lastCheckResult = true
    elseif not isInRange and lastCheckResult then
        ShopUIEvent:FireServer("closeShop")
        lastCheckResult = false
    end
    
    debounce = false
end)

print("🎊 Система автоматического открытия магазина ЗАПУЩЕНА!")