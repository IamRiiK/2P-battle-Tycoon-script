-- 2P Battle Tycoon — Refactored Full Script (Patched, Clean)
-- Features: Draggable UI + HUD + ESP + AutoE + WalkSpeed + Aimbot
-- Fixes applied: per-player connection mapping, drag connection leak fix,
-- walkspeed saved per-character, improved ESP lifecycle, safer camera writes,
-- AutoE cleanup simplification, weak-key esp table, humanoid health checks
-- CREDIT: RiiK (RiiK26) — patched by assistant

if not game:IsLoaded() then game.Loaded:Wait() end

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Camera safety (get or wait)
local Camera = Workspace.CurrentCamera or Workspace:FindFirstChild("CurrentCamera")
if not Camera then
    local ok, cam = pcall(function() return Workspace:WaitForChild("CurrentCamera", 5) end)
    Camera = ok and cam or Workspace.CurrentCamera
end

-- Optional exploit API (used only if available)
local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)

-- Config & state
local FEATURE = {
    ESP = false,
    AutoE = false,
    AutoEInterval = 0.5,
    WalkEnabled = false,
    WalkValue = 30,
    Aimbot = false,
    AIM_FOV_DEG = 8,
    AIM_LERP = 0.4,
    AIM_HOLD = false, -- if true, aimbot only while right mouse held
}

local MAX_ESP_DISTANCE = 250 -- studs
local WALK_UPDATE_INTERVAL = 0.12 -- seconds

-- Connection tracking: persistent vs per-player
local PersistentConnections = {}
local PerPlayerConnections = {} -- map player -> {conn, conn}

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

-- Safe UI parenting
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

-- Remove any previous GUIs (avoid duplicates when re-running)
pcall(function()
    if _G and _G.__TPB_CLEANUP then
        pcall(_G.__TPB_CLEANUP)
    end
    local old = PlayerGui:FindFirstChild("TPB_TycoonGUI_Final")
    if old then old:Destroy() end
    local old2 = PlayerGui:FindFirstChild("TPB_TycoonHUD_Final")
    if old2 then old2:Destroy() end
end)

-- Build UI
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

-- Title / Drag area
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
Instance.new("UIListLayout", Content).Padding = UDim.new(0,12)

-- Minimize button
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Content.Visible = not minimized
    MinBtn.Text = minimized and "+" or "-"
end)

-- Dragging (single, stable implementation)
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

            -- guard against leaked Changed connections: disconnect previous if present
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

-- HUD
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

local function updateHUD(name, state)
    if hudLabels[name] then
        hudLabels[name].Text = name .. ": " .. (state and "ON" or "OFF")
        hudLabels[name].TextColor3 = state and Color3.fromRGB(80,200,120) or Color3.fromRGB(200,200,200)
    end
end

-- Toggle UI/HUD with LeftAlt
keepPersistent(UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.LeftAlt then
        MainFrame.Visible = not MainFrame.Visible
        HUD.Visible = not MainFrame.Visible
    end
end))

-- Toggle helper (create toggle buttons)
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
                FEATURE[featureKey] = old -- rollback on failure
            end
        end
    end

    btn.MouseButton1Click:Connect(function()
        setState(not FEATURE[featureKey])
    end)

    ToggleCallbacks[featureKey] = setState
    Buttons[featureKey] = btn
    return btn
end

-- WalkSpeed input (text box)
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

-- ESP System (Highlight AlwaysOnTop, team colors, distance cull)
-- use weak-key table so players can be GC'd if necessary
local espObjects = setmetatable({}, { __mode = "k" })
local MAX_ESP_DIST_SQ = MAX_ESP_DISTANCE * MAX_ESP_DISTANCE

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
    -- also clear per-player connections
    clearConnectionsForPlayer(p)
end

local function getESPColor(p)
    if p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team then
        return Color3.fromRGB(0,200,0) -- green for team
    else
        return Color3.fromRGB(200,40,40) -- red for enemy
    end
end

