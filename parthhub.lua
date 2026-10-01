-- Parth Hub V7 - Ultimate Fruit Hunter (Advanced Edition)
-- All Mythicals + Buddha + Portal + Auto-Sell + Anti-Ban + Webhook
-- Kaitlyn Hub style server check | Delta Keyless | Mobile Compatible

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

-- ============ CONFIG ============
getgenv().Settings = {
    CheckServers = 500,
    AutoHopDelay = 2,
    AFKMode = true,
    ShowFruitName = true,
    BestFruitOnly = false,
    AutoCollect = true,
    AutoStore = true,
    AutoSell = false,
    AutoBuy = false,
    WebhookURL = "",
    AntiBan = true,
    SpeedBoost = false,
    AutoFarm = false,
    TeleportToFruit = true,
    InstantCollect = false,
    FruitESP = true,
    Notification = true,
}

-- ============ FRUIT RARITY ============
local FruitRarity = {
    Dragon = 100, Kitsune = 98, Leopard = 95, T-Rex = 92, Yeti = 90,
    Gas = 88, Tiger = 85, Mammoth = 82, Dough = 80, Venom = 75,
    Control = 70, Spirit = 68, Buddha = 65, Portal = 60, Gravity = 55,
    Rumble = 50, Quake = 45, Phoenix = 40, Shadow = 72,
    Flame = 5, Ice = 5, Light = 5, Dark = 5, Sand = 5,
    Spring = 5, Bomb = 5, Spin = 5, Chop = 5, Smoke = 5,
    Diamond = 5, Rubber = 5, Falcon = 5, Ghost = 5, Barrier = 5,
    Magma = 10, Blizzard = 10, Love = 10, Spider = 10, Sound = 10,
    Pain = 10, Eagle = 10, Spike = 10, Rocket = 5, Blade = 5,
}

-- ============ ANTI-BAN SYSTEM ============
local AntiBan = {
    Enabled = true,
    LastAction = 0,
    ActionCooldown = 0.5,
    
    Execute = function(self, action)
        if not self.Enabled then return true end
        local now = os.clock()
        if now - self.LastAction < self.ActionCooldown then
            task.wait(self.ActionCooldown - (now - self.LastAction))
        end
        self.LastAction = os.clock()
        return true
    end,
    
    Randomize = function()
        if not Settings.AntiBan then return end
        -- Random small delays to avoid detection patterns
        task.wait(math.random(50, 150) / 1000)
    end,
    
    FakeAFK = function()
        if not Settings.AFKMode then return end
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end,
    
    RandomHop = function()
        if not Settings.AntiBan then return end
        -- Occasionally hop to random servers instead of best
        if math.random(1, 10) == 1 then
            return true
        end
        return false
    end,
    
    StealthMode = function()
        if not Settings.AntiBan then return end
        -- Reduce visual effects
        pcall(function()
            Lighting.Brightness = 1
            Lighting.ClockTime = 14
        end)
    end,
}

-- ============ ESP SYSTEM ============
local ESP = {
    Enabled = true,
    Objects = {},
    
    Create = function(self, fruit)
        if not self.Enabled or not fruit then return end
        
        local billboard = Instance.new("BillboardGui")
        billboard.Size = UDim2.new(0, 100, 0, 30)
        billboard.AlwaysOnTop = true
        billboard.Adornee = fruit.model
        billboard.Parent = fruit.model
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = fruit.name .. " ⭐" .. fruit.value
        label.TextSize = 14
        label.Font = Enum.Font.GothamBold
        
        -- Color coding
        if fruit.value >= 90 then
            label.TextColor3 = Color3.fromRGB(255, 0, 0)
        elseif fruit.value >= 70 then
            label.TextColor3 = Color3.fromRGB(255, 150, 0)
        elseif fruit.value >= 50 then
            label.TextColor3 = Color3.fromRGB(255, 200, 0)
        else
            label.TextColor3 = Color3.fromRGB(150, 150, 150)
        end
        
        label.Parent = billboard
        
        -- Distance line
        local line = Instance.new("Part")
        line.Size = Vector3.new(0.1, 0.1, 0.1)
        line.Transparency = 0.5
        line.Color = label.TextColor3
        line.Anchored = true
        line.CanCollide = false
        line.Parent = workspace
        
        self.Objects[fruit.model] = {
            billboard = billboard,
            line = line,
            fruit = fruit
        }
    end,
    
    Update = function(self)
        if not self.Enabled then return end
        
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        
        local hrp = char.HumanoidRootPart
        
        for model, data in pairs(self.Objects) do
            if model and model.Parent then
                -- Update line position
                local fruitPos = model:GetPivot().Position
                data.line.CFrame = CFrame.new(hrp.Position, fruitPos)
                data.line.Size = Vector3.new(0.1, 0.1, (hrp.Position - fruitPos).Magnitude)
            else
                -- Clean up
                data.billboard:Destroy()
                data.line:Destroy()
                self.Objects[model] = nil
            end
        end
    end,
    
    Clear = function(self)
        for model, data in pairs(self.Objects) do
            if data.billboard then data.billboard:Destroy() end
            if data.line then data.line:Destroy() end
        end
        self.Objects = {}
    end
}

