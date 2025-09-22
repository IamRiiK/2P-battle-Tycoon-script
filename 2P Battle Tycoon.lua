-- TPB Refactor + Teleport & Predictive Aimbot (integrated)
if not game:IsLoaded() then game.Loaded:Wait() end

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local TeleportService = game:GetService("TeleportService")
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera or Workspace:FindFirstChild("CurrentCamera")
if not Camera then
    local ok, cam = pcall(function() return Workspace:WaitForChild("CurrentCamera", 5) end)
    Camera = ok and cam or Workspace.CurrentCamera
end

local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)

-- ---------- CONFIG / STATE ----------
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
    ProjectileSpeed = 300, -- studs/sec (tweakable)
    PredictionLimit = 1.5, -- max seconds lead
}

local WALK_UPDATE_INTERVAL = 0.12

-- Teleport coordinates (from user)
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

-- ---------- HELPERS & CONNECTION MANAGEMENT ----------
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

-- Ensure old GUI cleaned up on reload
pcall(function()
    if _G and _G.__TPB_CLEANUP then pcall(_G.__TPB_CLEANUP) end
    local old = PlayerGui:FindFirstChild("TPB_TycoonGUI_Final")
    if old then old:Destroy() end
    local old2 = PlayerGui:FindFirstChild("TPB_TycoonHUD_Final")
    if old2 then old2:Destroy() end
end)

-- ---------- MAIN UI (original + teleport area) ----------
local MainScreenGui = Instance.new("ScreenGui")
MainScreenGui.Name = "TPB_TycoonGUI_Final"
MainScreenGui.DisplayOrder = 9999
safeParentGui(MainScreenGui)

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0,360,0,660) -- sedikit lebih tinggi untuk Teleport
MainFrame.Position = UDim2.new(0.28,0,0.12,0)
MainFrame.BackgroundColor3 = Color3.fromRGB(28,28,30)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = MainScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0,12)

-- GUI Buatan
local ScreenGui = Instance.new("ScreenGui", LocalPlayer.PlayerGui)
ScreenGui.Name = "CustomUI"

local Frame = Instance.new("Frame", ScreenGui)
Frame.Size = UDim2.new(0, 350, 0, 450)
Frame.Position = UDim2.new(0.5, -175, 0.5, -225)
Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Frame.Active = true
Frame.Draggable = true

-- Scroll list teleport
local Scroller = Instance.new("ScrollingFrame", Frame)
Scroller.Size = UDim2.new(1, -10, 1, -50)
Scroller.Position = UDim2.new(0, 5, 0, 45)
Scroller.CanvasSize = UDim2.new(0,0,5,0)
Scroller.ScrollBarThickness = 6
Scroller.BackgroundTransparency = 1

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
Title.Text = "⚔️ 2P Battle Tycoon"
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
local listLayout = Instance.new("UIListLayout", Content)
listLayout.Padding = UDim.new(0,12)

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Content.Visible = not minimized
    MinBtn.Text = minimized and "+" or "-"
end)

-- draggable (same as before, but cleaned)
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

-- HUD Gui (mini status)
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
hudAdd("PredictiveAim")

local function updateHUD(name, state)
    if hudLabels[name] then
        hudLabels[name].Text = name .. ": " .. (state and "ON" or "OFF")
        hudLabels[name].TextColor3 = state and Color3.fromRGB(80,200,120) or Color3.fromRGB(200,200,200)
    end
end

-- LeftAlt toggles UI
keepPersistent(UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.LeftAlt then
        MainFrame.Visible = not MainFrame.Visible
        HUD.Visible = not MainFrame.Visible
    end
end))

-- Toggle buttons infra
local ToggleCallbacks = {}
local Buttons = {}
local function registerToggle(displayName, featureKey, onChange)
    local btn = Instance.new("TextButton", Content)
    btn.Size = UDim2.new(1,0,0,36)
    btn.BackgroundColor3 = Color3.fromRGB(36,36,36)
    btn.TextColor3 = Color3.fromRGB(235,235,235)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 15
    btn.Text = displayName .. " [OFF]"
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)
    btn.Parent = Content
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

-- WalkSpeed editor
do
    local frame = Instance.new("Frame", Content)
    frame.Size = UDim2.new(1,0,0,40)
    frame.BackgroundTransparency = 1
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0.55,-8,1,0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(230,230,230)
    label.Text = "WalkSpeed"
    local box = Instance.new("TextBox", frame)
    box.Size = UDim2.new(0.45,-12,0,28)
    box.Position = UDim2.new(0.55,0,0.5,-14)
    box.BackgroundColor3 = Color3.fromRGB(32,32,32)
    box.TextColor3 = Color3.fromRGB(240,240,240)
    box.Font = Enum.Font.Gotham
    box.TextSize = 13
    box.ClearTextOnFocus = false
    box.Text = tostring(FEATURE.WalkValue)
    box.PlaceholderText = "16–200 (rec 25-40)"
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,8)
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

