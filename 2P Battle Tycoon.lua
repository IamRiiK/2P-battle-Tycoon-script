-- TPB Refactor — Full merged script
-- Main UI (left) with toggles + integrated Value Editor section
-- Passes Editor UI kept as separate window
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

pcall(function()
    if _G and _G.__TPB_CLEANUP then
        pcall(_G.__TPB_CLEANUP)
    end
    local old = PlayerGui:FindFirstChild("TPB_TycoonGUI_Final")
    if old then old:Destroy() end
    local old2 = PlayerGui:FindFirstChild("TPB_TycoonHUD_Final")
    if old2 then old2:Destroy() end
end)

-- Main ScreenGui & MainFrame
local MainScreenGui = Instance.new("ScreenGui")
MainScreenGui.Name = "TPB_TycoonGUI_Final"
MainScreenGui.DisplayOrder = 9999
safeParentGui(MainScreenGui)

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0,360,0,560) -- taller to fit Value Editor
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

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Content.Visible = not minimized
    MinBtn.Text = minimized and "+" or "-"
end)

-- make MainFrame draggable
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

-- Toggle buttons
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

    btn.MouseButton1Click:Connect(function()
        setState(not FEATURE[featureKey])
    end)

    ToggleCallbacks[featureKey] = setState
    Buttons[featureKey] = btn
    return btn
end

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

-- ESP implementation
local espObjects = setmetatable({}, { __mode = "k" })

local function rootPartOfCharacter(char)
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
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

    if espObjects[p] then
        updateESPColorForPlayer(p)
        return
    end

    local char = p.Character
    if not char then return end
    local root = rootPartOfCharacter(char)
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
        if p ~= LocalPlayer then
            ensurePlayerListeners(p)
            refreshESPForPlayer(p)
        end
    end

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

local function disableESP()
    for p,_ in pairs(espObjects) do clearESPForPlayer(p) end
end

-- Auto E
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
registerToggle("Aimbot", "Aimbot", function(state)
    updateHUD("Aimbot", state)
end)

for k,_ in pairs(FEATURE) do
    local display = nil
    if k == "ESP" then display = "ESP" end
    if k == "AutoE" then display = "Auto Press E" end
    if k == "WalkEnabled" then display = "WalkSpeed" end
    if k == "Aimbot" then display = "Aimbot" end
    if display then updateHUD(display, FEATURE[k]) end
end

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
    end
end

-- ===========================
-- Passes Editor UI (kept separate)
-- ===========================
local PassesGui = Instance.new("ScreenGui")
PassesGui.Name = "PassesEditor"
PassesGui.Parent = game.CoreGui

local PassesFrame = Instance.new("Frame")
PassesFrame.Size = UDim2.new(0, 300, 0, 400)
PassesFrame.Position = UDim2.new(0.3, 0, 0.08, 0)
PassesFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
PassesFrame.Active = true
PassesFrame.Draggable = true -- legacy property; still supported in some contexts
PassesFrame.Parent = PassesGui

local PassesTitle = Instance.new("TextLabel")
PassesTitle.Text = "🎟️ Passes Editor"
PassesTitle.Size = UDim2.new(1, 0, 0, 40)
PassesTitle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
PassesTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
PassesTitle.Font = Enum.Font.SourceSansBold
PassesTitle.TextSize = 20
PassesTitle.Parent = PassesFrame

local ScrollingFrame = Instance.new("ScrollingFrame")
ScrollingFrame.Size = UDim2.new(1, 0, 1, -40)
ScrollingFrame.Position = UDim2.new(0, 0, 0, 40)
ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollingFrame.ScrollBarThickness = 6
ScrollingFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ScrollingFrame.Parent = PassesFrame

local function createPassButton(pass)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(1, -10, 0, 40)
    Button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    Button.Font = Enum.Font.SourceSansBold
    Button.TextSize = 18
    Button.Text = pass.Name .. " : " .. tostring(pass.Value)
    Button.Parent = ScrollingFrame

    Button.MouseButton1Click:Connect(function()
        pass.Value = not pass.Value
        Button.Text = pass.Name .. " : " .. tostring(pass.Value)
    end)

    return Button
end

local player = Players.LocalPlayer
local passesFolder = player:WaitForChild("Passes")

local y = 0
for _, pass in ipairs(passesFolder:GetChildren()) do
    if pass:IsA("BoolValue") then
        local btn = createPassButton(pass)
        btn.Position = UDim2.new(0, 5, 0, y)
        y = y + 45
    end
end
ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, y)

-- ===========================
-- Integrated Value Editor (moved into MainFrame -> Content)
-- ===========================

-- Container frame inside Content
local ValueEditorFrame = Instance.new("Frame", Content)
ValueEditorFrame.Name = "ValueEditor"
ValueEditorFrame.Size = UDim2.new(1, -10, 0, 240)
ValueEditorFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
ValueEditorFrame.BorderSizePixel = 0
Instance.new("UICorner", ValueEditorFrame).CornerRadius = UDim.new(0,8)

local VE_Label = Instance.new("TextLabel", ValueEditorFrame)
VE_Label.Size = UDim2.new(1, 0, 0, 28)
VE_Label.Position = UDim2.new(0,0,0,0)
VE_Label.BackgroundTransparency = 1
VE_Label.Text = "🔧 Value Editor"
VE_Label.TextColor3 = Color3.fromRGB(255, 255, 255)
VE_Label.Font = Enum.Font.GothamBold
VE_Label.TextSize = 14

