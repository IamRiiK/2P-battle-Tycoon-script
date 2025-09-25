if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local TeleportService = game:GetService("TeleportService")
local Camera = Workspace.CurrentCamera or Workspace:FindFirstChild("CurrentCamera")
if not Camera then
    local ok, cam = pcall(function() return Workspace:WaitForChild("CurrentCamera", 5) end)
    Camera = ok and cam or Workspace.CurrentCamera
end

local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)

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
    PredictiveAim = true,
    ProjectileSpeed = 300,
    PredictionLimit = 1.5,
    AutoTP = false,
    AutoTPTarget = nil,
}

local WALK_UPDATE_INTERVAL = 0.12

local TELEPORT_COORDS = {
    ["Black"] = {
        Spaceship = Vector3.new(153.2, 683.7, 814.4),
        Bunker = Vector3.new(63.9, 3.3, 143.9),
        PrivateIsland = Vector3.new(145.2, 87.5, 697.5),
        Submarine = Vector3.new(61.8, -101.0, 154.9),
        Spawn = Vector3.new(64.1, 72.0, 131.3),
    },
    ["White"] = {
        Spaceship = Vector3.new(-252.3, 683.7, 810.7),
        Bunker = Vector3.new(-116.3, 3.3, 152.9),
        PrivateIsland = Vector3.new(-259.7, 87.5, 697.9),
        Submarine = Vector3.new(-116.6, -101.0, 151.4),
        Spawn = Vector3.new(-115.7, 72.0, 131.2),
    },
    ["Purple"] = {
        Spaceship = Vector3.new(-922.3, 683.7, 95.3),
        Bunker = Vector3.new(-263.3, 3.3, 5.7),
        PrivateIsland = Vector3.new(-807.7, 87.5, 87.4),
        Submarine = Vector3.new(-265.1, -101.0, 6.4),
        Spawn = Vector3.new(-240.9, 72.0, 6.2),
    },
    ["Orange"] = {
        Spaceship = Vector3.new(-922.2, 683.7, -309.5),
        Bunker = Vector3.new(-261.3, 3.3, -173.9),
        PrivateIsland = Vector3.new(-806.2, 87.5, -318.0),
        Submarine = Vector3.new(-266.3, -101.0, -174.2),
        Spawn = Vector3.new(-240.9, 72.0, -174.0),
    },
    ["Yellow"] = {
        Spaceship = Vector3.new(-204.4, 683.7, -979.2),
        Bunker = Vector3.new(-115.9, 3.3, -317.8),
        PrivateIsland = Vector3.new(-197.2, 87.5, -868.6),
        Submarine = Vector3.new(-115.6, -101.0, -319.6),
        Spawn = Vector3.new(-115.8, 72.0, -299.1),
    },
    ["Blue"] = {
        Spaceship = Vector3.new(200.2, 683.7, -978.8),
        Bunker = Vector3.new(63.9, 3.3, -316.2),
        PrivateIsland = Vector3.new(207.6, 87.5, -865.2),
        Submarine = Vector3.new(63.9, -101.0, -319.2),
        Spawn = Vector3.new(63.9, 72.0, -298.7),
    },
    ["Green"] = {
        Spaceship = Vector3.new(871.9, 683.7, -263.0),
        Bunker = Vector3.new(202.8, 3.3, -174.1),
        PrivateIsland = Vector3.new(755.9, 87.5, -254.9),
        Submarine = Vector3.new(211.2, -101.0, -173.9),
        Spawn = Vector3.new(188.5, 72.0, -173.9),
    },
    ["Red"] = {
        Spaceship = Vector3.new(871.2, 683.7, 141.6),
        Bunker = Vector3.new(204.1, 3.3, 5.9),
        PrivateIsland = Vector3.new(755.4, 87.5, 149.4),
        Submarine = Vector3.new(209.8, -101.0, 6.4),
        Spawn = Vector3.new(188.8, 72.0, 6.1),
    },
    ["Flag"] = {
        Neutral = Vector3.new(-24.8, 42.3, -83.2),
    },
}

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
        for _, c in ipairs(t) do
            pcall(function() c:Disconnect() end)
        end
        PerPlayerConnections[p] = nil
    end
end

local function clearAllPerPlayerConnections()
    for p, _ in pairs(PerPlayerConnections) do
        clearConnectionsForPlayer(p)
    end
end

local function clearAllConnections()
    clearAllPerPlayerConnections()
    for _, c in ipairs(PersistentConnections) do
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

pcall(function()
    if _G and _G.__TPB_CLEANUP then pcall(_G.__TPB_CLEANUP) end
    local old = PlayerGui:FindFirstChild("TPB_TycoonGUI_Final")
    if old then old:Destroy() end
    local old2 = PlayerGui:FindFirstChild("TPB_TycoonHUD_Final")
    if old2 then old2:Destroy() end
end)

