-- 2P Battle Tycoon — Full Fixed Script (Patched, cleaned)
-- Features: Dark UI + HUD + ESP + AutoE + WalkSpeed + Aimbot + Infinite Ammo (safe)
-- CREDIT TO: RiiK (RiiK26) -- Cleaned/Fixed by assistant

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

-- Camera safety
local Camera = Workspace.CurrentCamera or Workspace:FindFirstChild("CurrentCamera")
if not Camera then
    local ok, cam = pcall(function() return Workspace:WaitForChild("CurrentCamera", 5) end)
    Camera = ok and cam or Workspace.CurrentCamera
end

-- Optional exploit API (used only if available)
local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)

-- Config & state (FIXED: proper table entry for InfiniteAmmo)
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
    InfiniteAmmo = false,
}

local MAX_ESP_DISTANCE = 250 -- studs
local WALK_UPDATE_INTERVAL = 0.12 -- seconds

-- Connection tracking for cleanup
local Connections = {}
local function keep(conn)
    if conn == nil then return nil end
    local t = typeof(conn)
    if t == "RBXScriptConnection" then
        table.insert(Connections, conn)
    else
        local ok, has = pcall(function() return conn and conn.Disconnect end)
        if ok and has then table.insert(Connections, conn) end
    end
    return conn
end
local function clearConnections()
    for _,c in ipairs(Connections) do
        pcall(function() c:Disconnect() end)
    end
    Connections = {}
end

-- Helpers
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

-- Minimize button functionality
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Content.Visible = not minimized
    MinBtn.Text = minimized and "+" or "-"
end)

-- HUD
local HUDGui = Instance.new("ScreenGui")
HUDGui.Name = "TPB_TycoonHUD_Final"
HUDGui.DisplayOrder = 10000
safeParentGui(HUDGui)

local HUD = Instance.new("Frame", HUDGui)
HUD.Size = UDim2.new(0,220,0,150)
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
hudAdd("Infinite Ammo")

local function updateHUD(name, state)
    if hudLabels[name] then
        hudLabels[name].Text = name .. ": " .. (state and "ON" or "OFF")
        hudLabels[name].TextColor3 = state and Color3.fromRGB(80,200,120) or Color3.fromRGB(200,200,200)
    end
end

