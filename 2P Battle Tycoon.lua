-- TPB Refactor + Teleport & Predictive Aimbot (compact UI, clean merge)
if not game:IsLoaded() then game.Loaded:Wait() end

-- Services
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

-- ---------- MAIN UI (compact + separators non-clickable) ----------
local MainScreenGui = Instance.new("ScreenGui")
MainScreenGui.Name = "TPB_TycoonGUI_Final"
MainScreenGui.DisplayOrder = 9999
safeParentGui(MainScreenGui)

local MainFrame = Instance.new("Frame", MainScreenGui)
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0,340,0,520) -- compact-ish
MainFrame.Position = UDim2.new(0.02,0,0.12,0)
MainFrame.BackgroundColor3 = Color3.fromRGB(28,28,30)
MainFrame.BorderSizePixel = 0
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0,10)

-- Title Bar
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
TitleLabel.Text = "⚔️ 2P Battle Tycoon (Compact)"
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

local Content = Instance.new("Frame", MainFrame)
Content.Name = "Content"
Content.Size = UDim2.new(1,-16,1,-56)
Content.Position = UDim2.new(0,8,0,44)
Content.BackgroundTransparency = 1

local listLayout = Instance.new("UIListLayout", Content)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0,8)

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Content.Visible = not minimized
    MinBtn.Text = minimized and "+" or "-"
end)

-- draggable (clean)
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

-- helper: create a compact separator (non-clickable)
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

-- Toggle buttons infra (compact look)
local ToggleCallbacks = {}
local Buttons = {}
local function registerToggle(displayName, featureKey, onChange)
    local btn = Instance.new("TextButton", Content)
    btn.Size = UDim2.new(1,0,0,32)
    btn.BackgroundColor3 = Color3.fromRGB(36,36,36)
    btn.TextColor3 = Color3.fromRGB(235,235,235)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.Text = displayName .. " [OFF]"
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
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

-- WalkSpeed editor (compact single-line)
do
    local frame = Instance.new("Frame", Content)
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

-- ---------- ESP (same as before) ----------
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
        rec.vel = rec.vel:Lerp(newVel, math.clamp(dt * 10, 0, 1))
        rec.pos = root.Position
        rec.t = now
    else
        rec.pos = root.Position
        rec.t = now
    end
end

local function getPredictedPosition(part)
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
    return basePos + vel * t
end

keepPersistent(RunService.RenderStepped:Connect(function()
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
                    -- skip
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

-- ---------- Teleport UI & Logic (compact, ScrollingFrame, non-clickable separators) ----------
-- TPB Refactor + Teleport & Predictive Aimbot (Compact UI Version)
if not game:IsLoaded() then game.Loaded:Wait() end

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local TeleportService = game:GetService("TeleportService")

-- Koordinat Teleport
local TELEPORT_COORDS = {
    ["Neutral"] = {
        Flag = Vector3.new(0, 5, 0),
    },
    ["Black"] = {
        Spawn = Vector3.new(153.2, 683.7, 814.4),
        Bunker = Vector3.new(63.9, 3.3, 143.9),
        PrivateIsland = Vector3.new(145.2, 87.5, 697.5),
        Submarine = Vector3.new(61.8, -101.0, 154.2)
    },
    ["Red"] = {
        Spawn = Vector3.new(-120.4, 683.7, -810.5),
        Bunker = Vector3.new(-60.1, 3.3, -142.6),
        PrivateIsland = Vector3.new(-140.7, 87.5, -690.3),
        Submarine = Vector3.new(-65.3, -101.0, -150.2)
    },
    ["Blue"] = {
        Spawn = Vector3.new(800.2, 683.7, -120.4),
        Bunker = Vector3.new(140.5, 3.3, -63.2),
        PrivateIsland = Vector3.new(690.7, 87.5, -145.9),
        Submarine = Vector3.new(150.8, -101.0, -61.9)
    },
    ["Green"] = {
        Spawn = Vector3.new(-810.3, 683.7, 120.9),
        Bunker = Vector3.new(-142.8, 3.3, 63.4),
        PrivateIsland = Vector3.new(-692.1, 87.5, 146.3),
        Submarine = Vector3.new(-151.2, -101.0, 62.5)
    }
}

-- UI Root
local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
ScreenGui.ResetOnSpawn = false

-- Main Frame
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 240, 0, 420)
MainFrame.Position = UDim2.new(0, 20, 0.5, -210)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 0
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

-- Title
local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 36)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Text = "Game Helper UI"

-- Content
local Content = Instance.new("Frame", MainFrame)
Content.Size = UDim2.new(1, -16, 1, -46)
Content.Position = UDim2.new(0, 8, 0, 40)
Content.BackgroundTransparency = 1

local layout = Instance.new("UIListLayout", Content)
layout.Padding = UDim.new(0, 6)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder

-- Utility function
local function makeSeparator(text)
    local sep = Instance.new("TextLabel")
    sep.Size = UDim2.new(1, 0, 0, 20)
    sep.BackgroundTransparency = 1
    sep.Text = "──────── " .. text .. " ────────"
    sep.Font = Enum.Font.GothamBold
    sep.TextSize = 12
    sep.TextColor3 = Color3.fromRGB(180,180,180)
    return sep
end

