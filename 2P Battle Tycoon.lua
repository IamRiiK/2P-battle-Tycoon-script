-- TPB Refactor v2 — Main Script (Refactor + Teleport Set / Hitbox Expander)
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera or Workspace:FindFirstChild("CurrentCamera")
if not Camera then
    local ok, cam = pcall(function() return Workspace:WaitForChild("CurrentCamera", 5) end)
    Camera = ok and cam or Workspace.CurrentCamera
end

local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)

-- =========================
-- Config / Feature state
-- =========================
local FEATURE = {
    ESP = false,
    AutoE = false,
    AutoEInterval = 0.5,
    WalkEnabled = false,
    WalkValue = 30,
    Aimbot = false,
    AIM_FOV_DEG = 8,
    AIM_LERP = 0.4,
    AIM_HOLD = false,
    HitboxEnabled = false,
    HitboxScale = 1.5, -- multiplier
}

local WALK_UPDATE_INTERVAL = 0.12

local PersistentConnections = {}
local PerPlayerConnections = {}

local function keepPersistent(conn)
    if conn and conn.Disconnect then
        table.insert(PersistentConnections, conn)
    end
    return conn
end

local function addPerPlayerConnection(p, conn)
    if not p or not conn then return conn end
    PerPlayerConnections[p] = PerPlayerConnections[p] or {}
    table.insert(PerPlayerConnections[p], conn)
    return conn
end

local function clearConnectionsForPlayer(p)
    local t = PerPlayerConnections[p]
    if t then
        for _,c in ipairs(t) do
            pcall(function() c:Disconnect() end)
        end
        PerPlayerConnections[p] = nil
    end
end

local function clearAllPerPlayerConnections()
    for p,_ in pairs(PerPlayerConnections) do
        clearConnectionsForPlayer(p)
    end
end

local function clearAllConnections()
    clearAllPerPlayerConnections()
    for _,c in ipairs(PersistentConnections) do
        pcall(function() c:Disconnect() end)
    end
    PersistentConnections = {}
end

local function safeParentGui(gui)
    gui.ResetOnSpawn = false
    if PlayerGui and PlayerGui.Parent then
        gui.Parent = PlayerGui
    else
        pcall(function() gui.Parent = PlayerGui end)
    end
end

local function safeWaitCamera()
    if not (Workspace.CurrentCamera or Camera) then
        local ok, cam = pcall(function() return Workspace:WaitForChild("CurrentCamera", 5) end)
        if ok and cam then Camera = cam end
    else
        Camera = Workspace.CurrentCamera or Camera
    end
end

local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

-- Cleanup from previous run
pcall(function()
    if _G and _G.__TPB_CLEANUP then
        pcall(_G.__TPB_CLEANUP)
    end
    local old = PlayerGui:FindFirstChild("TPB_TycoonGUI_Final")
    if old then old:Destroy() end
    local old2 = PlayerGui:FindFirstChild("TPB_TycoonHUD_Final")
    if old2 then old2:Destroy() end
end)

-- =========================
-- Globals for teleport storage & hitbox restore
-- =========================
getgenv().__TPB_TELEPORTS = getgenv().__TPB_TELEPORTS or {} -- structure: TeamName -> { Spaceship = Vector3, ... }
local OriginalPartSizes = {} -- part -> Vector3
local OriginalCollisions = {} -- part -> CanCollide
local espObjects = setmetatable({}, { __mode = "k" })

local function rootPartOfCharacter(char)
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
end

-- =========================
-- UI: Main Screen & Tabs
-- =========================
local MainScreenGui = Instance.new("ScreenGui")
MainScreenGui.Name = "TPB_TycoonGUI_Final"
MainScreenGui.DisplayOrder = 9999
safeParentGui(MainScreenGui)

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 380, 0, 520)
MainFrame.Position = UDim2.new(0.28,0,0.12,0)
MainFrame.BackgroundColor3 = Color3.fromRGB(28,28,30)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = MainScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0,12)

local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.Size = UDim2.new(1,0,0,40)
TitleBar.BackgroundTransparency = 1

local DragHandle = Instance.new("TextLabel", TitleBar)
DragHandle.Size = UDim2.new(0,28,0,28)
DragHandle.Position = UDim2.new(0,8,0,6)
DragHandle.BackgroundTransparency = 1
DragHandle.Font = Enum.Font.Gotham
DragHandle.TextSize = 20
DragHandle.TextColor3 = Color3.fromRGB(200,200,200)
DragHandle.Text = "≡"
DragHandle.Active = true
DragHandle.Selectable = true

local Title = Instance.new("TextLabel", TitleBar)
Title.Size = UDim2.new(0.6,0,1,0)
Title.Position = UDim2.new(0.07,0,0,0)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextColor3 = Color3.fromRGB(245,245,245)
Title.Text = "⚔️ 2P Battle Tycoon — Refactor"
Title.TextXAlignment = Enum.TextXAlignment.Left

local HintLabel = Instance.new("TextLabel", TitleBar)
HintLabel.Size = UDim2.new(0.36,-60,1,0)
HintLabel.Position = UDim2.new(0.64,0,0,0)
HintLabel.BackgroundTransparency = 1
HintLabel.Font = Enum.Font.Gotham
HintLabel.TextSize = 12
HintLabel.TextColor3 = Color3.fromRGB(170,170,170)
HintLabel.Text = "LeftAlt = Hide UI"
HintLabel.TextXAlignment = Enum.TextXAlignment.Right