-- Toggle UI/HUD with LeftAlt
keep(UIS.InputBegan:Connect(function(input, gp)
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

-- WalkSpeed input
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

-- ESP System
local espObjects = {}
local MAX_ESP_DIST_SQ = MAX_ESP_DISTANCE * MAX_ESP_DISTANCE

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
        return Color3.fromRGB(0,200,0)
    else
        return Color3.fromRGB(200,40,40)
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

local function enableESP()
    for p,_ in pairs(espObjects) do clearESPForPlayer(p) end

    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            refreshESPForPlayer(p)
            if p.Character then
                keep(p.CharacterRemoving:Connect(function() clearESPForPlayer(p) end))
            end
            keep(p.CharacterAdded:Connect(function()
                task.wait(0.5)
                refreshESPForPlayer(p)
                if p.Character then
                    keep(p.CharacterRemoving:Connect(function() clearESPForPlayer(p) end))
                end
            end))
            keep(p:GetPropertyChangedSignal("Team"):Connect(function() refreshESPForPlayer(p) end))
        end
    end

    keep(Players.PlayerAdded:Connect(function(p)
        if p ~= LocalPlayer then
            refreshESPForPlayer(p)
            keep(p.CharacterAdded:Connect(function()
                task.wait(0.5)
                refreshESPForPlayer(p)
                if p.Character then
                    keep(p.CharacterRemoving:Connect(function() clearESPForPlayer(p) end))
                end
            end))
            keep(p:GetPropertyChangedSignal("Team"):Connect(function() refreshESPForPlayer(p) end))
            keep(p.CharacterRemoving:Connect(function() clearESPForPlayer(p) end))
        end
    end))

    keep(Players.PlayerRemoving:Connect(function(p) clearESPForPlayer(p) end))
end

local function disableESP()
    for p,_ in pairs(espObjects) do clearESPForPlayer(p) end
end

-- Auto Press E
local autoEThread = nil
local function startAutoE()
    if autoEThread then return end
    if not VIM then
        FEATURE.AutoE = false
        warn("AutoE: VirtualInputManager not available. AutoE disabled.")
        updateHUD("Auto Press E", false)
        return
    end
    autoEThread = task.spawn(function()
        while FEATURE.AutoE do
            pcall(function()
                VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            end)
            task.wait(clamp(FEATURE.AutoEInterval or 0.5, 0.05, 5))
        end
        autoEThread = nil
    end)
end

local function stopAutoE()
    FEATURE.AutoE = false
    if autoEThread then
        task.spawn(function()
            task.wait(0.2)
            autoEThread = nil
        end)
    end
    updateHUD("Auto Press E", false)
end

-- WalkSpeed (heartbeat)
local originalWalkSpeed = nil
do
    local acc = 0
    keep(RunService.Heartbeat:Connect(function(dt)
        if not FEATURE.WalkEnabled then return end
        acc = acc + dt
        if acc < WALK_UPDATE_INTERVAL then return end
        acc = 0
        pcall(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                if not originalWalkSpeed then originalWalkSpeed = hum.WalkSpeed end
                if hum.WalkSpeed ~= FEATURE.WalkValue then
                    hum.WalkSpeed = FEATURE.WalkValue
                end
            end
        end)
    end))
end

local function restoreWalkSpeed()
    pcall(function()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and originalWalkSpeed then
            hum.WalkSpeed = originalWalkSpeed
        end
    end)
    originalWalkSpeed = nil
end

-- Aimbot (RenderStepped)
local function angleBetweenVectors(a, b)
    local dot = a:Dot(b)
    local m = math.max(a.Magnitude * b.Magnitude, 1e-6)
    local val = clamp(dot / m, -1, 1)
    return math.deg(math.acos(val))
end

keep(RunService.RenderStepped:Connect(function()
    if not FEATURE.Aimbot then return end
    if FEATURE.AIM_HOLD and not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
    if UIS:GetFocusedTextBox() then return end
    safeWaitCamera()
    if not Camera then return end

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
                    local dir = (head.Position - Camera.CFrame.Position)
                    local ang = angleBetweenVectors(Camera.CFrame.LookVector, dir.Unit)
                    if ang < bestAngle and ang <= FEATURE.AIM_FOV_DEG then
                        bestHead = head
                        bestAngle = ang
                    end
                end
            end
        end
    end

    if bestHead and bestHead.Parent then
        local success, err = pcall(function()
            local dir = (bestHead.Position - Camera.CFrame.Position).Unit
            local currentLook = Camera.CFrame.LookVector
            local blended = currentLook:Lerp(dir, clamp(FEATURE.AIM_LERP, 0, 1))
            local pos = Camera.CFrame.Position
            local targetCFrame = CFrame.new(pos, pos + blended)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, clamp(FEATURE.AIM_LERP, 0.05, 0.9))
        end)
        if not success then
            warn("Aimbot camera write error:", err)
            FEATURE.Aimbot = false
            updateHUD("Aimbot", false)
        end
    end
end))

-- === Infinite Ammo Implementation (cleaned & ordered) ===
local ammoConnections = {}
local attrConnections = {}

local function disconnectAmmoConnections()
    for _,c in ipairs(ammoConnections) do
        pcall(function() c:Disconnect() end)
    end
    ammoConnections = {}
    for _,c in ipairs(attrConnections) do
        pcall(function() c:Disconnect() end)
    end
    attrConnections = {}
end

local function forceAmmoValue(valObj)
    pcall(function()
        if valObj:IsA("IntValue") or valObj:IsA("NumberValue") then
            valObj.Value = 9999 -- use large finite number (safer than math.huge)
        end
    end)
end

local function setupGun(gun)
    if not FEATURE.InfiniteAmmo then return end

    -- Lock Ammo NumberValue if present
    local ammo = gun:FindFirstChild("Ammo")
    if ammo and ammo:IsA("NumberValue") then
        forceAmmoValue(ammo)
        local conn = ammo.Changed:Connect(function()
            if FEATURE.InfiniteAmmo then
                pcall(function() ammo.Value = 9999 end)
            end
        end)
        table.insert(ammoConnections, conn)
    end

    -- Set MaxAmmo attribute if present
    pcall(function()
        if gun.GetAttribute and gun.SetAttribute and gun:GetAttribute("MaxAmmo") ~= nil then
            gun:SetAttribute("MaxAmmo", 9999)
        end
    end)

    -- Keep Reloading attribute false if present
    if gun.GetAttribute and gun.SetAttribute then
        if gun:GetAttribute("Reloading") ~= nil then
            gun:SetAttribute("Reloading", false)
            local conn = gun.AttributeChanged:Connect(function(attr)
                if FEATURE.InfiniteAmmo and attr == "Reloading" then
                    pcall(function() gun:SetAttribute("Reloading", false) end)
                end
            end)
            table.insert(attrConnections, conn)
        end
    end
end

-- Safe namecall hook for blocking "reload" remotes (best-effort)
local originalNamecall = nil
local hook_ok = false
local function tryHookNamecall()
    -- Only try if hookmetamethod exists
    if type(hookmetamethod) ~= "function" then return false end
    local ok, ret = pcall(function()
        originalNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            -- avoid intercepting our own calls
            if not checkcaller and not pcall(function() return checkcaller() end) then
                -- if checkcaller not available, still proceed carefully
            end
            local isLocal = false
            pcall(function() isLocal = checkcaller() end)
            if isLocal then
                return originalNamecall(self, ...)
            end

            local method = getnamecallmethod and getnamecallmethod() or ""
            if FEATURE.InfiniteAmmo and method == "FireServer" then
                -- inspect Instance type and name safely
                local okClass, className = pcall(function() return self.ClassName end)
                local okName, nm = pcall(function() return tostring(self.Name) end)
                local lowerName = (okName and nm or ""):lower()
                if okClass and (className == "RemoteEvent" or className == "RemoteFunction") then
                    -- only block remotes that look like reloads
                    if lowerName:find("reload") then
                        -- block by returning nil (best-effort)
                        return nil
                    end
                else
                    -- fallback: if tostring(self) contains 'reload' (rare), block
                    if lowerName:find("reload") then
                        return nil
                    end
                end
            end
            return originalNamecall(self, ...)
        end)
    end)
    hook_ok = ok and (originalNamecall ~= nil)
    return hook_ok