local MainScreenGui = Instance.new("ScreenGui")
MainScreenGui.Name = "TPB_TycoonGUI_Final"
MainScreenGui.DisplayOrder = 9999
safeParentGui(MainScreenGui)

local MainFrame = Instance.new("Frame", MainScreenGui)
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0,340,0,520)
MainFrame.Position = UDim2.new(0.02,0,0.12,0)
MainFrame.BackgroundColor3 = Color3.fromRGB(28,28,30)
MainFrame.BorderSizePixel = 0
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0,10)

local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.Size = UDim2.new(1,0,0,36)
TitleBar.BackgroundTransparency = 1

local DragHandle = Instance.new("TextLabel", TitleBar)
DragHandle.Size = UDim2.new(0,28,0,28)
DragHandle.Position = UDim2.new(0,8,0,4)
DragHandle.BackgroundTransparency = 1
DragHandle.Font = Enum.Font.Gotham
DragHandle.TextSize = 20
DragHandle.TextColor3 = Color3.fromRGB(200,200,200)
DragHandle.Text = "≡"
DragHandle.Active = true
DragHandle.Selectable = true

local TitleLabel = Instance.new("TextLabel", TitleBar)
TitleLabel.Size = UDim2.new(1,-110,1,0)
TitleLabel.Position = UDim2.new(0.07,0,0,0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 16
TitleLabel.TextColor3 = Color3.fromRGB(245,245,245)
TitleLabel.Text = "⚔️2P Battle Tycoon"
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

local HintLabel = Instance.new("TextLabel", TitleBar)
HintLabel.Size = UDim2.new(0.3,0,1,0)
HintLabel.Position = UDim2.new(0.7,0,0,0)
HintLabel.BackgroundTransparency = 1
HintLabel.Font = Enum.Font.Gotham
HintLabel.TextSize = 12
HintLabel.TextColor3 = Color3.fromRGB(170,170,170)
HintLabel.Text = "LeftAlt = Hide UI"
HintLabel.TextXAlignment = Enum.TextXAlignment.Right

local MinBtn = Instance.new("TextButton", TitleBar)
MinBtn.Size = UDim2.new(0,36,0,28)
MinBtn.Position = UDim2.new(1,-42,0,4)
MinBtn.BackgroundColor3 = Color3.fromRGB(58,58,60)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 18
MinBtn.TextColor3 = Color3.fromRGB(240,240,240)
MinBtn.Text = "-"
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0,6)

-- Main Content Frame (akan berisi TabControl)
local Content = Instance.new("Frame", MainFrame)
Content.Name = "Content"
Content.Size = UDim2.new(1,-16,1,-56)
Content.Position = UDim2.new(0,8,0,44)
Content.BackgroundTransparency = 1

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Content.Visible = not minimized
    MinBtn.Text = minimized and "+" or "-"
end)

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
        if input and input.Position then return Vector2.new(input.Position.X, input.Position.Y) else return UIS:GetMouseLocation() end
    end
    local function onInputBegan(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragInput = input
            dragStart = getInputPos(input)
            startPosPixels = toPixels(MainFrame.Position)
            if dragChangedConn then pcall(function() dragChangedConn:Disconnect() end) dragChangedConn = nil end
            if input.Changed then
                dragChangedConn = input.Changed:Connect(function(property)
                    if property == "UserInputState" and input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                        dragInput = nil
                        if dragChangedConn then pcall(function() dragChangedConn:Disconnect() end) dragChangedConn = nil end
                    end
                end)
                keepPersistent(dragChangedConn)
            end
        end
    end
    local function onInputChanged(input)
        if not dragging then return end
        if input ~= dragInput and input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
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
            if dragChangedConn then pcall(function() dragChangedConn:Disconnect() end) dragChangedConn = nil end
        end
    end
    TitleBar.InputBegan:Connect(onInputBegan)
    DragHandle.InputBegan:Connect(onInputBegan)
    keepPersistent(UIS.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then onInputChanged(input) end
    end))
    keepPersistent(UIS.InputEnded:Connect(onInputEnded))
end

local HUDGui = Instance.new("ScreenGui")
HUDGui.Name = "TPB_TycoonHUD_Final"
HUDGui.DisplayOrder = 10000
safeParentGui(HUDGui)
local HUD = Instance.new("Frame", HUDGui)
HUD.Size = UDim2.new(0,220,0,120)
HUD.Position = UDim2.new(1,-240,1,-150)
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
    l.Size = UDim2.new(1,-12,0,18)
    l.Position = UDim2.new(0,8,0,0)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.Gotham
    l.TextSize = 13
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
hudAdd("PredictiveAim")
hudAdd("AutoTP")

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
        if MainFrame.Visible then
            -- Refresh daftar musuh saat UI dibuka
            populateEnemyList()
        end
    end
