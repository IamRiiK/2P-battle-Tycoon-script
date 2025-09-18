local Library = loadstring(Game:HttpGet("https://raw.githubusercontent.com/bloodball/-back-ups-for-libs/main/wizard"))()

local PhantomForcesWindow = Library:NewWindow("RiiK")

local KillingCheats = PhantomForcesWindow:NewSection("Speed")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

local tspeed = 0
local minSpeed = 0
local maxSpeed = 100
local hb = game:GetService("RunService").Heartbeat
local tpwalking = true
local player = game:GetService("Players")
local lplr = player.LocalPlayer
local hum

local function isNumber(str)
    return tonumber(str) ~= nil or str == 'inf'
end

local function adjustSpeed(newSpeed)
    if isNumber(newSpeed) then
        local speedValue = tonumber(newSpeed)
        if speedValue < minSpeed then
            tspeed = minSpeed
        elseif speedValue > maxSpeed then
            tspeed = maxSpeed
        else
            tspeed = speedValue
        end
    end
end

local function setupCharacter()
    local chr = lplr.Character or lplr.CharacterAdded:Wait()
    hum = chr:WaitForChild("Humanoid")

    -- Reemplazo de input field por KillingCheats:CreateTextbox
    KillingCheats:CreateTextbox("Speed", function(text)
        adjustSpeed(text)
    end)

    -- Bucle de movimiento
    spawn(function() -- Usar spawn para permitir que el bucle funcione en paralelo
        while tpwalking and hb:Wait() and chr and hum and hum.Parent do
            if hum.MoveDirection.Magnitude > 0 then
                local adjustedSpeed = tspeed * 0.2  -- Aumenta el multiplicador para velocidad mínima
                chr:TranslateBy(hum.MoveDirection * adjustedSpeed)
            end
        end
    end)
end

-- Configurar el personaje al iniciar
setupCharacter()

-- Conectar la función al evento CharacterAdded
lplr.CharacterAdded:Connect(function()
    -- Esperar que el nuevo personaje se configure antes de ejecutar
    wait(0.5)  -- Espera un breve momento para asegurar que el personaje se cargue
    setupCharacter()



local KillingCheats = PhantomForcesWindow:NewSection("Automátic")
KillingCheats:CreateButton("AutoClick", function(value)

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