-- ============ SPEED BOOST ============
local function SpeedBoost()
    if not Settings.SpeedBoost then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    
    if hrp and humanoid then
        -- Increase walkspeed
        humanoid.WalkSpeed = 100
        -- Jump power boost
        humanoid.JumpPower = 100
        -- Anti-gravity
        if hrp.Velocity.Magnitude > 50 then
            hrp.Velocity = hrp.Velocity * 1.5
        end
    end
end

-- ============ AUTO FARM ============
local AutoFarm = {
    Enabled = false,
    Target = nil,
    
    FindTarget = function(self)
        if not Settings.AutoFarm then return nil end
        
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
        
        local hrp = char.HumanoidRootPart
        local nearest = nil
        local nearestDist = math.huge
        
        -- Find nearest enemy
        for _, enemy in ipairs(workspace:GetChildren()) do
            if enemy:IsA("Model") and enemy:FindFirstChild("Humanoid") then
                local enemyHRP = enemy:FindFirstChild("HumanoidRootPart")
                if enemyHRP and enemy.Name ~= LocalPlayer.Name then
                    local dist = (hrp.Position - enemyHRP.Position).Magnitude
                    if dist < nearestDist and dist < 100 then
                        nearest = enemy
                        nearestDist = dist
                    end
                end
            end
        end
        
        return nearest
    end,
    
    Attack = function(self, target)
        if not target then return end
        
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        
        local hrp = char.HumanoidRootPart
        local enemyHRP = target:FindFirstChild("HumanoidRootPart")
        
        if enemyHRP then
            -- Teleport to enemy
            hrp.CFrame = enemyHRP.CFrame * CFrame.new(0, 0, 5)
            
            -- Use equipped tools
            for _, tool in ipairs(char:GetChildren()) do
                if tool:IsA("Tool") then
                    tool:Activate()
                    task.wait(0.1)
                end
            end
            
            -- Use skills (Blox Fruits specific)
            pcall(function()
                local skills = {
                    "Z", "X", "C", "V", "F", "G"
                }
                for _, skill in ipairs(skills) do
                    local key = Enum.KeyCode[skill]
                    if key then
                        key:Connect(function() end)
                    end
                end
            end)
        end
    end,
    
    Loop = function(self)
        while Settings.AutoFarm do
            self.Target = self:FindTarget()
            if self.Target then
                self:Attack(self.Target)
            end
            task.wait(0.5)
        end
    end
}

-- ============ INSTANT COLLECT ============
local function InstantCollect(fruit)
    if not Settings.InstantCollect then return end
    
    -- Use CFrame teleportation for instant collection
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = char.HumanoidRootPart
    hrp.CFrame = fruit.model:GetPivot()
    
    -- Fire all possible remotes at once
    pcall(function()
        local remotes = {
            "CollectFruit", "FruitCollect", "GetFruit", "ClaimFruit",
            "RemoteEvent", "RemoteFunction", "MainEvent"
        }
        
        for _, remoteName in ipairs(remotes) do
            local remote = ReplicatedStorage:FindFirstChild(remoteName)
            if remote then
                remote:FireServer(fruit.model)
                task.wait(0.05)
            end
        end
    end)
end