end))

local function createSeparator(parent, text)
    local lab = Instance.new("TextLabel", parent)
    lab.Size = UDim2.new(1,0,0,18)
    lab.BackgroundTransparency = 1
    lab.Font = Enum.Font.Gotham
    lab.TextSize = 12
    lab.TextColor3 = Color3.fromRGB(170,170,170)
    lab.Text = "─────────  " .. (text or "") .. "  ─────────"
    lab.TextXAlignment = Enum.TextXAlignment.Center
    return lab
end

local ToggleCallbacks = {}
local Buttons = {}
local function registerToggle(displayName, featureKey, parentFrame, onChange) -- Tambahkan parentFrame
    local btn = Instance.new("TextButton", parentFrame) -- Gunakan parentFrame
    btn.Size = UDim2.new(1,0,0,32)
    btn.BackgroundColor3 = Color3.fromRGB(36,36,36)
    btn.TextColor3 = Color3.fromRGB(235,235,235)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.Text = displayName .. " [OFF]"
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
    -- btn.Parent = parentFrame -- Sudah diatur di Instance.new
    local function setState(state)
        local old = FEATURE[featureKey]
        FEATURE[featureKey] = state
        btn.Text = displayName .. " [" .. (state and "ON" or "OFF") .. "]"
        btn.BackgroundColor3 = state and Color3.fromRGB(80,150,220) or Color3.fromRGB(36,36,36)
        updateHUD(displayName, state)
        if type(onChange) == "function" then
            local ok, err = pcall(onChange, state)
            if not ok then
                warn("Toggle callback error:", err)
                FEATURE[featureKey] = old
            end
        end
    end
    btn.MouseButton1Click:Connect(function() setState(not FEATURE[featureKey]) end)
    ToggleCallbacks[featureKey] = setState
    Buttons[featureKey] = btn
    return btn
end

-- ====================================================================================================
-- TAB CONTROL IMPLEMENTATION
-- ====================================================================================================

local TabButtonsFrame = Instance.new("Frame", Content)
TabButtonsFrame.Name = "TabButtonsFrame"
TabButtonsFrame.Size = UDim2.new(1,0,0,30)
TabButtonsFrame.Position = UDim2.new(0,0,0,0)
TabButtonsFrame.BackgroundTransparency = 1

local TabButtonListLayout = Instance.new("UIListLayout", TabButtonsFrame)
TabButtonListLayout.FillDirection = Enum.FillDirection.Horizontal
TabButtonListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabButtonListLayout.Padding = UDim.new(0,5)
TabButtonListLayout.SortOrder = Enum.SortOrder.LayoutOrder

local TabContentFrame = Instance.new("Frame", Content)
TabContentFrame.Name = "TabContentFrame"
TabContentFrame.Size = UDim2.new(1,0,1,-35)
TabContentFrame.Position = UDim2.new(0,0,0,35)
TabContentFrame.BackgroundTransparency = 1

local activeTab = nil
local tabPages = {}
local tabButtons = {}

local function createTab(name, order)
    local tabButton = Instance.new("TextButton", TabButtonsFrame)
    tabButton.Name = name .. "TabButton"
    tabButton.Size = UDim2.new(0.2,0,1,0) -- Sesuaikan ukuran tab button
    tabButton.BackgroundColor3 = Color3.fromRGB(45,45,48)
    tabButton.TextColor3 = Color3.fromRGB(180,180,180)
    tabButton.Font = Enum.Font.GothamBold
    tabButton.TextSize = 14
    tabButton.Text = name
    tabButton.LayoutOrder = order
    Instance.new("UICorner", tabButton).CornerRadius = UDim.new(0,6)

    local tabPage = Instance.new("ScrollingFrame", TabContentFrame)
    tabPage.Name = name .. "TabPage"
    tabPage.Size = UDim2.new(1,0,1,0)
    tabPage.BackgroundTransparency = 1
    tabPage.Visible = false
    tabPage.CanvasSize = UDim2.new(0,0,0,0)
    tabPage.ScrollBarThickness = 6
    tabPage.VerticalScrollBarInset = Enum.ScrollBarInset.Always

    local pageLayout = Instance.new("UIListLayout", tabPage)
    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    pageLayout.Padding = UDim.new(0,8)

    pageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        tabPage.CanvasSize = UDim2.new(0,0,0, pageLayout.AbsoluteContentSize.Y + 12)
    end)

    tabPages[name] = tabPage
    tabButtons[name] = tabButton

    tabButton.MouseButton1Click:Connect(function()
        if activeTab then
            tabPages[activeTab].Visible = false
            tabButtons[activeTab].BackgroundColor3 = Color3.fromRGB(45,45,48)
            tabButtons[activeTab].TextColor3 = Color3.fromRGB(180,180,180)
        end
        tabPage.Visible = true
        tabButton.BackgroundColor3 = Color3.fromRGB(80,150,220)
        tabButton.TextColor3 = Color3.fromRGB(245,245,245)
        activeTab = name

        -- Panggil fungsi refresh khusus untuk tab yang diaktifkan
        if name == "Teleport" then
            updateTeleportTeamLabel()
        elseif name == "AutoTP" then
            populateEnemyList()
        end
    end)

    return tabPage
