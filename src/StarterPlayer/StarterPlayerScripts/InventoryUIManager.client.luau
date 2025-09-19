-- InventoryClientManager (StarterPlayerScripts)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remoteEvent = ReplicatedStorage:WaitForChild("InventoryEvent")
local screenGui = playerGui:WaitForChild("ScreenGui")
local background = screenGui:WaitForChild("Background")

local selectedItem = nil
local scrollFrame = nil
local contentFrame = nil
local itemCounts = {}

-- Константы для расположения (УВЕЛИЧЕНЫ В 2 РАЗА)
local SLOT_WIDTH = 160  -- было 80
local SLOT_HEIGHT = 200 -- было 100
local SLOT_SPACING_X = 20
local SLOT_SPACING_Y = 20
local SLOTS_PER_ROW = 2
local VISIBLE_ROWS = 2  -- уменьшено чтобы вмещались большие кнопки

-- Ссылка на модуль строительства
local BuildManager = nil
local success, message = pcall(function()
    BuildManager = require(ReplicatedStorage:WaitForChild("BuildManager"))
end)
if not success then
    warn("Не удалось загрузить BuildManager: " .. tostring(message))
end

-- Создание скролл-контейнера
local function createScrollContainer()
    if scrollFrame then scrollFrame:Destroy() end
    
    scrollFrame = Instance.new("Frame")
    scrollFrame.Name = "ScrollContainer"
    scrollFrame.Size = UDim2.new(0, SLOTS_PER_ROW * SLOT_WIDTH + (SLOTS_PER_ROW + 1) * SLOT_SPACING_X, 
                                 0, VISIBLE_ROWS * SLOT_HEIGHT + (VISIBLE_ROWS + 1) * SLOT_SPACING_Y)
    scrollFrame.Position = UDim2.new(0, 10, 0, 10)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ClipsDescendants = true
    
    local scrollingFrame = Instance.new("ScrollingFrame")
    scrollingFrame.Name = "ScrollingFrame"
    scrollingFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollingFrame.Position = UDim2.new(0, 0, 0, 0)
    scrollingFrame.BackgroundTransparency = 1
    scrollingFrame.ScrollBarThickness = 12  -- толще скроллбар
    scrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120)
    scrollingFrame.VerticalScrollBarInset = Enum.ScrollBarInset.Always
    scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    
    contentFrame = Instance.new("Frame")
    contentFrame.Name = "Content"
    contentFrame.Size = UDim2.new(1, 0, 0, 0)
    contentFrame.Position = UDim2.new(0, 0, 0, 0)
    contentFrame.BackgroundTransparency = 1
    
    scrollingFrame.Parent = scrollFrame
    contentFrame.Parent = scrollingFrame
    scrollFrame.Parent = background
    
    return scrollingFrame
end