local MinBtn = Instance.new("TextButton", TitleBar)
MinBtn.Size = UDim2.new(0,38,0,28)
MinBtn.Position = UDim2.new(1,-46,0,6)
MinBtn.BackgroundColor3 = Color3.fromRGB(58,58,60)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 20
MinBtn.TextColor3 = Color3.fromRGB(240,240,240)
MinBtn.Text = "-"
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0,8)

local Content = Instance.new("Frame", MainFrame)
Content.Name = "Content"
Content.Size = UDim2.new(1,-16,1,-56)
Content.Position = UDim2.new(0,8,0,48)
Content.BackgroundTransparency = 1

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Content.Visible = not minimized
    MinBtn.Text = minimized and "+" or "-"
end)

-- draggable
do
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPosPixels = nil
    local dragChangedConn = nil

    local function getScreenSize()
        local viewportSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
        return viewportSize
    end

    local function toPixels(udim2)
        local screen = getScreenSize()
        local x = udim2.X.Offset + udim2.X.Scale * screen.X
        local y = udim2.Y.Offset + udim2.Y.Scale * screen.Y
        return Vector2.new(x, y)
    end

    local function getInputPos(input)
        if input and input.Position then
            return Vector2.new(input.Position.X, input.Position.Y)
        else
            return UIS:GetMouseLocation()
        end
    end

    local function onInputBegan(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragInput = input
            dragStart = getInputPos(input)
            startPosPixels = toPixels(MainFrame.Position)

            if dragChangedConn then
                pcall(function() dragChangedConn:Disconnect() end)
                dragChangedConn = nil
            end

            if input.Changed then
                dragChangedConn = input.Changed:Connect(function(property)
                    if property == "UserInputState" and input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                        dragInput = nil
                        if dragChangedConn then
                            pcall(function() dragChangedConn:Disconnect() end)
                            dragChangedConn = nil
                        end
                    end
                end)
                keepPersistent(dragChangedConn)
            end
        end
    end

    local function onInputChanged(input)
        if not dragging then return end
        if input ~= dragInput and input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local currentPos = getInputPos(input)
        local delta = currentPos - dragStart
        local newX = math.floor(startPosPixels.X + delta.X)
        local newY = math.floor(startPosPixels.Y + delta.Y)
        local screen = getScreenSize()
        local frameSize = Vector2.new(MainFrame.AbsoluteSize.X, MainFrame.AbsoluteSize.Y)
        newX = clamp(newX, 0, math.max(0, screen.X - frameSize.X))
        newY = clamp(newY, 0, math.max(0, screen.Y - frameSize.Y))
        MainFrame.Position = UDim2.new(0, newX, 0, newY)
    end

    local function onInputEnded(input)
        if input == dragInput then
            dragging = false
            dragInput = nil
            if dragChangedConn then
                pcall(function() dragChangedConn:Disconnect() end)
                dragChangedConn = nil
            end
        end
    end

    TitleBar.InputBegan:Connect(onInputBegan)
    DragHandle.InputBegan:Connect(onInputBegan)
    keepPersistent(UIS.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            onInputChanged(input)
        end
    end))
    keepPersistent(UIS.InputEnded:Connect(onInputEnded))
end

-- HUD (mini status)
local HUDGui = Instance.new("ScreenGui")
HUDGui.Name = "TPB_TycoonHUD_Final"
HUDGui.DisplayOrder = 10000
safeParentGui(HUDGui)

local HUD = Instance.new("Frame", HUDGui)
HUD.Size = UDim2.new(0,220,0,130)
HUD.Position = UDim2.new(1,-230,1,-160)
HUD.BackgroundColor3 = Color3.fromRGB(20,20,20)
HUD.BackgroundTransparency = 0.06
HUD.BorderSizePixel = 0
HUD.Visible = false
Instance.new("UICorner", HUD).CornerRadius = UDim.new(0,8)

local HUDList = Instance.new("UIListLayout", HUD)
HUDList.Padding = UDim.new(0,4)
HUDList.SortOrder = Enum.SortOrder.LayoutOrder

local hudLabels = {}
local function hudAdd(name)
    local l = Instance.new("TextLabel", HUD)
    l.Size = UDim2.new(1,-12,0,20)
    l.Position = UDim2.new(0,8,0,0)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.Gotham
    l.TextSize = 14
    l.TextColor3 = Color3.fromRGB(220,220,220)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = name .. ": OFF"
    l.Parent = HUD
    hudLabels[name] = l
end

hudAdd("ESP")
hudAdd("Auto Press E")
hudAdd("WalkSpeed")
hudAdd("Aimbot")
hudAdd("Hitbox")

local function updateHUD(name, state)
    if hudLabels[name] then
        hudLabels[name].Text = name .. ": " .. (state and "ON" or "OFF")
        hudLabels[name].TextColor3 = state and Color3.fromRGB(80,200,120) or Color3.fromRGB(200,200,200)
    end
end

keepPersistent(UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.LeftAlt then
        MainFrame.Visible = not MainFrame.Visible
        HUD.Visible = not MainFrame.Visible
    end
end))

-- =========================
-- Tab system
-- =========================
local TabContainer = Instance.new("Frame", MainFrame)
TabContainer.Size = UDim2.new(1,-16,0,36)
TabContainer.Position = UDim2.new(0,8,0,48)
TabContainer.BackgroundTransparency = 1
local TabLayout = Instance.new("UIListLayout", TabContainer)
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.Padding = UDim.new(0, 6)