end

local combatTab = createTab("Combat", 1)
local movementTab = createTab("Movement", 2)
local teleportTab = createTab("Teleport", 3)
local utilityTab = createTab("Utility", 4)
local autoTPTab = createTab("AutoTP", 5) -- Tab baru untuk AutoTP

-- Aktifkan tab pertama secara default
tabButtons["Combat"].MouseButton1Click:Fire()

-- ====================================================================================================
-- END TAB CONTROL IMPLEMENTATION
-- ====================================================================================================

-- ====================================================================================================
-- COMBAT TAB FEATURES
-- ====================================================================================================
createSeparator(combatTab, "Aimbot Settings")

local aimFrame = Instance.new("Frame", combatTab)
aimFrame.Size = UDim2.new(1,0,0,72)
aimFrame.BackgroundTransparency = 1
local aimLayout = Instance.new("UIListLayout", aimFrame)
aimLayout.SortOrder = Enum.SortOrder.LayoutOrder
aimLayout.Padding = UDim.new(0,6)

local row = Instance.new("Frame", aimFrame)
row.Size = UDim2.new(1,0,0,28)
row.BackgroundTransparency = 1

local predBtn = Instance.new("TextButton", row)
predBtn.Size = UDim2.new(0.42,0,1,0)
predBtn.Position = UDim2.new(0,0,0,0)
predBtn.BackgroundColor3 = Color3.fromRGB(36,36,36)
predBtn.Font = Enum.Font.Gotham
predBtn.TextSize = 13
predBtn.TextColor3 = Color3.fromRGB(235,235,235)
predBtn.Text = "Predictive: " .. (FEATURE.PredictiveAim and "ON" or "OFF")
Instance.new("UICorner", predBtn).CornerRadius = UDim.new(0,6)
predBtn.MouseButton1Click:Connect(function()
    FEATURE.PredictiveAim = not FEATURE.PredictiveAim
    predBtn.Text = "Predictive: " .. (FEATURE.PredictiveAim and "ON" or "OFF")
    updateHUD("PredictiveAim", FEATURE.PredictiveAim)
end)

local speedBox = Instance.new("TextBox", row)
speedBox.Size = UDim2.new(0.28,0,1,0)
speedBox.Position = UDim2.new(0.44,6,0,0)
speedBox.BackgroundColor3 = Color3.fromRGB(36,36,36)
speedBox.TextColor3 = Color3.fromRGB(240,240,240)
speedBox.Font = Enum.Font.Gotham
speedBox.TextSize = 13
speedBox.ClearTextOnFocus = false
speedBox.Text = tostring(FEATURE.ProjectileSpeed)
speedBox.PlaceholderText = "Speed"
Instance.new("UICorner", speedBox).CornerRadius = UDim.new(0,6)
speedBox.FocusLost:Connect(function(enter)
    if enter then
        local n = tonumber(speedBox.Text)
        if n and n >= 10 and n <= 5000 then FEATURE.ProjectileSpeed = n else speedBox.Text = tostring(FEATURE.ProjectileSpeed) end
    end
end)

local limitBox = Instance.new("TextBox", row)
limitBox.Size = UDim2.new(0.28,0,1,0)
limitBox.Position = UDim2.new(0.72,6,0,0)
limitBox.BackgroundColor3 = Color3.fromRGB(36,36,36)
limitBox.TextColor3 = Color3.fromRGB(240,240,240)
limitBox.Font = Enum.Font.Gotham
limitBox.TextSize = 13
limitBox.ClearTextOnFocus = false
limitBox.Text = tostring(FEATURE.PredictionLimit)
limitBox.PlaceholderText = "Limit"
Instance.new("UICorner", limitBox).CornerRadius = UDim.new(0,6)
limitBox.FocusLost:Connect(function(enter)
    if enter then
        local n = tonumber(limitBox.Text)
        if n and n >= 0.1 and n <= 5 then FEATURE.PredictionLimit = n else limitBox.Text = tostring(FEATURE.PredictionLimit) end
    end
end)

