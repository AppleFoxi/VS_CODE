local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Скрипт управляет выдачей полей игрокам и дополнительными сервисами для панелей.
local FIELD_TAG_NAME = "PlayerField"
local TELEPORT_EVENT_NAME = "TeleportToFieldEvent"

local teleportEvent = ReplicatedStorage:FindFirstChild(TELEPORT_EVENT_NAME)
if not teleportEvent then
    teleportEvent = Instance.new("RemoteEvent")
    teleportEvent.Name = TELEPORT_EVENT_NAME
    teleportEvent.Parent = ReplicatedStorage
end

local fieldToPlayer = {}
local playerToField = {}

local function getFieldLabel(field)
    if not field then
        return "неизвестное поле"
    end

    local slot = field:GetAttribute("Slot")
        or field:GetAttribute("FieldSlot")
        or field:GetAttribute("FieldNumber")
        or field:GetAttribute("Index")

    if typeof(slot) == "number" or typeof(slot) == "string" then
        return tostring(slot)
    end

    return field.Name
end

local function getTaggedFields()
    local taggedFields = CollectionService:GetTagged(FIELD_TAG_NAME)
    if #taggedFields == 0 then
        warn("В мире не найдено ни одного объекта с тегом " .. FIELD_TAG_NAME)
    end
    return taggedFields
end

local function findAssignedField(player)
    return playerToField[player]
end

local function findFreeField()
    local taggedFields = getTaggedFields()
    for _, field in ipairs(taggedFields) do
        if field:IsDescendantOf(workspace) and not fieldToPlayer[field] then
            return field
        end
    end
    return nil
end

local function markFieldOwner(field, player)
    if not field then
        return
    end

    if player then
        field:SetAttribute("AssignedUserId", player.UserId)
        field:SetAttribute("AssignedUserName", player.Name)
        field:SetAttribute("AssignedDisplayName", player.DisplayName)
    else
        field:SetAttribute("AssignedUserId", nil)
        field:SetAttribute("AssignedUserName", nil)
        field:SetAttribute("AssignedDisplayName", nil)
    end
end

local function assignPlayerField(player)
    local currentField = findAssignedField(player)
    if currentField then
        return true, currentField
    end

    local freeField = findFreeField()
    if not freeField then
        warn("Нет свободных полей для игрока: " .. player.Name)
        return false, nil
    end

    fieldToPlayer[freeField] = player
    playerToField[player] = freeField
    markFieldOwner(freeField, player)

    print("Игрок " .. player.Name .. " получил поле " .. getFieldLabel(freeField))
    return true, freeField
end

local function releasePlayerField(player)
    local assignedField = playerToField[player]
    if not assignedField then
        return
    end

    fieldToPlayer[assignedField] = nil
    playerToField[player] = nil
    markFieldOwner(assignedField, nil)

    print("Поле " .. getFieldLabel(assignedField) .. " снова свободно после выхода игрока " .. player.Name)
end

local function teleportPlayerToField(player, field)
    if not player or not field then
        return
    end

    if not field:IsDescendantOf(workspace) then
        return
    end

    if not CollectionService:HasTag(field, FIELD_TAG_NAME) then
        return
    end

    local character = player.Character
    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")

    if not humanoidRootPart then
        return
    end

    local position = field.Position
    local lift = 5
    if field:IsA("BasePart") then
        lift = math.max(field.Size.Y * 0.5 + 5, 5)
    end

    humanoidRootPart.CFrame = CFrame.new(Vector3.new(position.X, position.Y + lift, position.Z))
end

teleportEvent.OnServerEvent:Connect(function(player, field)
    if typeof(field) ~= "Instance" then
        return
    end

    if not field:IsA("BasePart") then
        return
    end

    teleportPlayerToField(player, field)
end)

Players.PlayerAdded:Connect(function(player)
    assignPlayerField(player)
end)

Players.PlayerRemoving:Connect(function(player)
    releasePlayerField(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
    task.defer(assignPlayerField, player)
end

local function validateFieldsOnStart()
    local taggedFields = CollectionService:GetTagged(FIELD_TAG_NAME)
    if #taggedFields == 0 then
        warn("PlayerFieldManager не нашёл объектов с тегом " .. FIELD_TAG_NAME)
        return
    end

    for _, field in ipairs(taggedFields) do
        if fieldToPlayer[field] then
            markFieldOwner(field, fieldToPlayer[field])
        else
            markFieldOwner(field, nil)
        end
    end

    print("Найдено полей с тегом " .. FIELD_TAG_NAME .. ": " .. #taggedFields)
end

validateFieldsOnStart()