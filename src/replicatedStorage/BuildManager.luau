-- BuildManager (ModuleScript в ReplicatedStorage)
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local BuildManager = {}
local remoteEvent = ReplicatedStorage:WaitForChild("BuildBlockEvent")

-- Локальные переменные
local previewBlock = nil
local canBuild = false
local isBuildingMode = false
local currentBlockType = nil
local connection = nil
local mouseConnection = nil
local gridSize = 4
local lastBuildTime = 0
local COOLDOWN_TIME = 0.5

-- Функция выравнивания по сетке
local function snapToGrid(position)
    return Vector3.new(
        math.floor(position.X / gridSize) * gridSize + gridSize/2,
        math.floor(position.Y / gridSize) * gridSize + gridSize/2,
        math.floor(position.Z / gridSize) * gridSize + gridSize/2
    )
end

-- Получение позиции строительства
local function getBuildPosition()
    if not mouse.Target then return nil end
    
    if player.Character and mouse.Target:IsDescendantOf(player.Character) then
        return nil
    end
    
    local hitPosition = mouse.Hit.Position
    local surfaceNormal = mouse.TargetSurface
    
    local offset = Vector3.new(0, gridSize/2, 0)
    if surfaceNormal == Enum.NormalId.Front then
        offset = Vector3.new(0, 0, gridSize/2)
    elseif surfaceNormal == Enum.NormalId.Back then
        offset = Vector3.new(0, 0, -gridSize/2)
    elseif surfaceNormal == Enum.NormalId.Right then
        offset = Vector3.new(gridSize/2, 0, 0)
    elseif surfaceNormal == Enum.NormalId.Left then
        offset = Vector3.new(-gridSize/2, 0, 0)
    elseif surfaceNormal == Enum.NormalId.Bottom then
        offset = Vector3.new(0, -gridSize/2, 0)
    end
    
    return snapToGrid(hitPosition + offset)
end

-- Проверка можно ли строить на этой поверхности
local function canBuildOnSurface()
    if not mouse.Target then return false end
    return mouse.TargetSurface ~= Enum.NormalId.Bottom
end

-- Проверка коллизий
local function checkCollision(position)
    local testPart = Instance.new("Part")
    testPart.Size = Vector3.new(gridSize - 0.2, gridSize - 0.2, gridSize - 0.2)
    testPart.Position = position
    testPart.Anchored = true
    testPart.CanCollide = false
    testPart.Transparency = 1
    testPart.Parent = workspace

    local ignoreList = {testPart}
    if player.Character then
        for _, part in ipairs(player.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                table.insert(ignoreList, part)
            end
        end
    end

    local touchingParts = testPart:GetTouchingParts()
    for _, part in ipairs(touchingParts) do
        if part.Transparency < 0.5 and part.CanCollide then
            testPart:Destroy()
            return true
        end
    end
    testPart:Destroy()
    return false
end

-- Создание предпросмотра
local function createPreview()
    if previewBlock then previewBlock:Destroy() end

    previewBlock = Instance.new("Part")
    previewBlock.Size = Vector3.new(gridSize - 0.1, gridSize - 0.1, gridSize - 0.1)
    previewBlock.Transparency = 0.7
    previewBlock.Anchored = true
    previewBlock.CanCollide = false
    previewBlock.Material = Enum.Material.Neon
    previewBlock.Name = "BuildPreview"
    previewBlock.CanQuery = false
    previewBlock.Massless = true
    
    -- Цвет в зависимости от типа блока
    if currentBlockType == "Stone" then
        previewBlock.Color = Color3.fromRGB(150, 150, 150)
    elseif currentBlockType == "Wood" then
        previewBlock.Color = Color3.fromRGB(139, 69, 19)
    elseif currentBlockType == "Glass" then
        previewBlock.Color = Color3.fromRGB(200, 200, 255)
        previewBlock.Transparency = 0.5
    elseif currentBlockType == "Metal" then
        previewBlock.Color = Color3.fromRGB(200, 200, 200)
    else
        previewBlock.Color = Color3.fromRGB(50, 255, 50)
    end
    
    -- Настройка collision groups
    pcall(function()
        if not PhysicsService:GetCollisionGroupName("Preview") then
            PhysicsService:CreateCollisionGroup("Preview")
            PhysicsService:CollisionGroupSetCollidable("Preview", "Default", false)
        end
        previewBlock.CollisionGroup = "Preview"
    end)
    
    previewBlock.Parent = workspace
    return previewBlock
end

-- Обновление предпросмотра
local function updatePreview()
    if not previewBlock or not isBuildingMode then return end

    local buildPosition = getBuildPosition()
    if not buildPosition then
        previewBlock.Transparency = 1
        canBuild = false
        return
    end
    
    previewBlock.Position = buildPosition
    previewBlock.Transparency = 0.7
    
    -- Проверяем можно ли строить
    local surfaceValid = canBuildOnSurface()
    local collisionFree = not checkCollision(buildPosition)
    
    canBuild = surfaceValid and collisionFree
    
    -- Меняем цвет в зависимости от возможности строительства
    if canBuild then
        previewBlock.BrickColor = BrickColor.Green()
    elseif not surfaceValid then
        previewBlock.BrickColor = BrickColor.Red()
    else
        previewBlock.BrickColor = BrickColor.new("Bright orange")
    end
end

-- Обработчик клика для строительства
local function onMouseClick()
    if isBuildingMode and canBuild and (os.clock() - lastBuildTime) >= COOLDOWN_TIME then
        local buildPosition = getBuildPosition()
        if buildPosition then
            lastBuildTime = os.clock()
            remoteEvent:FireServer("buildBlock", currentBlockType, buildPosition)
            
            -- Визуальная обратная связь
            if previewBlock then
                previewBlock.Transparency = 0.3
                delay(0.1, function()
                    if previewBlock and previewBlock.Parent then
                        previewBlock.Transparency = 0.7
                    end
                end)
            end
        end
    end
end

-- Запуск режима строительства
function BuildManager.StartBuildingMode(blockType)
    if isBuildingMode then
        BuildManager.StopBuildingMode()
    end
    
    currentBlockType = blockType
    isBuildingMode = true
    createPreview()
    
    -- Подключаем обновление предпросмотра
    connection = RunService.Heartbeat:Connect(updatePreview)
    
    -- Подключаем обработчик клика для строительства (ОДИН РАЗ)
    if not mouseConnection then
        mouseConnection = mouse.Button1Down:Connect(onMouseClick)
    end
    
    print("🏗️ Режим строительства запущен: " .. blockType)
end

-- Остановка режима строительства
function BuildManager.StopBuildingMode()
    isBuildingMode = false
    canBuild = false
    currentBlockType = nil
    
    if connection then
        connection:Disconnect()
        connection = nil
    end
    
    if previewBlock then
        previewBlock:Destroy()
        previewBlock = nil
    end
    
    print("🛑 Режим строительства остановлен")
end

-- Отключение всех соединений
function BuildManager.Cleanup()
    if connection then
        connection:Disconnect()
        connection = nil
    end
    
    if mouseConnection then
        mouseConnection:Disconnect()
        mouseConnection = nil
    end
    
    if previewBlock then
        previewBlock:Destroy()
        previewBlock = nil
    end
    
    isBuildingMode = false
end

-- Проверка активности режима строительства
function BuildManager.IsBuilding()
    return isBuildingMode
end

return BuildManager