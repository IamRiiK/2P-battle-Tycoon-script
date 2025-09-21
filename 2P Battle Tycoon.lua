
-- skrip1_final.lua
-- Final patched skrip1:
-- 1) Passes Editor & Value Editor removed
-- 2) Teleport (all team locations visible; Spawn only teleports to your team)
-- 3) Hitbox Expander (entire body, fixed size 5 studs) + hotkey F6
-- 4) Aimbot upgraded with linear velocity prediction
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

-- Feature configuration
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
    AIM_PREDICT = true,
    PREDICTION_MULTIPLIER = 1.0,
    Hitbox = false,
    Hitbox_Size = 5, -- fixed 5 studs
    Teleport = true,
}

local WALK_UPDATE_INTERVAL = 0.12

-- teleport coordinates (from you)
local TEAM_LOCATIONS = {
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

-- internals
local PersistentConnections = {}
local PerPlayerConnections = {}
local espObjects = setmetatable({}, { __mode = "k" })
local hitboxParts = {} -- [player] = {partname = part}
local lastPositions = {} -- [player] = {pos=Vector3, vel=Vector3, t=time}
local lastRefresh = setmetatable({}, { __mode = "k" })
local MIN_REFRESH_INTERVAL = 0.12
local OriginalWalkByCharacter = {}

-- helpers
local function keepPersistent(conn)
    if conn and conn.Disconnect then table.insert(PersistentConnections, conn) end
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
        for _,c in ipairs(t) do pcall(function() c:Disconnect() end) end
        PerPlayerConnections[p] = nil
    end
end

local function clearAllPerPlayerConnections()
    for p,_ in pairs(PerPlayerConnections) do clearConnectionsForPlayer(p) end
end

local function clearAllConnections()
    clearAllPerPlayerConnections()
    for _,c in ipairs(PersistentConnections) do pcall(function() c:Disconnect() end) end
    PersistentConnections = {}
end

local function safeParentGui(gui)
    gui.ResetOnSpawn = false
    if PlayerGui and PlayerGui.Parent then gui.Parent = PlayerGui else pcall(function() gui.Parent = PlayerGui end) end
end

local function safeWaitCamera()
    if not (Workspace.CurrentCamera or Camera) then
        local ok, cam = pcall(function() return Workspace:WaitForChild("CurrentCamera", 5) end)
        if ok and cam then Camera = cam end
    else
        Camera = Workspace.CurrentCamera or Camera
    end
end

local function clamp(v,a,b) if v < a then return a end if v > b then return b end return v end

local function rootPartOfCharacter(char)
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
end

local function getESPColor(p)
    if p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team then return Color3.fromRGB(0,200,0) else return Color3.fromRGB(200,40,40) end
end

local function shouldRefreshForPlayer(p)
    local t = tick()
    local last = lastRefresh[p] or 0
    if t - last < MIN_REFRESH_INTERVAL then return false end
    lastRefresh[p] = t
    return true
end

-- cleanup previous
pcall(function()
    if _G and _G.__TPB_CLEANUP then pcall(_G.__TPB_CLEANUP) end
    local old = PlayerGui:FindFirstChild("skrip1_final")
    if old then old:Destroy() end
    local old2 = PlayerGui:FindFirstChild("TPB_TycoonHUD_Final")
    if old2 then old2:Destroy() end
end)

-- UI
local MainScreenGui = Instance.new("ScreenGui")
MainScreenGui.Name = "skrip1_final"
MainScreenGui.DisplayOrder = 9999
safeParentGui(MainScreenGui)

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0,380,0,560)
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
Title.Text = "⚔️ 2P Battle Tycoon (skrip1)"
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
Instance.new("UIListLayout", Content).Padding = UDim.new(0,12)

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
                        if dragChangedConn then pcall(function() dragChangedConn:Disconnect() end) dragChangedConn = nil end
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
            if dragChangedConn then pcall(function() dragChangedConn:Disconnect() end) dragChangedConn = nil end
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

-- HUD
local HUDGui = Instance.new("ScreenGui")
HUDGui.Name = "TPB_TycoonHUD_Final"
HUDGui.DisplayOrder = 10000
safeParentGui(HUDGui)