-- ============ AUTO SELL ============
local function AutoSellFruits()
    if not Settings.AutoSell then return end
    
    -- Find sell NPC
    for _, npc in ipairs(workspace:GetChildren()) do
        local name = npc.Name:lower()
        if name:find("seller") or name:find("dealer") or name:find("merchant") then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                char.HumanoidRootPart.CFrame = CFrame.new(npc:GetPivot().Position + Vector3.new(0, 3, 0))
                task.wait(0.3)
                
                -- Click sell button
                local cd = npc:FindFirstChildOfClass("ClickDetector")
                if cd then
                    fireclickdetector(cd)
                end
                
                -- Fire sell remote
                pcall(function()
                    local sellRemote = ReplicatedStorage:FindFirstChild("SellFruit")
                    if sellRemote then
                        sellRemote:FireServer()
                    end
                end)
            end
        end
    end
end

-- ============ AUTO BUY ============
local function AutoBuyFruit(fruitName)
    if not Settings.AutoBuy then return end
    
    -- Find fruit shop
    for _, shop in ipairs(workspace:GetChildren()) do
        local name = shop.Name:lower()
        if name:find("shop") or name:find("dealer") then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                char.HumanoidRootPart.CFrame = CFrame.new(shop:GetPivot().Position + Vector3.new(0, 3, 0))
                task.wait(0.3)
                
                -- Buy fruit
                pcall(function()
                    local buyRemote = ReplicatedStorage:FindFirstChild("BuyFruit")
                    if buyRemote then
                        buyRemote:FireServer(fruitName)
                    end
                end)
            end
        end
    end
end

-- ============ NOTIFICATION SYSTEM ============
local function Notify(title, text, duration)
    if not Settings.Notification then return end
    
    local notification = Instance.new("ScreenGui")
    notification.Name = "Notification"
    notification.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 50)
    frame.Position = UDim2.new(0.5, -100, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    frame.BorderSizePixel = 0
    frame.Parent = notification
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0.4, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
    titleLabel.TextSize = 14
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = frame
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 0.6, 0)
    textLabel.Position = UDim2.new(0, 0, 0.4, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = text
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextSize = 12
    textLabel.Font = Enum.Font.Gotham
    textLabel.Parent = frame
    
    task.wait(duration or 3)
    notification:Destroy()
end

-- ============ GUI ============
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ParthHubV7"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 350, 0, 600)
MainFrame.Position = UDim2.new(0.03, 0, 0.03, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 30)
MainFrame.BackgroundTransparency = 0.05
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

-- Title
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 45)
TitleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 65)
TitleBar.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 1, 0)
Title.BackgroundTransparency = 1
Title.Text = "🍎 Parth Hub V7 - Ultimate"
Title.TextColor3 = Color3.fromRGB(255, 200, 0)
Title.TextSize = 20
Title.Font = Enum.Font.GothamBold
Title.Parent = TitleBar

-- Status
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 35)
StatusLabel.Position = UDim2.new(0, 10, 0, 55)
StatusLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
StatusLabel.Text = "Status: Idle"
StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
StatusLabel.TextSize = 14
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Parent = MainFrame

-- Server info
local ServerInfo = Instance.new("TextLabel")
ServerInfo.Size = UDim2.new(1, -20, 0, 25)
ServerInfo.Position = UDim2.new(0, 10, 0, 95)
ServerInfo.BackgroundTransparency = 1
ServerInfo.Text = "Servers checked: 0/500"
ServerInfo.TextColor3 = Color3.fromRGB(150, 150, 150)
ServerInfo.TextSize = 12
ServerInfo.Font = Enum.Font.Gotham
ServerInfo.Parent = MainFrame

-- Tabs
local Tab1 = Instance.new("TextButton")
Tab1.Size = UDim2.new(0.5, -10, 0, 30)
Tab1.Position = UDim2.new(0, 10, 0, 125)
Tab1.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
Tab1.Text = "Main"
Tab1.TextColor3 = Color3.fromRGB(255, 255, 255)
Tab1.TextSize = 14
Tab1.Font = Enum.Font.GothamBold
Tab1.Parent = MainFrame

local Tab2 = Instance.new("TextButton")
Tab2.Size = UDim2.new(0.5, -10, 0, 30)
Tab2.Position = UDim2.new(0.5, 0, 0, 125)
Tab2.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
Tab2.Text = "Advanced"
Tab2.TextColor3 = Color3.fromRGB(255, 255, 255)
Tab2.TextSize = 14
Tab2.Font = Enum.Font.GothamBold
Tab2.Parent = MainFrame

-- Main tab content
local MainContent = Instance.new("Frame")
MainContent.Size = UDim2.new(1, -20, 1, -170)
MainContent.Position = UDim2.new(0, 10, 0, 160)
MainContent.BackgroundTransparency = 1
MainContent.Parent = MainFrame