registerToggle("Aimbot", "Aimbot", combatTab, function(state) updateHUD("Aimbot", state) end)

-- ====================================================================================================
-- MOVEMENT TAB FEATURES
-- ====================================================================================================
createSeparator(movementTab, "Movement Settings")

do
    local frame = Instance.new("Frame", movementTab)
    frame.Size = UDim2.new(1,0,0,36)
    frame.BackgroundTransparency = 1
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0.5,0,1,0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(230,230,230)
    label.Text = "WalkSpeed"
    label.TextXAlignment = Enum.TextXAlignment.Left

    local box = Instance.new("TextBox", frame)
    box.Size = UDim2.new(0.5,-6,1,0)
    box.Position = UDim2.new(0.5,6,0,0)
    box.BackgroundColor3 = Color3.fromRGB(36,36,36)
    box.TextColor3 = Color3.fromRGB(240,240,240)
    box.Font = Enum.Font.Gotham
    box.TextSize = 13
    box.ClearTextOnFocus = false
    box.Text = tostring(FEATURE.WalkValue)
    box.PlaceholderText = "16–200"
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
registerToggle("WalkSpeed", "WalkEnabled", movementTab, function(state)
    if state then
        pcall(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum and LocalPlayer.Character and OriginalWalkByCharacter[LocalPlayer.Character] == nil then OriginalWalkByCharacter[LocalPlayer.Character] = hum.WalkSpeed end
            if hum then hum.WalkSpeed = FEATURE.WalkValue end
        end)
        updateHUD("WalkSpeed", true)
    else
        restoreWalkSpeedForCharacter(LocalPlayer.Character)
    end
end)

-- ====================================================================================================
-- TELEPORT TAB FEATURES
-- ====================================================================================================
createSeparator(teleportTab, "Team Teleports")

local teleportContainer = Instance.new("ScrollingFrame", teleportTab)
teleportContainer.Size = UDim2.new(1,0,0,300) -- Sesuaikan ukuran agar muat di tab
teleportContainer.CanvasSize = UDim2.new(0,0,0,0)
teleportContainer.ScrollBarThickness = 6
teleportContainer.BackgroundTransparency = 1
teleportContainer.VerticalScrollBarInset = Enum.ScrollBarInset.Always

local teleportListLayout = Instance.new("UIListLayout", teleportContainer)
teleportListLayout.SortOrder = Enum.SortOrder.LayoutOrder
teleportListLayout.Padding = UDim.new(0,6)

teleportListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    teleportContainer.CanvasSize = UDim2.new(0,0,0, teleportListLayout.AbsoluteContentSize.Y + 12)
end)

local teleportTeamKeys = {}
for k, _ in pairs(TELEPORT_COORDS) do
    if k ~= "Flag" then
        table.insert(teleportTeamKeys, k)
    end
end
table.sort(teleportTeamKeys)

local currentTeamIndex = 1
local currentTeleportTeam = teleportTeamKeys[currentTeamIndex] or teleportTeamKeys[1] or "Black"

local tpHeader = Instance.new("Frame", teleportContainer)
tpHeader.Size = UDim2.new(1,0,0,28)
tpHeader.BackgroundTransparency = 1
local teamLabel = Instance.new("TextLabel", tpHeader)
teamLabel.Size = UDim2.new(0.6,0,1,0)
teamLabel.BackgroundTransparency = 1
teamLabel.Font = Enum.Font.Gotham
teamLabel.TextSize = 13
teamLabel.TextColor3 = Color3.fromRGB(220,220,220)
teamLabel.Text = "Team: " .. tostring(currentTeleportTeam)
teamLabel.TextXAlignment = Enum.TextXAlignment.Left

local switchHolder = Instance.new("Frame", tpHeader)
switchHolder.Size = UDim2.new(0.4,0,1,0)
switchHolder.Position = UDim2.new(0.6,0,0,0)
switchHolder.BackgroundTransparency = 1

local btnPrevTeam = Instance.new("TextButton", switchHolder)
btnPrevTeam.Size = UDim2.new(0.48,0,0.7,0)
btnPrevTeam.Position = UDim2.new(0,0.02,0.15,0)
btnPrevTeam.BackgroundColor3 = Color3.fromRGB(60,60,60)
btnPrevTeam.Font = Enum.Font.Gotham
btnPrevTeam.TextSize = 12
btnPrevTeam.TextColor3 = Color3.fromRGB(230,230,230)
btnPrevTeam.Text = "<"
Instance.new("UICorner", btnPrevTeam).CornerRadius = UDim.new(0,6)