-- ---------- ESP (improved duplicate-safety) ----------
local espObjects = setmetatable({}, { __mode = "k" })
local function rootPartOfCharacter(char)
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
end
local function getESPColor(p)
    if p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team then return Color3.fromRGB(0,200,0) else return Color3.fromRGB(200,40,40) end
end
local function clearESPForPlayer(p)
    if not p then return end
    local list = espObjects[p]
    if list then
        for _, v in pairs(list) do
            if v and v.Parent then pcall(function() v:Destroy() end) end
        end
        espObjects[p] = nil
    end
end
local function updateESPColorForPlayer(p)
    local list = espObjects[p]
    if list then
        for _, hl in ipairs(list) do
            if hl and hl.Parent then hl.FillColor = getESPColor(p) end
        end
    end
end

local lastRefresh = setmetatable({}, { __mode = "k" })
local MIN_REFRESH_INTERVAL = 0.12
local function shouldRefreshForPlayer(p)
    local t = tick()
    local last = lastRefresh[p] or 0
    if t - last < MIN_REFRESH_INTERVAL then return false end
    lastRefresh[p] = t
    return true
end

local function createESPForPlayer(p)
    if not p then return end
    if not FEATURE.ESP then return end
    if not shouldRefreshForPlayer(p) then return end
    if espObjects[p] then updateESPColorForPlayer(p) return end
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
    if p.Character then addPerPlayerConnection(p, p.CharacterRemoving:Connect(function() clearESPForPlayer(p) end)) end
    addPerPlayerConnection(p, p:GetPropertyChangedSignal("Team"):Connect(function() updateESPColorForPlayer(p) end))
end

local playersAddedConn = nil
local playersRemovingConn = nil
local function enableESP()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then ensurePlayerListeners(p) refreshESPForPlayer(p) end
    end
    if not playersAddedConn then
        playersAddedConn = keepPersistent(Players.PlayerAdded:Connect(function(p)
            if p ~= LocalPlayer then ensurePlayerListeners(p) task.wait(0.12) refreshESPForPlayer(p) end
        end))
    end
    if not playersRemovingConn then
        playersRemovingConn = keepPersistent(Players.PlayerRemoving:Connect(function(p)
            clearESPForPlayer(p)
            clearConnectionsForPlayer(p)
        end))
    end
end

local function disableESP()
    for p,_ in pairs(espObjects) do clearESPForPlayer(p) end
end

-- ---------- Auto E ----------
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

-- ---------- WalkSpeed ----------
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
            if char then setPlayerWalkSpeedForCharacter(char, FEATURE.WalkValue) end
        end)
    end))
end

local function restoreWalkSpeedForCharacter(char)
    if not char then return end
    pcall(function()
        local hum = char:FindFirstChildOfClass("Humanoid")
        local orig = OriginalWalkByCharacter[char]
        if hum and orig then hum.WalkSpeed = orig end
    end)
    OriginalWalkByCharacter[char] = nil
end

local function restoreAllWalkSpeeds()
    for char, _ in pairs(OriginalWalkByCharacter) do restoreWalkSpeedForCharacter(char) end
    OriginalWalkByCharacter = {}
    updateHUD("WalkSpeed", false)
end

-- ---------- Aimbot with Prediction ----------
local angleBetweenVectors = function(a, b)
    local dot = a:Dot(b)
    local m = math.max(a.Magnitude * b.Magnitude, 1e-6)
    local val = clamp(dot / m, -1, 1)
    return math.deg(math.acos(val))
end

-- store last positions/last update times for velocity estimation
local playerMotion = setmetatable({}, { __mode = "k" })
local function updatePlayerMotion(p, root)
    if not p or not root then return end
    local now = tick()
    local rec = playerMotion[p]
    if not rec then
        playerMotion[p] = { pos = root.Position, t = now, vel = Vector3.new(0,0,0) }
        return
    end
    local dt = now - (rec.t or now)
    if dt > 0 then
        local newVel = (root.Position - rec.pos) / dt
        -- simple smoothing to reduce jitter
        rec.vel = rec.vel:Lerp(newVel, math.clamp(dt * 10, 0, 1))
        rec.pos = root.Position
        rec.t = now
    else
        rec.pos = root.Position
        rec.t = now
    end