-- Advanced tab content
local AdvancedContent = Instance.new("Frame")
AdvancedContent.Size = UDim2.new(1, -20, 1, -170)
AdvancedContent.Position = UDim2.new(0, 10, 0, 160)
AdvancedContent.BackgroundTransparency = 1
AdvancedContent.Visible = false
AdvancedContent.Parent = MainFrame

-- Create toggles function
local function CreateToggle(parent, name, pos, default, setting)
    local Toggle = Instance.new("TextButton")
    Toggle.Size = UDim2.new(1, -10, 0, 25)
    Toggle.Position = UDim2.new(0, 5, 0, pos)
    Toggle.BackgroundColor3 = default and Color3.fromRGB(50, 200, 100) or Color3.fromRGB(70, 70, 85)
    Toggle.Text = name .. (default and " ✅" or " ❌")
    Toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    Toggle.TextSize = 12
    Toggle.Font = Enum.Font.Gotham
    Toggle.Parent = parent
    
    local state = default
    Toggle.MouseButton1Click:Connect(function()
        state = not state
        Toggle.BackgroundColor3 = state and Color3.fromRGB(50, 200, 100) or Color3.fromRGB(70, 70, 85)
        Toggle.Text = name .. (state and " ✅" or " ❌")
        Settings[setting] = state
    end)
    return Toggle
end

-- Main toggles
CreateToggle(MainContent, "AFK Mode", 0, true, "AFKMode")
CreateToggle(MainContent, "Show Fruits", 30, true, "ShowFruitName")
CreateToggle(MainContent, "Best Fruit Only", 60, false, "BestFruitOnly")
CreateToggle(MainContent, "Auto Collect", 90, true, "AutoCollect")
CreateToggle(MainContent, "Auto Store", 120, true, "AutoStore")
CreateToggle(MainContent, "Fruit ESP", 150, true, "FruitESP")
CreateToggle(MainContent, "Teleport To Fruit", 180, true, "TeleportToFruit")

-- Advanced toggles
CreateToggle(AdvancedContent, "Anti-Ban", 0, true, "AntiBan")
CreateToggle(AdvancedContent, "Speed Boost", 30, false, "SpeedBoost")
CreateToggle(AdvancedContent, "Auto Farm", 60, false, "AutoFarm")
CreateToggle(AdvancedContent, "Instant Collect", 90, false, "InstantCollect")
CreateToggle(AdvancedContent, "Auto Sell", 120, false, "AutoSell")
CreateToggle(AdvancedContent, "Auto Buy", 150, false, "AutoBuy")
CreateToggle(AdvancedContent, "Notifications", 180, true, "Notification")

-- Start button
local StartButton = Instance.new("TextButton")
StartButton.Size = UDim2.new(1, -20, 0, 40)
StartButton.Position = UDim2.new(0, 10, 0, 220)
StartButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
StartButton.Text = "🚀 START HUNTER"
StartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
StartButton.TextSize = 16
StartButton.Font = Enum.Font.GothamBold
StartButton.Parent = MainContent

-- Fruit list
local FruitListFrame = Instance.new("ScrollingFrame")
FruitListFrame.Size = UDim2.new(1, -10, 0, 150)
FruitListFrame.Position = UDim2.new(0, 5, 0, 265)
FruitListFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
FruitListFrame.CanvasSize = UDim2.new(0, 0, 2, 0)
FruitListFrame.ScrollBarThickness = 3
FruitListFrame.Parent = MainContent

-- Tab switching
Tab1.MouseButton1Click:Connect(function()
    MainContent.Visible = true
    AdvancedContent.Visible = false
    Tab1.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
    Tab2.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
end)

Tab2.MouseButton1Click:Connect(function()
    MainContent.Visible = false
    AdvancedContent.Visible = true
    Tab2.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
    Tab1.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
end)

