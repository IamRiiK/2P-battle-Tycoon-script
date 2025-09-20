-- 🔥 QUICK RELOAD SYSTEM
local QuickReloadEnabled = true -- default aktif
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- mapping max ammo (bisa ditambah sesuai kebutuhan)
local MaxAmmoMap = {
    ["SMG"] = 30,
    ["Sniper"] = 1,
    ["Railgun"] = 3
}

-- toggle dengan F5
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.F5 then
        QuickReloadEnabled = not QuickReloadEnabled
        warn("⚡ QuickReload: " .. tostring(QuickReloadEnabled))
    end
end)

-- cari ammo value dari tool
local function getAmmoValue(tool)
    if tool and tool:FindFirstChild("Ammo") and tool.Ammo:IsA("NumberValue") then
        return tool.Ammo
    end
    return nil
end

-- fungsi quick reload
local function quickReload(tool)
    local ammoVal = getAmmoValue(tool)
    if ammoVal then
        local maxAmmo = MaxAmmoMap[tool.Name] or ammoVal.Value
        ammoVal.Value = maxAmmo
        warn("⚡ QuickReload: " .. tool.Name .. " -> refill " .. maxAmmo)
    end
end

-- deteksi tombol reload bawaan (R)
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.R then
        local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if tool and QuickReloadEnabled then
            -- blokir reload bawaan, ganti quick reload
            quickReload(tool)
        end
    end
end)

-----------------------------------------------------------------
-- 🔽 SISA SCRIPT UTAMAMU 🔽
-- 2P Battle Tycoon — Full Fixed Script (Final v3)
-- Dark UI + HUD (show only when UI hidden) + ESP (team auto-update, fixed respawn) + AutoE + WalkSpeed + Aimbot (FOV=8, LERP=0.4)
-- Hotkeys: F1=ESP, F2=AutoE, F3=Walk toggle, F4=A
-- ... (lanjutkan semua kode utamamu di sini, tanpa diubah) ...
-- 2P Battle Tycoon — Full Fixed Script (Final v3 + Instant QuickReload Universal)
-- Dark UI + HUD (show only when UI hidden) + ESP (team auto-update, fixed respawn) + AutoE + WalkSpeed + Aimbot (FOV=8, LERP=0.4) + Instant QuickReload (fire all reload remotes)
-- Hotkeys: F1=ESP, F2=AutoE, F3=Walk toggle, F4=Aimbot toggle, F5=QuickReload toggle, LeftAlt=Toggle UI/HUD, R=QuickReload
--Credit to RiiK @RiiK26--

-- Ensure game loaded
if not game:IsLoaded() then game.Loaded:Wait() end

-- ==========
-- Services
-- ==========
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Safe camera reference
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
    QuickReload = false,
    ReloadDelay = 0.05, -- very small delay for instant feel
}

-- ==========
-- Helpers
-- ==========
local function safeParentGui(gui)
    gui.ResetOnSpawn = false
    local ok = pcall(function() gui.Parent = PlayerGui end)
    if not ok then
        pcall(function() gui.Parent = game:GetService("CoreGui") end)
    end
end

local function safeWaitCamera()
    if not (Workspace.CurrentCamera or Camera) then
        local ok, cam = pcall(function() return Workspace:WaitForChild("CurrentCamera", 5) end)
        if ok and cam then
            Camera = cam
        else
            Camera = Workspace.CurrentCamera
        end
    else
        Camera = Workspace.CurrentCamera or Camera
    end
end

local function findMaxAmmoFromTool(tool)
    -- try to find explicit max ammo fields
    local candidates = {"MaxAmmo", "Max", "Capacity", "MagazineSize", "ClipSize"}
    for _,name in ipairs(candidates) do
        local v = tool:FindFirstChild(name, true)
        if v and (v:IsA("NumberValue") or v:IsA("IntValue")) then
            return tonumber(v.Value)
        end
    end
    -- fallback: look for any NumberValue descendant with 'max'/'cap'/'mag' in name
    for _,v in ipairs(tool:GetDescendants()) do
        if (v:IsA("NumberValue") or v:IsA("IntValue")) then
            local n = v.Name:lower()
            if n:find("max") or n:find("cap") or n:find("mag") or n:find("clip") then
                return tonumber(v.Value)
            end
        end
    end
    -- final fallback: common default
    return 30
