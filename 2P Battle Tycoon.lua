-- 2P Battle Tycoon — Refactored Full Script (Patched, Clean, + Anti-Spread)
-- Features: Draggable UI + HUD + ESP + AutoE + WalkSpeed + Aimbot + AntiSpread
-- Fixes: single drag impl (no leak), ESP lifecycle & distance refresh, scoped connections,
--        safer camera writes, walk restore consistent, AutoE debounce, aimbot non-fatal errors
-- CREDIT: RiiK (RiiK26)

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
    AntiSpread = false, -- NEW: attempt to remove weapon spread client-side
}

local MAX_ESP_DISTANCE = 250 -- studs
local WALK_UPDATE_INTERVAL = 0.12 -- seconds

-- Connection tracking: persistent vs player-scoped
local PersistentConnections = {}
local PlayerConnections = {}
local function keepPersistent(conn)
    if conn and conn.Disconnect then
        table.insert(PersistentConnections, conn)
    end
    return conn
end
local function keepPlayer(conn)
    if conn and conn.Disconnect then
        table.insert(PlayerConnections, conn)
    end
    return conn
end
local function clearPlayerConnections()
    for _,c in ipairs(PlayerConnections) do
        pcall(function() c:Disconnect() end)
    end
    PlayerConnections = {}
end
local function clearAllConnections()
    -- clear player-scoped first
    clearPlayerConnections()
    for _,c in ipairs(PersistentConnections) do
        pcall(function() c:Disconnect() end)
    end
    PersistentConnections = {}
end

-- Run a cleanup early if re-running
pcall(function()
    if _G and _G.__TPB_CLEANUP then
        pcall(_G.__TPB_CLEANUP)
    end
end)
-- ensure old connections cleared before proceeding (prevents dup connections on re-run)
clearAllConnections()

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

-- Dragging (single, stable implementation) - NO per-input Changed connections (avoids leak)
do
    local dragging = false
    local dragStart = nil
    local startPosPixels = nil
    local dragInputType = nil

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

    local function startDrag(input)
        dragging = true
        dragInputType = input.UserInputType
        dragStart = getInputPos(input)
        startPosPixels = toPixels(MainFrame.Position)
    end

    local function updateDrag(input)
        if not dragging then return end
        if input.UserInputType ~= dragInputType and input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
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

    local function endDrag(input)
        if not dragging then return end
        if input.UserInputType == dragInputType or input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            dragInputType = nil
        end
    end

    local function onInputBegan(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            startDrag(input)
        end
    end

    TitleBar.InputBegan:Connect(onInputBegan)
    DragHandle.InputBegan:Connect(onInputBegan)

    keepPersistent(UIS.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            updateDrag(input)
        end
    end))
    keepPersistent(UIS.InputEnded:Connect(function(input)
        endDrag(input)
    end))
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
hudAdd("Anti-Spread")

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
        FEATURE[featureKey] = state
        btn.Text = displayName .. " [" .. (state and "ON" or "OFF") .. "]"
        btn.BackgroundColor3 = state and Color3.fromRGB(80,150,220) or Color3.fromRGB(36,36,36)
        updateHUD(displayName, state)
        if type(onChange) == "function" then
            local ok, err = pcall(onChange, state)
            if not ok then warn("Toggle callback error:", err) end
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

-- ESP System (Highlight AlwaysOnTop, team colors, distance cull) with distance refresh loop
local espObjects = {}
local MAX_ESP_DIST_SQ = MAX_ESP_DISTANCE * MAX_ESP_DISTANCE
local perPlayerListeners = {} -- keep track to avoid duplicate listeners

local function clearESPForPlayer(p)
    if espObjects[p] then
        for _,v in pairs(espObjects[p]) do
            if v and v.Parent then
                pcall(function() v:Destroy() end)
            end
        end
        espObjects[p] = nil
    end
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

local function createESPForPlayer(p)
    clearESPForPlayer(p)
    if not p.Character then return end
    local root = rootPartOfCharacter(p.Character)
    if not root then return end
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
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- always visible through walls
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

