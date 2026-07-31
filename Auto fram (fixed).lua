-- Auto fram (fixed)
-- Helper patch: stable pull/unpull, presence marking, and small admin panel
-- This file is non-destructive and safe to run alongside the original script.

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- ========== Presence setup ==========
local PRESENCE_FOLDER_NAME = "AMT_Presence"
local presenceFolder = RS:FindFirstChild(PRESENCE_FOLDER_NAME)
if not presenceFolder then
    presenceFolder = Instance.new("Folder")
    presenceFolder.Name = PRESENCE_FOLDER_NAME
    presenceFolder.Parent = RS
end

-- Mark this player as active (script enabled)
local myPresence = presenceFolder:FindFirstChild(LocalPlayer.Name)
if not myPresence then
    myPresence = Instance.new("BoolValue")
    myPresence.Name = LocalPlayer.Name
    myPresence.Value = true
    myPresence.Parent = presenceFolder
else
    myPresence.Value = true
end

-- Clean up on exit
LocalPlayer.AncestryChanged:Connect(function(_, parent)
    if not parent then
        pcall(function() if myPresence and myPresence.Parent then myPresence:Destroy() end end)
    end
end)
game:BindToClose(function()
    pcall(function() if myPresence and myPresence.Parent then myPresence:Destroy() end end)
end)

-- ========== Pull / Unpull implementation ==========
local PulledPlayers = {}
local function safeSetPartAnchored(part, anchored)
    pcall(function() part.Anchored = anchored end)
end

local function restorePlayerState(player)
    pcall(function()
        if not player or not player.Character then return end
        for _, part in ipairs(player.Character:GetChildren()) do
            if part:IsA("BasePart") then
                safeSetPartAnchored(part, false)
            end
        end
        local hum = player.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.PlatformStand = false
            hum.WalkSpeed = 16
            hum.JumpPower = 50
        end
    end)
    PulledPlayers[player] = nil
end

local function unpullAllPlayers()
    for p, _ in pairs(PulledPlayers) do
        restorePlayerState(p)
    end
    PulledPlayers = {}
    -- attempt to notify original UI if it exists
    pcall(function()
        local gui = CoreGui:FindFirstChild("AMT_FarmerKiller") or (LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("AMT_FarmerKiller"))
        if gui and gui:FindFirstChild("LogText") then
            local lab = gui:FindFirstChild("LogText")
            lab.Text = "• أعدت الحالة لجميع اللاعبين المسحوبين"
        end
    end)
end

local function pullAllPlayers()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local pos = root.Position
    local rootCFrame = root.CFrame
    local index = 0

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if targetRoot and hum and hum.Health > 0 then
                local row = math.floor(index / 4)
                local col = index % 4
                local offsetX = (col - 1.5) * 1.4
                local offsetZ = row * 1.6 + 2.2
                local offsetVec = rootCFrame:VectorToWorldSpace(Vector3.new(offsetX, 0, offsetZ))
                local targetPos = pos + offsetVec + Vector3.new(0, 2, 0)

                pcall(function()
                    targetRoot.CFrame = CFrame.new(targetPos)
                    task.wait(0.03)
                    for _, part in ipairs(player.Character:GetChildren()) do
                        if part:IsA("BasePart") then
                            safeSetPartAnchored(part, true)
                        end
                    end
                    if hum then
                        hum.WalkSpeed = 0
                        hum.JumpPower = 0
                        hum.PlatformStand = true
                    end
                    PulledPlayers[player] = true
                end)
                index = index + 1
                task.wait(0.02)
            end
        end
    end

    -- simple in-game notification (non-destructive)
    pcall(function()
        local gui = CoreGui:FindFirstChild("AMT_FarmerKiller") or (LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("AMT_FarmerKiller"))
        if gui and gui:FindFirstChild("LogText") then
            local lab = gui:FindFirstChild("LogText")
            lab.Text = "• تم محاولة سحب " .. tostring(index) .. " لاعب(ين)"
        end
    end)
end