end

-- ==========
-- Build UI
-- ==========
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TPB_TycoonGUI_Final"
ScreenGui.DisplayOrder = 9999
safeParentGui(ScreenGui)

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0,360,0,460)
MainFrame.Position = UDim2.new(0.28,0,0.18,0)
MainFrame.BackgroundColor3 = Color3.fromRGB(28,28,30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0,12)

local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.Size = UDim2.new(1,0,0,40)
TitleBar.BackgroundColor3 = Color3.fromRGB(42,42,45)
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0,12)

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
Content.Size = UDim2.new(1,-16,1,-56)
Content.Position = UDim2.new(0,8,0,48)
Content.BackgroundTransparency = 1

local UIList = Instance.new("UIListLayout", Content)
UIList.Padding = UDim.new(0,12)

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Content.Visible = not minimized
    MinBtn.Text = minimized and "+" or "-"
end)

-- HUD
local HUDGui = Instance.new("ScreenGui")
HUDGui.Name = "TPB_TycoonHUD_FINAL"
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
    hudLabels[name] = l
end

hudAdd("ESP")
hudAdd("Auto Press E")
hudAdd("WalkSpeed")
hudAdd("Aimbot")
hudAdd("Quick Reload")

local function updateHUD(name, state)
    if hudLabels[name] then
        hudLabels[name].Text = name .. ": " .. (state and "ON" or "OFF")
        hudLabels[name].TextColor3 = state and Color3.fromRGB(80,200,120) or Color3.fromRGB(200,200,200)
    end
end

-- LeftAlt toggle UI/HUD (kept separate to avoid interfering)
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.LeftAlt then
        MainFrame.Visible = not MainFrame.Visible
        HUD.Visible = not MainFrame.Visible
    end
end)

-- ==========
-- Quick Reload (manual + instant auto loop will use FEATURE.QuickReload)
-- Inserted here so updateHUD and UI exist
-- ==========
-- tabel max ammo per senjata
local MaxAmmo = {
    SMG = 30,
    Sniper = 1,
    Railgun = 3,
}

-- fungsi deteksi tool & ammo value (gunakan LocalPlayer)
local function getCurrentToolAmmo()
    local char = LocalPlayer.Character or workspace:FindFirstChild(LocalPlayer.Name)
    if not char then return end

    for _, tool in ipairs(char:GetChildren()) do
        local ammo = tool:FindFirstChild("Ammo")
        if ammo and ammo:IsA("NumberValue") then
            return tool, ammo
        end
    end
end

-- fungsi kirim semua RemoteEvent di Tool yang berisi kata 'reload'
local function fireAllReloadRemotes(tool)
    if not tool then return end
    for _, obj in ipairs(tool:GetDescendants()) do
        if obj:IsA("RemoteEvent") and string.find(obj.Name:lower(), "reload") then
            pcall(function() obj:FireServer() end)
            print("📡 FireServer ke Remote:", obj:GetFullName())
        end
    end
    -- juga cek direct children (in case name exactly 'Reload')
    for _, obj in ipairs(tool:GetChildren()) do
        if obj:IsA("RemoteEvent") and string.find(obj.Name:lower(), "reload") then
            pcall(function() obj:FireServer() end)
            print("📡 FireServer ke Remote:", obj:GetFullName())
        end
    end
end

-- fungsi quick reload manual (R)
local function quickReloadManual()
    local tool, ammo = getCurrentToolAmmo()
    if tool and ammo then
        local max = MaxAmmo[tool.Name] or findMaxAmmoFromTool(tool)
        if max then
            pcall(function() ammo.Value = max end)
            print("⚡ QuickReload manual:", tool.Name, "->", ammo.Value)

            -- kirim semua remote reload yang relevan agar server unlock reload
            pcall(function() fireAllReloadRemotes(tool) end)
        end
    end
end

-- fungsi stop animasi reload
local function stopReloadAnimation()
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
        local anim = track.Animation
        if anim and string.lower(anim.Name):find("reload") then
            pcall(function() track:Stop() end)
            print("🛑 Reload animation dibatalkan:", anim.Name)
        end
    end