-- Создание ячейки инвентаря (УВЕЛИЧЕННЫЕ РАЗМЕРЫ)
local function createItemSlot(itemName, itemCount, maxCount, position)
    -- Проверка входных данных
    if not itemName or not itemCount or not maxCount then
        warn("❌ Неверные данные для создания слота: " .. tostring(itemName))
        return nil, nil, nil
    end
    
    local template = Instance.new("Frame")
    template.Name = tostring(itemName) .. "Slot"
    template.Size = UDim2.new(0, SLOT_WIDTH, 0, SLOT_HEIGHT)
    template.Position = position
    template.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    template.BorderSizePixel = 3  -- толще граница
    template.BorderColor3 = Color3.fromRGB(100, 100, 120)
    
    -- Сохраняем максимальное количество для этого предмета
    itemCounts[itemName] = {current = itemCount, max = maxCount}
    
    -- Добавляем TextButton для обработки кликов
    local clickDetector = Instance.new("TextButton")
    clickDetector.Name = "ClickDetector"
    clickDetector.Size = UDim2.new(1, 0, 1, 0)
    clickDetector.BackgroundTransparency = 1
    clickDetector.BorderSizePixel = 0
    clickDetector.Text = ""
    clickDetector.ZIndex = 10
    clickDetector.Parent = template
    
    -- Иконка предмета (УВЕЛИЧЕНА)
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 120, 0, 120)  -- было 60x60
    icon.Position = UDim2.new(0.5, 0, 0.1, 0)
    icon.AnchorPoint = Vector2.new(0.5, 0)
    icon.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    icon.Image = "rbxassetid://12345678"
    
    -- Название предмета (УВЕЛИЧЕНО, ЖИРНЫЙ ШРИФТ)
    local nameText = Instance.new("TextLabel")
    nameText.Name = "NameText"
    nameText.Size = UDim2.new(0, 140, 0, 30)  -- было 70x15
    nameText.Position = UDim2.new(0.5, 0, 0.6, 0)
    nameText.AnchorPoint = Vector2.new(0.5, 0)
    nameText.Text = tostring(itemName)
    nameText.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameText.TextScaled = true
    nameText.BackgroundTransparency = 1
    nameText.Font = Enum.Font.GothamBlack  -- ОЧЕНЬ ЖИРНЫЙ ШРИФТ
    nameText.TextStrokeTransparency = 0.8  -- обводка для лучшей читаемости
    nameText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    
    -- Счетчик предметов (УВЕЛИЧЕНО, ЖИрНЫЙ ШРИФТ)
    local countText = Instance.new("TextLabel")
    countText.Name = "CountText"
    countText.Size = UDim2.new(0, 140, 0, 30)  -- было 70x15
    countText.Position = UDim2.new(0.5, 0, 0.8, 0)
    countText.AnchorPoint = Vector2.new(0.5, 0)
    countText.Text = tostring(itemCount) .. "/" .. tostring(maxCount)
    countText.TextColor3 = Color3.fromRGB(200, 200, 200)
    countText.TextScaled = true
    countText.BackgroundTransparency = 1
    countText.Font = Enum.Font.GothamBold  -- ЖИРНЫЙ ШРИФТ
    countText.TextStrokeTransparency = 0.8
    countText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    
    -- Эффект при наведении (УВЕЛИЧЕН)
    local hoverEffect = Instance.new("Frame")
    hoverEffect.Name = "HoverEffect"
    hoverEffect.Size = UDim2.new(1, 0, 1, 0)
    hoverEffect.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    hoverEffect.BackgroundTransparency = 0.9
    hoverEffect.Visible = false
    hoverEffect.ZIndex = 5
    
    -- Скругление углов для красоты
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = template
    
    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, 8)
    iconCorner.Parent = icon
    
    icon.Parent = template
    nameText.Parent = template
    countText.Parent = template
    hoverEffect.Parent = template
    
    return template, clickDetector, countText
end