local btnNextTeam = Instance.new("TextButton", switchHolder)
btnNextTeam.Size = UDim2.new(0.48,0,0.7,0)
btnNextTeam.Position = UDim2.new(0.52,0.02,0.15,0)
btnNextTeam.BackgroundColor3 = Color3.fromRGB(60,60,60)
btnNextTeam.Font = Enum.Font.Gotham
btnNextTeam.TextSize = 12
btnNextTeam.TextColor3 = Color3.fromRGB(230,230,230)
btnNextTeam.Text = ">"
Instance.new("UICorner", btnNextTeam).CornerRadius = UDim.new(0,6)

local activeTeleportButtons = {}

local function clearTeleportButtons()
    for _, b in ipairs(activeTeleportButtons) do
        if b and b.Parent then b:Destroy() end
    end
    activeTeleportButtons = {}
end

local function teleportPlayerTo(vec3)
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(vec3 + Vector3.new(0,3,0))
    end
end

local function createTeleportButtonsForTeam(team)
    clearTeleportButtons()
    local places = TELEPORT_COORDS[team]
    if not places then return end
    
    local sep = createSeparator(teleportContainer, "Teleport: " .. team)
    table.insert(activeTeleportButtons, sep)

    for place, pos in pairs(places) do
        local btn = Instance.new("TextButton", teleportContainer)
        btn.Size = UDim2.new(1,0,0,30)
        btn.BackgroundColor3 = Color3.fromRGB(50,50,50)
        btn.TextColor3 = Color3.fromRGB(235,235,235)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 13
        btn.Name = "TPBtn"
        btn.Text = place
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

        btn.MouseButton1Click:Connect(function()
            if place == "Spawn" then
                local myTeamName = (LocalPlayer.Team and LocalPlayer.Team.Name) or ""
                if myTeamName == team then
                    teleportPlayerTo(pos)
                else
                    warn("❌ Tidak bisa teleport ke Spawn tim lain")
                end
            else
                teleportPlayerTo(pos)
            end
        end)

        table.insert(activeTeleportButtons, btn)
    end

    local flagData = TELEPORT_COORDS["Flag"] or {}
    if next(flagData) then
        local fsep = createSeparator(teleportContainer, "Neutral / Flag")
        table.insert(activeTeleportButtons, fsep)
        for name, vec in pairs(flagData) do
            local fbtn = Instance.new("TextButton", teleportContainer)
            fbtn.Size = UDim2.new(1,0,0,30)
            fbtn.BackgroundColor3 = Color3.fromRGB(55,55,55)
            fbtn.TextColor3 = Color3.fromRGB(240,240,240)
            fbtn.Font = Enum.Font.Gotham
            fbtn.TextSize = 13
            fbtn.Text = name
            Instance.new("UICorner", fbtn).CornerRadius = UDim.new(0,6)
            fbtn.MouseButton1Click:Connect(function() teleportPlayerTo(vec) end)
            table.insert(activeTeleportButtons, fbtn)
        end
    end
end

local function updateTeleportTeamLabel()
    currentTeleportTeam = teleportTeamKeys[currentTeamIndex] or currentTeleportTeam
    teamLabel.Text = "Team: " .. tostring(currentTeleportTeam)
    createTeleportButtonsForTeam(currentTeleportTeam)
end

btnPrevTeam.MouseButton1Click:Connect(function()
    currentTeamIndex = currentTeamIndex - 1
    if currentTeamIndex < 1 then currentTeamIndex = #teleportTeamKeys end
    updateTeleportTeamLabel()
end)
btnNextTeam.MouseButton1Click:Connect(function()
    currentTeamIndex = currentTeamIndex + 1
    if currentTeamIndex > #teleportTeamKeys then currentTeamIndex = 1 end
    updateTeleportTeamLabel()
end)

-- ====================================================================================================
-- UTILITY TAB FEATURES
-- ====================================================================================================
createSeparator(utilityTab, "General Utilities")
registerToggle("ESP", "ESP", utilityTab, function(state)
    if state then enableESP() else disableESP() end
    updateHUD("ESP", state)
end)
registerToggle("Auto Press E", "AutoE", utilityTab, function(state)
    if state then startAutoE() else stopAutoE() end
end)

-- ====================================================================================================
-- AUTOTP TAB FEATURES
-- ====================================================================================================
local LocalPlayerSpawnPosition = nil

-- Fungsi untuk mendapatkan daftar musuh yang valid
local function getValidEnemies()
    local enemies = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChildOfClass("Humanoid") and p.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            -- Periksa apakah tim musuh berbeda dengan tim pemain lokal
            if p.Team and LocalPlayer.Team and p.Team ~= LocalPlayer.Team then
                table.insert(enemies, p)
            elseif not p.Team or not LocalPlayer.Team then -- Jika tidak ada tim, anggap sebagai musuh
                table.insert(enemies, p)
            end
        end
    end
    return enemies
