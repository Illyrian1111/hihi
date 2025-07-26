-- UDHL-DaHood.lua (Silent‑Aim Version)
-- Einbinden via:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/Illyrian1111/uwu/main/main.lua"))()

--// Services
local Players          = game:GetService("Players")
local LocalPlayer      = Players.LocalPlayer
local Camera           = workspace.CurrentCamera
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage= game:GetService("ReplicatedStorage")

--// Remotes
local ShootEvent = ReplicatedStorage:WaitForChild("ShootEvent")

--// Settings
local Settings = {
    Aimbot = {
        Enabled     = false,                    -- Silent‑Aim on/off
        Key         = Enum.KeyCode.Q,           -- Toggle Silent‑Aim
        SwitchKey   = Enum.KeyCode.E,           -- Neues Ziel im FOV wählen
        FOV         = 60,                       -- FOV in Grad
        Prediction  = 0.15,
        AimPart     = "Head",                   -- "Head" oder "HumanoidRootPart"
    },
    ESP = {
        Enabled     = false,
        BoxColor    = Color3.fromRGB(255,0,0),
        Distance    = 1000,
    },
    UI = {
        ToggleKey   = Enum.KeyCode.T,
    }
}

--// State
local State = {
    Target      = nil,
    ESPData     = {},   -- [player] = { box, nameText }
    UIVisible   = true,
}

--// Helper: World -> Screen
local function worldToScreen(pos)
    return Camera:WorldToViewportPoint(pos)
end

--// Ziel im FOV finden
local function inFOV(pos)
    local camPos, camLook = Camera.CFrame.Position, Camera.CFrame.LookVector
    local dir = (pos - camPos).Unit
    local angle = math.deg(math.acos(math.clamp(camLook:Dot(dir), -1,1)))
    return angle <= Settings.Aimbot.FOV
end

local function getClosest()
    local best, bestAng = nil, Settings.Aimbot.FOV
    local camPos, camLook = Camera.CFrame.Position, Camera.CFrame.LookVector
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character and pl.Character:FindFirstChild(Settings.Aimbot.AimPart) then
            local part = pl.Character[Settings.Aimbot.AimPart]
            local dir  = (part.Position - camPos).Unit
            local ang  = math.deg(math.acos(math.clamp(camLook:Dot(dir), -1,1)))
            if ang < bestAng then
                bestAng, best = ang, pl
            end
        end
    end
    return best
end

--// Silent‑Aim Hook
do
    local mt     = getrawmetatable(game)
    local old    = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args   = {...}
        if not checkcaller()
        and self == ShootEvent
        and method == "FireServer"
        and Settings.Aimbot.Enabled
        and State.Target
        and State.Target.Character
        and State.Target.Character:FindFirstChild(Settings.Aimbot.AimPart) then

            local pos = State.Target.Character[Settings.Aimbot.AimPart].Position
            if inFOV(pos) then
                args[1] = pos
            end
        end
        return old(self, unpack(args))
    end)
    setreadonly(mt, true)
end

--// ESP + UI (dein existierender Code, unverändert)

local function initESP()
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer then
            local box = Drawing.new("Square")
            box.Color     = Settings.ESP.BoxColor
            box.Thickness = 2
            box.Filled    = false
            box.Visible   = false

            local nameText = Drawing.new("Text")
            nameText.Text    = pl.Name
            nameText.Size    = 14
            nameText.Center  = true
            nameText.Color   = Settings.ESP.BoxColor
            nameText.Visible = false

            State.ESPData[pl] = { box = box, nameText = nameText }
        end
    end
    Players.PlayerAdded:Connect(function(pl)
        if pl ~= LocalPlayer then
            local box = Drawing.new("Square")
            box.Color     = Settings.ESP.BoxColor
            box.Thickness = 2
            box.Filled    = false
            box.Visible   = false

            local nameText = Drawing.new("Text")
            nameText.Text    = pl.Name
            nameText.Size    = 14
            nameText.Center  = true
            nameText.Color   = Settings.ESP.BoxColor
            nameText.Visible = false

            State.ESPData[pl] = { box = box, nameText = nameText }
        end
    end)
    Players.PlayerRemoving:Connect(function(pl)
        local d = State.ESPData[pl]
        if d then
            d.box:Remove()
            d.nameText:Remove()
            State.ESPData[pl] = nil
        end
    end)
