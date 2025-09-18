-- LocalScript: Speedhack + Auto "E" Click (Client-side only)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

-- GUI references
local frame = script.Parent
local speedInput = frame:WaitForChild("SpeedInput")
local applyBtn = frame:WaitForChild("ApplySpeedBtn")
local autoToggleBtn = frame:WaitForChild("AutoClickToggleBtn")

-- Config
local MIN_SPEED = 1
local MAX_SPEED = 50
local DEFAULT_SPEED = 16
local AUTO_INTERVAL = 0.6 -- 600ms

-- State
local autoClicking = false
local autoCoroutine = nil

-- Helper: sanitize numeric input
local function sanitizeSpeed(txt)
    local digits = txt:gsub("%D", "")
    if digits == "" then return DEFAULT_SPEED end
    local num = tonumber(digits) or DEFAULT_SPEED
    if num < MIN_SPEED then num = MIN_SPEED end
    if num > MAX_SPEED then num = MAX_SPEED end
    return num
end

-- Keep Humanoid updated when respawn
local currentSpeed = DEFAULT_SPEED
local function applySpeed(speed)
    currentSpeed = speed
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = speed
        end
    end
end

player.CharacterAdded:Connect(function(char)
    char:WaitForChild("Humanoid", 5)
    applySpeed(currentSpeed)
end)

-- Input filter: hanya angka
speedInput:GetPropertyChangedSignal("Text"):Connect(function()
    local digits = speedInput.Text:gsub("%D", "")
    if speedInput.Text ~= digits then
        speedInput.Text = digits
    end
end)

-- Apply speed
applyBtn.MouseButton1Click:Connect(function()
    local num = sanitizeSpeed(speedInput.Text)
    applySpeed(num)
    applyBtn.Text = "Applied: " .. tostring(num)
    task.delay(0.8, function()
        if applyBtn and applyBtn.Parent then
            applyBtn.Text = "Apply Speed"
        end
    end)
end)

-- Auto-click loop
local function startAutoClick()
    if autoClicking then return end
    autoClicking = true
    autoToggleBtn.Text = "Auto E: ON"

    autoCoroutine = coroutine.create(function()
        while autoClicking do
            -- simulate press E
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.05) -- short hold
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)

            -- wait interval
            local t0 = tick()
            while tick() - t0 < AUTO_INTERVAL do
                if not autoClicking then break end
                RunService.Heartbeat:Wait()
            end
        end
    end)
    coroutine.resume(autoCoroutine)
end

local function stopAutoClick()
    autoClicking = false
    autoToggleBtn.Text = "Auto E: OFF"
end

autoToggleBtn.MouseButton1Click:Connect(function()
    if autoClicking then
        stopAutoClick()
    else
        startAutoClick()
    end
end)

-- Init
speedInput.Text = tostring(DEFAULT_SPEED)
applyBtn.Text = "Apply Speed"
autoToggleBtn.Text = "Auto E: OFF"
