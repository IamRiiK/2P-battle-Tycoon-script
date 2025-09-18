-- 2P battle Tycoon Script (Final + Hint Hotkey)

-------------------------
-- Services
-------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-------------------------
-- Feature Toggles
-------------------------
local FEATURE = {
    ESP = false,
    AutoE = false,
    AutoGrab = false,
    WalkEnabled = false,
    WalkValue = 16,
    Aimbot = false
}

-------------------------
-- UI Setup
-------------------------
local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.BackgroundColor3 = Color3.fromRGB(240,240,240)
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(0,0,0)
MainFrame.Position = UDim2.new(0.3,0,0.2,0)
MainFrame.Size = UDim2.new(0,280,0,350)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = true

local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.BackgroundColor3 = Color3.fromRGB(200,200,200)
TitleBar.Size = UDim2.new(1,0,0,28)

local Title = Instance.new("TextLabel", TitleBar)
Title.Size = UDim2.new(0.6,0,1,0)
Title.BackgroundTransparency = 1
Title.Text = "2P battle Tycoon"
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 18
Title.TextColor3 = Color3.fromRGB(0,0,0)
Title.TextXAlignment = Enum.TextXAlignment.Left

local MinBtn = Instance.new("TextButton", TitleBar)
MinBtn.Text = "-"
MinBtn.Size = UDim2.new(0,28,1,0)
MinBtn.Position = UDim2.new(1,-28,0,0)
MinBtn.BackgroundColor3 = Color3.fromRGB(220,220,220)

-- Hint text
local HintLabel = Instance.new("TextLabel", TitleBar)
HintLabel.Size = UDim2.new(0.4, -28, 1, 0)
HintLabel.Position = UDim2.new(0.6, 0, 0, 0)
HintLabel.BackgroundTransparency = 1
HintLabel.Font = Enum.Font.SourceSansItalic
HintLabel.TextSize = 13
HintLabel.TextColor3 = Color3.fromRGB(120,120,120)
HintLabel.TextXAlignment = Enum.TextXAlignment.Right
HintLabel.Text = "Press LeftAlt to toggle UI"

local Content = Instance.new("Frame", MainFrame)
Content.Size = UDim2.new(1,0,1,-28)
Content.Position = UDim2.new(0,0,0,28)
Content.BackgroundTransparency = 1

local UIList = Instance.new("UIListLayout", Content)
UIList.Padding = UDim.new(0,6)

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Content.Visible = not minimized
    MinBtn.Text = minimized and "+" or "-"
end)

-- Toggle show/hide UI with LeftAlt
UIS.InputBegan:Connect(function(input,gp)
    if not gp and input.KeyCode == Enum.KeyCode.LeftAlt then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

-------------------------
-- Helper: Create Toggle
-------------------------
local function createToggle(name, callback)
    local btn = Instance.new("TextButton", Content)
    btn.Size = UDim2.new(1,0,0,28)
    btn.BackgroundColor3 = Color3.fromRGB(220,220,220)
    btn.TextColor3 = Color3.fromRGB(0,0,0)
    btn.TextSize = 15
    btn.Font = Enum.Font.SourceSans
    btn.Text = name.." [OFF]"

    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = name.." ["..(state and "ON" or "OFF").."]"
        callback(state)
    end)
end

-------------------------
-- ESP Highlight
-------------------------
local highlights = {}

local function applyESP(player)
    if player == LocalPlayer then return end
    local function add(char)
        if not char or highlights[player] then return end
        local h = Instance.new("Highlight")
        h.Adornee = char
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.FillTransparency = 0.5
        if player.Team == LocalPlayer.Team then
            h.FillColor = Color3.fromRGB(13,71,21)
        else
            h.FillColor = Color3.fromRGB(205,24,24)
        end
        h.Parent = char
        highlights[player] = h
    end
    if player.Character then add(player.Character) end
    player.CharacterAdded:Connect(function(c) add(c) end)
end

local function removeESP()
    for _,h in pairs(highlights) do
        if h and h.Parent then h:Destroy() end
    end
    highlights = {}
end

-------------------------
-- Auto Press E
-------------------------
local function startAutoE()
    task.spawn(function()
        while FEATURE.AutoE do
            VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            task.wait(0.5)
        end
    end)
end

-------------------------
-- Auto Grab
-------------------------
local toolGiverNames = {
    "ToolGiver1P1","ToolGiver1P2","ToolGiver2P1",
    "ToolGiver3P1","ToolGiver3P2","ToolGiver4P1","ToolGiver4P2",
    "ToolGiver5","ToolGiver5P1","ToolGiver5P2",
    "ToolGiver6P1","ToolGiver6P2","ToolGiver7P1","ToolGiver7P2",
    "ToolGiver8P1","ToolGiver8P2","ToolGiver9P1","ToolGiver9P2",
    "ToolGiver10P1","ToolGiver10P2","ToolGiver11P1","ToolGiver11P2",
    "ToolGiver12P1","ToolGiver12P2","ToolGiver13P1","ToolGiver13P2",
    "ToolGiver14P1","ToolGiver14P2","ToolGiver100"
}
local hasFireTouch = (type(firetouchinterest)=="function")