end

local function getPredictedPosition(part)
    -- returns predicted position for a part using stored playerMotion and FEATURE.ProjectileSpeed
    if not part then return nil end
    local owner = nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and (p.Character:FindFirstChild("Head") == part or p.Character:FindFirstChild("HumanoidRootPart") == part) then
            owner = p
            break
        end
    end
    local basePos = part.Position
    if not FEATURE.PredictiveAim or not owner then return basePos end
    local rec = playerMotion[owner]
    local vel = rec and rec.vel or Vector3.new(0,0,0)
    local distance = (basePos - (Camera and Camera.CFrame.Position or Vector3.new())).Magnitude
    local projectileSpeed = math.max(1, FEATURE.ProjectileSpeed or 300)
    local t = distance / projectileSpeed
    t = clamp(t, 0, FEATURE.PredictionLimit or 1.5)
    -- simple gravity compensation is ignored (game-dependent)
    return basePos + vel * t
end

keepPersistent(RunService.RenderStepped:Connect(function()
    -- update player motions (for all players with rootparts)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local root = rootPartOfCharacter(p.Character)
            if root then updatePlayerMotion(p, root) end
        end
    end
end))

keepPersistent(RunService.RenderStepped:Connect(function()
    if not FEATURE.Aimbot then return end
    if FEATURE.AIM_HOLD and not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
    if UIS:GetFocusedTextBox() then return end
    safeWaitCamera()
    if not Camera or not Camera.CFrame then return end
    local bestHead = nil
    local bestAngle = 1e9
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local okTarget = false
            if p.Team and LocalPlayer.Team then okTarget = (p.Team ~= LocalPlayer.Team) else okTarget = true end
            if okTarget and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if not hum or hum.Health <= 0 then
                    -- skip dead
                else
                    local head = p.Character:FindFirstChild("Head") or p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("HumanoidRootPart")
                    if head then
                        local aimPos = getPredictedPosition(head)
                        if aimPos then
                            local dir = aimPos - Camera.CFrame.Position
                            if dir.Magnitude > 0.001 then
                                local ang = angleBetweenVectors(Camera.CFrame.LookVector, dir.Unit)
                                if ang < bestAngle and ang <= FEATURE.AIM_FOV_DEG then
                                    bestHead = aimPos
                                    bestAngle = ang
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if bestHead then
        local success, err = pcall(function()
            local dir = (bestHead - Camera.CFrame.Position)
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

-- ---------- Teleport UI & Logic ----------
-- Utility to resolve all teams (keys present in TELEPORT_COORDS except "Flag")
local teamKeys = {}
for k,_ in pairs(TELEPORT_COORDS) do
    if k ~= "Flag" then table.insert(teamKeys, k) end
end
table.sort(teamKeys)

-- container for teleport buttons
local teleportContainer = Instance.new("Frame", Content)
teleportContainer.Size = UDim2.new(1,0,0,220)
teleportContainer.BackgroundTransparency = 1
local teleportLayout = Instance.new("UIListLayout", teleportContainer)
teleportLayout.Padding = UDim.new(0,6)

-- team selector (TextLabel + Dropdown-like simple list)
local currentTeleportTeam = teamKeys[1] or "Black"
local teamLabel = Instance.new("TextLabel", teleportContainer)
teamLabel.Size = UDim2.new(1,0,0,20)
teamLabel.BackgroundTransparency = 1
teamLabel.Font = Enum.Font.Gotham
teamLabel.TextSize = 13
teamLabel.TextColor3 = Color3.fromRGB(220,220,220)
teamLabel.Text = "Team: " .. tostring(currentTeleportTeam)
teamLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Fungsi teleport
local function teleportPlayer(targetCFrame)
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(targetCFrame)
    end
end

-- Tambah tombol teleport
local function addTeleportButton(team, place, position)
    local Button = Instance.new("TextButton", Scroller)
    Button.Size = UDim2.new(1, -10, 0, 35)
    Button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    Button.TextColor3 = Color3.fromRGB(255, 255, 255) -- teks jadi putih
    Button.Text = team .. " — " .. place
    Button.Font = Enum.Font.SourceSansBold
    Button.TextSize = 18
    Button.BorderSizePixel = 0
    Button.MouseButton1Click:Connect(function()
        -- Spawn hanya bisa tim sendiri
        if place == "Spawn" then
            if string.lower(team) == string.lower(LocalPlayer.Team.Name) then
                teleportPlayer(position)
            else
                warn("Tidak bisa teleport ke Spawn tim lain!")
            end
        else
            teleportPlayer(position)
        end
    end)
end

-- Generate semua tombol teleport
for team, places in pairs(Locations) do
    for place, pos in pairs(places) do
        addTeleportButton(team, place, pos)
    end
end


    local data = TELEPORT_COORDS[teamKey] or {}
    for place, vec in pairs(data) do
        local placeName = place
        -- Spawn rule: only allow Spawn teleport if team matches player's team name
        local isSpawn = (placeName == "Spawn")
        local btn = makeTeleportBtn(teamKey .. " — " .. placeName, function()
            -- Validate character & hrp
            local char = LocalPlayer.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
            if not hrp then return end

            if isSpawn then
                -- check player's team
                local myTeamName = (LocalPlayer.Team and LocalPlayer.Team.Name) or ""
                if tostring(myTeamName) ~= tostring(teamKey) then
                    -- deny
                    warn("Teleport to spawn denied: spawn teleport only to your own team.")
                    return
                end
            end

            -- safe teleport: set CFrame (with small upward offset to avoid getting stuck)
            local targetPos = vec
            local targetCFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
            pcall(function()
                -- try set PrimaryPart CFrame first
                if char.PrimaryPart then
                    char:SetPrimaryPartCFrame(targetCFrame)
                else
                    local root = hrp
                    root.CFrame = targetCFrame
                end
            end)
        end)
        -- optionally disable spawn buttons visually if not allowed
        if isSpawn and (LocalPlayer.Team and LocalPlayer.Team.Name ~= teamKey) then
            btn.BackgroundColor3 = Color3.fromRGB(80,80,80)
        end
    end
end

-- initial populate
populateTeleportButtonsForTeam(currentTeleportTeam)

-- team switching buttons (compact)
do
    local switchFrame = Instance.new("Frame", teleportContainer)
    switchFrame.Size = UDim2.new(1,0,0,30)
    switchFrame.BackgroundTransparency = 1
    local inner = Instance.new("Frame", switchFrame)
    inner.Size = UDim2.new(1,0,1,0)
    inner.BackgroundTransparency = 1
    local x = 0
    for _, tk in ipairs(teamKeys) do
        local tbtn = Instance.new("TextButton", inner)
        tbtn.Size = UDim2.new(1/#teamKeys, -4, 1, 0)
        tbtn.Position = UDim2.new(x/#teamKeys, 0, 0, 0)
        x = x + 1
        tbtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
        tbtn.Font = Enum.Font.Gotham
        tbtn.TextSize = 12
        tbtn.TextColor3 = Color3.fromRGB(230,230,230)
        tbtn.Text = tk
        Instance.new("UICorner", tbtn).CornerRadius = UDim.new(0,6)
        tbtn.MouseButton1Click:Connect(function()
            currentTeleportTeam = tk
            teamLabel.Text = "Team: " .. tostring(currentTeleportTeam)
            populateTeleportButtonsForTeam(currentTeleportTeam)
        end)
    end
end

-- Flag / neutral area button(s)
do
    local flagData = TELEPORT_COORDS["Flag"] or {}
    for name, vec in pairs(flagData) do
        makeTeleportBtn("Flag — " .. tostring(name), function()
            local char = LocalPlayer.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
            if not hrp then return end
            local targetCFrame = CFrame.new(vec + Vector3.new(0,3,0))
            pcall(function()
                if char.PrimaryPart then char:SetPrimaryPartCFrame(targetCFrame) else hrp.CFrame = targetCFrame end
            end)
        end)
    end
end

-- ---------- Register toggles ----------
registerToggle("ESP", "ESP", function(state)
    if state then enableESP() else disableESP() end
    updateHUD("ESP", state)
end)
registerToggle("Auto Press E", "AutoE", function(state)
    if state then startAutoE() else stopAutoE() end
end)
registerToggle("WalkSpeed", "WalkEnabled", function(state)
    if state then
        pcall(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum and LocalPlayer.Character and OriginalWalkByCharacter[LocalPlayer.Character] == nil then
                OriginalWalkByCharacter[LocalPlayer.Character] = hum.WalkSpeed
            end
            if hum then hum.WalkSpeed = FEATURE.WalkValue end
        end)
        updateHUD("WalkSpeed", true)
    else
        restoreWalkSpeedForCharacter(LocalPlayer.Character)
    end
end)
registerToggle("Aimbot", "Aimbot", function(state) updateHUD("Aimbot", state) end)

-- predictive aim toggle & sliders UI
do
    local frame = Instance.new("Frame", Content)
    frame.Size = UDim2.new(1,0,0,84)
    frame.BackgroundTransparency = 1
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1,0,0,18)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(220,220,220)
    label.Text = "Aimbot Prediction Settings"

    local cb = Instance.new("TextButton", frame)
    cb.Size = UDim2.new(0.45,0,0,28)
    cb.Position = UDim2.new(0,0,0,22)
    cb.BackgroundColor3 = Color3.fromRGB(36,36,36)
    cb.Text = "Predictive: " .. (FEATURE.PredictiveAim and "ON" or "OFF")
    cb.Font = Enum.Font.Gotham
    cb.TextSize = 13
    Instance.new("UICorner", cb).CornerRadius = UDim.new(0,8)
    cb.MouseButton1Click:Connect(function()
        FEATURE.PredictiveAim = not FEATURE.PredictiveAim
        cb.Text = "Predictive: " .. (FEATURE.PredictiveAim and "ON" or "OFF")
        updateHUD("PredictiveAim", FEATURE.PredictiveAim)
    end)

    local speedBox = Instance.new("TextBox", frame)
    speedBox.Size = UDim2.new(0.45,0,0,28)
    speedBox.Position = UDim2.new(0.55,0,0,22)
    speedBox.BackgroundColor3 = Color3.fromRGB(255,255,255)
    speedBox.TextColor3 = Color3.fromRGB(240,240,240)
    speedBox.Font = Enum.Font.Gotham
    speedBox.TextSize = 13
    speedBox.ClearTextOnFocus = false
    speedBox.Text = tostring(FEATURE.ProjectileSpeed)
    Instance.new("UICorner", speedBox).CornerRadius = UDim.new(0,8)
    speedBox.FocusLost:Connect(function(enter)
        if enter then
            local n = tonumber(speedBox.Text)
            if n and n >= 10 and n <= 5000 then FEATURE.ProjectileSpeed = n else speedBox.Text = tostring(FEATURE.ProjectileSpeed) end
        end
    end)

    local limitBox = Instance.new("TextBox", frame)
    limitBox.Size = UDim2.new(1,0,0,28)
    limitBox.Position = UDim2.new(0,0,0,52)
    limitBox.BackgroundColor3 = Color3.fromRGB(255,255,255)
    limitBox.TextColor3 = Color3.fromRGB(240,240,240)
    limitBox.Font = Enum.Font.Gotham
    limitBox.TextSize = 13
    limitBox.ClearTextOnFocus = false
    limitBox.Text = tostring(FEATURE.PredictionLimit)
    Instance.new("UICorner", limitBox).CornerRadius = UDim.new(0,8)
    limitBox.PlaceholderText = "Max prediction seconds (0.1 - 5)"
    limitBox.FocusLost:Connect(function(enter)
        if enter then
            local n = tonumber(limitBox.Text)
            if n and n >= 0.1 and n <= 5 then FEATURE.PredictionLimit = n else limitBox.Text = tostring(FEATURE.PredictionLimit) end
        end
    end)
end

-- initial HUD state
for k,_ in pairs(FEATURE) do
    local display = nil
    if k == "ESP" then display = "ESP" end
    if k == "AutoE" then display = "Auto Press E" end
    if k == "WalkEnabled" then display = "WalkSpeed" end
    if k == "Aimbot" then display = "Aimbot" end
    if k == "PredictiveAim" then display = "PredictiveAim" end
    if display then updateHUD(display, FEATURE[k]) end
end

-- hotkeys
keepPersistent(UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if UIS:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.F1 and ToggleCallbacks.ESP then ToggleCallbacks.ESP(not FEATURE.ESP)
    elseif input.KeyCode == Enum.KeyCode.F2 and ToggleCallbacks.AutoE then ToggleCallbacks.AutoE(not FEATURE.AutoE)
    elseif input.KeyCode == Enum.KeyCode.F3 and ToggleCallbacks.WalkEnabled then ToggleCallbacks.WalkEnabled(not FEATURE.WalkEnabled)
    elseif input.KeyCode == Enum.KeyCode.F4 and ToggleCallbacks.Aimbot then ToggleCallbacks.Aimbot(not FEATURE.Aimbot) end
end))

-- Character events
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
        for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then refreshESPForPlayer(p) end end
    end
end))

-- ---------- Global cleanup ----------
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
        clearAllConnections()
        playerMotion = {}
        espObjects = {}
    end
end

print("✅ TPB Refactor patched loaded. Toggles: F1=ESP, F2=AutoE, F3=Walk, F4=Aimbot. LeftAlt toggles UI/HUD. Teleport panel added.")