local Tabs = {}
local CurrentTab = nil

local function createTab(name)
    local btn = Instance.new("TextButton", TabContainer)
    btn.Size = UDim2.new(0, 100, 1, 0)
    btn.Text = name
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.BackgroundColor3 = Color3.fromRGB(40,40,40)
    btn.TextColor3 = Color3.fromRGB(230,230,230)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

    local tabContent = Instance.new("Frame", Content)
    tabContent.Size = UDim2.new(1,0,1, -36)
    tabContent.BackgroundTransparency = 1
    tabContent.Visible = false

    btn.MouseButton1Click:Connect(function()
        if CurrentTab then CurrentTab.Visible = false end
        tabContent.Visible = true
        CurrentTab = tabContent
    end)

    Tabs[name] = tabContent
    return tabContent
end

local MainTab = createTab("Main")
local TeleportTab = createTab("Teleport")
local SettingsTab = createTab("Settings")

-- default view
MainTab.Visible = true
CurrentTab = MainTab

-- Helper to add UI elements quickly
local function addLabel(parent, text)
    local l = Instance.new("TextLabel", parent)
    l.Size = UDim2.new(1,0,0,18)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.Gotham
    l.TextSize = 13
    l.TextColor3 = Color3.fromRGB(230,230,230)
    l.Text = text
    l.TextXAlignment = Enum.TextXAlignment.Left
    return l
end

local function addButton(parent, txt, size)
    local btn = Instance.new("TextButton", parent)
    btn.Size = size or UDim2.new(1,0,0,32)
    btn.BackgroundColor3 = Color3.fromRGB(50,50,50)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(240,240,240)
    btn.Text = txt
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
    return btn
end

local function addToggle(parent, name, initial, onChange)
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1,0,0,36)
    frame.BackgroundTransparency = 1

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0.7,0,1,0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(230,230,230)
    label.Text = name
    label.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(0.28,0,0,28)
    btn.Position = UDim2.new(0.72,0,0.5,-14)
    btn.BackgroundColor3 = initial and Color3.fromRGB(80,150,220) or Color3.fromRGB(36,36,36)
    btn.TextColor3 = Color3.fromRGB(245,245,245)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.Text = initial and "ON" or "OFF"
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)

    btn.MouseButton1Click:Connect(function()
        local new = not FEATURE[name:gsub("%s","")]
        if type(onChange) == "function" then
            onChange(new, btn)
        else
            FEATURE[name:gsub("%s","")] = new
            btn.Text = new and "ON" or "OFF"
            btn.BackgroundColor3 = new and Color3.fromRGB(80,150,220) or Color3.fromRGB(36,36,36)
        end
    end)

    return frame, btn
end

-- Layout containers for tabs
local MainLayout = Instance.new("UIListLayout", MainTab)
MainLayout.Padding = UDim.new(0,8)
MainLayout.SortOrder = Enum.SortOrder.LayoutOrder
MainLayout.Parent = MainTab

local TeleLayout = Instance.new("UIListLayout", TeleportTab)
TeleLayout.Padding = UDim.new(0,8)
TeleLayout.SortOrder = Enum.SortOrder.LayoutOrder
TeleLayout.Parent = TeleportTab

local SettingsLayout = Instance.new("UIListLayout", SettingsTab)
SettingsLayout.Padding = UDim.new(0,8)
SettingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
SettingsLayout.Parent = SettingsTab

-- =========================
-- MAIN Tab: feature toggles
-- =========================
-- ESP toggle
do
    local frame, btn = addToggle(MainTab, "ESP", FEATURE.ESP, function(state)
        FEATURE.ESP = state
        btn.Text = state and "ON" or "OFF"
        btn.BackgroundColor3 = state and Color3.fromRGB(80,150,220) or Color3.fromRGB(36,36,36)
        updateHUD("ESP", state)
        if state then
            -- enable esp for current players
            for _,p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    -- ensure listeners and refresh
                    if p.Character then
                        task.wait(0.05)
                        local char = p.Character
                        -- create highlight
                        if not espObjects[p] then
                            local hl = Instance.new("Highlight")
                            hl.Name = "TPB_BoxESP"
                            hl.Adornee = char
                            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                            hl.OutlineTransparency = 0
                            hl.OutlineColor = Color3.fromRGB(255,255,255)
                            hl.FillTransparency = 0.7
                            hl.FillColor = (p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team) and Color3.fromRGB(0,200,0) or Color3.fromRGB(200,40,40)
                            hl.Parent = char
                            espObjects[p] = { hl }
                        end
                    end
                end
            end
            -- player added/removed handled below via connections
        else
            -- clear all esp
            for p,_ in pairs(espObjects) do
                for _,v in pairs(espObjects[p]) do
                    pcall(function() v:Destroy() end)
                end
                espObjects[p] = nil
            end
        end
    end)
end