local function ensurePerPlayerListeners(p)
    if perPlayerListeners[p] then return end
    perPlayerListeners[p] = true
    -- cleanup when player removed/character removed
    keepPlayer(p.CharacterRemoving:Connect(function()
        clearESPForPlayer(p)
    end))
    keepPlayer(p.CharacterAdded:Connect(function()
        task.wait(0.5)
        refreshESPForPlayer(p)
    end))
    keepPlayer(p:GetPropertyChangedSignal("Team"):Connect(function() refreshESPForPlayer(p) end))
end

local espDistanceUpdater = nil
local function startESPDistanceLoop()
    if espDistanceUpdater then return end
    espDistanceUpdater = task.spawn(function()
        while FEATURE.ESP do
            safeWaitCamera()
            for _,p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    if p.Character then
                        local root = rootPartOfCharacter(p.Character)
                        if root and Camera and Camera.CFrame then
                            local diff = root.Position - Camera.CFrame.Position
                            local dsq = diff:Dot(diff)
                            if dsq <= MAX_ESP_DIST_SQ then
                                if not espObjects[p] then
                                    createESPForPlayer(p)
                                else
                                    -- update color if team changed
                                    if espObjects[p][1] and espObjects[p][1].Parent then
                                        espObjects[p][1].FillColor = getESPColor(p)
                                    end
                                end
                            else
                                clearESPForPlayer(p)
                            end
                        end
                    else
                        clearESPForPlayer(p)
                    end
                    ensurePerPlayerListeners(p)
                end
            end
            task.wait(0.45)
        end
        -- exit cleanup: remove any leftover highlights
        for p,_ in pairs(espObjects) do clearESPForPlayer(p) end
        espDistanceUpdater = nil
    end)
end

local function enableESP()
    -- ensure previous per-player listeners cleared
    clearPlayerConnections()
    perPlayerListeners = {}
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            refreshESPForPlayer(p)
            ensurePerPlayerListeners(p)
        end
    end

    keepPlayer(Players.PlayerAdded:Connect(function(p)
        if p ~= LocalPlayer then
            refreshESPForPlayer(p)
            ensurePerPlayerListeners(p)
        end
    end))

    keepPlayer(Players.PlayerRemoving:Connect(function(p)
        clearESPForPlayer(p)
        perPlayerListeners[p] = nil
    end))

    -- start distance loop
    startESPDistanceLoop()
    updateHUD("ESP", true)
end

local function disableESP()
    FEATURE.ESP = false
    -- clear highlights and per-player listeners
    for p,_ in pairs(espObjects) do clearESPForPlayer(p) end
    perPlayerListeners = {}
    -- clear any player-scoped connections created by enableESP
    clearPlayerConnections()
    updateHUD("ESP", false)
end

-- Auto Press E
local autoEThread = nil
local autoERunning = false
local function startAutoE()
    if autoERunning then return end
    if not VIM then
        FEATURE.AutoE = false
        warn("AutoE: VirtualInputManager not available. AutoE disabled.")
        updateHUD("Auto Press E", false)
        return
    end
    autoERunning = true
    autoEThread = task.spawn(function()
        while FEATURE.AutoE do
            local ok, err = pcall(function()
                -- safe/clamped interval
                local interval = clamp(FEATURE.AutoEInterval or 0.5, 0.05, 5)
                -- send press and release
                pcall(function()
                    VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                end)
                task.wait(interval)
            end)
            if not ok then
                warn("AutoE error:", err)
            end
        end
        autoERunning = false
        autoEThread = nil
    end)
    updateHUD("Auto Press E", true)
end

local function stopAutoE()
    FEATURE.AutoE = false
    -- autoEThread will exit naturally; flag prevents double spawn
    if autoEThread then
        -- give short time for thread to wrap
        task.spawn(function()
            task.wait(0.15)
            autoEThread = nil
            autoERunning = false
        end)
    else
        autoERunning = false
    end
    updateHUD("Auto Press E", false)
