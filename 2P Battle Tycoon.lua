-- 2P Battle Tycoon — Full Fixed Script (Stabilized + ESP AlwaysOnTop)
-- Perbaikan: cleanup koneksi, optimise loops, safer GUI parenting, aimbot guard, ESP AlwaysOnTop
-- ESP: hijau untuk teman, merah untuk musuh, selalu terlihat meski terhalang objek
-- Features: Dark UI + HUD + ESP (Highlight) + AutoE + WalkSpeed + Aimbot
-- Hotkeys: F1=ESP, F2=AutoE, F3=Walk toggle, F4=Aimbot toggle, LeftAlt=Toggle UI/HUD
-- Credit: adapted from original (RiiK @RiiK26), patched for stability

if not game:IsLoaded() then game.Loaded:Wait() end

-- ==========
-- Services
-- ==========
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Camera
local Camera = Workspace.CurrentCamera or Workspace:FindFirstChild("CurrentCamera")
if not Camera then
    local ok, cam = pcall(function() return Workspace:WaitForChild("CurrentCamera", 5) end)
    Camera = ok and cam or Workspace.CurrentCamera
end

-- Optional exploit API
local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)

-- ==========
-- Feature state & config
-- ==========
local FEATURE = {
    ESP = false,
    AutoE = false,
    AutoEInterval = 0.5,
    WalkEnabled = false,
    WalkValue = 25,
    Aimbot = false,
    AIM_FOV_DEG = 8,
    AIM_LERP = 0.4,
}

local MAX_ESP_DISTANCE = 250
local WALK_UPDATE_INTERVAL = 0.12

-- ==========
-- Connection management
-- ==========
local Connections = {}
local function keep(conn)
    if conn and conn.Disconnect then table.insert(Connections, conn) end
    return conn
end
local function clearConnections()
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    Connections = {}
end

-- ==========
-- Helpers
-- ==========
local function safeParentGui(gui)
    gui.ResetOnSpawn = false
    gui.Parent = PlayerGui
end

local function safeWaitCamera()
    if not (Workspace.CurrentCamera or Camera) then
        local ok, cam = pcall(function() return Workspace:WaitForChild("CurrentCamera", 5) end)
        Camera = ok and cam or Workspace.CurrentCamera
    else
        Camera = Workspace.CurrentCamera or Camera
    end
end

pcall(function()
    local old = PlayerGui:FindFirstChild("TPB_TycoonGUI_Final")
    if old then old:Destroy() end
    local old2 = PlayerGui:FindFirstChild("TPB_TycoonHUD_Final")
    if old2 then old2:Destroy() end
end)

-- ==========
-- UI (Main + HUD)
-- ==========
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TPB_TycoonGUI_Final"
ScreenGui.DisplayOrder = 9999
safeParentGui(ScreenGui)

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0,360,0,460)
MainFrame.Position = UDim2.new(0.28,0,0.18,0)
MainFrame.BackgroundColor3 = Color3.fromRGB(28,28,30)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0,12)

-- Drag
do
    local dragging = false
    local dragStart = Vector2.new()
    local startPos = UDim2.new()
    local top = Instance.new("Frame", MainFrame)
    top.Name = "DragTitle"
    top.Size = UDim2.new(1,0,0,40)
    top.BackgroundTransparency = 1
    top.Position = UDim2.new(0,0,0,0)

    top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local Content = Instance.new("Frame", MainFrame)
Content.Name = "Content"
Content.Size = UDim2.new(1,-16,1,-56)
Content.Position = UDim2.new(0,8,0,48)
Content.BackgroundTransparency = 1
Instance.new("UIListLayout", Content).Padding = UDim.new(0,12)

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

local hudLabels = {}
local function hudAdd(name)
    local l = Instance.new("TextLabel", HUD)
    l.Size = UDim2.new(1,-12,0,20)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.Gotham
    l.TextSize = 14
    l.TextColor3 = Color3.fromRGB(220,220,220)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = name .. ": OFF"
    hudLabels[name] = l
end

hudAdd("ESP"); hudAdd("Auto Press E"); hudAdd("WalkSpeed"); hudAdd("Aimbot")

local function updateHUD(name, state)
    if hudLabels[name] then
        hudLabels[name].Text = name .. ": " .. (state and "ON" or "OFF")
        hudLabels[name].TextColor3 = state and Color3.fromRGB(80,200,120) or Color3.fromRGB(200,200,200)
    end
end

UIS.InputBegan:Connect(function(input,gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.LeftAlt then
        MainFrame.Visible = not MainFrame.Visible
        HUD.Visible = not MainFrame.Visible
    end
end)

-- ==========
-- Toggle helper
-- ==========
local ToggleCallbacks = {}
local function registerToggle(displayName, featureKey, onChange)
    local btn = Instance.new("TextButton", Content)
    btn.Size = UDim2.new(1,0,0,36)
    btn.BackgroundColor3 = Color3.fromRGB(36,36,36)
    btn.TextColor3 = Color3.fromRGB(235,235,235)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 15
    btn.Text = displayName .. " [OFF]"
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)

    local function setState(state)
        FEATURE[featureKey] = state
        btn.Text = displayName .. " [" .. (state and "ON" or "OFF") .. "]"
        btn.BackgroundColor3 = state and Color3.fromRGB(80,150,220) or Color3.fromRGB(36,36,36)
        updateHUD(displayName, state)
        if type(onChange) == "function" then pcall(onChange, state) end
    end

    btn.MouseButton1Click:Connect(function() setState(not FEATURE[featureKey]) end)
    ToggleCallbacks[featureKey] = setState
