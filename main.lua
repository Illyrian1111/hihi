-- UDHL-DaHood-SilentOnly.lua
-- Einbinden via:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/Illyrian1111/uwu/main/main.lua", true))()

--// Services
local Players          = game:GetService("Players")
local LocalPlayer      = Players.LocalPlayer
local Camera           = workspace.CurrentCamera
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage= game:GetService("ReplicatedStorage")

--// Shoot‑Remote in DaHood
local ShootEvent = ReplicatedStorage:WaitForChild("ShootEvent")

--// Settings
local Settings = {
    FOV          = 50,                     -- Silent‑Aim FOV in Grad
    ESP = {
        Enabled     = true,                -- ESP immer an
        DefaultColor= Color3.fromRGB(255,0,0),
        TargetColor = Color3.fromRGB(0,255,0),
        Distance    = 1000,
    },
    Keys = {
        SelectTarget = Enum.KeyCode.E,     -- Ziel wählen
    }
}

--// State
local State = {
    Target   = nil,    -- aktuell ausgewähltes Ziel
    ESPBoxes = {},     -- [player] = Drawing.Square
}

--// Hilfsfunktion: Welt → Bildschirmkoordinaten
local function worldToScreen(pos)
    return Camera:WorldToViewportPoint(pos)
end

--// Findet den nächsten Spieler im FOV
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

--// Silent‑Aim Hook: überschreibt jeden Schuss auf State.Target
do
    local mt   = getrawmetatable(game)
    local old  = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method, args = getnamecallmethod(), {...}
        if not checkcaller()
        and self == ShootEvent
        and method == "FireServer"
        and State.Target
        and State.Target.Character
        and State.Target.Character:FindFirstChild("Head") then

            local pos = State.Target.Character.Head.Position
            -- wenn Ziel im FOV, dann override
            local camLook = Camera.CFrame.LookVector
            local dir     = (pos - Camera.CFrame.Position).Unit
            local ang     = math.deg(math.acos(math.clamp(camLook:Dot(dir), -1,1)))
            if ang <= Settings.FOV then
                args[1] = pos
            end
        end
        return old(self, unpack(args))
    end)
    setreadonly(mt, true)
end

--// ESP einrichten
local function initESP()
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer then
            local box = Drawing.new("Square")
            box.Thickness = 2
            box.Filled    = false
            box.Color     = Settings.ESP.DefaultColor
            box.Visible   = false
            State.ESPBoxes[pl] = box
        end
    end
    Players.PlayerAdded:Connect(function(pl)
        if pl ~= LocalPlayer then
            local box = Drawing.new("Square")
            box.Thickness = 2
            box.Filled    = false
            box.Color     = Settings.ESP.DefaultColor
            box.Visible   = false
            State.ESPBoxes[pl] = box
        end
    end)
    Players.PlayerRemoving:Connect(function(pl)
        if State.ESPBoxes[pl] then
            State.ESPBoxes[pl]:Remove()
            State.ESPBoxes[pl] = nil
        end
    end)
end

--// Ziel‑Auswahl per E
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Settings.Keys.SelectTarget then
        State.Target = getClosest()
    end
end)

--// Haupt‑Render‑Loop: ESP‑Updates & Target‑Highlight
RunService.RenderStepped:Connect(function()
    for pl, box in pairs(State.ESPBoxes) do
        local hrp = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
        if Settings.ESP.Enabled and hrp then
            local tl, vis1 = worldToScreen(hrp.Position + Vector3.new(-1,3,0))
            local br, vis2 = worldToScreen(hrp.Position + Vector3.new( 1,-1,0))
            if vis1 and vis2 then
                local w,h = br.X - tl.X, br.Y - tl.Y
                box.Position = Vector2.new(tl.X, tl.Y)
                box.Size     = Vector2.new(w, h)
                box.Visible  = (hrp.Position - Camera.CFrame.Position).Magnitude <= Settings.ESP.Distance
                -- Ziel farblich hervorheben
                if pl == State.Target then
                    box.Color = Settings.ESP.TargetColor
                else
                    box.Color = Settings.ESP.DefaultColor
                end
            else
                box.Visible = false
            end
        else
            box.Visible = false
        end
    end
end)

--// Initialisierung
initESP()
