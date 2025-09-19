-- BuildClientManager (LocalScript в инструменте)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local tool = script.Parent
local remoteEvent = ReplicatedStorage:WaitForChild("BuildBlockEvent")
local gridSize = 4
local previewBlock = nil
local canBuild = false
local isOnCooldown = false
local lastPosition = nil
local connection = nil

-- Настройки кулдауна
local COOLDOWN_TIME = 0.5
local lastBuildTime = 0

-- Ссылка на модуль UI
local UITool = nil
local success, message = pcall(function()
	UITool = require(tool:WaitForChild("UITool"))
end)
if not success then
	warn("Не удалось загрузить UITool: " .. tostring(message))
	return
end

print("✅ BuildClientManager: RemoteEvent и UITool найдены")

-- Функция выравнивания по сетке
local function snapToGrid(position)
    return Vector3.new(
        math.floor(position.X / gridSize) * gridSize + gridSize/2,
        math.floor(position.Y / gridSize) * gridSize + gridSize/2,
        math.floor(position.Z / gridSize) * gridSize + gridSize/2
    )
end

-- Получение позиции строительства (упрощенная версия)
local function getBuildPosition()
    if not mouse.Target then return nil end
    
    -- Благодаря CanQuery = false, превью-блоки игнорируются автоматически
    if player.Character and mouse.Target:IsDescendantOf(player.Character) then
        return nil
    end
    
    local hitPosition = mouse.Hit.Position
    local surfaceNormal = mouse.TargetSurface
    
    -- Смещаем позицию в зависимости от грани
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

-- Упрощенная проверка коллизий
local function checkCollision(position)
    local testPart = Instance.new("Part")
    testPart.Size = Vector3.new(gridSize - 0.2, gridSize - 0.2, gridSize - 0.2)
    testPart.Position = position
    testPart.Anchored = true
    testPart.CanCollide = false
    testPart.Transparency = 1
    testPart.Parent = workspace

    -- Игнорируем только персонажа игрока
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
        -- Проверяем только обычные коллизионные части
        if part.Transparency < 0.5 and part.CanCollide then
            testPart:Destroy()
            return true
        end
    end
    testPart:Destroy()
    return false
end

-- Создание предпросмотра (без тега)
local function createPreview()
    if previewBlock then previewBlock:Destroy() end

    previewBlock = Instance.new("Part")
    previewBlock.Size = Vector3.new(gridSize - 0.1, gridSize - 0.1, gridSize - 0.1)
    previewBlock.Transparency = 0.7
    previewBlock.Anchored = true
    previewBlock.CanCollide = false
    previewBlock.Material = Enum.Material.Neon
    previewBlock.Name = "BuildPreview"
    
    -- Делаем блок необнаружимым для лучей и физики
    previewBlock.CanQuery = false
    previewBlock.Massless = true
    
    -- Настраиваем collision groups
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
    if not previewBlock then return end

    local buildPosition = getBuildPosition()
    if not buildPosition then
        previewBlock.Transparency = 1
        canBuild = false
        return
    end
    
    if lastPosition and (buildPosition - lastPosition).Magnitude < 0.5 then
        return
    end
    lastPosition = buildPosition
    
    -- Проверяем можно ли строить на этой поверхности и нет ли коллизий
    local surfaceValid = canBuildOnSurface()
    local collisionFree = not checkCollision(buildPosition)
    
    canBuild = surfaceValid and collisionFree
    
    previewBlock.Position = buildPosition
    previewBlock.Transparency = 0.7
    
    -- Меняем цвет в зависимости от возможности строительства
    if canBuild then
        previewBlock.Color = Color3.fromRGB(50, 255, 50) -- Зеленый: можно строить
    elseif not surfaceValid then
        previewBlock.Color = Color3.fromRGB(255, 50, 50) -- Красный: неверная поверхность
    else
        previewBlock.Color = Color3.fromRGB(255, 150, 50) -- Оранжевый: коллизия
    end
end

-- Визуальная обратная связь
local function showBuildFeedback(success)
    if not previewBlock then return end
    
    if success then
        -- Обновляем позицию перед показом кулдауна
        local mousePos = UserInputService:GetMouseLocation()
        UITool.UpdateCooldownPosition(mousePos.X, mousePos.Y)
        
        previewBlock.Color = Color3.fromRGB(150, 255, 150)
        previewBlock.Transparency = 0.3
        isOnCooldown = true
        lastBuildTime = os.clock()
        UITool.StartCooldown(COOLDOWN_TIME)
    else
        -- Мигание красным при неудачной попытке
        previewBlock.Color = Color3.fromRGB(255, 50, 50)
        previewBlock.Transparency = 0.5
        
        delay(0.2, function()
            if previewBlock and previewBlock.Parent then
                previewBlock.Transparency = 0.7
                -- Возвращаем соответствующий цвет после мигания
                if canBuildOnSurface() then
                    previewBlock.Color = Color3.fromRGB(50, 255, 50)
                else
                    previewBlock.Color = Color3.fromRGB(255, 50, 50)
                end
            end
        end)
    end
    
    delay(0.3, function()
        if previewBlock and previewBlock.Parent then
            previewBlock.Transparency = 0.7
            -- Возвращаем соответствующий цвет
            if canBuild then
                previewBlock.Color = Color3.fromRGB(50, 255, 50)
            elseif not canBuildOnSurface() then
                previewBlock.Color = Color3.fromRGB(255, 50, 50)
            else
                previewBlock.Color = Color3.fromRGB(255, 150, 50)
            end
        end
    end)
end

-- Проверка можно ли строить (используется в Activated)
local function canBuildNow()
    if isOnCooldown then return false end
    return canBuild
end

-- Обработчики инструмента
tool.Equipped:Connect(function()
    createPreview()
    UITool.Init()
    connection = RunService.Heartbeat:Connect(updatePreview)
end)

tool.Unequipped:Connect(function()
    if connection then connection:Disconnect() end
    if previewBlock then previewBlock:Destroy() end
    UITool.Cleanup()
    canBuild = false
    isOnCooldown = false
end)

tool.Activated:Connect(function()
    if mouse.Target and previewBlock then
        local buildPosition = getBuildPosition()
        if buildPosition and canBuildNow() and canBuildOnSurface() then
            showBuildFeedback(true)
            remoteEvent:FireServer(previewBlock.Position)
        else
            showBuildFeedback(false)
        end
    else
        showBuildFeedback(false)
    end
end)

-- В Heartbeat проверяем завершился ли кулдаун
RunService.Heartbeat:Connect(function()
	if isOnCooldown then
		if os.clock() - lastBuildTime >= COOLDOWN_TIME then
			isOnCooldown = false
		end
	end
end)

tool.Destroying:Connect(function()
    if connection then connection:Disconnect() end
    if previewBlock then previewBlock:Destroy() end
    UITool.Cleanup()
end)

print("🛠️ BuildClientManager: Клиентский скрипт готов! Превью теперь полностью игнорируется.")