-- Auto Press E
do
    local frame, btn = addToggle(MainTab, "Auto Press E", FEATURE.AutoE, function(state)
        FEATURE.AutoE = state
        btn.Text = state and "ON" or "OFF"
        btn.BackgroundColor3 = state and Color3.fromRGB(80,150,220) or Color3.fromRGB(36,36,36)
        updateHUD("Auto Press E", state)
        -- AutoE loop is separate
    end)

    local subFrame = Instance.new("Frame", MainTab)
    subFrame.Size = UDim2.new(1,0,0,28)
    subFrame.BackgroundTransparency = 1
    local label = Instance.new("TextLabel", subFrame)
    label.Size = UDim2.new(0.5,0,1,0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(200,200,200)
    label.Text = "Interval (s):"
    label.TextXAlignment = Enum.TextXAlignment.Left

    local box = Instance.new("TextBox", subFrame)
    box.Size = UDim2.new(0.48,0,0,24)
    box.Position = UDim2.new(0.5,0,0.5,-12)
    box.BackgroundColor3 = Color3.fromRGB(32,32,32)
    box.TextColor3 = Color3.fromRGB(240,240,240)
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.ClearTextOnFocus = false
    box.Text = tostring(FEATURE.AutoEInterval)
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,6)
    box.FocusLost:Connect(function(enter)
        if enter then
            local n = tonumber(box.Text)
            if n and n >= 0.05 and n <= 5 then
                FEATURE.AutoEInterval = n
                box.Text = tostring(n)
            else
                box.Text = tostring(FEATURE.AutoEInterval)
            end
        end
    end)
end

-- WalkSpeed (toggle + input)
do
    local frame, btn = addToggle(MainTab, "WalkSpeed", FEATURE.WalkEnabled, function(state)
        FEATURE.WalkEnabled = state
        btn.Text = state and "ON" or "OFF"
        btn.BackgroundColor3 = state and Color3.fromRGB(80,150,220) or Color3.fromRGB(36,36,36)
        updateHUD("WalkSpeed", state)
        if state then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = FEATURE.WalkValue
            end
        else
            -- nothing extra: restore handled on character removal via cleanup restore
        end
    end)

    local subFrame = Instance.new("Frame", MainTab)
    subFrame.Size = UDim2.new(1,0,0,28)
    subFrame.BackgroundTransparency = 1
    local box = Instance.new("TextBox", subFrame)
    box.Size = UDim2.new(0.48,0,0,24)
    box.Position = UDim2.new(0,0,0.5,-12)
    box.BackgroundColor3 = Color3.fromRGB(32,32,32)
    box.TextColor3 = Color3.fromRGB(240,240,240)
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.ClearTextOnFocus = false
    box.Text = tostring(FEATURE.WalkValue)
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,6)
    box.FocusLost:Connect(function(enter)
        if enter then
            local n = tonumber(box.Text)
            if n and n >= 16 and n <= 200 then
                FEATURE.WalkValue = n
                box.Text = tostring(n)
            else
                box.Text = tostring(FEATURE.WalkValue)
            end
        end
    end)
end

-- Aimbot toggle + settings
do
    local frame, btn = addToggle(MainTab, "Aimbot", FEATURE.Aimbot, function(state)
        FEATURE.Aimbot = state
        btn.Text = state and "ON" or "OFF"
        btn.BackgroundColor3 = state and Color3.fromRGB(80,150,220) or Color3.fromRGB(36,36,36)
        updateHUD("Aimbot", state)
    end)

    local subFrame = Instance.new("Frame", MainTab)
    subFrame.Size = UDim2.new(1,0,0,28)
    subFrame.BackgroundTransparency = 1
    local fovLabel = Instance.new("TextLabel", subFrame)
    fovLabel.Size = UDim2.new(0.5,0,1,0)
    fovLabel.BackgroundTransparency = 1
    fovLabel.Font = Enum.Font.Gotham
    fovLabel.TextSize = 12
    fovLabel.TextColor3 = Color3.fromRGB(200,200,200)
    fovLabel.Text = "FOV (deg):"
    fovLabel.TextXAlignment = Enum.TextXAlignment.Left

    local fovBox = Instance.new("TextBox", subFrame)
    fovBox.Size = UDim2.new(0.48,0,0,24)
    fovBox.Position = UDim2.new(0.5,0,0.5,-12)
    fovBox.BackgroundColor3 = Color3.fromRGB(32,32,32)
    fovBox.TextColor3 = Color3.fromRGB(240,240,240)
    fovBox.Font = Enum.Font.Gotham
    fovBox.TextSize = 12
    fovBox.ClearTextOnFocus = false
    fovBox.Text = tostring(FEATURE.AIM_FOV_DEG)
    Instance.new("UICorner", fovBox).CornerRadius = UDim.new(0,6)
    fovBox.FocusLost:Connect(function(enter)
        if enter then
            local n = tonumber(fovBox.Text)
            if n and n >= 1 and n <= 180 then
                FEATURE.AIM_FOV_DEG = n
                fovBox.Text = tostring(n)
            else
                fovBox.Text = tostring(FEATURE.AIM_FOV_DEG)
            end
        end
    end)
end

-- =========================
-- Teleport Tab
-- =========================
-- Locations list (fixed names)
local LocationNames = {"Spaceship", "Bunker", "PrivateIsland", "Submarine"}

addLabel(TeleportTab, "Pilih lokasi lalu tekan Teleport.")
addLabel(TeleportTab, "Jika belum ada koordinat, gunakan 'Set untuk Tim Saya' saat berada di lokasi.")

-- Dropdown (simple emulation using buttons)
local selectedLocation = LocationNames[1]

local locFrame = Instance.new("Frame", TeleportTab)
locFrame.Size = UDim2.new(1,0,0,32)
locFrame.BackgroundTransparency = 1
local locLabel = Instance.new("TextLabel", locFrame)
locLabel.Size = UDim2.new(0.6,0,1,0)
locLabel.BackgroundTransparency = 1
locLabel.Font = Enum.Font.Gotham
locLabel.TextSize = 13
locLabel.TextColor3 = Color3.fromRGB(230,230,230)
locLabel.Text = "Lokasi: " .. selectedLocation
locLabel.TextXAlignment = Enum.TextXAlignment.Left