local function startAutoGrab()
    task.spawn(function()
        while FEATURE.AutoGrab do
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                for _,tycoon in ipairs(Workspace.Tycoons:GetChildren()) do
                    local purchased = tycoon:FindFirstChild("PurchasedObjects")
                    if purchased then
                        for _,name in ipairs(toolGiverNames) do
                            local giver = purchased:FindFirstChild(name)
                            if giver and giver:FindFirstChild("Touch") and giver.Touch:IsA("BasePart") then
                                if hasFireTouch then
                                    pcall(function()
                                        firetouchinterest(giver.Touch, root, 0)
                                        firetouchinterest(giver.Touch, root, 1)
                                    end)
                                end
                            end
                        end
                    end
                end
            end
            task.wait(1)
        end
    end)
end

-------------------------
-- WalkSpeed
-------------------------
local function startWalk()
    task.spawn(function()
        while FEATURE.WalkEnabled do
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = FEATURE.WalkValue
            end
            task.wait(0.2)
        end
    end)
end

-------------------------
-- Aimbot (Smooth + Threshold)
-------------------------
local AIM_LERP = 0.3
local AIM_THRESHOLD = math.rad(35)

local function angleBetween(v1,v2)
    return math.acos(math.clamp(v1:Dot(v2)/(v1.Magnitude*v2.Magnitude),-1,1))
end

local function getClosestEnemy()
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return end
    local closest,shortest=nil,math.huge
    local myPos=myChar.HumanoidRootPart.Position
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr~=LocalPlayer and plr.Team~=LocalPlayer.Team and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local dist=(plr.Character.HumanoidRootPart.Position-myPos).Magnitude
            local hum=plr.Character:FindFirstChild("Humanoid")
            if hum and hum.Health>0 and dist<shortest then
                shortest=dist
                closest=plr
            end
        end
    end
    return closest
end

RunService.RenderStepped:Connect(function()
    if FEATURE.Aimbot then
        local target=getClosestEnemy()
        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            local camCF=Camera.CFrame
            local camDir=camCF.LookVector
            local dir=(target.Character.HumanoidRootPart.Position-camCF.Position).Unit
            if angleBetween(camDir,dir)<AIM_THRESHOLD then
                local newCF=CFrame.new(camCF.Position, camCF.Position+camDir:Lerp(dir,AIM_LERP))
                Camera.CFrame=newCF
            end
        end
    end
end)

-- Hotkey F1 for Aimbot
UIS.InputBegan:Connect(function(input,gp)
    if not gp and input.KeyCode==Enum.KeyCode.F1 then
        FEATURE.Aimbot=not FEATURE.Aimbot
    end
end)

-------------------------
-- UI: Features
-------------------------
-- 1) ESP
createToggle("ESP",function(val)
    FEATURE.ESP=val
    if val then
        for _,plr in ipairs(Players:GetPlayers()) do
            applyESP(plr)
        end
        Players.PlayerAdded:Connect(applyESP)
    else
        removeESP()
    end
end)

-- 2) Auto Press E
createToggle("Auto Press E",function(val)
    FEATURE.AutoE=val
    if val then startAutoE() end
end)

-- 3) Auto Grab Weapon
createToggle("Auto Grab Weapon",function(val)
    FEATURE.AutoGrab=val
    if val then startAutoGrab() end
end)

-- 4) Toggle WalkSpeed
createToggle("WalkSpeed Enabled",function(val)
    FEATURE.WalkEnabled=val
    if val then startWalk() end
end)

-- 5) Input WalkSpeed + placeholder
do
    local frame=Instance.new("Frame",Content)
    frame.Size=UDim2.new(1,0,0,34)
    frame.BackgroundTransparency=1

    local label=Instance.new("TextLabel",frame)
    label.Size=UDim2.new(0.5,-8,1,0)
    label.BackgroundTransparency=1
    label.Font=Enum.Font.SourceSans
    label.TextSize=15
    label.TextColor3=Color3.fromRGB(0,0,0)
    label.Text="WalkSpeed (number)"

    local box=Instance.new("TextBox",frame)
    box.Size=UDim2.new(0.5,0,1,0)
    box.Position=UDim2.new(0.5,8,0,0)
    box.BackgroundColor3=Color3.fromRGB(255,255,255)
    box.TextColor3=Color3.fromRGB(0,0,0)
    box.Font=Enum.Font.SourceSans
    box.TextSize=15
    box.Text=tostring(FEATURE.WalkValue)
    box.ClearTextOnFocus=false

    local placeholder=Instance.new("TextLabel",box)
    placeholder.Size=UDim2.new(1,-6,1,0)
    placeholder.Position=UDim2.new(0,3,0,0)
    placeholder.BackgroundTransparency=1
    placeholder.Text="16–200 Reccomend 25-40"
    placeholder.Font=Enum.Font.SourceSansItalic
    placeholder.TextSize=14
    placeholder.TextColor3=Color3.fromRGB(150,150,150)
    placeholder.TextXAlignment=Enum.TextXAlignment.Left

    local function updatePlaceholder()
        placeholder.Visible=(box.Text=="")
    end
    box:GetPropertyChangedSignal("Text"):Connect(updatePlaceholder)
    box.Focused:Connect(updatePlaceholder)
    box.FocusLost:Connect(function(enter)
        updatePlaceholder()
        if enter then
            local n=tonumber(box.Text)
            if n and n>=16 and n<=200 then
                FEATURE.WalkValue=n
                box.Text=tostring(n)
            else
                FEATURE.WalkValue=16
                box.Text=tostring(FEATURE.WalkValue)
            end
        end
    end)
    updatePlaceholder()
end

-- 6) Aimbot
createToggle("Aimbot (F1 hotkey)",function(val)
    FEATURE.Aimbot=val
end)