local function rootPartOfCharacter(char)
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
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
    clearESPForPlayer(p)
    if not p.Character then return end
    local root = rootPartOfCharacter(p.Character)
    if not root then return end

    local hum = p.Character:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then return end -- don't ESP dead

    safeWaitCamera()
    if not Camera or not Camera.CFrame then return end
    local camPos = Camera.CFrame.Position
    local diff = root.Position - camPos
    local distSq = diff:Dot(diff)
    if distSq > MAX_ESP_DIST_SQ then
        return
    end

    local hl = Instance.new("Highlight")
    hl.Name = "TPB_BoxESP"
    hl.Adornee = p.Character
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.OutlineTransparency = 0
    hl.OutlineColor = Color3.fromRGB(255,255,255)
    hl.FillTransparency = 0.7
    hl.FillColor = getESPColor(p)
    hl.Parent = p.Character

    espObjects[p] = { hl }
end

local function refreshESPForPlayer(p)
    if FEATURE.ESP then
        createESPForPlayer(p)
    else
        clearESPForPlayer(p)
    end
end

-- We will keep one persistent Players.PlayerAdded listener (registered on enableESP first time)
local playersAddedConn = nil
local playersRemovingConn = nil
local playersPropertyConn = nil -- unused here but reserved

local function onPlayerCharacterAdded(p)
    -- wait for relevant parts
    local char = p.Character
    if not char then return end
    -- wait a bit for root/humanoid, but bounded
    char:WaitForChild("HumanoidRootPart", 2)
    task.wait(0.05)
    refreshESPForPlayer(p)
    -- add character removal listener per-player
    addPerPlayerConnection(p, p.CharacterRemoving:Connect(function() clearESPForPlayer(p) end))
end

local function enableESP()
    -- only set listeners once as persistent
    -- clear per-player connections & existing esp then re-add for all players
    clearAllPerPlayerConnections()
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            refreshESPForPlayer(p)
            if p.Character then
                addPerPlayerConnection(p, p.CharacterRemoving:Connect(function() clearESPForPlayer(p) end))
            end
            -- per-player property listener for team changes
            addPerPlayerConnection(p, p:GetPropertyChangedSignal("Team"):Connect(function() updateESPColorForPlayer(p) end))
            -- per-player characteradded
            addPerPlayerConnection(p, p.CharacterAdded:Connect(function() task.wait(0.15) refreshESPForPlayer(p) end))
        end
    end

    if not playersAddedConn then
        playersAddedConn = keepPersistent(Players.PlayerAdded:Connect(function(p)
            if p ~= LocalPlayer then
                refreshESPForPlayer(p)
                addPerPlayerConnection(p, p.CharacterAdded:Connect(function() task.wait(0.15) refreshESPForPlayer(p) end))
                addPerPlayerConnection(p, p:GetPropertyChangedSignal("Team"):Connect(function() updateESPColorForPlayer(p) end))
                addPerPlayerConnection(p, p.CharacterRemoving:Connect(function() clearESPForPlayer(p) end))
            end
        end))
    end

    if not playersRemovingConn then
        playersRemovingConn = keepPersistent(Players.PlayerRemoving:Connect(function(p) clearESPForPlayer(p) end))
    end
end

local function disableESP()
    for p,_ in pairs(espObjects) do clearESPForPlayer(p) end
    -- do not clear persistent UI/input connections here
end

-- Auto Press E
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
                -- safe/clamped interval
                local interval = clamp(FEATURE.AutoEInterval or 0.5, 0.05, 5)
                -- send press and release
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
    -- thread will clear autoEThread itself
end

-- WalkSpeed (throttled writes) with save/restore per-character
local OriginalWalkByCharacter = {} -- character -> originalWalk

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

-- heartbeat loop to maintain walkspeed while enabled
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

-- restore walk speed for specific character
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

-- Aimbot helpers
local function angleBetweenVectors(a, b)
    local dot = a:Dot(b)
    local m = math.max(a.Magnitude * b.Magnitude, 1e-6)
    local val = clamp(dot / m, -1, 1)
    return math.deg(math.acos(val))
end

-- Aimbot loop (RenderStepped)
keepPersistent(RunService.RenderStepped:Connect(function()
    if not FEATURE.Aimbot then return end
    if FEATURE.AIM_HOLD and not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
    -- don't aim while typing into textboxes
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
                    -- skip dead
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
            -- Attempt safe write. This may error in some environments.
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, lerpVal)
        end)
        if not success then
            warn("Aimbot camera write error:", err)
            -- disable aimbot after repeated errors could be implemented; for now, disable to avoid spam
            FEATURE.Aimbot = false
            updateHUD("Aimbot", false)
        end
    end