local chooseBtn = Instance.new("TextButton", locFrame)
chooseBtn.Size = UDim2.new(0.38,0,1,0)
chooseBtn.Position = UDim2.new(0.62,0,0,0)
chooseBtn.Text = "Ubah Lokasi"
chooseBtn.Font = Enum.Font.Gotham
chooseBtn.TextSize = 13
chooseBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
chooseBtn.TextColor3 = Color3.fromRGB(240,240,240)
Instance.new("UICorner", chooseBtn).CornerRadius = UDim.new(0,6)

-- simple cycle through locations on click
chooseBtn.MouseButton1Click:Connect(function()
    for i,name in ipairs(LocationNames) do
        if name == selectedLocation then
            local nextIndex = i % #LocationNames + 1
            selectedLocation = LocationNames[nextIndex]
            locLabel.Text = "Lokasi: " .. selectedLocation
            break
        end
    end
end)

-- Teleport now button
local teleBtn = addButton(TeleportTab, "Teleport Sekarang", UDim2.new(1,0,0,36))
teleBtn.MouseButton1Click:Connect(function()
    local teamName = tostring(LocalPlayer.Team and LocalPlayer.Team.Name or "Neutral")
    local tbl = getgenv().__TPB_TELEPORTS[teamName]
    if tbl and tbl[selectedLocation] then
        local pos = tbl[selectedLocation]
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = LocalPlayer.Character.HumanoidRootPart
            hrp.CFrame = CFrame.new(pos + Vector3.new(0,3,0))
            print("Teleported to", selectedLocation, "for team", teamName)
        end
    else
        warn("Koordinat untuk lokasi '"..selectedLocation.."' belum diset untuk tim "..teamName..". Gunakan 'Set untuk Tim Saya' terlebih dahulu.")
    end
end)

-- Set for my team
local setBtn = addButton(TeleportTab, "Set untuk Tim Saya (pakai posisi saat ini)", UDim2.new(1,0,0,36))
setBtn.BackgroundColor3 = Color3.fromRGB(80,150,220)
setBtn.MouseButton1Click:Connect(function()
    if not LocalPlayer.Team then
        warn("Tidak ada team terdeteksi. Pastikan Anda sudah berada di team.")
        return
    end
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local pos = LocalPlayer.Character.HumanoidRootPart.Position
        local teamName = tostring(LocalPlayer.Team.Name)
        getgenv().__TPB_TELEPORTS[teamName] = getgenv().__TPB_TELEPORTS[teamName] or {}
        getgenv().__TPB_TELEPORTS[teamName][selectedLocation] = pos
        print("Tersimpan:", teamName, selectedLocation, pos)
    else
        warn("Karakter atau HumanoidRootPart tidak ditemukan.")
    end
end)

-- Optional: Copy/export current teleport table (print to console)
local exportBtn = addButton(TeleportTab, "Tampilkan Data Teleport (console)", UDim2.new(1,0,0,28))
exportBtn.BackgroundColor3 = Color3.fromRGB(50,180,50)
exportBtn.MouseButton1Click:Connect(function()
    print("===== TPB Teleport Table =====")
    for team,tbl in pairs(getgenv().__TPB_TELEPORTS) do
        print(team .. " = {")
        for loc,vec in pairs(tbl) do
            print(string.format("  %s = Vector3.new(%.2f, %.2f, %.2f),", loc, vec.X, vec.Y, vec.Z))
        end
        print("}")
    end
    print("===== End =====")
end)

-- =========================
-- SETTINGS Tab: Hitbox Expander + Cleanup
-- =========================
addLabel(SettingsTab, "Hitbox Expander (aplikasi ke semua body parts musuh)")

local hitFrame = Instance.new("Frame", SettingsTab)
hitFrame.Size = UDim2.new(1,0,0,36)
hitFrame.BackgroundTransparency = 1

local hitLabel = Instance.new("TextLabel", hitFrame)
hitLabel.Size = UDim2.new(0.55,0,1,0)
hitLabel.BackgroundTransparency = 1
hitLabel.Font = Enum.Font.Gotham
hitLabel.TextSize = 13
hitLabel.Text = "Scale (1.0 - 5.0):"
hitLabel.TextXAlignment = Enum.TextXAlignment.Left

local hitBox = Instance.new("TextBox", hitFrame)
hitBox.Size = UDim2.new(0.45, -4, 0, 28)
hitBox.Position = UDim2.new(0.55, 0, 0.5, -14)
hitBox.BackgroundColor3 = Color3.fromRGB(32,32,32)
hitBox.TextColor3 = Color3.fromRGB(240,240,240)
hitBox.Font = Enum.Font.Gotham
hitBox.TextSize = 13
hitBox.ClearTextOnFocus = false
hitBox.Text = tostring(FEATURE.HitboxScale)
Instance.new("UICorner", hitBox).CornerRadius = UDim.new(0,8)

