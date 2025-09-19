-- InitServer (Script в ServerScriptService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Список необходимых RemoteEvents
local remoteEvents = {
    "BuildBlockEvent",
    "InventoryEvent"
}

-- Создаем все RemoteEvents
for _, eventName in ipairs(remoteEvents) do
    if not ReplicatedStorage:FindFirstChild(eventName) then
        local event = Instance.new("RemoteEvent")
        event.Name = eventName
        event.Parent = ReplicatedStorage
        print("✅ Создан RemoteEvent: " .. eventName)
    end
end

print("✅ Все RemoteEvents созданы")