end))

-- Register Toggles (UI + callbacks)
registerToggle("ESP", "ESP", function(state)
    if state then enableESP() else disableESP() end
    updateHUD("ESP", state)
end)
registerToggle("Auto Press E", "AutoE", function(state)
    if state then
        startAutoE()
    else
        stopAutoE()
    end
end)
registerToggle("WalkSpeed", "WalkEnabled", function(state)
    if state then
        -- capture current character's original if possible
        pcall(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum and LocalPlayer.Character and OriginalWalkByCharacter[LocalPlayer.Character] == nil then
                OriginalWalkByCharacter[LocalPlayer.Character] = hum.WalkSpeed
            end
            if hum then hum.WalkSpeed = FEATURE.WalkValue end
        end)
        updateHUD("WalkSpeed", true)
    else
        -- restore for current character
        restoreWalkSpeedForCharacter(LocalPlayer.Character)
    end
end)
registerToggle("Aimbot", "Aimbot", function(state)
    updateHUD("Aimbot", state)
end)

-- Initialize HUD with current states
for k,_ in pairs(FEATURE) do
    local display = nil
    if k == "ESP" then display = "ESP" end
    if k == "AutoE" then display = "Auto Press E" end
    if k == "WalkEnabled" then display = "WalkSpeed" end
    if k == "Aimbot" then display = "Aimbot" end
    if display then updateHUD(display, FEATURE[k]) end
end

-- Hotkeys (F1-F4) -- ignore if typing into TextBox
keepPersistent(UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if UIS:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.F1 and ToggleCallbacks.ESP then
        ToggleCallbacks.ESP(not FEATURE.ESP)
    elseif input.KeyCode == Enum.KeyCode.F2 and ToggleCallbacks.AutoE then
        ToggleCallbacks.AutoE(not FEATURE.AutoE)
    elseif input.KeyCode == Enum.KeyCode.F3 and ToggleCallbacks.WalkEnabled then
        ToggleCallbacks.WalkEnabled(not FEATURE.WalkEnabled)
    elseif input.KeyCode == Enum.KeyCode.F4 and ToggleCallbacks.Aimbot then
        ToggleCallbacks.Aimbot(not FEATURE.Aimbot)
    end
end))

-- Cleanup for character remove (only local player character cleanup)
keepPersistent(LocalPlayer.CharacterRemoving:Connect(function(char)
    -- clear ESP highlights for others when our character is removed (some highlights may reference our camera)
    for p,_ in pairs(espObjects) do clearESPForPlayer(p) end
    -- clear only per-player connections for others (we keep persistent ones intact)
    clearAllPerPlayerConnections()
    -- restore walk speed for this character
    restoreWalkSpeedForCharacter(char)
    -- stop AutoE
    stopAutoE()
end))

-- Ensure we restore/set walk speed on respawn as well
keepPersistent(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if FEATURE.WalkEnabled then
        pcall(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum and OriginalWalkByCharacter[LocalPlayer.Character] == nil then OriginalWalkByCharacter[LocalPlayer.Character] = hum.WalkSpeed end
            if hum then hum.WalkSpeed = FEATURE.WalkValue end
        end)
    end
    -- If ESP enabled, refresh per-player esp for characters that just loaded
    if FEATURE.ESP then
        -- small delay to allow other characters to initialize
        task.wait(0.2)
        for _,p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                refreshESPForPlayer(p)
            end
        end
    end
end))

-- Provide a global cleanup hook for re-run in some executors
if _G then
    _G.__TPB_CLEANUP = function()
        for p,_ in pairs(espObjects) do clearESPForPlayer(p) end
        -- destroy GUIs
        pcall(function()
            local g = PlayerGui:FindFirstChild("TPB_TycoonGUI_Final")
            if g then g:Destroy() end
            local gh = PlayerGui:FindFirstChild("TPB_TycoonHUD_Final")
            if gh then gh:Destroy() end
        end)
        -- restore walks and stop autoE
        restoreAllWalkSpeeds()
        stopAutoE()
        -- clear all connections (persistent and player)
        clearAllConnections()
    end
end

print("✅ TPB Refactor patched and loaded. Toggles: F1=ESP, F2=AutoE, F3=Walk, F4=Aimbot. LeftAlt toggles UI/HUD. UI draggable.")