local hitToggleFrame, hitToggleBtn = addToggle(SettingsTab, "Hitbox", FEATURE.HitboxEnabled, function(state)
    FEATURE.HitboxEnabled = state
    hitToggleBtn.Text = state and "ON" or "OFF"
    hitToggleBtn.BackgroundColor3 = state and Color3.fromRGB(80,150,220) or Color3.fromRGB(36,36,36)
    updateHUD("Hitbox", state)
    if state then
        -- apply immediately
        for _,p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local char = p.Character
                for _,part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if not OriginalPartSizes[part] then
                            OriginalPartSizes[part] = part.Size
                            OriginalCollisions[part] = part.CanCollide
                        end
                        local scale = clamp(tonumber(hitBox.Text) or FEATURE.HitboxScale, 1, 5)
                        part.Size = OriginalPartSizes[part] * scale
                        part.CanCollide = false
                    end
                end
            end
        end
    else
        -- restore
        for part,orig in pairs(OriginalPartSizes) do
            pcall(function()
                if part and part.Parent then
                    part.Size = orig
                    part.CanCollide = (OriginalCollisions[part] ~= nil) and OriginalCollisions[part] or part.CanCollide
                end
            end)
        end
        OriginalPartSizes = {}
        OriginalCollisions = {}
    end
end)

hitBox.FocusLost:Connect(function(enter)
    if enter then
        local n = tonumber(hitBox.Text)
        if n and n >= 1 and n <= 5 then
            FEATURE.HitboxScale = n
            if FEATURE.HitboxEnabled then
                -- reapply scale
                for _,p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        local char = p.Character
                        for _,part in ipairs(char:GetDescendants()) do
                            if part:IsA("BasePart") then
                                if not OriginalPartSizes[part] then
                                    OriginalPartSizes[part] = part.Size
                                    OriginalCollisions[part] = part.CanCollide
                                end
                                part.Size = OriginalPartSizes[part] * n
                                part.CanCollide = false
                            end
                        end
                    end
                end
            end
        else
            hitBox.Text = tostring(FEATURE.HitboxScale)
        end
    end
end)

-- Cleanup / Uninject button
local cleanupBtn = addButton(SettingsTab, "Cleanup / Uninject", UDim2.new(1,0,0,36))
cleanupBtn.BackgroundColor3 = Color3.fromRGB(200,80,80)
cleanupBtn.MouseButton1Click:Connect(function()
    if _G and _G.__TPB_CLEANUP then
        pcall(_G.__TPB_CLEANUP)
    end
end)

-- =========================
-- HUD / Toggle hotkeys
-- =========================
local ToggleCallbacks = {}
local Buttons = {}

local function registerToggle(displayName, featureKey, onChange)
    ToggleCallbacks[featureKey] = onChange
end

-- hotkeys F1-F4 mapping (like before)
keepPersistent(UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if UIS:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.F1 then
        FEATURE.ESP = not FEATURE.ESP
        if ToggleCallbacks.ESP then ToggleCallbacks.ESP(FEATURE.ESP) end
        updateHUD("ESP", FEATURE.ESP)
    elseif input.KeyCode == Enum.KeyCode.F2 then
        FEATURE.AutoE = not FEATURE.AutoE
        updateHUD("Auto Press E", FEATURE.AutoE)
    elseif input.KeyCode == Enum.KeyCode.F3 then
        FEATURE.WalkEnabled = not FEATURE.WalkEnabled
        updateHUD("WalkSpeed", FEATURE.WalkEnabled)
    elseif input.KeyCode == Enum.KeyCode.F4 then
        FEATURE.Aimbot = not FEATURE.Aimbot
        updateHUD("Aimbot", FEATURE.Aimbot)
    end
end))

-- =========================
-- ESP Implementation (event-driven where possible)
-- =========================
local lastRefresh = setmetatable({}, { __mode = "k" })
local MIN_REFRESH_INTERVAL = 0.12

local function shouldRefreshForPlayer(p)
    local t = tick()
    local last = lastRefresh[p] or 0
    if t - last < MIN_REFRESH_INTERVAL then return false end
    lastRefresh[p] = t
    return true
end

local function getESPColor(p)
    if p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team then
        return Color3.fromRGB(0,200,0)
    else
        return Color3.fromRGB(200,40,40)
    end
end

local function clearESPForPlayer(p)
    if not p then return end
    local list = espObjects[p]
    if list then
        for _,v in pairs(list) do
            if v and v.Parent then
                pcall(function() v:Destroy() end)
            end
        end
        espObjects[p] = nil
    end
end

local function updateESPColorForPlayer(p)
    local list = espObjects[p]
    if list then
        for _,hl in ipairs(list) do
            if hl and hl.Parent then
                hl.FillColor = getESPColor(p)
            end
        end
    end
end

local function createESPForPlayer(p)
    if not p then return end
    if not FEATURE.ESP then return end
    if not shouldRefreshForPlayer(p) then return end
    if espObjects[p] then
        updateESPColorForPlayer(p)
        return
    end
    local char = p.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then return end
    local hl = Instance.new("Highlight")
    hl.Name = "TPB_BoxESP"
    hl.Adornee = char
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.OutlineTransparency = 0
    hl.OutlineColor = Color3.fromRGB(255,255,255)
    hl.FillTransparency = 0.7
    hl.FillColor = getESPColor(p)
    hl.Parent = char
    espObjects[p] = { hl }
end

local function refreshESPForPlayer(p)
    if FEATURE.ESP then createESPForPlayer(p) else clearESPForPlayer(p) end
end

local function ensurePlayerListeners(p)
    if not p then return end
    if PerPlayerConnections[p] then return end

    addPerPlayerConnection(p, p.CharacterAdded:Connect(function()
        local char = p.Character
        if char then
            char:WaitForChild("HumanoidRootPart", 2)
            task.wait(0.06)
            refreshESPForPlayer(p)

            addPerPlayerConnection(p, p.CharacterRemoving:Connect(function() clearESPForPlayer(p) end))
        end
    end))

    if p.Character then
        addPerPlayerConnection(p, p.CharacterRemoving:Connect(function() clearESPForPlayer(p) end))
    end

    addPerPlayerConnection(p, p:GetPropertyChangedSignal("Team"):Connect(function() updateESPColorForPlayer(p) end))
