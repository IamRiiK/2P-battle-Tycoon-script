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

-- Feature config
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
}

local WALK_UPDATE_INTERVAL = 0.12
local TELEPORT_COORDS = {
    ["Black"] = {Spaceship = Vector3.new(153.2, 683.7, 814.4), Bunker = Vector3.new(63.9,3.3,143.9), PrivateIsland = Vector3.new(145.2,87.5,697.5), Submarine = Vector3.new(61.8,-101,154.9), Spawn = Vector3.new(64.1,72,131.3)},
    ["White"] = {Spaceship = Vector3.new(-252.3,683.7,810.7), Bunker = Vector3.new(-116.3,3.3,152.9), PrivateIsland = Vector3.new(-259.7,87.5,697.9), Submarine = Vector3.new(-116.6,-101,151.4), Spawn = Vector3.new(-115.7,72,131.2)},
    ["Purple"] = {Spaceship = Vector3.new(-922.3,683.7,95.3), Bunker = Vector3.new(-263.3,3.3,5.7), PrivateIsland = Vector3.new(-807.7,87.5,87.4), Submarine = Vector3.new(-265.1,-101,6.4), Spawn = Vector3.new(-240.9,72,6.2)},
    ["Orange"] = {Spaceship = Vector3.new(-922.2,683.7,-309.5), Bunker = Vector3.new(-261.3,3.3,-173.9), PrivateIsland = Vector3.new(-806.2,87.5,-318.0), Submarine = Vector3.new(-266.3,-101,-174.2), Spawn = Vector3.new(-240.9,72,-174.0)},
    ["Yellow"] = {Spaceship = Vector3.new(-204.4,683.7,-979.2), Bunker = Vector3.new(-115.9,3.3,-317.8), PrivateIsland = Vector3.new(-197.2,87.5,-868.6), Submarine = Vector3.new(-115.6,-101,-319.6), Spawn = Vector3.new(-115.8,72,-299.1)},
    ["Blue"] = {Spaceship = Vector3.new(200.2,683.7,-978.8), Bunker = Vector3.new(63.9,3.3,-316.2), PrivateIsland = Vector3.new(207.6,87.5,-865.2), Submarine = Vector3.new(63.9,-101,-319.2), Spawn = Vector3.new(63.9,72,-298.7)},
    ["Green"] = {Spaceship = Vector3.new(871.9,683.7,-263.0), Bunker = Vector3.new(202.8,3.3,-174.1), PrivateIsland = Vector3.new(755.9,87.5,-254.9), Submarine = Vector3.new(211.2,-101,-173.9), Spawn = Vector3.new(188.5,72,-173.9)},
    ["Red"] = {Spaceship = Vector3.new(871.2,683.7,141.6), Bunker = Vector3.new(204.1,3.3,5.9), PrivateIsland = Vector3.new(755.4,87.5,149.4), Submarine = Vector3.new(209.8,-101,6.4), Spawn = Vector3.new(188.8,72,6.1)},
    ["Flag"] = {Neutral = Vector3.new(-24.8,42.3,-83.2)}
}

-- Persistent connections
local PersistentConnections = {}
local PerPlayerConnections = {}
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
        for _, c in ipairs(t) do pcall(function() c:Disconnect() end) end
        PerPlayerConnections[p] = nil
    end
end
local function clearAllPerPlayerConnections()
    for p,_ in pairs(PerPlayerConnections) do clearConnectionsForPlayer(p) end
end
local function clearAllConnections()
    clearAllPerPlayerConnections()
    for _, c in ipairs(PersistentConnections) do pcall(function() c:Disconnect() end) end
    PersistentConnections = {}
end

-- Safe parent GUI
local function safeParentGui(gui)
    gui.ResetOnSpawn = false
    if PlayerGui and PlayerGui.Parent then
        gui.Parent = PlayerGui
    else pcall(function() gui.Parent = PlayerGui end) end
end

-- Clamp helper
local function clamp(v,a,b) if v<a then return a end if v>b then return b end return v end

-- Cleanup old UI
pcall(function()
    if _G and _G.__TPB_CLEANUP then pcall(_G.__TPB_CLEANUP) end
    local old = PlayerGui:FindFirstChild("TPB_TycoonGUI_Final")
    if old then old:Destroy() end
end)

-- ======================= GUI NEW FROM GITHUB =======================
local GUIURL = "https://raw.githubusercontent.com/IamRiiK/2P-battle-Tycoon-script/refs/heads/main/GUI%26UI"
local HttpService = game:GetService("HttpService")
local guiCode = game:HttpGet(GUIURL)
local chunk, err = loadstring(guiCode)
if not chunk then error("Failed to load GUI: "..tostring(err)) end
chunk() -- Load GUI

