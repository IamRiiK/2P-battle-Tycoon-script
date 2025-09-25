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
    PredictiveAim = false,
    ProjectileSpeed = 100,
    PredictionLimit = 0.5,
    AutoTP = false
    AutoTPShot = false,

}

local SelectedTarget = nil

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

local function setupAutoTP(tool)
    tool.Activated:Connect(function()
        if FEATURE.AutoTPShot and SelectedTarget and SelectedTarget.Character and SelectedTarget.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local targetHRP = SelectedTarget.Character.HumanoidRootPart
            if hrp and targetHRP then
                -- Offset di belakang target
                hrp.CFrame = targetHRP.CFrame * CFrame.new(0,0,-2)
            end
        end
    end)
end


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
hudAdd("Auto TP")
hudAdd("Auto TP Shot")

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

local function getValidPlayers()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if not LocalPlayer.Team or not p.Team or (p.Team ~= LocalPlayer.Team) then
                table.insert(list, p)
            end
        end
    end
    return list
end


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
            if SelectedTarget and p ~= SelectedTarget then
                continue
            end

                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if not hum or hum.Health <= 0 then
                    
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

local teleportContainer = Instance.new("ScrollingFrame", Content)
teleportContainer.Size = UDim2.new(1,0,0,160)
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

local autoTPThread = nil
local autoTPStop = false
local OFFSET = -3

local function startAutoTP()
    if autoTPThread then return end
    autoTPStop = false
    autoTPThread = task.spawn(function()
        while FEATURE.AutoTP and not autoTPStop do
            pcall(function()
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    -- cari musuh terdekat
                    local target = nil
                    local nearestDist = math.huge
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer and p.Character then
                            local hum = p.Character:FindFirstChildOfClass("Humanoid")
                            local enemyRoot = p.Character:FindFirstChild("HumanoidRootPart")
                            if hum and hum.Health > 0 and enemyRoot then
                                local dist = (enemyRoot.Position - root.Position).Magnitude
                                if dist < nearestDist then
                                    nearestDist = dist
                                    target = enemyRoot
                                end
                            end
                        end
                    end

                    -- teleport sebentar ke musuh, lalu balik
                    if target then
                        local oldPos = root.CFrame
                        root.CFrame = target.CFrame * CFrame.new(0, 0, OFFSET)
                        task.wait(0.1) -- delay sangat singkat untuk hit
                        root.CFrame = oldPos
                    end
                end
            end)
            task.wait(0.25) -- jeda antar TP
        end
        autoTPThread = nil
    end)
end

local function stopAutoTP()
    FEATURE.AutoTP = false
    autoTPStop = true
end


updateTeleportTeamLabel()

createSeparator(Content, "Aimbot Settings")

local aimFrame = Instance.new("Frame", Content)
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

registerToggle("Aimbot", "Aimbot", function(state) updateHUD("Aimbot", state) end)

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

registerToggle("AutoTP Shot", "AutoTP" function(state)
    if state then
        startAutoTP()
    else
        stopAutoTP()
    end
end)

local playerDropdown = Instance.new("TextButton", Content)
playerDropdown.Size = UDim2.new(1,0,0,32)
playerDropdown.BackgroundColor3 = Color3.fromRGB(36,36,36)
playerDropdown.TextColor3 = Color3.fromRGB(235,235,235)
playerDropdown.Font = Enum.Font.Gotham
playerDropdown.TextSize = 14
playerDropdown.Text = "🎯 Pilih Target: NONE"
Instance.new("UICorner", playerDropdown).CornerRadius = UDim.new(0,6)

playerDropdown.MouseButton1Click:Connect(function()
    local valid = getValidPlayers()
    if #valid == 0 then
        playerDropdown.Text = "🎯 Tidak ada target"
        SelectedTarget = nil
        return
    end
    
    local idx = table.find(valid, SelectedTarget) or 0
    idx = idx + 1
    if idx > #valid then idx = 1 end
    SelectedTarget = valid[idx]
    playerDropdown.Text = "🎯 Target: " .. SelectedTarget.Name
end)


for k,_ in pairs(FEATURE) do
    local display = nil
    if k == "ESP" then display = "ESP" end
    if k == "AutoE" then display = "Auto Press E" end
    if k == "WalkEnabled" then display = "WalkSpeed" end
    if k == "Aimbot" then display = "Aimbot" end
    if k == "PredictiveAim" then display = "PredictiveAim" end
    if display then updateHUD(display, FEATURE[k]) end
end

keepPersistent(UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if UIS:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.F1 and ToggleCallbacks.ESP then ToggleCallbacks.ESP(not FEATURE.ESP)
    elseif input.KeyCode == Enum.KeyCode.F2 and ToggleCallbacks.AutoE then ToggleCallbacks.AutoE(not FEATURE.AutoE)
    elseif input.KeyCode == Enum.KeyCode.F3 and ToggleCallbacks.WalkEnabled then ToggleCallbacks.WalkEnabled(not FEATURE.WalkEnabled)
    elseif input.KeyCode == Enum.KeyCode.F4 and ToggleCallbacks.Aimbot then ToggleCallbacks.Aimbot(not FEATURE.Aimbot) 
    elseif input.KeyCode == Enum.KeyCode.T and ToggleCallbacks.AutoTP then ToggleCallbacks.AutoTP(not FEATURE.AutoTP)end
end))

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

print("Script Loaded")