end

-- initial ESP wiring
local playersAddedConn = nil
local playersRemovingConn = nil
local function enableESPListeners()
    if not playersAddedConn then
        playersAddedConn = keepPersistent(Players.PlayerAdded:Connect(function(p)
            if p ~= LocalPlayer then
                ensurePlayerListeners(p)
                task.wait(0.12)
                refreshESPForPlayer(p)
            end
        end))
    end

    if not playersRemovingConn then
        playersRemovingConn = keepPersistent(Players.PlayerRemoving:Connect(function(p)
            clearESPForPlayer(p)
            clearConnectionsForPlayer(p)
        end))
    end
end
enableESPListeners()

-- =========================
-- AutoE implementation (rate-limited)
-- =========================
local autoEThread = nil
local autoEStop = false
local function startAutoE()
    if autoEThread then return end
    if not VIM then
        FEATURE.AutoE = false
        warn("AutoE: VirtualInputManager not available. AutoE disabled.")
        updateHUD("Auto Press E", false)
        return
    end
    autoEStop = false
    autoEThread = task.spawn(function()
        while FEATURE.AutoE and not autoEStop do
            pcall(function()
                local interval = clamp(FEATURE.AutoEInterval or 0.5, 0.05, 5)
                pcall(function()
                    VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                end)
                task.wait(interval)
            end)
        end
        autoEThread = nil
    end)
    updateHUD("Auto Press E", true)
end

local function stopAutoE()
    FEATURE.AutoE = false
    autoEStop = true
    updateHUD("Auto Press E", false)
end

-- Watch FEATURE.AutoE change
keepPersistent(RunService.Heartbeat:Connect(function()
    -- start/stop autoE depending on feature
    if FEATURE.AutoE and not autoEThread then
        startAutoE()
    elseif not FEATURE.AutoE and autoEThread then
        stopAutoE()
    end
end))

-- =========================
-- WalkSpeed management (optimized)
-- =========================
local OriginalWalkByCharacter = {}

local function setPlayerWalkSpeedForCharacter(char, value)
    if not char then return end
    pcall(function()
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            if OriginalWalkByCharacter[char] == nil then OriginalWalkByCharacter[char] = hum.WalkSpeed end
            if hum.WalkSpeed ~= value then hum.WalkSpeed = value end
        end
    end)
end

do
    local acc = 0
    keepPersistent(RunService.Heartbeat:Connect(function(dt)
        if not FEATURE.WalkEnabled then return end
        acc = acc + dt
        if acc < WALK_UPDATE_INTERVAL then return end
        acc = 0
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                setPlayerWalkSpeedForCharacter(char, FEATURE.WalkValue)
            end
        end)
    end))
end

local function restoreWalkSpeedForCharacter(char)
    if not char then return end
    pcall(function()
        local hum = char:FindFirstChildOfClass("Humanoid")
        local orig = OriginalWalkByCharacter[char]
        if hum and orig then
            hum.WalkSpeed = orig
        end
    end)
    OriginalWalkByCharacter[char] = nil
end

local function restoreAllWalkSpeeds()
    for char,_ in pairs(OriginalWalkByCharacter) do
        restoreWalkSpeedForCharacter(char)
    end
    OriginalWalkByCharacter = {}
    updateHUD("WalkSpeed", false)
end

-- =========================
-- Aimbot (RenderStepped, rate-limited & safe)
-- =========================
local function angleBetweenVectors(a, b)
    local dot = a:Dot(b)
    local m = math.max(a.Magnitude * b.Magnitude, 1e-6)
    local val = clamp(dot / m, -1, 1)
    return math.deg(math.acos(val))
end

keepPersistent(RunService.RenderStepped:Connect(function()
    if not FEATURE.Aimbot then return end
    if FEATURE.AIM_HOLD and not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
    if UIS:GetFocusedTextBox() then return end
    safeWaitCamera()
    if not Camera or not Camera.CFrame then return end

    local bestHead = nil
    local bestAngle = 1e9

    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local okTarget = false
            if p.Team and LocalPlayer.Team then
                okTarget = (p.Team ~= LocalPlayer.Team)
            else
                okTarget = true
            end
            if okTarget and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if not hum or hum.Health <= 0 then
                else
                    local head = p.Character:FindFirstChild("Head") or p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("HumanoidRootPart")
                    if head then
                        local dir = head.Position - Camera.CFrame.Position
                        if dir.Magnitude > 0.001 then
                            local ang = angleBetweenVectors(Camera.CFrame.LookVector, dir.Unit)
                            if ang < bestAngle and ang <= FEATURE.AIM_FOV_DEG then
                                bestHead = head
                                bestAngle = ang
                            end
                        end
                    end
                end
            end
        end
    end

    if bestHead and bestHead.Parent then
        local success, err = pcall(function()
            local dir = (bestHead.Position - Camera.CFrame.Position)
            if dir.Magnitude < 1e-4 then return end
            dir = dir.Unit
            local currentLook = Camera.CFrame.LookVector
            local lerpVal = clamp(FEATURE.AIM_LERP, 0.01, 0.95)
            local blended = currentLook:Lerp(dir, lerpVal)
            local pos = Camera.CFrame.Position
            local targetCFrame = CFrame.new(pos, pos + blended)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, lerpVal)
        end)
        if not success then
            warn("Aimbot camera write error:", err)
            FEATURE.Aimbot = false
            updateHUD("Aimbot", false)
        end
    end
end))

