local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = playerGui:WaitForChild("ScreenGui")

wait(2)

local function setupShopSystem()
    local mainFrame = screenGui:FindFirstChild("Frame")
    
    if not mainFrame then
        for _, child in ipairs(screenGui:GetChildren()) do
            if child:IsA("Frame") then
                mainFrame = child
                break
            end
        end
    end
    
    if not mainFrame then
        warn("❌ Основной фрейм не найден")
        return
    end
    
    -- Находим магазины
    local blockShop = mainFrame:FindFirstChild("BlockShop")
    local gunShop = mainFrame:FindFirstChild("GunShop")
    local decorShop = mainFrame:FindFirstChild("DecorShop")
    
    -- Рекурсивный поиск
    if not blockShop or not gunShop or not decorShop then
        for _, descendant in ipairs(screenGui:GetDescendants()) do
            if descendant.Name == "BlockShop" and not blockShop then
                blockShop = descendant
            elseif descendant.Name == "GunShop" and not gunShop then
                gunShop = descendant
            elseif descendant.Name == "DecorShop" and not decorShop then
                decorShop = descendant
            end
        end
    end
    
    local tagToShop = {
        BLOCK_BUTTON = blockShop,
        GUN_BUTTON = gunShop,
        DECOR_BUTTON = decorShop
    }
    
    local function switchToShop(shopToShow, activeButton)
        if not shopToShow then return end
        
        -- Скрываем все магазины
        for _, shop in pairs(tagToShop) do
            if shop then shop.Visible = false end
        end
        
        -- Показываем нужный магазин
        shopToShow.Visible = true
        if shopToShow:IsA("ScrollingFrame") then
            shopToShow.CanvasPosition = Vector2.new(0, 0)
        end
        
        -- Сбрасываем цвет кнопок
        for _, guiObject in ipairs(screenGui:GetDescendants()) do
            if guiObject:IsA("GuiButton") then
                if guiObject:GetAttribute("Tag") == "BLOCK_BUTTON" or 
                   guiObject:GetAttribute("Tag") == "GUN_BUTTON" or 
                   guiObject:GetAttribute("Tag") == "DECOR_BUTTON" then
                    guiObject.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                end
            end
        end
        
        -- Подсвечиваем активную кнопку
        if activeButton then
            activeButton.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
        end
    end
    
    -- Находим кнопки по атрибутам
    for _, guiObject in ipairs(screenGui:GetDescendants()) do
        if guiObject:IsA("GuiButton") then
            local tag = guiObject:GetAttribute("Tag")
            
            if tag == "BLOCK_BUTTON" then
                guiObject.MouseButton1Click:Connect(function()
                    switchToShop(blockShop, guiObject)
                end)
            elseif tag == "GUN_BUTTON" then
                guiObject.MouseButton1Click:Connect(function()
                    switchToShop(gunShop, guiObject)
                end)
            elseif tag == "DECOR_BUTTON" then
                guiObject.MouseButton1Click:Connect(function()
                    switchToShop(decorShop, guiObject)
                end)
            end
        end
    end
    
    -- Включаем первый магазин по умолчанию
    for _, guiObject in ipairs(screenGui:GetDescendants()) do
        if guiObject:IsA("GuiButton") and guiObject:GetAttribute("Tag") == "BLOCK_BUTTON" then
            if blockShop then
                switchToShop(blockShop, guiObject)
            end
            break
        end
    end
end

setupShopSystem()
print("✅ Система магазина готова!")