-- Подсветка выбранного предмета
local function highlightSelectedItem(selectedName)
    if not selectedName then
        selectedName = ""
    end
    
    for _, child in ipairs(contentFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name:find("Slot") then
            if child.Name == selectedName .. "Slot" then
                -- Яркая обводка для выбранного предмета
                child.BorderColor3 = Color3.fromRGB(0, 255, 0)
                child.BorderSizePixel = 4  -- толще выделение
                child.BackgroundColor3 = Color3.fromRGB(80, 100, 80)
            else
                child.BorderColor3 = Color3.fromRGB(100, 100, 120)
                child.BorderSizePixel = 3
                child.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
            end
        end
    end
end

-- Обновление счетчика предмета (ИСПРАВЛЕННАЯ ФУНКЦИЯ)
local function updateItemCount(itemName, newCount)
    if not itemName or not itemCounts[itemName] then
        warn("❌ Не удалось обновить счетчик: неверное имя предмета - " .. tostring(itemName))
        return
    end
    
    itemCounts[itemName].current = newCount
    
    local slot = contentFrame:FindFirstChild(tostring(itemName) .. "Slot")
    if slot then
        local countText = slot:FindFirstChild("CountText")
        if countText then
            local maxCount = itemCounts[itemName].max or 0
            countText.Text = tostring(newCount) .. "/" .. tostring(maxCount)
            
            -- Меняем цвет если предмет закончился
            if newCount <= 0 then
                countText.TextColor3 = Color3.fromRGB(255, 100, 100)
            else
                countText.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        end
    end
end

-- Запрос выбора предмета на сервер
local function selectItem(itemName)
    if not itemName or not itemCounts[itemName] or itemCounts[itemName].current <= 0 then
        print("❌ Нельзя выбрать: " .. tostring(itemName) .. " (закончился или не существует)")
        return
    end
    
    print("🎯 Выбран предмет для строительства:", itemName)
    selectedItem = itemName
    highlightSelectedItem(itemName)
    
    -- Запускаем режим строительства
    if BuildManager then
        BuildManager.StartBuildingMode(itemName)
    end
    
    remoteEvent:FireServer("selectItem", itemName)
end

-- Обработка ответов от сервера (ИСПРАВЛЕННЫЙ ОБРАБОТЧИК)
remoteEvent.OnClientEvent:Connect(function(action, itemName, count, maxCount)
    if action == "itemSelected" then
        if itemName and count and maxCount then
            selectedItem = itemName
            highlightSelectedItem(itemName)
            print("✅ Предмет выбран:", itemName, "Осталось:", count .. "/" .. maxCount)
        else
            warn("❌ Неверные данные для itemSelected")
        end
    elseif action == "itemUsed" then
        -- Обновляем счетчик в UI
        if itemName and count then
            updateItemCount(itemName, count)
            print("📦 Использован предмет:", itemName, "Осталось:", count)
        else
            warn("❌ Неверные данные для itemUsed")
        end
    elseif action == "error" then
        print("❌ Ошибка:", tostring(itemName))
    elseif action == "initInventory" then
        -- Инициализация инвентаря данными с сервера
        if itemName and type(itemName) == "table" then
            for item, count in pairs(itemName) do
                if itemCounts[item] then
                    updateItemCount(item, count)
                end
            end
        else
            warn("❌ Неверные данные для initInventory")
        end
    end
end)

-- Инициализация инвентаря
local function initInventory()
    local scrollingFrame = createScrollContainer()
    
    -- Тестовые данные
    local playerData = {
        {"Stone", 10, 50},
        {"Wood", 25, 100},
        {"Glass", 5, 20},
        {"Metal", 2, 10},
        {"Brick", 15, 30},
        {"Gold", 1, 5}
    }
    
    for i, data in ipairs(playerData) do
        local itemName, itemCount, maxCount = data[1], data[2], data[3]
        
        -- Вычисляем позицию для текущего слота
        local row = math.floor((i - 1) / SLOTS_PER_ROW)
        local col = (i - 1) % SLOTS_PER_ROW
        
        local xPos = SLOT_SPACING_X + col * (SLOT_WIDTH + SLOT_SPACING_X)
        local yPos = SLOT_SPACING_Y + row * (SLOT_HEIGHT + SLOT_SPACING_Y)
        
        local position = UDim2.new(0, xPos, 0, yPos)
        
        local slot, clickDetector, countText = createItemSlot(itemName, itemCount, maxCount, position)
        if slot then
            slot.Parent = contentFrame
            
            -- Обработчик клика
            clickDetector.MouseButton1Click:Connect(function()
                selectItem(itemName)
            end)
            
            -- Эффект при наведении
            clickDetector.MouseEnter:Connect(function()
                local hoverEffect = slot:FindFirstChild("HoverEffect")
                if hoverEffect then
                    hoverEffect.Visible = true
                end
            end)
            
            clickDetector.MouseLeave:Connect(function()
                local hoverEffect = slot:FindFirstChild("HoverEffect")
                if hoverEffect then
                    hoverEffect.Visible = false
                end
            end)
        end
    end
    
    -- Автоматически подстраиваем размер контента
    local totalRows = math.ceil(#playerData / SLOTS_PER_ROW)
    contentFrame.Size = UDim2.new(
        1, 0,
        0, totalRows * SLOT_HEIGHT + (totalRows + 1) * SLOT_SPACING_Y
    )
    
    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, contentFrame.Size.Y.Offset)
end

-- Функция для отмены строительства
local function cancelBuilding()
    if selectedItem then
        selectedItem = nil
        highlightSelectedItem("")
        if BuildManager then
            BuildManager.StopBuildingMode()
        end
        print("🚫 Режим строительства отменен")
    end
end

-- Отмена строительства по клавише ESC
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Escape then
        cancelBuilding()
    end
end)

-- Запуск
game:GetService("RunService").RenderStepped:Wait()
initInventory()
print("✅ Клиентский инвентарь запущен. Выберите предмет для строительства!")