end

local function buildUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "UDHL_DaHood_UI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 150)
    frame.Position = UDim2.new(0, 20, 0, 100)
    frame.BackgroundColor3 = Color3.fromRGB(25,25,35)
    frame.BackgroundTransparency = 0.3
    frame.Parent = screenGui

    local function newBtn(text, y, cb)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -10, 0, 25)
        btn.Position = UDim2.new(0, 5, 0, y)
        btn.BackgroundTransparency = 0.2
        btn.BorderSizePixel = 0
        btn.Text = text
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Parent = frame
        btn.MouseButton1Click:Connect(function()
            cb(btn)
        end)
        return btn
    end

    newBtn("SilentAim: OFF", 10, function(self)
        Settings.Aimbot.Enabled = not Settings.Aimbot.Enabled
        self.Text = "SilentAim: " .. (Settings.Aimbot.Enabled and "ON" or "OFF")
        if not Settings.Aimbot.Enabled then
            State.Target = nil
        end
    end)

    newBtn("ESP: OFF", 45, function(self)
        Settings.ESP.Enabled = not Settings.ESP.Enabled
        self.Text = "ESP: " .. (Settings.ESP.Enabled and "ON" or "OFF")
    end)

    newBtn("Aim Part: Head", 80, function(self)
        Settings.Aimbot.AimPart = (Settings.Aimbot.AimPart == "Head") and "HumanoidRootPart" or "Head"
        self.Text = "Aim Part: " .. Settings.Aimbot.AimPart
    end)

    return screenGui
end

--// FOV‑Circle (optional)
local fovCircle = Drawing.new("Circle")
fovCircle.NumSides     = 64
fovCircle.Radius       = Settings.Aimbot.FOV
fovCircle.Thickness    = 1
fovCircle.Transparency = 0.7
fovCircle.Color        = Color3.fromRGB(255,50,50)
fovCircle.Visible      = false

--// Initialization
initESP()
local ui = buildUI()

--// Input Handling
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    local key = input.KeyCode
    if key == Settings.Aimbot.Key then
        -- beim Q einfach das nächste Ziel picken
        State.Target = getClosest()
    elseif key == Settings.Aimbot.SwitchKey then
        State.Target = getClosest()
    elseif key == Settings.UI.ToggleKey then
        State.UIVisible = not State.UIVisible
        ui.Enabled = State.UIVisible
    end
end)

--// Main Loop
RunService.RenderStepped:Connect(function()
    -- FOV‑Circle
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    fovCircle.Visible  = Settings.Aimbot.Enabled
    fovCircle.Radius   = Settings.Aimbot.FOV

    -- ESP
    for pl, data in pairs(State.ESPData) do
        local box, nameText = data.box, data.nameText
        local root = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
        if Settings.ESP.Enabled and root then
            local tl,vis1 = worldToScreen(root.Position + Vector3.new(-1,3,0))
            local br,vis2 = worldToScreen(root.Position + Vector3.new(1,-1,0))
            if vis1 and vis2 then
                local w,h = br.X-tl.X, br.Y-tl.Y
                box.Position = Vector2.new(tl.X, tl.Y)
                box.Size     = Vector2.new(w, h)
                box.Visible  = (root.Position - Camera.CFrame.Position).Magnitude <= Settings.ESP.Distance

                nameText.Position = Vector2.new(tl.X + w/2, tl.Y - 2)
                nameText.Visible  = box.Visible
            else
                box.Visible, nameText.Visible = false, false
            end
        else
            box.Visible, nameText.Visible = false, false
        end
    end
end)