local VE_Scroll = Instance.new("ScrollingFrame", ValueEditorFrame)
VE_Scroll.Size = UDim2.new(1, -10, 1, -36)
VE_Scroll.Position = UDim2.new(0, 5, 0, 32)
VE_Scroll.BackgroundTransparency = 1
VE_Scroll.ScrollBarThickness = 6
local VE_Layout = Instance.new("UIListLayout", VE_Scroll)
VE_Layout.Padding = UDim.new(0, 6)
VE_Layout.SortOrder = Enum.SortOrder.LayoutOrder

-- Helper: create editor line for a Value instance
local function createValueEditorLine(parent, valueInst)
    if not parent or not valueInst then return end
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -8, 0, 40)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0.35, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(230,230,230)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = valueInst.Name

    local box = Instance.new("TextBox", frame)
    box.Size = UDim2.new(0.4, -12, 0, 28)
    box.Position = UDim2.new(0.35, 0, 0.5, -14)
    box.BackgroundColor3 = Color3.fromRGB(32,32,32)
    box.TextColor3 = Color3.fromRGB(240,240,240)
    box.Font = Enum.Font.Gotham
    box.TextSize = 13
    box.ClearTextOnFocus = false
    box.Text = tostring(valueInst.Value)
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,8)

    local applyBtn = Instance.new("TextButton", frame)
    applyBtn.Size = UDim2.new(0.22, -8, 0, 28)
    applyBtn.Position = UDim2.new(0.75, 0, 0.5, -14)
    applyBtn.BackgroundColor3 = Color3.fromRGB(50,180,50)
    applyBtn.TextColor3 = Color3.fromRGB(240,240,240)
    applyBtn.Font = Enum.Font.GothamBold
    applyBtn.TextSize = 13
    applyBtn.Text = "Apply"
    Instance.new("UICorner", applyBtn).CornerRadius = UDim.new(0,8)

    local forceEnabled = false
    local forceThread

    applyBtn.MouseButton1Click:Connect(function()
        if forceEnabled then
            -- stop force mode
            forceEnabled = false
            applyBtn.Text = "Apply"
            applyBtn.BackgroundColor3 = Color3.fromRGB(50,180,50)
        else
            -- single apply
            local n = tonumber(box.Text)
            if n then
                valueInst.Value = n
                box.Text = tostring(valueInst.Value)
            else
                box.Text = tostring(valueInst.Value)
            end
        end
    end)

    applyBtn.MouseButton2Click:Connect(function()
        forceEnabled = not forceEnabled
        if forceEnabled then
            applyBtn.Text = "Force"
            applyBtn.BackgroundColor3 = Color3.fromRGB(200,80,80)
            forceThread = task.spawn(function()
                while forceEnabled do
                    local n = tonumber(box.Text)
                    if n then valueInst.Value = n end
                    task.wait(0.2)
                end
            end)
        else
            applyBtn.Text = "Apply"
            applyBtn.BackgroundColor3 = Color3.fromRGB(50,180,50)
        end
    end)

    valueInst:GetPropertyChangedSignal("Value"):Connect(function()
        box.Text = tostring(valueInst.Value)
    end)
end

-- Recursively scan folders for numeric values
local function scanFolderForValues(folder)
    for _,v in ipairs(folder:GetChildren()) do
        if v:IsA("IntValue") or v:IsA("NumberValue") then
            createValueEditorLine(VE_Scroll, v)
        elseif v:IsA("Folder") then
            scanFolderForValues(v)
        end
    end
end

local function buildValueEditor()
    -- clear previous entries
    for _,c in ipairs(VE_Scroll:GetChildren()) do
        if not c:IsA("UIListLayout") then
            c:Destroy()
        end
    end
    -- scan common data locations
    if LocalPlayer:FindFirstChild("leaderstats") then
        scanFolderForValues(LocalPlayer.leaderstats)
    end
    if LocalPlayer:FindFirstChild("Upgrades") then
        scanFolderForValues(LocalPlayer.Upgrades)
    end
    if LocalPlayer:FindFirstChild("DataFolder") then
        scanFolderForValues(LocalPlayer.DataFolder)
    end
    -- adjust canvas size
    VE_Scroll.CanvasSize = UDim2.new(0,0,0,VE_Layout.AbsoluteContentSize.Y + 10)
end

-- initial build
buildValueEditor()

-- provide a simple refresh button inside ValueEditorFrame
local refreshBtn = Instance.new("TextButton", ValueEditorFrame)
refreshBtn.Size = UDim2.new(0, 80, 0, 24)
refreshBtn.Position = UDim2.new(1, -90, 0, 4)
refreshBtn.Text = "Refresh"
refreshBtn.Font = Enum.Font.Gotham
refreshBtn.TextSize = 12
refreshBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
refreshBtn.TextColor3 = Color3.fromRGB(230,230,230)
Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0,6)
refreshBtn.MouseButton1Click:Connect(function() buildValueEditor() end)

print("✅ Value Editor berhasil dimuat! Semua value (Cash, Points, dll.) siap diubah.")
print("✅ TPB Refactor patched loaded. Toggles: F1=ESP, F2=AutoE, F3=Walk, F4=Aimbot. LeftAlt toggles UI/HUD. UI draggable.")

-- End of script