-- Assume GUI creates global `MainFrame` and `Content` containers
-- We now attach features into it

local listLayout = Content:FindFirstChildOfClass("UIListLayout")
if not listLayout then
    listLayout = Instance.new("UIListLayout", Content)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0,8)
end

-- HUD
local HUD = PlayerGui:FindFirstChild("TPB_TycoonHUD_Final")
if not HUD then
    HUD = Instance.new("Frame", PlayerGui)
    HUD.Name = "TPB_TycoonHUD_Final"
    HUD.Size = UDim2.new(0,220,0,120)
    HUD.Position = UDim2.new(1,-240,1,-150)
    HUD.BackgroundColor3 = Color3.fromRGB(20,20,20)
    HUD.BackgroundTransparency = 0.06
    HUD.BorderSizePixel = 0
    HUD.Visible = false
    Instance.new("UICorner", HUD).CornerRadius = UDim.new(0,8)
end
local HUDList = HUD:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout", HUD)
HUDList.Padding = UDim.new(0,4)
HUDList.SortOrder = Enum.SortOrder.LayoutOrder
local hudLabels = {}
local function hudAdd(name)
    if hudLabels[name] then return end
    local l = Instance.new("TextLabel", HUD)
    l.Size = UDim2.new(1,-12,0,18)
    l.Position = UDim2.new(0,8,0,0)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.Gotham
    l.TextSize = 13
    l.TextColor3 = Color3.fromRGB(220,220,220)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = name..": OFF"
    hudLabels[name] = l
end
for _, n in ipairs({"ESP","Auto Press E","WalkSpeed","Aimbot","PredictiveAim"}) do hudAdd(n) end
local function updateHUD(name, state)
    if hudLabels[name] then
        hudLabels[name].Text = name..": "..(state and "ON" or "OFF")
        hudLabels[name].TextColor3 = state and Color3.fromRGB(80,200,120) or Color3.fromRGB(200,200,200)
    end
end

-- ======================= Feature Setup =======================
-- Toggle helper
local ToggleCallbacks = {}
local Buttons = {}
local function registerToggle(displayName, featureKey, onChange)
    local btn = Instance.new("TextButton", Content)
    btn.Size = UDim2.new(1,0,0,32)
    btn.BackgroundColor3 = Color3.fromRGB(36,36,36)
    btn.TextColor3 = Color3.fromRGB(235,235,235)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.Text = displayName.." [OFF]"
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
    local function setState(state)
        local old = FEATURE[featureKey]
        FEATURE[featureKey] = state
        btn.Text = displayName.." ["..(state and "ON" or "OFF").."]"
        btn.BackgroundColor3 = state and Color3.fromRGB(80,150,220) or Color3.fromRGB(36,36,36)
        updateHUD(displayName,state)
        if type(onChange)=="function" then pcall(onChange,state) end
    end
    btn.MouseButton1Click:Connect(function() setState(not FEATURE[featureKey]) end)
    ToggleCallbacks[featureKey]=setState
    Buttons[featureKey]=btn
    return btn
end

-- Utility Toggles
registerToggle("ESP","ESP",function(state) 
    if state then enableESP() else disableESP() end
end)
registerToggle("Auto Press E","AutoE",function(state) 
    if state then startAutoE() else stopAutoE() end
end)
registerToggle("WalkSpeed","WalkEnabled",function(state) 
    if state then 
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = FEATURE.WalkValue end
    else
        restoreWalkSpeedForCharacter(LocalPlayer.Character)
    end
end)
registerToggle("Aimbot","Aimbot",function(state) end)

-- Teleport buttons (reuse your previous teleport code)
do
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
        teleportContainer.CanvasSize = UDim2.new(0,0,0,teleportListLayout.AbsoluteContentSize.Y + 12)
    end)
    -- Buttons creation code here (same as old)
end

-- ======================= Hotkeys =======================
keepPersistent(UIS.InputBegan:Connect(function(input,gp)
    if gp then return end
    if input.KeyCode==Enum.KeyCode.LeftAlt then
        MainFrame.Visible = not MainFrame.Visible
        HUD.Visible = not MainFrame.Visible
    end
end))

-- ======================= Cleanup =======================
if _G then
    _G.__TPB_CLEANUP=function()
        clearAllConnections()
        playerMotion={}
        espObjects={}
        if PlayerGui then
            local g = PlayerGui:FindFirstChild("TPB_TycoonGUI_Final")
            if g then g:Destroy() end
            local h = PlayerGui:FindFirstChild("TPB_TycoonHUD_Final")
            if h then h:Destroy() end
        end
        restoreAllWalkSpeeds()
        stopAutoE()
    end
end

print("Script Loaded with NEW GUI!")
