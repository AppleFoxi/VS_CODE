local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local BuildRemoteEvent = ReplicatedStorage:WaitForChild("BuildRemoteEvent")

-- Настройки
local GRID_SIZE = 4
local isBuilding = false
local playerFieldNumber = nil
local playerFieldData = nil
local previewBlock = nil

print("⏳ Система строительства загружается...")

-- Получение информации о поле
BuildRemoteEvent.OnClientEvent:Connect(function(action, data)
    if action == "fieldAssigned" then
        playerFieldNumber = data.fieldNumber
        playerFieldData = data
        print("🎯 Ваше поле: " .. playerFieldNumber)
        
    elseif action == "buildSuccess" then
        print("✅ Блок построен!")
        
    elseif action == "buildError" then
        print("❌ " .. tostring(data))
    end
end)

-- Создание превью блока
local function createPreviewBlock()
    if previewBlock then
        previewBlock:Destroy()
    end
    
    previewBlock = Instance.new("Part")
    previewBlock.Name = "BuildPreview"
    previewBlock.Size = Vector3.new(GRID_SIZE, GRID_SIZE, GRID_SIZE)
    previewBlock.Anchored = true
    previewBlock.CanCollide = false
    previewBlock.Material = Enum.Material.Neon
    previewBlock.BrickColor = BrickColor.new("Bright green")
    previewBlock.Transparency = 0.7
    previewBlock.Parent = workspace
    
    -- Сразу прячем
    previewBlock.Position = Vector3.new(0, 1000, 0)
    
    return previewBlock
end

-- Проверка находится ли позиция на поле игрока
local function isOnPlayerField(position)
    if not playerFieldNumber or not playerFieldData then 
        return false 
    end
    
    local fieldsFolder = workspace:FindFirstChild("PlayerFields")
    if not fieldsFolder then return false end
    
    local field = fieldsFolder:FindFirstChild("PlayerField_" .. playerFieldNumber)
    if not field then return false end
    
    local fieldCenter = field.Position
    local fieldSize = field.Size
    
    local minX = fieldCenter.X - fieldSize.X/2
    local maxX = fieldCenter.X + fieldSize.X/2
    local minZ = fieldCenter.Z - fieldSize.Z/2
    local maxZ = fieldCenter.Z + fieldSize.Z/2
    
    return position.X >= minX and position.X <= maxX and 
           position.Z >= minZ and position.Z <= maxZ
end

-- Привязка к сетке
local function snapToGrid(position)
    return Vector3.new(
        math.floor(position.X / GRID_SIZE) * GRID_SIZE + GRID_SIZE/2,
        math.floor(position.Y / GRID_SIZE) * GRID_SIZE + GRID_SIZE/2,
        math.floor(position.Z / GRID_SIZE) * GRID_SIZE + GRID_SIZE/2
    )
end

-- Включение режима строительства
local function activateBuilding()
    if not playerFieldNumber then
        print("❌ У вас еще нет поля!")
        return false
    end
    
    if not previewBlock then
        createPreviewBlock()
    end
    
    isBuilding = true
    previewBlock.Transparency = 0.3
    print("🔨 Режим строительства АКТИВИРОВАН")
    return true
end

-- Выключение режима строительства
local function deactivateBuilding()
    isBuilding = false
    
    if previewBlock then
        previewBlock.Position = Vector3.new(0, 1000, 0)
        previewBlock.Transparency = 0.7
    end
    
    print("🔨 Режим строительства ВЫКЛЮЧЕН")
end

-- Установка блока
local function placeBlock()
    if not isBuilding or not previewBlock or not playerFieldNumber then 
        return 
    end
    
    local blockPosition = previewBlock.Position
    if blockPosition.Y > 100 then  -- Если превью спрятан
        return
    end
    
    if isOnPlayerField(blockPosition) then
        print("🔄 Установка блока на позиции: " .. tostring(blockPosition))
        BuildRemoteEvent:FireServer(blockPosition, "BasicBlock")
    else
        print("❌ Нельзя строить за пределами поля!")
    end
end

-- Обработка кликов мыши
mouse.Button1Down:Connect(function()
    if isBuilding then
        placeBlock()
    end
end)

mouse.Button2Down:Connect(function()
    if isBuilding then
        deactivateBuilding()
    end
end)

-- Функция для активации из инструмента
local BuildingAPI = {}

function BuildingAPI.activate()
    return activateBuilding()
end

function BuildingAPI.deactivate()
    deactivateBuilding()
end

function BuildingAPI.isActive()
    return isBuilding
end

-- Основной цикл обновления превью
RunService.Heartbeat:Connect(function()
    if not isBuilding or not previewBlock then
        return
    end
    
    local target = mouse.Target
    local hitPoint = mouse.Hit and mouse.Hit.Position
    
    if not target or not hitPoint then
        previewBlock.Position = Vector3.new(0, 1000, 0)
        return
    end
    
    -- Игнорируем превью блок
    if target.Name == "BuildPreview" then
        return
    end
    
    local snappedPos = snapToGrid(hitPoint)
    
    -- Проверяем что позиция на поле игрока
    if isOnPlayerField(snappedPos) then
        previewBlock.Position = snappedPos
        previewBlock.BrickColor = BrickColor.new("Bright green")
        previewBlock.Transparency = 0.3
    else
        previewBlock.Position = Vector3.new(0, 1000, 0)
        previewBlock.BrickColor = BrickColor.new("Bright red")
    end
end)

-- Экспортируем API для инструмента
return BuildingAPI