-- ============ SERVER CHECKER (Enhanced) ============
local function GetAllServers()
    local servers = {}
    local cursor = ""
    local totalChecked = 0
    
    repeat
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?limit=100"
        if cursor ~= "" then url = url .. "&cursor=" .. cursor end
        
        local success, response = pcall(function()
            return HttpService:GetAsync(url)
        end)
        
        if success then
            local data = HttpService:JSONDecode(response)
            for _, server in ipairs(data.data) do
                if server.playing < server.maxPlayers and server.id ~= game.JobId then
                    table.insert(servers, {
                        id = server.id,
                        players = server.playing,
                        maxPlayers = server.maxPlayers,
                        ping = server.ping or 0,
                    })
                end
            end
            totalChecked = totalChecked + #data.data
            ServerInfo.Text = "Servers checked: " .. totalChecked .. "/" .. Settings.CheckServers
            cursor = data.nextPageCursor or ""
        else
            break
        end
        task.wait(0.1)
    until cursor == "" or totalChecked >= Settings.CheckServers
    
    return servers
end

-- ============ FRUIT DETECTION (Enhanced) ============
local function DetectFruitsInCurrentServer()
    local fruits = {}
    
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") then
            local name = obj.Name
            for fruitName in pairs(FruitRarity) do
                if name:lower():find(fruitName:lower()) and (name:lower():find("fruit") or name:lower():find("_")) then
                    table.insert(fruits, {
                        name = fruitName,
                        value = FruitRarity[fruitName],
                        model = obj,
                        position = obj:GetPivot().Position
                    })
                    break
                end
            end
        end
        
        if obj:IsA("Part") and obj:FindFirstChild("ClickDetector") then
            local name = obj.Name
            for fruitName in pairs(FruitRarity) do
                if name:lower():find(fruitName:lower()) then
                    table.insert(fruits, {
                        name = fruitName,
                        value = FruitRarity[fruitName],
                        model = obj,
                        position = obj.Position
                    })
                    break
                end
            end
        end
    end
    
    return fruits
end

-- ============ SERVER SCORING ============
local function ScoreServer(server)
    local score = 0
    
    if server.players <= 3 then score = score + 50
    elseif server.players <= 6 then score = score + 30
    elseif server.players <= 10 then score = score + 15
    else score = score + 5 end
    
    if server.ping < 100 then score = score + 30
    elseif server.ping < 200 then score = score + 20
    else score = score + 10 end
    
    return score
end

local function FindBestServer(servers)
    local best = nil
    local bestScore = -1
    
    for _, server in ipairs(servers) do
        local score = ScoreServer(server)
        if score > bestScore then
            bestScore = score
            best = server
        end
    end
    
    return best
end

-- ============ COLLECT FRUIT (Enhanced) ============
local function CollectFruit(fruit)
    if not fruit or not fruit.model then return end
    
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    AntiBan:Execute()
    
    -- Teleport to fruit
    if Settings.TeleportToFruit then
        local hrp = char.HumanoidRootPart
        hrp.CFrame = CFrame.new(fruit.position + Vector3.new(0, 5, 0))
        task.wait(0.3)
    end
    
    -- Try click detector
    local cd = fruit.model:FindFirstChildOfClass("ClickDetector")
    if cd then
        fireclickdetector(cd)
    end
    
    -- Try all remotes
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        for _, remote in ipairs(remotes:GetChildren()) do
            local rname = remote.Name:lower()
            if rname:find("fruit") or rname:find("collect") or rname:find("claim") then
                pcall(function()
                    remote:FireServer(fruit.model)
                end)
            end
        end
    end
    
    -- Legacy remotes
    pcall(function()
        local event = ReplicatedStorage:FindFirstChild("Fruit")
        if event then
            event:FireServer(fruit.model)
        end
    end)
    
    if Settings.InstantCollect then
        InstantCollect(fruit)
    end
    
    if Settings.ShowFruitName then
        StatusLabel.Text = "🎯 Collected: " .. fruit.name
        StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        Notify("Fruit Collected!", fruit.name .. " ⭐" .. fruit.value, 2)
    end
end

-- ============ STORE FRUIT (Enhanced) ============
local function StoreFruit()
    if not Settings.AutoStore then return end
    
    for _, obj in ipairs(workspace:GetChildren()) do
        local name = obj.Name:lower()
        if name:find("store") or name:find("chest") or name:find("storage") or name:find("vault") then
            local cd = obj:FindFirstChildOfClass("ClickDetector")
            if cd then
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    char.HumanoidRootPart.CFrame = CFrame.new(obj:GetPivot().Position + Vector3.new(0, 3, 0))
                    task.wait(0.3)
                    fireclickdetector(cd)
                end
            end
        end
    end
end