end

-- hook input: F5 toggle (sync ke FEATURE & HUD), R for manual reload
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end

    if input.KeyCode == Enum.KeyCode.F5 then
        FEATURE.QuickReload = not FEATURE.QuickReload
        updateHUD("Quick Reload", FEATURE.QuickReload)
        print("🔀 QuickReload:", FEATURE.QuickReload and "ON" or "OFF")
        if FEATURE.QuickReload then
            -- start the instant reload loop (the function defined later will check FEATURE.QuickReload)
            pcall(function() instantReloadLoop() end)
        end
    end

    if FEATURE.QuickReload and input.KeyCode == Enum.KeyCode.R then
        quickReloadManual()
        stopReloadAnimation()
    end
end)

-- ==========
-- Toggle helper
-- ==========
local ToggleCallbacks = {}
local Buttons = {}
local displayNameFor = {}

local function registerToggle(displayName, featureKey, onChange)
    displayNameFor[featureKey] = displayName
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
        if type(onChange) == "function" then
            pcall(onChange, state)
        end
    end

    btn.MouseEnter:Connect(function()
        pcall(function()
            TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(46,46,46)}):Play()
        end)
    end)
    btn.MouseLeave:Connect(function()
        pcall(function()
            TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = FEATURE[featureKey] and Color3.fromRGB(80,150,220) or Color3.fromRGB(36,36,36)}):Play()
        end)
    end)
    btn.MouseButton1Click:Connect(function()
        setState(not FEATURE[featureKey])
    end)

    ToggleCallbacks[featureKey] = setState
    Buttons[featureKey] = btn
    return btn
end

-- ==========
-- WalkSpeed input
-- ==========
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

-- ==========
-- ESP System (Box ESP dengan Highlight)
-- ==========
local espObjects = {}

local function clearESP(p)
    if espObjects[p] then
        for _,v in pairs(espObjects[p]) do
            if v and v.Parent then v:Destroy() end
        end
        espObjects[p] = nil
    end
end

local function createESP(p)
    clearESP(p)
    if not p.Character then return end
    local root = p.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local hl = Instance.new("Highlight")
    hl.Name = "BoxESP"
    hl.Adornee = p.Character
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.OutlineTransparency = 0
    hl.OutlineColor = Color3.fromRGB(255,255,255)
    hl.FillTransparency = 0.25

    if p.Team and LocalPlayer.Team then
        if p.Team == LocalPlayer.Team then
            hl.FillColor = Color3.fromRGB(0,255,0)
        else
            hl.FillColor = Color3.fromRGB(255,0,0)
        end
    else
        hl.FillColor = Color3.fromRGB(255,255,0)
    end

    hl.Parent = p.Character
    espObjects[p] = {hl}
end

local function refreshESPForPlayer(p)
    if FEATURE.ESP then
        createESP(p)
    else
        clearESP(p)
    end
end

local function enableESP()
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            refreshESPForPlayer(p)
            p.CharacterAdded:Connect(function()
                task.wait(0.5)
                refreshESPForPlayer(p)
            end)
        end
    end
    Players.PlayerAdded:Connect(function(p)
        if p ~= LocalPlayer then
            p.CharacterAdded:Connect(function()
                task.wait(0.5)
                refreshESPForPlayer(p)
            end)
            refreshESPForPlayer(p)
        end
    end)
    Players.PlayerRemoving:Connect(function(p)
        clearESP(p)
    end)
end

local function disableESP()
    for p,_ in pairs(espObjects) do
        clearESP(p)
    end
end

-- ==========
-- Auto Press E
-- ==========
local autoEThread = nil
local function startAutoE()
    if autoEThread then return end
    autoEThread = task.spawn(function()
        while FEATURE.AutoE do
            pcall(function()
                if VIM then
                    VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                end
            end)
            task.wait(math.clamp(FEATURE.AutoEInterval or 0.5, 0.05, 5))
        end
        autoEThread = nil
    end)
end

-- ==========
-- Walk Speed
-- ==========
RunService.Heartbeat:Connect(function()
    if FEATURE.WalkEnabled then
        pcall(function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
                LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = FEATURE.WalkValue
            end
        end)
    end
end)

