--// 2P Battle Tycoon Hack - Final Version (dengan Auto Press E)
-- UI + Aimbot + AutoGrab + WalkSpeed + ESP + Auto Press E

------------------------
-- Services
------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

------------------------
-- UI Setup
------------------------
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- hapus UI lama biar gak dobel
if PlayerGui:FindFirstChild("TycoonHackUI") then
    PlayerGui.TycoonHackUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TycoonHackUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.Size = UDim2.new(0, 240, 0, 350)
MainFrame.Position = UDim2.new(0, 120, 0.3, 0)
MainFrame.Visible = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

-- Title bar (bisa drag)
local TitleBar = Instance.new("TextLabel")
TitleBar.Parent = MainFrame
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
TitleBar.Text = "2P Battle Tycoon Hack"
TitleBar.Font = Enum.Font.SourceSansBold
TitleBar.TextSize = 16
TitleBar.TextColor3 = Color3.fromRGB(255, 255, 255)

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Parent = MainFrame
UIListLayout.Padding = UDim.new(0, 4)
UIListLayout.FillDirection = Enum.FillDirection.Vertical
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder

local UIPadding = Instance.new("UIPadding")
UIPadding.Parent = MainFrame
UIPadding.PaddingTop = UDim.new(0, 35)

-- Floating menu button (selalu ada)
local FloatBtn = Instance.new("TextButton")
FloatBtn.Parent = ScreenGui
FloatBtn.Size = UDim2.new(0, 80, 0, 30)
FloatBtn.Position = UDim2.new(0, 20, 0, 20)
FloatBtn.Text = "Menu"
FloatBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
FloatBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 6)

FloatBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Dragging MainFrame
do
    local dragging, dragInput, dragStart, startPos
    local function update(input)
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    TitleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)
end

------------------------
-- UI Helpers
------------------------
local function createToggle(name, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 200, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = "[ ] " .. name
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 16
    btn.Parent = MainFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = (state and "[✔] " or "[ ] ") .. name
        callback(state)
    end)
    return btn
end

local function createTextbox(name, callback)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 200, 0, 30)
    box.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.PlaceholderText = name
    box.ClearTextOnFocus = false
    box.Parent = MainFrame
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
    box.FocusLost:Connect(function(enter)
        if enter and box.Text ~= "" then
            callback(box.Text)
        end
    end)
    return box
end

------------------------
-- Features
------------------------

-- Aimbot
do
    local aimbotEnabled = false
    local function getClosestEnemy()
        local myChar = LocalPlayer.Character
        if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return nil end
        local myPos = myChar.HumanoidRootPart.Position
        local closest, shortest = nil, math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Team ~= LocalPlayer.Team and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local dist = (plr.Character.HumanoidRootPart.Position - myPos).Magnitude
                local hum = plr.Character:FindFirstChild("Humanoid")
                if hum and hum.Health > 0 and dist < shortest then
                    shortest, closest = dist, plr
                end
            end
        end
        return closest
    end
    RunService.RenderStepped:Connect(function()
        if aimbotEnabled then
            local target = getClosestEnemy()
            if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Character.HumanoidRootPart.Position)
            end
        end
    end)
    createToggle("Aimbot", function(val)
        aimbotEnabled = val
    end)
end