-- =========================
-- Hitbox Expander handlers (apply/restore on player join/leave)
-- =========================
local function expandCharacterParts(char, scale)
    if not char then return end
    for _,part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if not OriginalPartSizes[part] then
                OriginalPartSizes[part] = part.Size
                OriginalCollisions[part] = part.CanCollide
            end
            pcall(function()
                part.Size = OriginalPartSizes[part] * scale
                part.CanCollide = false
            end)
        end
    end
end

local function restoreCharacterParts(char)
    if not char then return end
    for _,part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                if OriginalPartSizes[part] then
                    part.Size = OriginalPartSizes[part]
                    part.CanCollide = (OriginalCollisions[part] ~= nil) and OriginalCollisions[part] or part.CanCollide
                    OriginalPartSizes[part] = nil
                    OriginalCollisions[part] = nil
                end
            end)
        end
    end
end

-- watch players to apply/restore when characters spawn
keepPersistent(Players.PlayerAdded:Connect(function(p)
    if p == LocalPlayer then return end
    addPerPlayerConnection(p, p.CharacterAdded:Connect(function(char)
        if FEATURE.HitboxEnabled then
            task.wait(0.05)
            expandCharacterParts(char, FEATURE.HitboxScale)
        end
        -- ensure cleanup connection to restore when character removed
        addPerPlayerConnection(p, p.CharacterRemoving:Connect(function()
            restoreCharacterParts(char)
        end))
    end))
end))

-- apply existing players
for _,p in ipairs(Players:GetPlayers()) do
    ensurePlayerListeners(p)
    if p ~= LocalPlayer and p.Character and FEATURE.HitboxEnabled then
        expandCharacterParts(p.Character, FEATURE.HitboxScale)
    end
end

-- =========================
-- Player removal handling: cleanup original sizes
-- =========================
keepPersistent(Players.PlayerRemoving:Connect(function(p)
    -- clear esp
    clearESPForPlayer(p)
    -- clear original sizes that belong to this player's character parts
    if p.Character then
        restoreCharacterParts(p.Character)
    end
    clearConnectionsForPlayer(p)
end))

-- =========================
-- Local player character events (restore walk speed & stop autoE on death)
-- =========================
keepPersistent(LocalPlayer.CharacterRemoving:Connect(function(char)
    restoreWalkSpeedForCharacter(char)
    stopAutoE()
end))

keepPersistent(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if FEATURE.WalkEnabled then
        pcall(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum and OriginalWalkByCharacter[LocalPlayer.Character] == nil then OriginalWalkByCharacter[LocalPlayer.Character] = hum.WalkSpeed end
            if hum then hum.WalkSpeed = FEATURE.WalkValue end
        end)
    end
    if FEATURE.ESP then
        task.wait(0.2)
        for _,p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                refreshESPForPlayer(p)
            end
        end
    end
end))

-- =========================
-- Safe cleanup function
-- =========================
if _G then
    _G.__TPB_CLEANUP = function()
        -- destroy GUIs
        pcall(function()
            local g = PlayerGui:FindFirstChild("TPB_TycoonGUI_Final")
            if g then g:Destroy() end
            local gh = PlayerGui:FindFirstChild("TPB_TycoonHUD_Final")
            if gh then gh:Destroy() end
        end)

        -- restore esp
        for p,_ in pairs(espObjects) do
            clearESPForPlayer(p)
        end
        espObjects = {}

        -- restore hitboxes
        for part,orig in pairs(OriginalPartSizes) do
            pcall(function()
                if part and part.Parent then
                    part.Size = orig
                    part.CanCollide = (OriginalCollisions[part] ~= nil) and OriginalCollisions[part] or part.CanCollide
                end
            end)
        end
        OriginalPartSizes = {}
        OriginalCollisions = {}

        -- restore walks
        restoreAllWalkSpeeds()

        -- stop autoE
        stopAutoE()

        -- disconnect connections
        clearAllConnections()

        -- clear teleport storage (optional: keep if you want, here we keep it)
        -- getgenv().__TPB_TELEPORTS = nil

        print("[TPB Refactor] cleanup complete.")
    end
end

-- =========================
-- Initial HUD values
-- =========================
updateHUD("ESP", FEATURE.ESP)
updateHUD("Auto Press E", FEATURE.AutoE)
updateHUD("WalkSpeed", FEATURE.WalkEnabled)
updateHUD("Aimbot", FEATURE.Aimbot)
updateHUD("Hitbox", FEATURE.HitboxEnabled)

-- =========================
-- Final notes to user (console)
-- =========================
print("✅ TPB Refactor v2 loaded.")
print("Fitur: ESP, AutoPressE, WalkSpeed, Aimbot, Teleport, Hitbox Expander.")
print("Cara set teleport: pindah ke lokasi (Spaceship/Bunker/PrivateIsland/Submarine) untuk TIMMU, lalu buka tab Teleport -> pilih lokasi -> tekan 'Set untuk Tim Saya'.")
print("Setiap tim memiliki titik terpisah. Gunakan tombol 'Tampilkan Data Teleport' untuk melihat data di console.")
print("Gunakan tab Settings -> 'Cleanup / Uninject' untuk memulihkan keadaan semula dan menghentikan script.")