end

createSeparator(autoTPTab, "Auto Teleport to Enemy")

local autoTPToggleBtn = registerToggle("AutoTP", "AutoTP", autoTPTab, function(state)
    if state then
        LocalPlayerSpawnPosition = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.CFrame.Position
        if not LocalPlayerSpawnPosition then
            warn("AutoTP: Tidak dapat menemukan posisi spawn pemain lokal. AutoTP dinonaktifkan.")
            ToggleCallbacks.AutoTP(false) -- Matikan toggle jika tidak bisa mendapatkan posisi spawn
            return
        end
        startAutoTP()
    else
        stopAutoTP()
    end
    updateHUD("AutoTP", state)
end)

local enemyListContainer = Instance.new("ScrollingFrame", autoTPTab)
enemyListContainer.Size = UDim2.new(1,0,0,150) -- Ukuran untuk daftar musuh
enemyListContainer.CanvasSize = UDim2.new(0,0,0,0)
enemyListContainer.ScrollBarThickness = 6
enemyListContainer.BackgroundTransparency = 1
enemyListContainer.VerticalScrollBarInset = Enum.ScrollBarInset.Always

local enemyListLayout = Instance.new("UIListLayout", enemyListContainer)
enemyListLayout.SortOrder = Enum.SortOrder.LayoutOrder
enemyListLayout.Padding = UDim.new(0,4)

enemyListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    enemyListContainer.CanvasSize = UDim2.new(0,0,0, enemyListLayout.AbsoluteContentSize.Y + 8)
end)

local activeEnemyButtons = {}

local function clearEnemyButtons()
    for _, b in ipairs(activeEnemyButtons) do
        if b and b.Parent then b:Destroy() end
    end
    activeEnemyButtons = {}
end

local function populateEnemyList()
    clearEnemyButtons()
    local enemies = getValidEnemies()
    if #enemies == 0 then
        local noEnemyLabel = Instance.new("TextLabel", enemyListContainer)
        noEnemyLabel.Size = UDim2.new(1,0,0,20)
        noEnemyLabel.BackgroundTransparency = 1
        noEnemyLabel.Font = Enum.Font.Gotham
        noEnemyLabel.TextSize = 12
        noEnemyLabel.TextColor3 = Color3.fromRGB(170,170,170)
        noEnemyLabel.Text = "Tidak ada musuh ditemukan."
        noEnemyLabel.TextXAlignment = Enum.TextXAlignment.Center
        table.insert(activeEnemyButtons, noEnemyLabel)
    else
        for _, enemyPlayer in ipairs(enemies) do
            local enemyBtn = Instance.new("TextButton", enemyListContainer)
            enemyBtn.Size = UDim2.new(1,0,0,24)
            enemyBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
            enemyBtn.TextColor3 = Color3.fromRGB(235,235,235)
            enemyBtn.Font = Enum.Font.Gotham
            enemyBtn.TextSize = 12
            enemyBtn.Text = enemyPlayer.Name
            Instance.new("UICorner", enemyBtn).CornerRadius = UDim.new(0,4)

            enemyBtn.MouseButton1Click:Connect(function()
                FEATURE.AutoTPTarget = enemyPlayer
                for _, btn in ipairs(activeEnemyButtons) do
                    if btn:IsA("TextButton") then
                        btn.BackgroundColor3 = Color3.fromRGB(50,50,50)
                    end
                end
                enemyBtn.BackgroundColor3 = Color3.fromRGB(80,150,220) -- Warna biru untuk target terpilih
                warn("AutoTP: Target diatur ke " .. enemyPlayer.Name)
            end)
            table.insert(activeEnemyButtons, enemyBtn)
        end
    end
end

-- Refresh daftar musuh saat pemain ditambahkan/dihapus
keepPersistent(Players.PlayerAdded:Connect(function(p)
    task.wait(0.5) -- Beri waktu karakter untuk memuat
    if activeTab == "AutoTP" then populateEnemyList() end
end))
keepPersistent(Players.PlayerRemoving:Connect(function(p)
    if FEATURE.AutoTPTarget == p then
        FEATURE.AutoTPTarget = nil
        stopAutoTP()
        warn("AutoTP: Target musuh keluar, AutoTP dinonaktifkan.")
    end
    if activeTab == "AutoTP" then populateEnemyList() end
end))

-- AutoTP logic
local autoTPThread = nil
local autoTPStop = false