-- ============ UPDATE FRUIT LIST ============
local function UpdateFruitList(fruits)
    for _, child in ipairs(FruitListFrame:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    
    local y = 0
    for _, fruit in ipairs(fruits) do
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -10, 0, 20)
        label.Position = UDim2.new(0, 5, 0, y)
        label.BackgroundTransparency = 1
        label.Text = "• " .. fruit.name .. " (⭐" .. fruit.value .. ")"
        
        if fruit.value >= 90 then
            label.TextColor3 = Color3.fromRGB(255, 0, 0)
        elseif fruit.value >= 70 then
            label.TextColor3 = Color3.fromRGB(255, 150, 0)
        elseif fruit.value >= 50 then
            label.TextColor3 = Color3.fromRGB(255, 200, 0)
        else
            label.TextColor3 = Color3.fromRGB(150, 150, 150)
        end
        
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Font = Enum.Font.Gotham
        label.Parent = FruitListFrame
        y = y + 22
    end
    FruitListFrame.CanvasSize = UDim2.new(0, 0, 0, y)
end

-- ============ MAIN HUNTING LOOP (Enhanced) ============
local Hunting = false

local function HuntLoop()
    while Hunting do
        AntiBan:Randomize()
        
        local currentFruits = DetectFruitsInCurrentServer()
        
        if #currentFruits > 0 then
            table.sort(currentFruits, function(a, b)
                return a.value > b.value
            end)
            
            local bestFruit = currentFruits[1]
            
            if Settings.ShowFruitName then
                StatusLabel.Text = "🎯 Found: " .. bestFruit.name .. " (⭐" .. bestFruit.value .. ")"
                StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
                UpdateFruitList(currentFruits)
            end
            
            -- ESP update
            if Settings.FruitESP then
                ESP:Clear()
                for _, fruit in ipairs(currentFruits) do
                    ESP:Create(fruit)
                end
            end
            
            if (Settings.BestFruitOnly and bestFruit.value >= 60) or (not Settings.BestFruitOnly and bestFruit.value >= 5) then
                CollectFruit(bestFruit)
                StoreFruit()
                AutoSellFruits()
                task.wait(2)
            end
        else
            StatusLabel.Text = "🔄 Scanning " .. Settings.CheckServers .. " servers..."
            StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
            
            local servers = GetAllServers()
            
            if #servers > 0 then
                local bestServer = FindBestServer(servers)
                
                if bestServer then
                    StatusLabel.Text = "🎯 Best server: " .. bestServer.players .. " players"
                    StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
                    
                    -- Anti-ban random hop
                    if AntiBan:RandomHop() then
                        local randomServer = servers[math.random(1, #servers)]
                        if randomServer then
                            bestServer = randomServer
                        end
                    end
                    
                    task.wait(Settings.AutoHopDelay)
                    
                    pcall(function()
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, bestServer.id, LocalPlayer)
                    end)
                    
                    task.wait(3)
                end
            else
                StatusLabel.Text = "⚠️ No servers found, retrying..."
                StatusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
                task.wait(Settings.AutoHopDelay)
            end
        end
        
        -- Speed boost
        SpeedBoost()
        
        task.wait(1)
    end
end

-- ============ START BUTTON ============
StartButton.MouseButton1Click:Connect(function()
    Hunting = not Hunting
    
    if Hunting then
        StartButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        StartButton.Text = "⏸ STOP HUNTER"
        StatusLabel.Text = "Status: HUNTING"
        StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        task.spawn(HuntLoop)
        task.spawn(AutoFarm.Loop, AutoFarm)
        Notify("Hunter Started!", "Scanning for fruits...", 2)
    else
        StartButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        StartButton.Text = "🚀 START HUNTER"
        StatusLabel.Text = "Status: Idle"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        ESP:Clear()
        Notify("Hunter Stopped!", "AFK Mode disabled", 2)
    end
end)

-- ============ ANTI-AFK ============
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- ============ ESP LOOP ============
RunService.RenderStepped:Connect(function()
    ESP:Update()
end)

-- ============ TOGGLE GUI ============
game:GetService("UserInputService").InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.RightShift then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

-- ============ INITIALIZATION ============
AntiBan:StealthMode()
print("✅ Parth Hub V7 loaded!")
print("🍎 All Mythicals + Buddha + Portal included")
print("🎯 Kaitlyn Hub style server checker active")
print("🛡️ Anti-Ban system enabled")
print("⌨️ Press RightShift to toggle GUI")
