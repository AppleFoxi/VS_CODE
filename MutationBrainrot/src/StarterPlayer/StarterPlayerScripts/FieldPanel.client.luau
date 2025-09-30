local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local FIELD_TAG_NAME = "PlayerField"
local TELEPORT_EVENT_NAME = "TeleportToFieldEvent"
local PANEL_NAME = "FieldOccupantPanel"

local teleportEvent = ReplicatedStorage:WaitForChild(TELEPORT_EVENT_NAME)

local panels = {}
local fieldWatchers = {}

-- Получаем аватар игрока, чтобы отрисовать его на панели.
local function getAvatarImage(userId)
    local success, image = pcall(function()
        return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
    end)

    if success then
        return image
    end

    warn("Не удалось получить аватар для userId: " .. tostring(userId))
    return ""
end

local function destroyPanel(field)
    local data = panels[field]
    if not data then
        return
    end

    if data.gui then
        data.gui:Destroy()
    end

    panels[field] = nil
end

local function unwatchField(field)
    local watcher = fieldWatchers[field]
    if not watcher then
        return
    end

    for _, connection in ipairs(watcher) do
        connection:Disconnect()
    end

    fieldWatchers[field] = nil
    destroyPanel(field)
end

local function createPanel(field)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = PANEL_NAME
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 250
    billboard.Size = UDim2.new(0, 220, 0, 110)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
    billboard.Adornee = field

    local button = Instance.new("TextButton")
    button.Name = "TeleportButton"
    button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    button.BackgroundTransparency = 0.2
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, 0, 1, 0)
    button.AutoButtonColor = true
    button.Text = ""
    button.Parent = billboard

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Transparency = 0.7
    stroke.Parent = button

    local avatar = Instance.new("ImageLabel")
    avatar.Name = "Avatar"
    avatar.BackgroundTransparency = 1
    avatar.Size = UDim2.new(0, 72, 0, 72)
    avatar.Position = UDim2.new(0, 12, 0.5, -36)
    avatar.Parent = button

    local displayName = Instance.new("TextLabel")
    displayName.Name = "DisplayName"
    displayName.BackgroundTransparency = 1
    displayName.Font = Enum.Font.GothamBold
    displayName.TextColor3 = Color3.new(1, 1, 1)
    displayName.TextScaled = false
    displayName.TextSize = 24
    displayName.TextWrapped = true
    displayName.TextXAlignment = Enum.TextXAlignment.Left
    displayName.TextYAlignment = Enum.TextYAlignment.Top
    displayName.AnchorPoint = Vector2.new(0, 0)
    displayName.Position = UDim2.new(0, 100, 0, 16)
    displayName.Size = UDim2.new(1, -110, 0, 34)
    displayName.Parent = button

    local userName = Instance.new("TextLabel")
    userName.Name = "UserName"
    userName.BackgroundTransparency = 1
    userName.Font = Enum.Font.Gotham
    userName.TextColor3 = Color3.fromRGB(200, 200, 200)
    userName.TextScaled = false
    userName.TextSize = 18
    userName.TextWrapped = true
    userName.TextXAlignment = Enum.TextXAlignment.Left
    userName.TextYAlignment = Enum.TextYAlignment.Top
    userName.Position = UDim2.new(0, 100, 0, 54)
    userName.Size = UDim2.new(1, -110, 0, 32)
    userName.Parent = button

    button.MouseButton1Click:Connect(function()
        teleportEvent:FireServer(field)
    end)

    billboard.Parent = field

    panels[field] = {
        gui = billboard,
        avatar = avatar,
        displayName = displayName,
        userName = userName,
        userId = nil,
    }
end

local function updatePanel(field)
    local userId = field:GetAttribute("AssignedUserId")
    local storedName = field:GetAttribute("AssignedUserName")
    local display = field:GetAttribute("AssignedDisplayName") or storedName

    if not userId or not storedName then
        destroyPanel(field)
        return
    end

    if not panels[field] then
        createPanel(field)
    end

    local data = panels[field]
    if not data then
        return
    end

    if data.userId ~= userId then
        data.avatar.Image = getAvatarImage(userId)
        data.userId = userId
    end

    data.displayName.Text = display or storedName
    data.userName.Text = "@" .. storedName
end

local function watchField(field)
    if panels[field] or fieldWatchers[field] then
        updatePanel(field)
        return
    end

    local connections = {}

    table.insert(connections, field:GetAttributeChangedSignal("AssignedUserId"):Connect(function()
        updatePanel(field)
    end))

    table.insert(connections, field:GetAttributeChangedSignal("AssignedUserName"):Connect(function()
        updatePanel(field)
    end))

    table.insert(connections, field:GetAttributeChangedSignal("AssignedDisplayName"):Connect(function()
        updatePanel(field)
    end))

    fieldWatchers[field] = connections
    updatePanel(field)
end

for _, field in ipairs(CollectionService:GetTagged(FIELD_TAG_NAME)) do
    watchField(field)
end

CollectionService:GetInstanceAddedSignal(FIELD_TAG_NAME):Connect(function(field)
    watchField(field)
end)

CollectionService:GetInstanceRemovedSignal(FIELD_TAG_NAME):Connect(function(field)
    unwatchField(field)
end)

localPlayer.CharacterAdded:Connect(function()
    for field in pairs(panels) do
        updatePanel(field)
    end
end)