local function makeButton(text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.TextColor3 = Color3.fromRGB(235, 235, 235)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.Text = text
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function makeTextBox(labelText, placeholder)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 28)
    frame.BackgroundTransparency = 1

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0.4, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(235,235,235)
    label.Text = labelText
    label.TextXAlignment = Enum.TextXAlignment.Left

    local box = Instance.new("TextBox", frame)
    box.Size = UDim2.new(0.6, -6, 1, 0)
    box.Position = UDim2.new(0.4, 6, 0, 0)
    box.BackgroundColor3 = Color3.fromRGB(45,45,45)
    box.TextColor3 = Color3.fromRGB(230,230,230)
    box.Font = Enum.Font.Gotham
    box.PlaceholderText = placeholder
    box.TextSize = 13
    box.ClearTextOnFocus = false
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

    return frame, box
end

-- ========== WalkSpeed Input ==========
local wsFrame, wsBox = makeTextBox("WalkSpeed:", "Masukkan kecepatan...")
wsBox.Text = "30"
wsBox.FocusLost:Connect(function()
    local val = tonumber(wsBox.Text)
    if val and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = val
    end
end)
wsFrame.Parent = Content

-- ========== Teleport Section ==========
makeSeparator("Teleport").Parent = Content

-- Flag button (selalu di atas)
makeButton("Teleport: Flag", function()
    local pos = TELEPORT_COORDS["Neutral"].Flag
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(0,3,0))
    end
end).Parent = Content

-- Tim lain
for team, places in pairs(TELEPORT_COORDS) do
    if team ~= "Neutral" then
        local teamLabel = Instance.new("TextLabel", Content)
        teamLabel.Size = UDim2.new(1, 0, 0, 20)
        teamLabel.BackgroundTransparency = 1
        teamLabel.Text = "─── " .. team .. " Team ───"
        teamLabel.Font = Enum.Font.GothamBold
        teamLabel.TextSize = 12
        teamLabel.TextColor3 = Color3.fromRGB(200,200,200)

        for place, pos in pairs(places) do
            makeButton("Teleport: " .. place, function()
                if place == "Spawn" then
                    if LocalPlayer.Team and tostring(LocalPlayer.Team.Name) == team then
                        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(0,3,0))
                    else
                        warn("⚠️ Tidak bisa teleport ke spawn tim lain!")
                    end
                else
                    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(0,3,0))
                end
            end).Parent = Content
        end
    end
end

-- ========== Aimbot Section ==========
makeSeparator("Aimbot").Parent = Content

local predFrame, predBox = makeTextBox("Prediction:", "Masukkan nilai prediksi...")
predBox.Text = "300"
predFrame.Parent = Content

local smoothFrame, smoothBox = makeTextBox("Smoothness:", "Masukkan smoothness...")
smoothBox.Text = "1.5"
smoothFrame.Parent = Content

local aimbotBtn = makeButton("Aimbot: OFF", function(btn)
    if btn.Text == "Aimbot: OFF" then
        btn.Text = "Aimbot: ON"
    else
        btn.Text = "Aimbot: OFF"
    end
end)
aimbotBtn.Parent = Content

-- ========== Utility Section ==========
makeSeparator("Utility").Parent = Content

local espBtn = makeButton("ESP: OFF", function(btn)
    btn.Text = (btn.Text == "ESP: OFF") and "ESP: ON" or "ESP: OFF"
end)
espBtn.Parent = Content

local autoBtn = makeButton("Auto Press E: OFF", function(btn)
    btn.Text = (btn.Text == "Auto Press E: OFF") and "Auto Press E: ON" or "Auto Press E: OFF"
end)
autoBtn.Parent = Content

local wsBtn = makeButton("WalkSpeed: OFF", function(btn)
    btn.Text = (btn.Text == "WalkSpeed: OFF") and "WalkSpeed: ON" or "WalkSpeed: OFF"
end)
wsBtn.Parent = Content


-- initialize teleport UI
updateTeleportTeamLabel()

-- ---------- Aimbot compact settings (with separator non-clickable) ----------
createSeparator(Content, "Aimbot Settings")

local aimFrame = Instance.new("Frame", Content)
aimFrame.Size = UDim2.new(1,0,0,72)
aimFrame.BackgroundTransparency = 1
local aimLayout = Instance.new("UIListLayout", aimFrame)
aimLayout.SortOrder = Enum.SortOrder.LayoutOrder
aimLayout.Padding = UDim.new(0,6)

-- predictive toggle + inputs row
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

-- Aimbot toggle compact
registerToggle("Aimbot", "Aimbot", function(state) updateHUD("Aimbot", state) end)

-- ---------- Utility separator + toggles ----------
createSeparator(Content, "Utility")
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
            if hum and LocalPlayer.Character and OriginalWalkByCharacter[LocalPlayer.Character] == nil then OriginalWalkByCharacter[LocalPlayer.Character] = hum.WalkSpeed end
            if hum then hum.WalkSpeed = FEATURE.WalkValue end
        end)
        updateHUD("WalkSpeed", true)
    else
        restoreWalkSpeedForCharacter(LocalPlayer.Character)
    end
end)

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

print("✅ TPB Compact UI patched loaded. Toggles: F1=ESP, F2=AutoE, F3=Walk, F4=Aimbot. LeftAlt toggles UI/HUD. Teleport panel compact ready.")