end

-- WalkSpeed (throttled writes) with save/restore on toggles/respawn
local originalWalkSpeed = nil
local function cacheDefaultWalkSpeed()
    -- store a sensible default (tries to read currently present humanoid once)
    pcall(function()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and originalWalkSpeed == nil then
            originalWalkSpeed = hum.WalkSpeed
        end
    end)
    if originalWalkSpeed == nil then
        -- fallback to common default if unknown
        originalWalkSpeed = 16
    end
end

local function setPlayerWalkSpeed(value)
    pcall(function()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = value end
    end)
end

-- ensure we capture default early
cacheDefaultWalkSpeed()

-- heartbeat loop to maintain walkspeed while enabled
do
    local acc = 0
    keepPersistent(RunService.Heartbeat:Connect(function(dt)
        if not FEATURE.WalkEnabled then return end
        acc = acc + dt
        if acc < WALK_UPDATE_INTERVAL then return end
        acc = 0
        pcall(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                if originalWalkSpeed == nil then originalWalkSpeed = hum.WalkSpeed end
                if hum.WalkSpeed ~= FEATURE.WalkValue then
                    hum.WalkSpeed = FEATURE.WalkValue
                end
            end
        end)
    end))
end

-- restore walk speed
local function restoreWalkSpeed()
    pcall(function()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and originalWalkSpeed then
            hum.WalkSpeed = originalWalkSpeed
        end
    end)
    -- keep originalWalkSpeed so future toggles restore to same base unless explicitly reset
    updateHUD("WalkSpeed", false)
end

-- Aimbot helpers
local function angleBetweenVectors(a, b)
    local dot = a:Dot(b)
    local m = math.max(a.Magnitude * b.Magnitude, 1e-6)
    local val = clamp(dot / m, -1, 1)
    return math.deg(math.acos(val))
end

-- Anti-Spread (best-effort, client-side)
-- Try to zero out common spread/recoil properties on currently equipped tool(s).
-- NOTE: many games enforce spread server-side; client-side changes may not work in that case.
local antiSpreadListeners = {}
local function patchToolSpread(tool)
    if not tool then return end
    -- common property names to attempt to set to 0
    local candidates = {"Spread", "SpreadAmount", "BulletSpread", "Recoil", "Accuracy", "SpreadRadius", "SpreadAngle"}
    for _,name in ipairs(candidates) do
        local v = tool:FindFirstChild(name)
        if v and v:IsA("NumberValue") then
            pcall(function() v.Value = 0 end)
        elseif v and v:IsA("BoolValue") then
            pcall(function() v.Value = false end)
        elseif v and v:IsA("NumberValue") == false and v and v:IsA("IntValue") then
            pcall(function() v.Value = 0 end)
        end
    end
    -- also try to set properties on tool itself if present (rare)
    pcall(function()
        if tool:IsA("Tool") then
            for _,prop in ipairs({"Spread","Recoil","Accuracy"}) do
                if tool[prop] ~= nil then
                    pcall(function() tool[prop] = 0 end)
                end
            end
        end
    end)
end

local function enableAntiSpreadForCharacter(char)
    if not char then return end
    -- patch any tools already in character
    for _,obj in ipairs(char:GetChildren()) do
        if obj:IsA("Tool") or obj:IsA("HopperBin") then
            patchToolSpread(obj)
        end
    end
    -- watch for tools equipped/added
    if antiSpreadListeners[char] then return end
    antiSpreadListeners[char] = true
    keepPlayer(char.ChildAdded:Connect(function(child)
        if (child:IsA("Tool") or child:IsA("HopperBin")) and FEATURE.AntiSpread then
            task.wait(0.04)
            patchToolSpread(child)
        end
    end))
end

local function disableAntiSpread()
    FEATURE.AntiSpread = false
    -- nothing to explicitly undo since we only set client-side values; remove listeners
    antiSpreadListeners = {}
end

