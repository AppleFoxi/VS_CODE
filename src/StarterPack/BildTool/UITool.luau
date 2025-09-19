-- UITool (ModuleScript в инструменте)
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService") -- Добавляем для получения позиции курсора
local player = Players.LocalPlayer

local UITool = {}

-- Локальные переменные модуля
local cooldownUI = nil
local cooldownConnection = nil
local active = false

-- Создание текстового индикатора кулдауна
local function createCooldownUI()
    if cooldownUI then 
        cooldownUI:Destroy()
        cooldownUI = nil
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BuildCooldownUI"
    screenGui.Parent = player.PlayerGui
    screenGui.ResetOnSpawn = false
    screenGui.Enabled = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Основной контейнер
    local container = Instance.new("Frame")
    container.Name = "CooldownContainer"
    container.Size = UDim2.new(0, 80, 0, 40)
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    container.BackgroundTransparency = 0.3
    container.BorderSizePixel = 0
    container.ZIndex = 10
    
    -- Скругление углов
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = container
    
    -- Тень
    local shadow = Instance.new("UIStroke")
    shadow.Color = Color3.fromRGB(0, 0, 0)
    shadow.Thickness = 2
    shadow.Transparency = 0.7
    shadow.Parent = container
    
    -- Текст кулдауна
    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "CooldownText"
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = "0.0s"
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.GothamBold
    textLabel.ZIndex = 11
    
    container.Parent = screenGui
    textLabel.Parent = container
    
    return screenGui
end

-- Публичные методы

function UITool.Init()
    cooldownUI = createCooldownUI()
    active = true
end

function UITool.StartCooldown(cooldownTime)
    if not active or not cooldownUI then return end
    
    -- Получаем текущую позицию курсора
    local mousePos = UserInputService:GetMouseLocation()
    
    -- Устанавливаем позицию индикатора
    local container = cooldownUI:FindFirstChild("CooldownContainer")
    if container then
        container.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y + 50)
    end
    
    -- Показываем индикатор
    cooldownUI.Enabled = true

    local startTime = os.clock()
    local endTime = startTime + cooldownTime

    -- Останавливаем предыдущую анимацию
    if cooldownConnection then
        cooldownConnection:Disconnect()
    end

    -- Запускаем новую анимацию
    cooldownConnection = RunService.Heartbeat:Connect(function()
        if not active then
            cooldownConnection:Disconnect()
            return
        end

        local currentTime = os.clock()
        local remaining = math.max(0, endTime - currentTime)
        local progress = 1 - (remaining / cooldownTime)

        -- Обновляем текст
        local textLabel = cooldownUI:FindFirstChild("CooldownContainer") and cooldownUI.CooldownContainer:FindFirstChild("CooldownText")
        if textLabel then
            textLabel.Text = string.format("%.1fs", remaining)
            
            -- Меняем цвет текста в зависимости от оставшегося времени
            if remaining > cooldownTime * 0.7 then
                textLabel.TextColor3 = Color3.fromRGB(255, 100, 100) -- Красный
            elseif remaining > cooldownTime * 0.3 then
                textLabel.TextColor3 = Color3.fromRGB(255, 200, 0) -- Желтый
            else
                textLabel.TextColor3 = Color3.fromRGB(0, 255, 100) -- Зеленый
            end

            if remaining <= 0 then
                -- Завершаем анимацию
                textLabel.Text = "Готово!"
                textLabel.TextColor3 = Color3.fromRGB(0, 255, 200)
                
                -- Скрываем индикатор через короткую задержку
                delay(0.3, function()
                    if active and cooldownUI then
                        cooldownUI.Enabled = false
                    end
                end)
                cooldownConnection:Disconnect()
            end
        end
    end)
end

function UITool.UpdateCooldownPosition(x, y)
    -- Этот метод теперь может быть не нужен, но оставим на всякий случай
    if not active or not cooldownUI then return end
    
    local container = cooldownUI:FindFirstChild("CooldownContainer")
    if container then
        container.Position = UDim2.new(0, x, 0, y + 50)
    end
end

function UITool.Cleanup()
    active = false
    if cooldownConnection then
        cooldownConnection:Disconnect()
        cooldownConnection = nil
    end
    if cooldownUI then
        cooldownUI:Destroy()
        cooldownUI = nil
    end
end

return UITool