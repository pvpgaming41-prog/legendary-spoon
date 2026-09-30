-- Parth Hub v4.1 - Main Script
-- Save this as parthhub.lua on GitHub
-- Delta Executor Keyless | Mobile & PC

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

-- CONFIG
getgenv().Settings = {
    CheckServers = 200,
    MinFruitValue = 1000000,
    AutoHopDelay = 5,
    AFKMode = true,
    ShowFruitName = true,
    BestFruitOnly = false,
    GitHubFile = ""
}

-- Rare fruits list
local RareFruits = {
    "Dragon", "Leopard", "Venom", "Shadow", "Dough",
    "Control", "Gravity", "Rumble", "Mammoth", "T-Rex",
    "Buddha", "Portal", "Gas", "Yeti", "Lightning", "Magnet"
}

-- GUI Creation
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ParthHubGUI"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 400)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
MainFrame.BackgroundTransparency = 0.1
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
TitleBar.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 1, 0)
Title.BackgroundTransparency = 1
Title.Text = "Parth Hub - Server Hop"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 18
Title.Font = Enum.Font.GothamBold
Title.Parent = TitleBar

-- Close Button
local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 30, 0, 30)
CloseButton.Position = UDim2.new(1, -35, 0, 5)
CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.Parent = TitleBar
CloseButton.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Status Label
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 30)
StatusLabel.Position = UDim2.new(0, 10, 0, 50)
StatusLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
StatusLabel.Text = "Status: Idle"
StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
StatusLabel.TextSize = 14
StatusLabel.Parent = MainFrame

-- Toggle Buttons
local function CreateToggle(name, pos, default)
    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Size = UDim2.new(1, -20, 0, 35)
    ToggleButton.Position = UDim2.new(0, 10, 0, pos)
    ToggleButton.BackgroundColor3 = default and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(100, 100, 100)
    ToggleButton.Text = name .. (default and " ✅" or " ❌")
    ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleButton.TextSize = 14
    ToggleButton.Parent = MainFrame
    
    local state = default
    ToggleButton.MouseButton1Click:Connect(function()
        state = not state
        ToggleButton.BackgroundColor3 = state and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(100, 100, 100)
        ToggleButton.Text = name .. (state and " ✅" or " ❌")
        if name == "AFK Mode" then
            Settings.AFKMode = state
        elseif name == "Show Fruits" then
            Settings.ShowFruitName = state
        elseif name == "Best Fruit Only" then
            Settings.BestFruitOnly = state
        end
    end)
    
    return ToggleButton
end

CreateToggle("AFK Mode", 90, true)
CreateToggle("Show Fruits", 130, true)
CreateToggle("Best Fruit Only", 170, false)

-- Start Button
local StartButton = Instance.new("TextButton")
StartButton.Size = UDim2.new(1, -20, 0, 45)
StartButton.Position = UDim2.new(0, 10, 0, 220)
StartButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
StartButton.Text = "🚀 Start Server Hop"
StartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
StartButton.TextSize = 16
StartButton.Font = Enum.Font.GothamBold
StartButton.Parent = MainFrame

-- Function to get servers
local function GetServers(gameId)
    local servers = {}
    local cursor = ""
    repeat
        local url = string.format("https://games.roblox.com/v1/games/%s/servers/Public?limit=100", gameId) .. "&cursor=" .. cursor
        local success, response = pcall(function()
            return HttpService:GetAsync(url)
        end)
        if success then
            local data = HttpService:JSONDecode(response)
            for _, server in ipairs(data.data) do
                table.insert(servers, server)
            end
            cursor = data.nextPageCursor or ""
        end
    until cursor == "" or #servers >= Settings.CheckServers
    return servers
end

-- Function to check fruits in a server
local function CheckFruits(serverId)
    -- Simulate fruit detection (adapt this)
    local fruits = {}
    -- Add your own fruit detector here
    return fruits
end

-- Main server hop function
local function ServerHop()
    StatusLabel.Text = "Status: Searching servers..."
    local gameId = game.PlaceId
    local servers = GetServers(gameId)
    
    local bestServer = nil
    local bestFruit = nil
    
    for _, server in ipairs(servers) do
        if server.playing < server.maxPlayers then
            local fruits = CheckFruits(server.id)
            if #fruits > 0 then
                for _, fruit in ipairs(fruits) do
                    if Settings.ShowFruitName then
                        StatusLabel.Text = "🍎 Found: " .. fruit.name .. " in server " .. server.id
                        print("🍎 Fruit found: " .. fruit.name .. " in server " .. server.id)
                    end
                    
                    local isRare = table.find(RareFruits, fruit.name) ~= nil
                    local isBest = fruit.value >= Settings.MinFruitValue
                    
                    if Settings.BestFruitOnly and isBest then
                        bestServer = server
                        bestFruit = fruit
                        break
                    elseif not Settings.BestFruitOnly and isRare then
                        bestServer = server
                        bestFruit = fruit
                        break
                    end
                end
            end
        end
        wait(0.1)
    end
    
    if bestServer then
        StatusLabel.Text = "🎯 Best server found with: " .. bestFruit.name
        print("🎯 Best server found with: " .. bestFruit.name)
        wait(1)
        TeleportService:TeleportToPlaceInstance(gameId, bestServer.id)
    else
        StatusLabel.Text = "🔄 No good server found, hopping..."
        print("🔄 No good server found, hopping...")
        wait(1)
        TeleportService:TeleportToPlaceInstance(gameId, servers[1].id)
    end
end

-- Start button click
StartButton.MouseButton1Click:Connect(function()
    StatusLabel.Text = "🚀 Starting server hop..."
    while Settings.AFKMode do
        ServerHop()
        wait(Settings.AutoHopDelay)
    end
end)

-- Keep GUI visible
game:GetService("UserInputService").InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.RightShift then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

print("✅ Parth Hub v4.1 loaded! Press RightShift to toggle GUI")