local HUD = Instance.new("Frame", HUDGui)
HUD.Size = UDim2.new(0,220,0,150)
HUD.Position = UDim2.new(1,-230,1,-180)
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
hudAdd("Teleport")

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

-- Toggles
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

-- WalkSpeed UI
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
    box.Parent = frame

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

-- ESP functions
local function clearESPForPlayer(p)
    if not p then return end
    local list = espObjects[p]
    if list then
        for _,v in pairs(list) do
            if v and v.Parent then pcall(function() v:Destroy() end) end
        end
        espObjects[p] = nil
    end
end

local function updateESPColorForPlayer(p)
    local list = espObjects[p]
    if list then
        for _,hl in ipairs(list) do
            if hl and hl.Parent then hl.FillColor = getESPColor(p) end
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

local playersAddedConn = nil
local playersRemovingConn = nil

local function enableESP()
    for _,p in ipairs(Players:GetPlayers()) do
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

-- AutoE
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

-- WalkSpeed management
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
    for char,_ in pairs(OriginalWalkByCharacter) do restoreWalkSpeedForCharacter(char) end
    OriginalWalkByCharacter = {}
    updateHUD("WalkSpeed", false)
end

-- Hitbox expander (entire body)
local function createHitboxesForPlayer(p)
    if not p or not p.Character then return end
    -- clear any existing
    if hitboxParts[p] then
        for _,part in pairs(hitboxParts[p]) do
            if part and part.Parent then pcall(function() part:Destroy() end) end
        end
    end
    hitboxParts[p] = {}
    -- iterate character descendants and create invisible welded parts for each BasePart
    for _,desc in ipairs(p.Character:GetDescendants()) do
        if desc:IsA("BasePart") then
            -- skip accessories' handle duplicates sometimes; but still create to expand
            local hb = Instance.new("Part")
            hb.Name = "TPB_Hitbox_" .. desc.Name
            hb.Size = Vector3.new(FEATURE.Hitbox_Size, FEATURE.Hitbox_Size, FEATURE.Hitbox_Size)
            hb.Transparency = 1
            hb.CanCollide = false
            hb.Anchored = false
            hb.Massless = true
            hb.Parent = workspace
            -- weld using WeldConstraint or Weld
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = hb
            weld.Part1 = desc
            weld.Parent = hb
            hitboxParts[p][desc.Name] = hb
        end
    end
end

local function clearHitboxesForPlayer(p)
    if not p then return end
    if hitboxParts[p] then
        for _,part in pairs(hitboxParts[p]) do if part and part.Parent then pcall(function() part:Destroy() end) end end
        hitboxParts[p] = nil
    end
end

local function enableHitboxes()
    for _,p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then createHitboxesForPlayer(p) end end
    keepPersistent(Players.PlayerAdded:Connect(function(p) if p ~= LocalPlayer and FEATURE.Hitbox then task.wait(0.12) createHitboxesForPlayer(p) end end))
    keepPersistent(Players.PlayerRemoving:Connect(function(p) clearHitboxesForPlayer(p) end))
    -- keep sizes updated
    keepPersistent(RunService.Heartbeat:Connect(function()
        if not FEATURE.Hitbox then return end
        for p,parts in pairs(hitboxParts) do
            for name,part in pairs(parts) do
                if part and part.Parent then
                    part.Size = Vector3.new(FEATURE.Hitbox_Size, FEATURE.Hitbox_Size, FEATURE.Hitbox_Size)
                end
            end
        end
    end))
end

local function disableHitboxes()
    for p,_ in pairs(hitboxParts) do clearHitboxesForPlayer(p) end
end

-- Teleport UI
local TeleportFrame = Instance.new("Frame", Content)
TeleportFrame.Size = UDim2.new(1,0,0,220)
TeleportFrame.BackgroundTransparency = 1

local TP_Label = Instance.new("TextLabel", TeleportFrame)
TP_Label.Size = UDim2.new(1,0,0,20)
TP_Label.BackgroundTransparency = 1
TP_Label.Font = Enum.Font.GothamBold
TP_Label.TextSize = 13
TP_Label.TextColor3 = Color3.fromRGB(240,240,240)
TP_Label.Text = "📍 Teleport (All teams available)"