-- Keyboard toggles to control pull/unpull locally
local UIS = game:GetService("UserInputService")
local pulling = false
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.P then -- toggle pull
        pulling = not pulling
        if pulling then
            pullAllPlayers()
        else
            unpullAllPlayers()
        end
    elseif input.KeyCode == Enum.KeyCode.U then
        unpullAllPlayers()
    end
end)

-- ========== Admin Panel (non-destructive) ==========
-- Only visible to a viewer (the same name used in original script)
local VIEWER_NAME = "tegrugjvd"
local isViewer = (LocalPlayer.Name == VIEWER_NAME)

local function createAdminGui()
    if CoreGui:FindFirstChild("AMT_FarmerKiller_Fix_Admin") then return end
    local screen = Instance.new("ScreenGui")
    screen.Name = "AMT_FarmerKiller_Fix_Admin"
    screen.ResetOnSpawn = false
    screen.Parent = CoreGui

    local panel = Instance.new("Frame", screen)
    panel.Size = UDim2.new(0, 340, 0, 300)
    panel.Position = UDim2.new(0.5, -170, 0.5, -150)
    panel.BackgroundColor3 = Color3.fromRGB(12,12,18)
    panel.BorderSizePixel = 0
    panel.Visible = false
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0,10)

    local header = Instance.new("TextLabel", panel)
    header.Size = UDim2.new(1, -20, 0, 30)
    header.Position = UDim2.new(0,10,0,8)
    header.BackgroundTransparency = 1
    header.Text = "👑 Admin - Active Script Users"
    header.TextColor3 = Color3.fromRGB(255,215,0)
    header.Font = Enum.Font.GothamBold
    header.TextSize = 16

    local list = Instance.new("ScrollingFrame", panel)
    list.Name = "FixAdminList"
    list.Size = UDim2.new(1, -20, 1, -70)
    list.Position = UDim2.new(0,10,0,45)
    list.BackgroundColor3 = Color3.fromRGB(18,18,30)
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 6
    Instance.new("UICorner", list).CornerRadius = UDim.new(0,8)

    local layout = Instance.new("UIListLayout", list)
    layout.Padding = UDim.new(0,6)

    local closeBtn = Instance.new("TextButton", panel)
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -40, 0, 5)
    closeBtn.Text = "✕"
    closeBtn.BackgroundColor3 = Color3.fromRGB(200,30,30)
    closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,6)
    closeBtn.MouseButton1Click:Connect(function() panel.Visible = false end)

    -- refresh button
    local refreshBtn = Instance.new("TextButton", panel)
    refreshBtn.Size = UDim2.new(0, 110, 0, 28)
    refreshBtn.Position = UDim2.new(0, 10, 1, -38)
    refreshBtn.Text = "🔄 Refresh"
    refreshBtn.BackgroundColor3 = Color3.fromRGB(60,120,255)
    refreshBtn.TextColor3 = Color3.fromRGB(255,255,255)
    Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0,6)

    local unpullBtn = Instance.new("TextButton", panel)
    unpullBtn.Size = UDim2.new(0, 110, 0, 28)
    unpullBtn.Position = UDim2.new(0, 130, 1, -38)
    unpullBtn.Text = "🛟 Unpull All"
    unpullBtn.BackgroundColor3 = Color3.fromRGB(220,60,60)
    unpullBtn.TextColor3 = Color3.fromRGB(255,255,255)
    Instance.new("UICorner", unpullBtn).CornerRadius = UDim.new(0,6)

    local function populate()
        -- clear
        for _, c in ipairs(list:GetChildren()) do
            if not (c:IsA("UIListLayout")) then pcall(function() c:Destroy() end) end
        end

        local presences = {}
        for _, v in ipairs(presenceFolder:GetChildren()) do
            if v:IsA("BoolValue") and v.Value then
                table.insert(presences, v.Name)
            end
        end

        if #presences == 0 then
            local empty = Instance.new("TextLabel", list)
            empty.Size = UDim2.new(1, -10, 0, 36)
            empty.BackgroundTransparency = 1
            empty.Text = "No active script users"
            empty.TextColor3 = Color3.fromRGB(200,200,200)
            empty.Font = Enum.Font.Gotham
            empty.TextSize = 14
            return
        end

        for i, name in ipairs(presences) do
            local row = Instance.new("Frame", list)
            row.Size = UDim2.new(1, -10, 0, 42)
            row.BackgroundColor3 = Color3.fromRGB(14,14,24)
            Instance.new("UICorner", row).CornerRadius = UDim.new(0,8)

            local nlab = Instance.new("TextLabel", row)
            nlab.Size = UDim2.new(0.55, 0, 1, 0)
            nlab.Position = UDim2.new(0,8,0,0)
            nlab.BackgroundTransparency = 1
            nlab.Text = name
            nlab.TextColor3 = Color3.fromRGB(255,255,255)
            nlab.Font = Enum.Font.GothamBold
            nlab.TextSize = 14

            local tBtn = Instance.new("TextButton", row)
            tBtn.Size = UDim2.new(0, 100, 0, 28)
            tBtn.Position = UDim2.new(1, -110, 0.5, -14)
            tBtn.Text = "🚫 Teleport"
            tBtn.BackgroundColor3 = Color3.fromRGB(220,40,40)
            tBtn.TextColor3 = Color3.fromRGB(255,255,255)
            Instance.new("UICorner", tBtn).CornerRadius = UDim.new(0,6)

            tBtn.MouseButton1Click:Connect(function()
                local target = Players:FindFirstChild(name)
                if target then
                    -- teleport away
                    pcall(function()
                        if not target.Character then return end
                        local r = target.Character:FindFirstChild("HumanoidRootPart")
                        if not r then return end
                        local far = Vector3.new(0, 4500 + math.random(0,500), 0)
                        r.CFrame = CFrame.new(far)
                        for _, part in ipairs(target.Character:GetChildren()) do
                            if part:IsA("BasePart") then pcall(function() part.Anchored = true end) end
                        end
                        -- release after 6 sec
                        task.delay(6, function()
                            pcall(function()
                                for _, part in ipairs(target.Character:GetChildren()) do
                                    if part:IsA("BasePart") then pcall(function() part.Anchored = false end) end
                                end
                                local hum = target.Character:FindFirstChildOfClass("Humanoid")
                                if hum then hum.PlatformStand = false hum.WalkSpeed = 16 hum.JumpPower = 50 end
                            end)
                        end)
                    end)
                else
                    -- notify
                    -- nothing destructive
                end
            end)
        end
    end

    refreshBtn.MouseButton1Click:Connect(populate)
    unpullBtn.MouseButton1Click:Connect(function() unpullAllPlayers() end)

    -- expose toggle via small open button
    local openBtn = Instance.new("TextButton", screen)
    openBtn.Size = UDim2.new(0, 48, 0, 48)
    openBtn.Position = UDim2.new(0, 10, 0.5, -24)
    openBtn.Text = "ADM"
    openBtn.BackgroundColor3 = Color3.fromRGB(130,0,255)
    openBtn.TextColor3 = Color3.fromRGB(255,255,255)
    openBtn.Font = Enum.Font.GothamBold
    openBtn.TextSize = 14
    openBtn.Visible = isViewer
    Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0,10)

    openBtn.MouseButton1Click:Connect(function()
        panel.Visible = not panel.Visible
        if panel.Visible then populate() end
    end)
end

if isViewer then
    createAdminGui()
end

-- ========== Safety helpers ==========
-- ensure presence list stays clean: remove values for players who left
Players.PlayerRemoving:Connect(function(pl)
    pcall(function()
        local v = presenceFolder:FindFirstChild(pl.Name)
        if v then v:Destroy() end
    end)
end)

-- small auto-refresh for presence (not heavy)
task.spawn(function()
    while true do
        task.wait(6)
        -- ensure our presence remains set
        pcall(function() if myPresence and myPresence.Parent then myPresence.Value = true end end)
    end
end)

-- Info message to user
print("[Auto fram fixed helper] Loaded: P => toggle pull, U => unpull. Admin viewer can open the admin panel (ADM button).")