local function startAutoTP()
    if autoTPThread then return end
    if not FEATURE.AutoTPTarget then
        warn("AutoTP: Tidak ada target musuh yang dipilih. AutoTP dinonaktifkan.")
        ToggleCallbacks.AutoTP(false)
        return
    end
    if not LocalPlayerSpawnPosition then
        warn("AutoTP: Posisi spawn pemain lokal tidak ditemukan. AutoTP dinonaktifkan.")
        ToggleCallbacks.AutoTP(false)
        return
    end

    autoTPStop = false
    autoTPThread = task.spawn(function()
        while FEATURE.AutoTP and not autoTPStop do
            pcall(function()
                local targetPlayer = FEATURE.AutoTPTarget
                if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChildOfClass("Humanoid") or targetPlayer.Character:FindFirstChildOfClass("Humanoid").Health <= 0 then
                    warn("AutoTP: Target musuh tidak valid atau mati. Mencari target baru...")
                    FEATURE.AutoTPTarget = nil
                    populateEnemyList() -- Refresh daftar musuh
                    ToggleCallbacks.AutoTP(false) -- Matikan AutoTP
                    return
                end

                local targetRoot = rootPartOfCharacter(targetPlayer.Character)
                local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

                if targetRoot and localRoot then
                    -- Teleport ke musuh
                    localRoot.CFrame = CFrame.new(targetRoot.Position + Vector3.new(0, 3, 0))
                    task.wait(0.1) -- Beri sedikit waktu di dekat musuh

                    -- Kembali ke posisi spawn
                    localRoot.CFrame = CFrame.new(LocalPlayerSpawnPosition + Vector3.new(0, 3, 0))
                end
                task.wait(0.5) -- Interval per teleport
            end)
        end
        autoTPThread = nil
    end)
    updateHUD("AutoTP", true)
end

local function stopAutoTP()
    FEATURE.AutoTP = false
    autoTPStop = true
    updateHUD("AutoTP", false)
end

-- ====================================================================================================
-- INITIALIZATION AND CONNECTIONS
-- ====================================================================================================

for k,_ in pairs(FEATURE) do
    local display = nil
    if k == "ESP" then display = "ESP" end
    if k == "AutoE" then display = "Auto Press E" end
    if k == "WalkEnabled" then display = "WalkSpeed" end
    if k == "Aimbot" then display = "Aimbot" end
    if k == "PredictiveAim" then display = "PredictiveAim" end
    if k == "AutoTP" then display = "AutoTP" end
    if display then updateHUD(display, FEATURE[k]) end
end

keepPersistent(UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if UIS:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.F1 and ToggleCallbacks.ESP then ToggleCallbacks.ESP(not FEATURE.ESP)
    elseif input.KeyCode == Enum.KeyCode.F2 and ToggleCallbacks.AutoE then ToggleCallbacks.AutoE(not FEATURE.AutoE)
    elseif input.KeyCode == Enum.KeyCode.F3 and ToggleCallbacks.WalkEnabled then ToggleCallbacks.WalkEnabled(not FEATURE.WalkEnabled)
    elseif input.KeyCode == Enum.KeyCode.F4 and ToggleCallbacks.Aimbot then ToggleCallbacks.Aimbot(not FEATURE.Aimbot)
    elseif input.KeyCode == Enum.KeyCode.F5 and ToggleCallbacks.AutoTP then ToggleCallbacks.AutoTP(not FEATURE.AutoTP) end
end))

keepPersistent(LocalPlayer.CharacterRemoving:Connect(function(char)
    restoreWalkSpeedForCharacter(char)
    stopAutoE()
    stopAutoTP()
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
        for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then refreshESPForPlayer(p) end end
    end
    if FEATURE.AutoTP then
        LocalPlayerSpawnPosition = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.CFrame.Position
        if not LocalPlayerSpawnPosition then
            warn("AutoTP: Posisi spawn pemain lokal tidak ditemukan setelah respawn. AutoTP dinonaktifkan.")
            ToggleCallbacks.AutoTP(false)
        end
    end
end))

if _G then
    _G.__TPB_CLEANUP = function()
        for p,_ in pairs(espObjects) do clearESPForPlayer(p) end
        pcall(function()
            local g = PlayerGui:FindFirstChild("TPB_TycoonGUI_Final")
            if g then g:Destroy() end
            local gh = PlayerGui:FindFirstChild("TPB_TycoonHUD_Final")
            if gh then gh:Destroy() end
        end)
        restoreAllWalkSpeeds()
        stopAutoE()
        stopAutoTP()
        clearAllConnections()
        playerMotion = {}
        espObjects = {}
        FEATURE.AutoTPTarget = nil
        LocalPlayerSpawnPosition = nil
        clearEnemyButtons()
        -- Tidak perlu menghancurkan autoTPFrame secara eksplisit jika sudah menjadi bagian dari MainFrame yang dihancurkan
    end
end
print("Script Loaded")