end

-- start/stop infinite ammo helpers
local infiniteLoopConn = nil
local function startInfiniteAmmo()
    if infiniteLoopConn then return end
    -- initial apply to existing tools in Character & Backpack
    pcall(function()
        if LocalPlayer.Character then
            for _,obj in ipairs(LocalPlayer.Character:GetChildren()) do
                if obj:IsA("Tool") then setupGun(obj) end
            end
        end
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if backpack then
            for _,obj in ipairs(backpack:GetChildren()) do
                if obj:IsA("Tool") then setupGun(obj) end
            end
        end
    end)

    -- watch for new tools
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if backpack then
        keep(backpack.ChildAdded:Connect(function(c)
            if c:IsA("Tool") then
                task.wait(0.12)
                setupGun(c)
            end
        end))
    end
    keep(LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        -- apply to new tools
        for _,obj in ipairs(char:GetChildren()) do
            if obj:IsA("Tool") then setupGun(obj) end
        end
        keep(char.ChildAdded:Connect(function(c)
            if c:IsA("Tool") then
                task.wait(0.12)
                setupGun(c)
            end
        end))
    end))

    -- periodic re-scan in case game recreates values
    infiniteLoopConn = keep(RunService.Heartbeat:Connect(function()
        if not FEATURE.InfiniteAmmo then return end
        pcall(function()
            if LocalPlayer.Character then
                for _,obj in ipairs(LocalPlayer.Character:GetChildren()) do
                    if obj:IsA("Tool") then setupGun(obj) end
                end
            end
        end)
    end))

    -- attempt hook (best-effort)
    tryHookNamecall()
end

local function stopInfiniteAmmo()
    FEATURE.InfiniteAmmo = false
    disconnectAmmoConnections()
    if infiniteLoopConn then
        pcall(function() infiniteLoopConn:Disconnect() end)
        infiniteLoopConn = nil
    end
    updateHUD("Infinite Ammo", false)
    -- note: cannot always reliably unhook namecall in all executors; the hook checks FEATURE flag
