-- UDHL-DaHood-SilentUI.lua
-- Lade mit:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/Illyrian1111/hihi/main/main.lua", true))()

--// Services
local Players           = game:GetService("Players")
local LocalPlayer       = Players.LocalPlayer
local Camera            = workspace.CurrentCamera
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Remotes
local ShootEvent = ReplicatedStorage:WaitForChild("ShootEvent")

--// Settings
local Settings = {
    FOV         = 50,                       -- Silent‑Aim FOV
    ESP         = {Enabled = false},
    SilentAim   = {Enabled = false},
    Keys        = {ToggleMenu = Enum.KeyCode.T},
}

--// State
local State = {
    Target    = nil,
    ESPBoxes  = {},  -- [player] = Drawing.Square
    UIVisible = false,
}

--// Helpers
local function worldToScreen(pos)
    return Camera:WorldToViewportPoint(pos)
end

local function inFOV(pos)
    local camPos, camLook = Camera.CFrame.Position, Camera.CFrame.LookVector
    local dir   = (pos - camPos).Unit
    local angle = math.deg(math.acos(math.clamp(camLook:Dot(dir), -1, 1)))
    return angle <= Settings.FOV
end

local function getClosest()
    local best, bestAng = nil, Settings.FOV
    local camPos, camLook = Camera.CFrame.Position, Camera.CFrame.LookVector
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character and pl.Character:FindFirstChild("Head") then
            local head = pl.Character.Head
            local dir  = (head.Position - camPos).Unit
            local ang  = math.deg(math.acos(math.clamp(camLook:Dot(dir), -1, 1)))
            if ang < bestAng then
                bestAng, best = ang, pl
            end
        end
    end
    return best
end

--// Silent‑Aim Hook
do
    local mt, old = getrawmetatable(game), nil
    old = mt.__namecall
    setreadonly(mt,false)
    mt.__namecall = newcclosure(function(self, ...)
        local method, args = getnamecallmethod(), {...}
        if not checkcaller()
        and self == ShootEvent
        and method == "FireServer"
        and Settings.SilentAim.Enabled
        and State.Target
        and State.Target.Character
        and State.Target.Character:FindFirstChild("Head") then

            local pos = State.Target.Character.Head.Position
            if inFOV(pos) then args[1] = pos end
        end
        return old(self, unpack(args))
    end)
    setreadonly(mt,true)
end

--// ESP Setup
local function initESP()
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl~=LocalPlayer then
            local box = Drawing.new("Square")
            box.Thickness = 2
            box.Filled    = false
            box.Color     = Color3.fromRGB(255,0,0)
            box.Visible   = false
            State.ESPBoxes[pl] = box
        end
    end
    Players.PlayerAdded:Connect(function(pl)
        if pl~=LocalPlayer then initESP() end
    end)
    Players.PlayerRemoving:Connect(function(pl)
        if State.ESPBoxes[pl] then
            State.ESPBoxes[pl]:Remove()
            State.ESPBoxes[pl] = nil
        end
    end)
end

--// Build Menu UI
local function buildUI()
    local gui = Instance.new("ScreenGui")
    gui.Name         = "SilentAimMenu"
    gui.ResetOnSpawn = false
    gui.Parent       = LocalPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame", gui)
    frame.Size               = UDim2.new(0, 200, 0, 180)
    frame.Position           = UDim2.new(0, 20, 0, 100)
    frame.BackgroundColor3   = Color3.fromRGB(30,30,40)
    frame.BorderSizePixel    = 0

    local function newBtn(text, y, cb)
        local btn = Instance.new("TextButton", frame)
        btn.Size             = UDim2.new(1, -20, 0, 30)
        btn.Position         = UDim2.new(0, 10, 0, y)
        btn.BackgroundColor3 = Color3.fromRGB(50,50,60)
        btn.BorderSizePixel  = 0
        btn.Font             = Enum.Font.GothamBold
        btn.TextSize         = 14
        btn.TextColor3       = Color3.new(1,1,1)
        btn.Text             = text
        btn.MouseButton1Click:Connect(function()
            cb(btn)
        end)
        return btn
    end

    -- Silent‑Aim toggle
    newBtn("Silent Aim: OFF", 10, function(self)
        Settings.SilentAim.Enabled = not Settings.SilentAim.Enabled
        self.Text = "Silent Aim: " .. (Settings.SilentAim.Enabled and "ON" or "OFF")
    end)

    -- ESP toggle
    newBtn("ESP: OFF", 50, function(self)
        Settings.ESP.Enabled = not Settings.ESP.Enabled
        self.Text = "ESP: " .. (Settings.ESP.Enabled and "ON" or "OFF")
    end)

    -- Select Target
    newBtn("Select Target", 90, function()
        State.Target = getClosest()
        targetLabel.Text = "Target: " .. (State.Target and State.Target.Name or "None")
    end)

    -- Target display
    local targetLabel = Instance.new("TextLabel", frame)
    targetLabel.Size                = UDim2.new(1, -20, 0, 25)
    targetLabel.Position            = UDim2.new(0, 10, 0, 130)
    targetLabel.BackgroundTransparency = 1
    targetLabel.Font                = Enum.Font.GothamBold
    targetLabel.TextSize            = 14
    targetLabel.TextColor3          = Color3.new(1,1,1)
    targetLabel.Text                = "Target: None"

    -- Hide UI initially
    gui.Enabled = State.UIVisible

    return gui, targetLabel
end

--// Input: toggle menu
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Settings.Keys.ToggleMenu then
        State.UIVisible = not State.UIVisible
        menu.Enabled    = State.UIVisible
    end
end)

--// Main Loop: ESP & highlight target
RunService.RenderStepped:Connect(function()
    for pl, box in pairs(State.ESPBoxes) do
        local hrp = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
        if Settings.ESP.Enabled and hrp then
            local tl, v1 = worldToScreen(hrp.Position + Vector3.new(-1,3,0))
            local br, v2 = worldToScreen(hrp.Position + Vector3.new( 1,-1,0))
            if v1 and v2 then
                box.Position = Vector2.new(tl.X, tl.Y)
                box.Size     = Vector2.new(br.X - tl.X, br.Y - tl.Y)
                box.Visible  = (hrp.Position - Camera.CFrame.Position).Magnitude <= Settings.ESP.Distance
                box.Color    = (pl == State.Target)
                    and Color3.fromRGB(0,255,0)
                    or Color3.fromRGB(255,0,0)
            else
                box.Visible = false
            end
        else
            box.Visible = false
        end
    end
end)

--// Init
initESP()
local menu, targetLabel = buildUI()
