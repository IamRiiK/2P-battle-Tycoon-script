--// 2P Battle Tycoon Script - Dark Modern UI + HUD (Toggle Sync)
--// Features:
-- 1) ESP (F1)
-- 2) Auto Press E (F2)
-- 3) WalkSpeed (F3)
-- 4) Aimbot (F4)
--// UI: Dark modern, draggable, minimize, LeftAlt hide
--// HUD: Shows features status ONLY when UI is hidden

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
    WalkEnabled = false,
    WalkValue = 16,
    Aimbot = false,
    AIM_FOV_DEG = 8, -- sniper style FOV
}

-------------------------
-- UI Setup (Main Window)
-------------------------
local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.BackgroundColor3 = Color3.fromRGB(25,25,25)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.3,0,0.2,0)
MainFrame.Size = UDim2.new(0,300,0,380)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = true

local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.BackgroundColor3 = Color3.fromRGB(40,40,40)
TitleBar.Size = UDim2.new(1,0,0,28)

local Title = Instance.new("TextLabel", TitleBar)
Title.Size = UDim2.new(0.6,0,1,0)
Title.BackgroundTransparency = 1
Title.Text = "2P Battle Tycoon"
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 18
Title.TextColor3 = Color3.fromRGB(255,255,255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Position = UDim2.new(0,6,0,0)

local MinBtn = Instance.new("TextButton", TitleBar)
MinBtn.Text = "-"
MinBtn.Size = UDim2.new(0,28,1,0)
MinBtn.Position = UDim2.new(1,-28,0,0)
MinBtn.BackgroundColor3 = Color3.fromRGB(60,60,60)
MinBtn.TextColor3 = Color3.fromRGB(255,255,255)
MinBtn.Font = Enum.Font.SourceSansBold

local HintLabel = Instance.new("TextLabel", TitleBar)
HintLabel.Size = UDim2.new(0.4,-28,1,0)
HintLabel.Position = UDim2.new(0.6,0,0,0)
HintLabel.BackgroundTransparency = 1
HintLabel.Font = Enum.Font.SourceSansItalic
HintLabel.TextSize = 13
HintLabel.TextColor3 = Color3.fromRGB(180,180,180)
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

-------------------------
-- HUD Setup (only show when UI hidden)
-------------------------
local HUDFrame = Instance.new("Frame", ScreenGui)
HUDFrame.Size = UDim2.new(0,160,0,100)
HUDFrame.Position = UDim2.new(1,-170,1,-120) -- kanan bawah
HUDFrame.BackgroundColor3 = Color3.fromRGB(20,20,20)
HUDFrame.BackgroundTransparency = 0.3
HUDFrame.BorderSizePixel = 0
HUDFrame.Visible = false

local HUDList = Instance.new("UIListLayout", HUDFrame)
HUDList.Padding = UDim.new(0,2)

local HUDLabels = {}
local function addHUDLabel(name)
    local lbl = Instance.new("TextLabel", HUDFrame)
    lbl.Size = UDim2.new(1,0,0,20)
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.SourceSansBold
    lbl.TextSize = 14
    lbl.TextColor3 = Color3.fromRGB(200,200,200)
    lbl.Text = name..": OFF"
    HUDLabels[name] = lbl
end

addHUDLabel("ESP")
addHUDLabel("Auto E")
addHUDLabel("WalkSpeed")
addHUDLabel("Aimbot")

local function updateHUD(name,state)
    if HUDLabels[name] then
        HUDLabels[name].Text = name..": "..(state and "ON" or "OFF")
        HUDLabels[name].TextColor3 = state and Color3.fromRGB(0,255,100) or Color3.fromRGB(200,200,200)
    end
end

-- Toggle show/hide UI with LeftAlt
UIS.InputBegan:Connect(function(input,gp)
    if not gp and input.KeyCode == Enum.KeyCode.LeftAlt then
        MainFrame.Visible = not MainFrame.Visible
        HUDFrame.Visible = not MainFrame.Visible -- HUD muncul hanya saat UI hidden
    end
end)

-------------------------
-- Helper: Toggle System (Sync)
-------------------------
local ToggleCallbacks = {}

local function registerToggle(name, featureKey, callback)
    local btn = Instance.new("TextButton", Content)
    btn.Size = UDim2.new(1,0,0,28)
    btn.BackgroundColor3 = Color3.fromRGB(50,50,50)
    btn.TextColor3 = Color3.fromRGB(220,220,220)
    btn.TextSize = 15
    btn.Font = Enum.Font.SourceSans
    btn.Text = name.." [OFF]"

    local function setState(state)
        FEATURE[featureKey] = state
        btn.Text = name.." ["..(state and "ON" or "OFF").."]"
        btn.BackgroundColor3 = state and Color3.fromRGB(0,150,80) or Color3.fromRGB(50,50,50)
        updateHUD(name,state)
        callback(state)
    end

    btn.MouseButton1Click:Connect(function()
        setState(not FEATURE[featureKey])
    end)

    ToggleCallbacks[featureKey] = setState
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
        h.FillColor = Color3.fromRGB(205,24,24)
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
-- Aimbot (Sniper Style)
-------------------------
local AIM_LERP = 0.3
local AIM_THRESHOLD = math.rad(FEATURE.AIM_FOV_DEG)

local function angleBetween(v1,v2)
    return math.acos(math.clamp(v1:Dot(v2)/(v1.Magnitude*v2.Magnitude),-1,1))
end

local function getClosestEnemy()
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return end
    local camCF = Camera.CFrame
    local camPos = camCF.Position
    local camDir = camCF.LookVector

    local closest,shortest=nil,math.huge
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr~=LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local hum=plr.Character:FindFirstChild("Humanoid")
            if hum and hum.Health>0 then
                local head = plr.Character:FindFirstChild("Head") or plr.Character.HumanoidRootPart
                local dir=(head.Position-camPos).Unit
                local angle=angleBetween(camDir,dir)
                if angle < AIM_THRESHOLD and angle < shortest then
                    shortest=angle
                    closest=plr
                end
            end
        end
    end
    return closest
end

RunService.RenderStepped:Connect(function()
    if FEATURE.Aimbot then
        local target=getClosestEnemy()
        if target and target.Character then
            local head=target.Character:FindFirstChild("Head") or target.Character:FindFirstChild("HumanoidRootPart")
            if head then
                local camCF=Camera.CFrame
                local dir=(head.Position-camCF.Position).Unit
                local newCF=CFrame.new(camCF.Position, camCF.Position+camCF.LookVector:Lerp(dir,AIM_LERP))
                Camera.CFrame=newCF
            end
        end
    end
end)

-------------------------
-- Register Features + Hotkeys
-------------------------
-- ESP
registerToggle("ESP","ESP",function(val)
    if val then
        for _,plr in ipairs(Players:GetPlayers()) do
            applyESP(plr)
        end
        Players.PlayerAdded:Connect(applyESP)
    else
        removeESP()
    end
end)

-- Auto Press E
registerToggle("Auto Press E","AutoE",function(val)
    if val then startAutoE() end
end)

-- WalkSpeed
registerToggle("WalkSpeed Enabled","WalkEnabled",function(val)
    if val then startWalk() end
end)

-- WalkSpeed Input
do
    local frame=Instance.new("Frame",Content)
    frame.Size=UDim2.new(1,0,0,34)
    frame.BackgroundTransparency=1

    local label=Instance.new("TextLabel",frame)
    label.Size=UDim2.new(0.5,-8,1,0)
    label.BackgroundTransparency=1
    label.Font=Enum.Font.SourceSans
    label.TextSize=15
    label.TextColor3=Color3.fromRGB(220,220,220)
    label.Text="WalkSpeed (number)"

    local box=Instance.new("TextBox",frame)
    box.Size=UDim2.new(0.5,0,1,0)
    box.Position=UDim2.new(0.5,8,0,0)
    box.BackgroundColor3 = Color3.fromRGB(40,40,40)
    box.TextColor3 = Color3.fromRGB(255,255,255)
    box.Font = Enum.Font.SourceSans
    box.TextSize = 15
    box.Text = tostring(FEATURE.WalkValue)
    box.ClearTextOnFocus = false

    box.FocusLost:Connect(function(enter)
        if enter then
            local n=tonumber(box.Text)
            if n and n>=16 and n<=200 then
                FEATURE.WalkValue=n
                box.Text=tostring(n)
            else
                box.Text=tostring(FEATURE.WalkValue)
            end
        end
    end)
end

-- Aimbot
registerToggle("Aimbot (F4 hotkey)","Aimbot",function(val) end)

-- Hotkeys
UIS.InputBegan:Connect(function(input,gp)
    if not gp then
        if input.KeyCode == Enum.KeyCode.F1 then
            ToggleCallbacks.ESP(not FEATURE.ESP)
        elseif input.KeyCode == Enum.KeyCode.F2 then
            ToggleCallbacks.AutoE(not FEATURE.AutoE)
        elseif input.KeyCode == Enum.KeyCode.F3 then
            ToggleCallbacks.WalkEnabled(not FEATURE.WalkEnabled)
        elseif input.KeyCode == Enum.KeyCode.F4 then
            ToggleCallbacks.Aimbot(not FEATURE.Aimbot)
        end
    end
end)