-- Auto Grab Weapons
do
    local TycoonsFolder = Workspace:WaitForChild("Tycoons")
    local toolGiverNames = {
        "ToolGiver1P1","ToolGiver1P2","ToolGiver2P1","ToolGiver3P1","ToolGiver3P2",
        "ToolGiver4P1","ToolGiver4P2","ToolGiver5","ToolGiver5P1","ToolGiver5P2",
        "ToolGiver6P1","ToolGiver6P2","ToolGiver7P1","ToolGiver7P2",
        "ToolGiver8P1","ToolGiver8P2","ToolGiver9P1","ToolGiver9P2",
        "ToolGiver10P1","ToolGiver10P2","ToolGiver11P1","ToolGiver11P2",
        "ToolGiver12P1","ToolGiver12P2","ToolGiver13P1","ToolGiver13P2",
        "ToolGiver14P1","ToolGiver14P2","ToolGiver100"
    }
    local RootPart
    LocalPlayer.CharacterAdded:Connect(function(c) RootPart = c:WaitForChild("HumanoidRootPart") end)
    if LocalPlayer.Character then RootPart = LocalPlayer.Character:WaitForChild("HumanoidRootPart") end
    local running = false
    createToggle("Auto Grab Weapons", function(state)
        running = state
        if state then
            task.spawn(function()
                while running do
                    if RootPart and RootPart.Parent then
                        for _, tycoon in ipairs(TycoonsFolder:GetChildren()) do
                            local purchased = tycoon:FindFirstChild("PurchasedObjects")
                            if purchased then
                                for _, name in ipairs(toolGiverNames) do
                                    local giver = purchased:FindFirstChild(name)
                                    if giver and giver:FindFirstChild("Touch") then
                                        pcall(function()
                                            firetouchinterest(RootPart, giver.Touch, 0)
                                            firetouchinterest(RootPart, giver.Touch, 1)
                                        end)
                                    end
                                end
                            end
                        end
                    end
                    task.wait(2)
                end
            end)
        end
    end)
end

-- WalkSpeed
do
    local speed = 16
    local speedTextbox = createTextbox("WalkSpeed (number)", function(txt)
        local num = tonumber(txt)
        if num and num > 0 then
            speed = num
        end
    end)
    -- default display
    speedTextbox.Text = tostring(speed)
    -- apply speed only while toggled via checkbox (we reuse createToggle above pattern)
    local walkOn = false
    createToggle("Use WalkSpeed", function(v)
        walkOn = v
    end)
    RunService.Heartbeat:Connect(function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            if walkOn then
                pcall(function() LocalPlayer.Character.Humanoid.WalkSpeed = speed end)
            else
                pcall(function() LocalPlayer.Character.Humanoid.WalkSpeed = 16 end)
            end
        end
    end)
end

-- ESP (teman = cyan, musuh = magenta)
do
    local espEnabled = false
    local function applyESP(plr)
        if plr == LocalPlayer then return end
        if not plr.Character then return end
        if plr.Character:FindFirstChild("ESP_Highlight") then return end
        local hl = Instance.new("Highlight")
        hl.Name = "ESP_Highlight"
        hl.FillTransparency = 0.5
        hl.OutlineTransparency = 0
        if plr.Team == LocalPlayer.Team then
            hl.FillColor = Color3.fromRGB(0, 255, 255) -- cyan teman
            hl.OutlineColor = Color3.fromRGB(0, 200, 200)
        else
            hl.FillColor = Color3.fromRGB(255, 0, 255) -- magenta musuh
            hl.OutlineColor = Color3.fromRGB(200, 0, 200)
        end
        hl.Parent = plr.Character
    end

    createToggle("ESP", function(val)
        espEnabled = val
        if val then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    if p.Character then applyESP(p) end
                    p.CharacterAdded:Connect(function() task.wait(0.8) if espEnabled then applyESP(p) end end)
                end
            end
        else
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character and p.Character:FindFirstChild("ESP_Highlight") then
                    p.Character.ESP_Highlight:Destroy()
                end
            end
        end
    end)
end

-- Auto Press E (interval 0.5s) with toggle
do
    local autoE = false
    createToggle("Auto Press E", function(val)
        autoE = val
        if val then
            task.spawn(function()
                while autoE do
                    -- Try VirtualInputManager; wrap in pcall because not all executors expose it
                    local ok = pcall(function()
                        local vim = game:GetService("VirtualInputManager")
                        vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                        vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                    end)
                    -- If VirtualInputManager not available, try to fire a local input event (best-effort)
                    if not ok then
                        pcall(function()
                            -- Attempt to use UserInputService to simulate (may not work in many executors)
                            UIS.VirtualInput = UIS.VirtualInput -- no-op to avoid warning
                        end)
                    end
                    task.wait(0.5)
                end
            end)
        end
    end)
end

-- End of script