-- ==========
-- Aimbot
-- ==========
local function angleTo(a, b)
    local dot = a:Dot(b)
    local mag = math.max((a.Magnitude*b.Magnitude),1e-6)
    local val = math.clamp(dot/mag, -1,1)
    return math.deg(math.acos(val))
end

RunService.RenderStepped:Connect(function()
    if not FEATURE.Aimbot then return end
    safeWaitCamera()
    if not Camera then return end

    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local best, bestAngle = nil, 1e9
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Team and LocalPlayer.Team and p.Team ~= LocalPlayer.Team and p.Character and p.Character:FindFirstChild("Head") then
            local head = p.Character.Head
            local dir = (head.Position - Camera.CFrame.Position).Unit
            local ang = angleTo(Camera.CFrame.LookVector, dir)
            if ang < bestAngle and ang <= FEATURE.AIM_FOV_DEG then
                best, bestAngle = head, ang
            end
        end
    end
    if best then
        local dir = (best.Position - Camera.CFrame.Position).Unit
        local newLook = Camera.CFrame.LookVector:Lerp(dir, FEATURE.AIM_LERP)
        local pos = Camera.CFrame.Position
        Camera.CFrame = CFrame.new(pos, pos + newLook)
    end
end)

-- ==========
-- Instant Quick Reload (final) — uses fireAllReloadRemotes as fallback
-- ==========
local function instantReloadLoop()
    task.spawn(function()
        while FEATURE.QuickReload do
            pcall(function()
                local char = LocalPlayer.Character
                if not char then return end
                local tool = char:FindFirstChildOfClass("Tool")
                if not tool then return end

                local ammo = tool:FindFirstChild("Ammo")
                -- local reloadRemote = tool:FindFirstChild("Reload") -- no longer required; using fireAllReloadRemotes

                if ammo and ammo:IsA("NumberValue") then
                    if ammo.Value <= 0 then
                        local maxAmmo = findMaxAmmoFromTool(tool) or 30
                        -- set client-side ammo instantly (cancel animasi reload)
                        pcall(function() ammo.Value = maxAmmo end)

                        -- call remote(s) to sync server-side reload if available (call any reload-like RemoteEvent)
                        pcall(function() fireAllReloadRemotes(tool) end)

                        -- small delay to avoid tight spam
                        task.wait(FEATURE.ReloadDelay or 0.05)
                    end
                end
            end)
            task.wait(0.04)
        end
    end)
end

-- ==========
-- Register Toggles
-- ==========
registerToggle("ESP", "ESP", function(state)
    if state then enableESP() else disableESP() end
end)
registerToggle("Auto Press E", "AutoE", function(state)
    if state then startAutoE() end
end)
registerToggle("WalkSpeed", "WalkEnabled")
registerToggle("Aimbot", "Aimbot")
registerToggle("Quick Reload", "QuickReload", function(state)
    if state then instantReloadLoop() end
end)

-- ==========
-- Hotkeys (kept for backwards compatibility)
-- ==========
UIS.InputBegan:Connect(function(input,gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.F1 then
        ToggleCallbacks.ESP(not FEATURE.ESP)
    elseif input.KeyCode == Enum.KeyCode.F2 then
        ToggleCallbacks.AutoE(not FEATURE.AutoE)
    elseif input.KeyCode == Enum.KeyCode.F3 then
        ToggleCallbacks.WalkEnabled(not FEATURE.WalkEnabled)
    elseif input.KeyCode == Enum.KeyCode.F4 then
        ToggleCallbacks.Aimbot(not FEATURE.Aimbot)
    elseif input.KeyCode == Enum.KeyCode.F5 then
        ToggleCallbacks.QuickReload(not FEATURE.QuickReload)
    end
end)

-- ==========
-- Cleanup on unload / character remove
-- ==========
Players.PlayerRemoving:Connect(function(p)
    if espObjects[p] then clearESP(p) end
end)

LocalPlayer.CharacterRemoving:Connect(function()
    -- Clear local esp objects on respawn
    for p,_ in pairs(espObjects) do
        clearESP(p)
    end
end)

-- End of script