local function enableAntiSpread()
    FEATURE.AntiSpread = true
    -- attempt to patch LocalPlayer character tools
    if LocalPlayer.Character then
        enableAntiSpreadForCharacter(LocalPlayer.Character)
    end
    -- watch for future respawns
    keepPersistent(LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if FEATURE.AntiSpread then enableAntiSpreadForCharacter(char) end
    end))
    updateHUD("Anti-Spread", true)
end

-- Aimbot loop (RenderStepped) — non-fatal error handling (don't permanently disable)
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
            -- Attempt camera write — if it errors once, just warn and continue next frame
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, lerpVal)
        end)
        if not success then
            -- non-fatal: warn but don't permanently disable aimbot
            warn("Aimbot camera write error (non-fatal):", err)
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
        -- store original if possible (cached earlier)
        cacheDefaultWalkSpeed()
        updateHUD("WalkSpeed", true)
    else
        restoreWalkSpeed()
    end
end)
registerToggle("Aimbot", "Aimbot", function(state)
    updateHUD("Aimbot", state)
end)
registerToggle("Anti-Spread", "AntiSpread", function(state)
    if state then
        enableAntiSpread()
    else
        disableAntiSpread()
        updateHUD("Anti-Spread", false)
    end
end)

-- Initialize HUD with current states
for k,_ in pairs(FEATURE) do
    local display = nil
    if k == "ESP" then display = "ESP" end
    if k == "AutoE" then display = "Auto Press E" end
    if k == "WalkEnabled" then display = "WalkSpeed" end
    if k == "Aimbot" then display = "Aimbot" end
    if k == "AntiSpread" then display = "Anti-Spread" end
    if display then updateHUD(display, FEATURE[k]) end
end

-- Hotkeys (F1-F5)
keepPersistent(UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.F1 and ToggleCallbacks.ESP then
        ToggleCallbacks.ESP(not FEATURE.ESP)
    elseif input.KeyCode == Enum.KeyCode.F2 and ToggleCallbacks.AutoE then
        ToggleCallbacks.AutoE(not FEATURE.AutoE)
    elseif input.KeyCode == Enum.KeyCode.F3 and ToggleCallbacks.WalkEnabled then
        ToggleCallbacks.WalkEnabled(not FEATURE.WalkEnabled)
    elseif input.KeyCode == Enum.KeyCode.F4 and ToggleCallbacks.Aimbot then
        ToggleCallbacks.Aimbot(not FEATURE.Aimbot)
    elseif input.KeyCode == Enum.KeyCode.F5 and ToggleCallbacks.AntiSpread then
        ToggleCallbacks.AntiSpread(not FEATURE.AntiSpread)
    end
end))

-- Cleanup for character remove (only player-scoped)
keepPersistent(LocalPlayer.CharacterRemoving:Connect(function()
    -- clear ESP highlights for everyone (they should be tied to characters)
    for p,_ in pairs(espObjects) do clearESPForPlayer(p) end
    -- clear only player-scoped connections (listeners for players/characters)
    clearPlayerConnections()
    -- restore walk speed
    restoreWalkSpeed()
    -- stop AutoE
    stopAutoE()
    -- clear anti-spread listeners
    antiSpreadListeners = {}
end))

-- Ensure we restore/set walk speed on respawn as well
keepPersistent(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if FEATURE.WalkEnabled then
        pcall(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum and originalWalkSpeed == nil then originalWalkSpeed = hum.WalkSpeed end
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
    -- If Anti-Spread enabled, re-apply to new character
    if FEATURE.AntiSpread and LocalPlayer.Character then
        enableAntiSpreadForCharacter(LocalPlayer.Character)
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
        -- restore walk and stop autoE
        restoreWalkSpeed()
        stopAutoE()
        -- clear all connections (persistent and player)
        clearAllConnections()
    end
end

print("✅ TPB Refactor loaded. Toggles: F1=ESP, F2=AutoE, F3=Walk, F4=Aimbot, F5=AntiSpread. LeftAlt toggles UI/HUD. UI draggable.")