end

-- ==========
-- ESP System
-- ==========
local espObjects = {}
local MAX_ESP_DIST_SQ = MAX_ESP_DISTANCE * MAX_ESP_DISTANCE

local function clearESP(p)
    if espObjects[p] then
        for _,v in pairs(espObjects[p]) do if v and v.Parent then pcall(function() v:Destroy() end) end end
        espObjects[p] = nil
    end
end

local function createESP(p)
    clearESP(p)
    if not p.Character then return end
    local root = p.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    safeWaitCamera()
    if not Camera or not Camera.CFrame then return end
    local camPos = Camera.CFrame.Position
    if (root.Position - camPos).Magnitude^2 > MAX_ESP_DIST_SQ then return end

    local hl = Instance.new("Highlight")
    hl.Name = "BoxESP"
    hl.Adornee = p.Character
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- ✅ selalu terlihat
    hl.OutlineTransparency = 0.4
    hl.OutlineColor = Color3.fromRGB(255,255,255)
    hl.FillTransparency = 0.65
    hl.FillColor = (p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team) and Color3.fromRGB(0,200,0) or Color3.fromRGB(200,40,40)
    hl.Parent = p.Character
    espObjects[p] = {hl}
end

local function refreshESPForPlayer(p) if FEATURE.ESP then createESP(p) else clearESP(p) end end
local function enableESP()
    for _,p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then refreshESPForPlayer(p) keep(p.CharacterAdded:Connect(function() task.wait(0.5) refreshESPForPlayer(p) end)) end end
    keep(Players.PlayerAdded:Connect(function(p) if p ~= LocalPlayer then refreshESPForPlayer(p) keep(p.CharacterAdded:Connect(function() task.wait(0.5) refreshESPForPlayer(p) end)) end end))
    keep(Players.PlayerRemoving:Connect(function(p) clearESP(p) end))
end
local function disableESP() for p,_ in pairs(espObjects) do clearESP(p) end end

-- ==========
-- AutoE
-- ==========
local autoEThread=nil
local function startAutoE()
    if autoEThread then return end
    if not VIM then warn("AutoE: VirtualInputManager not available.") return end
    autoEThread = task.spawn(function()
        while FEATURE.AutoE do
            VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            task.wait(math.clamp(FEATURE.AutoEInterval,0.05,5))
        end
        autoEThread=nil
    end)
end

-- ==========
-- WalkSpeed
-- ==========
local lastSet=0
RunService.Heartbeat:Connect(function(dt)
    if not FEATURE.WalkEnabled then return end
    lastSet += dt
    if lastSet < WALK_UPDATE_INTERVAL then return end
    lastSet=0
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum and hum.WalkSpeed ~= FEATURE.WalkValue then hum.WalkSpeed = FEATURE.WalkValue end
end)

-- ==========
-- Aimbot
-- ==========
local function angleTo(a,b) return math.deg(math.acos(math.clamp(a:Dot(b)/(a.Magnitude*b.Magnitude),-1,1))) end
RunService.RenderStepped:Connect(function()
    if not FEATURE.Aimbot or UIS:GetFocusedTextBox() then return end
    safeWaitCamera()
    if not Camera then return end
    local best, bestAngle=nil,1e9
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Team and LocalPlayer.Team and p.Team~=LocalPlayer.Team and p.Character and p.Character:FindFirstChild("Head") then
            local head=p.Character.Head
            local ang=angleTo(Camera.CFrame.LookVector,(head.Position-Camera.CFrame.Position).Unit)
            if ang<bestAngle and ang<=FEATURE.AIM_FOV_DEG then best, bestAngle=head,ang end
        end
    end
    if best then
        local dir=(best.Position-Camera.CFrame.Position).Unit
        local blended=Camera.CFrame.LookVector:Lerp(dir,FEATURE.AIM_LERP)
        local pos=Camera.CFrame.Position
        Camera.CFrame=Camera.CFrame:Lerp(CFrame.new(pos,pos+blended),math.clamp(FEATURE.AIM_LERP,0.05,0.9))
    end
end)

-- ==========
-- Register Toggles
-- ==========
registerToggle("ESP","ESP",function(state) if state then enableESP() else disableESP() end end)
registerToggle("Auto Press E","AutoE",function(state) if state then startAutoE() end end)
registerToggle("WalkSpeed","WalkEnabled")
registerToggle("Aimbot","Aimbot")

-- ==========
-- Hotkeys
-- ==========
UIS.InputBegan:Connect(function(input,gp)
    if gp then return end
    if input.KeyCode==Enum.KeyCode.F1 then ToggleCallbacks.ESP(not FEATURE.ESP)
    elseif input.KeyCode==Enum.KeyCode.F2 then ToggleCallbacks.AutoE(not FEATURE.AutoE)
    elseif input.KeyCode==Enum.KeyCode.F3 then ToggleCallbacks.WalkEnabled(not FEATURE.WalkEnabled)
    elseif input.KeyCode==Enum.KeyCode.F4 then ToggleCallbacks.Aimbot(not FEATURE.Aimbot) end
end)

-- ==========
-- Cleanup
-- ==========
LocalPlayer.CharacterRemoving:Connect(function() for p,_ in pairs(espObjects) do clearESP(p) end clearConnections() end)

print("✅ TPB script loaded (ESP AlwaysOnTop). Hotkeys: F1 ESP, F2 AutoE, F3 Walk, F4 Aimbot. LeftAlt toggle UI/HUD.")
