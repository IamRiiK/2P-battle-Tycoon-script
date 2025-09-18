-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Library UI (Simple Drag + Minimize)
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
ScreenGui.Name = "RiiKHub"

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 260, 0, 340)
MainFrame.Position = UDim2.new(0.3, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.Active = true
MainFrame.Draggable = true

local TitleBar = Instance.new("TextButton", MainFrame)
TitleBar.Size = UDim2.new(1, 0, 0, 28)
TitleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
TitleBar.Text = " RiiK Hub - Toggle UI"

local Content = Instance.new("Frame", MainFrame)
Content.Size = UDim2.new(1, 0, 1, -48)
Content.Position = UDim2.new(0, 0, 0, 28)
Content.BackgroundColor3 = Color3.fromRGB(25, 25, 25)

local UIListLayout = Instance.new("UIListLayout", Content)
UIListLayout.Padding = UDim.new(0, 6)
UIListLayout.FillDirection = Enum.FillDirection.Vertical
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Aimbot status indicator
local AimbotStatus = Instance.new("TextLabel", MainFrame)
AimbotStatus.Size = UDim2.new(1, 0, 0, 20)
AimbotStatus.Position = UDim2.new(0, 0, 1, -20)
AimbotStatus.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
AimbotStatus.Text = "Aimbot: OFF"
AimbotStatus.TextColor3 = Color3.fromRGB(200, 50, 50)
AimbotStatus.TextScaled = true
AimbotStatus.Font = Enum.Font.SourceSansBold

local function updateAimbotStatus(state)
    if state then
        AimbotStatus.Text = "Aimbot: ON"
        AimbotStatus.TextColor3 = Color3.fromRGB(50, 200, 50)
    else
        AimbotStatus.Text = "Aimbot: OFF"
        AimbotStatus.TextColor3 = Color3.fromRGB(200, 50, 50)
    end
end

-- Minimize/maximize logic
local minimized = false
TitleBar.MouseButton1Click:Connect(function()
    minimized = not minimized
    Content.Visible = not minimized
    MainFrame.Size = minimized and UDim2.new(0,260,0,48) or UDim2.new(0,260,0,340)
end)

-------------------------------------------------
-- UI helper
-------------------------------------------------
local function createToggle(name, callback)
    local btn = Instance.new("TextButton", Content)
    btn.Size = UDim2.new(1, -10, 0, 28)
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    btn.Text = name .. " [OFF]"
    btn.MouseButton1Click:Connect(function()
        local state = btn.Text:find("OFF") ~= nil
        if state then
            btn.Text = name .. " [ON]"
            callback(true)
        else
            btn.Text = name .. " [OFF]"
            callback(false)
        end
    end)
end

local function createTextbox(name, callback)
    local box = Instance.new("TextBox", Content)
    box.Size = UDim2.new(1, -10, 0, 28)
    box.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    box.Text = name
    box.FocusLost:Connect(function()
        callback(box.Text)
    end)
end

-------------------------------------------------
-- 1. ESP
-------------------------------------------------
local espEnabled = false
local friendColor = Color3.fromRGB(13,71,21)
local enemyColor = Color3.fromRGB(76,75,22)

local function createESP(player)
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "ESPTag"
        billboard.Size = UDim2.new(0, 100, 0, 30)
        billboard.AlwaysOnTop = true
        billboard.Adornee = player.Character.HumanoidRootPart

        local label = Instance.new("TextLabel", billboard)
        label.Size = UDim2.new(1,0,1,0)
        label.BackgroundTransparency = 1
        label.Text = player.Name
        label.TextScaled = true
        label.Font = Enum.Font.SourceSansBold

        if player.Team == LocalPlayer.Team then
            label.TextColor3 = friendColor
        else
            label.TextColor3 = enemyColor
        end

        billboard.Parent = player.Character
    end
end

local function removeESP(player)
    if player.Character and player.Character:FindFirstChild("ESPTag") then
        player.Character.ESPTag:Destroy()
    end
end

local function toggleESP(state)
    espEnabled = state
    if espEnabled then
        for _,plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                createESP(plr)
            end
        end
        Players.PlayerAdded:Connect(function(plr)
            plr.CharacterAdded:Connect(function()
                if espEnabled then
                    task.wait(1)
                    createESP(plr)
                end
            end)
        end)
    else
        for _,plr in ipairs(Players:GetPlayers()) do
            removeESP(plr)
        end
    end
end

-------------------------------------------------
-- 2. Auto Press E
-------------------------------------------------
local autoPressE = false
createToggle("Auto Press E", function(state)
    autoPressE = state
    if state then
        task.spawn(function()
            while autoPressE do
                game:GetService("VirtualInputManager"):SendKeyEvent(true, "E", false, game)
                game:GetService("VirtualInputManager"):SendKeyEvent(false, "E", false, game)
                task.wait(0.5)
            end
        end)
    end
end)

-------------------------------------------------
-- 3. Auto Grab Weapon
-------------------------------------------------
local TycoonsFolder = Workspace:WaitForChild("Tycoons")
local toolGiverNames = {"ToolGiver1P1","ToolGiver1P2","ToolGiver2P1","ToolGiver3P1","ToolGiver3P2",
"ToolGiver4P1","ToolGiver4P2","ToolGiver5","ToolGiver5P1","ToolGiver5P2",
"ToolGiver6P1","ToolGiver6P2","ToolGiver7P1","ToolGiver7P2","ToolGiver8P1",
"ToolGiver8P2","ToolGiver9P1","ToolGiver9P2","ToolGiver10P1","ToolGiver10P2",
"ToolGiver11P1","ToolGiver11P2","ToolGiver12P1","ToolGiver12P2","ToolGiver13P1",
"ToolGiver13P2","ToolGiver14P1","ToolGiver14P2","ToolGiver100"}
local RootPart = nil
local function updateCharacterRoot()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    RootPart = character:WaitForChild("HumanoidRootPart")
end
updateCharacterRoot()
LocalPlayer.CharacterAdded:Connect(updateCharacterRoot)

local autoGrabRunning = false
createToggle("Auto Grab Weapon", function(state)
    autoGrabRunning = state
    if state then
        task.spawn(function()
            while autoGrabRunning do
                if RootPart then
                    for _,tycoon in ipairs(TycoonsFolder:GetChildren()) do
                        local purchased = tycoon:FindFirstChild("PurchasedObjects")
                        if purchased then
                            for _,name in ipairs(toolGiverNames) do
                                local giver = purchased:FindFirstChild(name)
                                if giver and giver:FindFirstChild("Touch") then
                                    pcall(function()
                                        firetouchinterest(giver.Touch, RootPart, 0)
                                        firetouchinterest(giver.Touch, RootPart, 1)
                                    end)
                                end
                            end
                        end
                    end
                end
                task.wait(1)
            end
        end)
    end
end)

-------------------------------------------------
-- 4. Walkspeed Toggle + Input
-------------------------------------------------
local walkspeedEnabled = false
local customSpeed = 16

createToggle("Toggle Walkspeed", function(state)
    walkspeedEnabled = state
end)

createTextbox("Set Walkspeed", function(text)
    local val = tonumber(text)
    if val then customSpeed = val end
end)

RunService.Heartbeat:Connect(function()
    if walkspeedEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = customSpeed
    end
end)

-------------------------------------------------
-- 5. Aimbot (smooth + F1 toggle + indicator)
-------------------------------------------------
local aimbotEnabled = false
local AIM_LERP = 0.3
local AIM_THRESHOLD = math.rad(35)

local function angleBetween(vec1, vec2)
    return math.acos(math.clamp(vec1:Dot(vec2) / (vec1.Magnitude * vec2.Magnitude), -1, 1))
end

local function getClosestEnemy()
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return nil end
    local myPos = myChar.HumanoidRootPart.Position
    local closest, shortest = nil, math.huge
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Team ~= LocalPlayer.Team and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local dist = (plr.Character.HumanoidRootPart.Position - myPos).Magnitude
            local hum = plr.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 and dist < shortest then
                shortest = dist
                closest = plr
            end
        end
    end
    return closest
end

RunService.RenderStepped:Connect(function()
    if aimbotEnabled then
        local target = getClosestEnemy()
        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            local camCF = Camera.CFrame
            local camDir = camCF.LookVector
            local dirToTarget = (target.Character.HumanoidRootPart.Position - camCF.Position).Unit
            local angle = angleBetween(camDir, dirToTarget)
            if angle <= AIM_THRESHOLD then
                local newCF = CFrame.new(camCF.Position, camCF.Position + camDir:Lerp(dirToTarget, AIM_LERP))
                Camera.CFrame = newCF
            end
        end
    end
end)

-- Hotkey F1
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.F1 then
        aimbotEnabled = not aimbotEnabled
        updateAimbotStatus(aimbotEnabled)
    end
end)

-------------------------------------------------
-- ESP Toggle button
-------------------------------------------------
createToggle("ESP", toggleESP)