end

-- Register Toggles (UI + callbacks)
registerToggle("ESP", "ESP", function(state)
    if state then enableESP() else disableESP() end
end)
registerToggle("Auto Press E", "AutoE", function(state)
    if state then startAutoE() else stopAutoE() end
end)
registerToggle("WalkSpeed", "WalkEnabled", function(state)
    if state then
        pcall(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum and not originalWalkSpeed then originalWalkSpeed = hum.WalkSpeed end
        end)
    else
        restoreWalkSpeed()
    end
end)
registerToggle("Aimbot", "Aimbot", function(state)
    -- nothing special on toggle
end)
registerToggle("Infinite Ammo", "InfiniteAmmo", function(state)
    if state then
        FEATURE.InfiniteAmmo = true
        startInfiniteAmmo()
        updateHUD("Infinite Ammo", true)
    else
        stopInfiniteAmmo()
    end
end)

-- Initialize HUD with current states
for k,_ in pairs(FEATURE) do
    local display = nil
    if k == "ESP" then display = "ESP" end
    if k == "AutoE" then display = "Auto Press E" end
    if k == "WalkEnabled" then display = "WalkSpeed" end
    if k == "Aimbot" then display = "Aimbot" end
    if k == "InfiniteAmmo" then display = "Infinite Ammo" end
    if display then updateHUD(display, FEATURE[k]) end
end

-- Hotkeys (F1-F5)
keep(UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.F1 and ToggleCallbacks.ESP then
        ToggleCallbacks.ESP(not FEATURE.ESP)
    elseif input.KeyCode == Enum.KeyCode.F2 and ToggleCallbacks.AutoE then
        ToggleCallbacks.AutoE(not FEATURE.AutoE)
    elseif input.KeyCode == Enum.KeyCode.F3 and ToggleCallbacks.WalkEnabled then
        ToggleCallbacks.WalkEnabled(not FEATURE.WalkEnabled)
    elseif input.KeyCode == Enum.KeyCode.F4 and ToggleCallbacks.Aimbot then
        ToggleCallbacks.Aimbot(not FEATURE.Aimbot)
    elseif input.KeyCode == Enum.KeyCode.F5 and ToggleCallbacks.InfiniteAmmo then
        ToggleCallbacks.InfiniteAmmo(not FEATURE.InfiniteAmmo)
    end
end))

-- Cleanup (character remove & global)
keep(LocalPlayer.CharacterRemoving:Connect(function()
    for p,_ in pairs(espObjects) do clearESPForPlayer(p) end
    -- do not fully clear global listeners here; only stop feature-specific things
    restoreWalkSpeed()
    stopAutoE()
    stopInfiniteAmmo()
end))

-- Ensure we restore walk speed and reapply infinite ammo on respawn
keep(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if FEATURE.WalkEnabled then
        pcall(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum and originalWalkSpeed == nil then originalWalkSpeed = hum.WalkSpeed end
            if hum then hum.WalkSpeed = FEATURE.WalkValue end
        end)
    end
    if FEATURE.InfiniteAmmo then
        task.spawn(function()
            task.wait(0.5)
            startInfiniteAmmo()
        end)
    end
end))

-- Provide a global cleanup hook for re-run in some executors
if _G then
    _G.__TPB_CLEANUP = function()
        for p,_ in pairs(espObjects) do clearESPForPlayer(p) end
        clearConnections()
        pcall(function()
            local g = PlayerGui:FindFirstChild("TPB_TycoonGUI_Final")
            if g then g:Destroy() end
            local gh = PlayerGui:FindFirstChild("TPB_TycoonHUD_Final")
            if gh then gh:Destroy() end
        end)
        restoreWalkSpeed()
        stopAutoE()
        stopInfiniteAmmo()
    end
end

print("✅ TPB Full Script loaded (Clean). Toggles: F1=ESP, F2=AutoE, F3=Walk, F4=Aimbot, F5=InfiniteAmmo. LeftAlt toggles UI/HUD.")