local Scroll = Instance.new("ScrollingFrame", TeleportFrame)
Scroll.Size = UDim2.new(1,0,0,200)
Scroll.Position = UDim2.new(0,0,0,22)
Scroll.CanvasSize = UDim2.new(0,0,0,0)
Scroll.ScrollBarThickness = 6
Scroll.BackgroundTransparency = 1
local sLayout = Instance.new("UIListLayout", Scroll)
sLayout.Padding = UDim.new(0,6)
sLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function makeTeleportButton(text, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0,160,0,28)
    b.Text = text
    b.Font = Enum.Font.Gotham
    b.TextSize = 13
    b.BackgroundColor3 = Color3.fromRGB(40,40,40)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    b.Parent = Scroll
    b.MouseButton1Click:Connect(callback)
    return b
end

local function buildTeleportButtons()
    for _,c in ipairs(Scroll:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
    local y = 0
    for teamName,locs in pairs(TEAM_LOCATIONS) do
        for locName,pos in pairs(locs) do
            local label = teamName .. " - " .. locName
            makeTeleportButton(label, function()
                pcall(function()
                    if not LocalPlayer.Character then return end
                    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end
                    -- Spawn button only teleports to your team spawn
                    if locName == "Spawn" then
                        if LocalPlayer.Team and LocalPlayer.Team.Name == teamName then
                            hrp.CFrame = CFrame.new(pos + Vector3.new(0,3,0))
                        else
                            -- do nothing (spawn of other team disabled)
                        end
                    else
                        -- other locations allowed for all teams
                        hrp.CFrame = CFrame.new(pos + Vector3.new(0,3,0))
                    end
                end)
            end)
            y = y + 34
        end
    end
    -- add Flag Neutral explicitly if not present
    if TEAM_LOCATIONS["Flag"] and TEAM_LOCATIONS["Flag"].Neutral then
        makeTeleportButton("Flag - Neutral", function()
            pcall(function()
                if not LocalPlayer.Character then return end
                local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = CFrame.new(TEAM_LOCATIONS["Flag"].Neutral + Vector3.new(0,3,0)) end
            end)
        end)
        y = y + 34
    end
    Scroll.CanvasSize = UDim2.new(0,0,0,y)
end

buildTeleportButtons()

-- Aimbot prediction helper
local function angleBetweenVectors(a,b)
    local dot = a:Dot(b)
    local m = math.max(a.Magnitude * b.Magnitude, 1e-6)
    local val = clamp(dot / m, -1, 1)
    return math.deg(math.acos(val))
end

-- track positions & velocities
keepPersistent(RunService.RenderStepped:Connect(function(dt)
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local now = tick()
            local prev = lastPositions[p]
            if prev then
                local dv = hrp.Position - prev.pos
                local dt_local = math.max(now - prev.t, 1e-6)
                prev.vel = dv / dt_local
                prev.pos = hrp.Position
                prev.t = now
            else
                lastPositions[p] = { pos = hrp.Position, vel = Vector3.new(0,0,0), t = now }
            end
        end
    end
end))

-- main aimbot renderstepped
keepPersistent(RunService.RenderStepped:Connect(function()
    if not FEATURE.Aimbot then return end
    if FEATURE.AIM_HOLD and not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
    if UIS:GetFocusedTextBox() then return end
    safeWaitCamera()
    if not Camera or not Camera.CFrame then return end

    local bestPart = nil
    local bestAngle = 1e9

    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local okTarget = true
            if p.Team and LocalPlayer.Team then okTarget = (p.Team ~= LocalPlayer.Team) end
            if okTarget and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local targetPart = p.Character:FindFirstChild("Head") or p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("HumanoidRootPart")
                    if targetPart then
                        local dir = targetPart.Position - Camera.CFrame.Position
                        if dir.Magnitude > 0.001 then
                            local ang = angleBetweenVectors(Camera.CFrame.LookVector, dir.Unit)
                            if ang < bestAngle and ang <= FEATURE.AIM_FOV_DEG then
                                bestPart = targetPart
                                bestAngle = ang
                            end
                        end
                    end
                end
            end
        end
    end

    if bestPart and bestPart.Parent then
        local success, err = pcall(function()
            local targetPos = bestPart.Position
            if FEATURE.AIM_PREDICT then
                -- find owner player
                local owner = nil
                for _,p in ipairs(Players:GetPlayers()) do
                    if p.Character == bestPart.Parent then owner = p; break end
                end
                if owner and lastPositions[owner] then
                    local lp = lastPositions[owner]
                    local vel = lp.vel or Vector3.new(0,0,0)
                    local toTarget = targetPos - Camera.CFrame.Position
                    local dist = toTarget.Magnitude
                    local leadTime = clamp((dist / 200), 0, 1.5) * (FEATURE.PREDICTION_MULTIPLIER or 1)
                    targetPos = targetPos + vel * leadTime
                end
            end
            local dir = (targetPos - Camera.CFrame.Position)
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

-- Register toggles
registerToggle("ESP", "ESP", function(state) if state then enableESP() else disableESP() end updateHUD("ESP", state) end)
registerToggle("Auto Press E", "AutoE", function(state) if state then startAutoE() else stopAutoE() end end)
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
registerToggle("Aimbot", "Aimbot", function(state) updateHUD("Aimbot", state) end)
registerToggle("Hitbox", "Hitbox", function(state) if state then enableHitboxes() else disableHitboxes() end updateHUD("Hitbox", state) end)
registerToggle("Teleport", "Teleport", function(state) updateHUD("Teleport", state) end)

-- initial HUD states
for k,_ in pairs(FEATURE) do
    local display = nil
    if k == "ESP" then display = "ESP" end
    if k == "AutoE" then display = "Auto Press E" end
    if k == "WalkEnabled" then display = "WalkSpeed" end
    if k == "Aimbot" then display = "Aimbot" end
    if k == "Hitbox" then display = "Hitbox" end
    if k == "Teleport" then display = "Teleport" end
    if display then updateHUD(display, FEATURE[k]) end
end

-- Keybinds (F1-F6; F6 = Hitbox)
keepPersistent(UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if UIS:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.F1 and ToggleCallbacks.ESP then ToggleCallbacks.ESP(not FEATURE.ESP)
    elseif input.KeyCode == Enum.KeyCode.F2 and ToggleCallbacks.AutoE then ToggleCallbacks.AutoE(not FEATURE.AutoE)
    elseif input.KeyCode == Enum.KeyCode.F3 and ToggleCallbacks.WalkEnabled then ToggleCallbacks.WalkEnabled(not FEATURE.WalkEnabled)
    elseif input.KeyCode == Enum.KeyCode.F4 and ToggleCallbacks.Aimbot then ToggleCallbacks.Aimbot(not FEATURE.Aimbot)
    elseif input.KeyCode == Enum.KeyCode.F6 and ToggleCallbacks.Hitbox then ToggleCallbacks.Hitbox(not FEATURE.Hitbox)
    end
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
        for _,p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then refreshESPForPlayer(p) end end
    end
    if FEATURE.Hitbox then
        task.wait(0.2)
        for _,p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then createHitboxesForPlayer(p) end end
    end
end))

-- Global cleanup
if _G then
    _G.__TPB_CLEANUP = function()
        for p,_ in pairs(espObjects) do clearESPForPlayer(p) end
        for p,_ in pairs(hitboxParts) do clearHitboxesForPlayer(p) end
        pcall(function()
            local g = PlayerGui:FindFirstChild("skrip1_final")
            if g then g:Destroy() end
            local gh = PlayerGui:FindFirstChild("TPB_TycoonHUD_Final")
            if gh then gh:Destroy() end
        end)
        restoreAllWalkSpeeds()
        stopAutoE()
        clearAllConnections()
    end
end

print("✅ skrip1_final.lua loaded. Teleport: all team locations shown (Spawn only teleports to your team). Hitbox size fixed at 5 stud. Hotkey F6 toggles Hitbox. Aimbot has prediction.")
