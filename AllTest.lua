if not _G.Settings then
    _G.Settings = {
        ["Enable Farm"] = true,
        ["SnipeLegendaryItem"] = false,
        ["Choose Team"] = "Marines",
        ["White Screen"] = false,
        ["Safe Mode"] = true
    }
end

repeat task.wait() until game:IsLoaded()

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function chooseTeam()
    local lonmauirac = playerGui:FindFirstChild("Main (minimal)")
    if not lonmauirac then
        warn("Main (minimal) not found in PlayerGui")
        return
    end

    local chomaubuoi = lonmauirac:FindFirstChild("ChooseTeam")
    if not chomaubuoi then
        warn("ChooseTeam not found in Main (minimal)")
        return
    end

    while task.wait() do
        if chomaubuoi.Visible then
            local teamChoice = _G.Settings["Choose Team"]
            local buttonPath = teamChoice == "Pirates" and chomaubuoi.Container.Pirates.Frame.TextButton or chomaubuoi.Container.Marines.Frame.TextButton
            for _, v in pairs(getconnections(buttonPath.Activated)) do
                v.Function()
            end
            break
        end
    end
end

task.spawn(chooseTeam)

-- Notification and clipboard setup
local Notification = require(game:GetService("ReplicatedStorage").Notification)
local linkloncc = "https://discord.gg/zED9HmrvVU"
setclipboard(linkloncc)

task.spawn(function()
    while task.wait(7) do
        Notification.new("<Color=Blue>Skull Hub | Join Our Discord Server: " .. linkloncc .. "<Color=/>"):Display()
    end
end)

-- Anti-Cheat bypass
local function checkAntiCheatBypass()
    local function destroyScripts(container, names)
        for _, v in pairs(container:GetDescendants()) do
            if v:IsA("LocalScript") and table.find(names, v.Name) then
                v:Destroy()
            end
        end
    end

    destroyScripts(player.Character or player.CharacterAdded:Wait(), {"General", "Shiftlock", "FallDamage", "4444", "CamBob", "JumpCD", "Looking", "Run"})
    destroyScripts(player.PlayerScripts, {"RobloxMotor6DBugFix", "CustomForceField", "MenuBloodSp", "PlayerList"})
end

local function bypassAntiExploit()
    for _, instance in ipairs(filtergc()) do
        if instance:IsA("AntiExploitSystem") then
            instance:Destroy()
        end
    end
end

if _G.Settings["Safe Mode"] then
    task.spawn(function()
        while task.wait(1) do
            pcall(checkAntiCheatBypass)
            pcall(bypassAntiExploit)
        end
    end)
end

-- Anti-idle
local vu = game:GetService("VirtualUser")
player.Idled:Connect(function()
    vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end)

-- Server hopping optimization
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local PlaceID = game.PlaceId
local AllIDs = {}
local foundAnything = ""
local actualHour = os.date("!*t").hour

local success, data = pcall(function()
    return HttpService:JSONDecode(readfile("NotSameServers.json"))
end)

if success and type(data) == "table" then
    AllIDs = data
else
    AllIDs = {actualHour}
    writefile("NotSameServers.json", HttpService:JSONEncode(AllIDs))
end

local function TPReturner()
    local url = 'https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Asc&limit=100'
    if foundAnything ~= "" then
        url = url .. "&cursor=" .. foundAnything
    end

    local response = HttpService:JSONDecode(game:HttpGet(url))
    for _, server in ipairs(response.data) do
        if server.playing < server.maxPlayers and not table.find(AllIDs, server.id) then
            table.insert(AllIDs, server.id)
            writefile("NotSameServers.json", HttpService:JSONEncode(AllIDs))
            TeleportService:TeleportToPlaceInstance(PlaceID, server.id, player)
            task.wait(4)
        end
    end

    if response.nextPageCursor then
        foundAnything = response.nextPageCursor
        TPReturner()
    end
end

function Teleport()
TPReturner()
end

repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer

local player = game.Players.LocalPlayer

-- Hàm để tìm và tương tác với rương
local function findAndInteractWithChest()
    local character = player.Character
    if not character then return end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end

    -- Tìm các loại rương trong ChestModels
    local chest = workspace:FindFirstChild("ChestModels") and (
        workspace.ChestModels:FindFirstChild("DiamondChest") or
        workspace.ChestModels:FindFirstChild("GoldChest") or
        workspace.ChestModels:FindFirstChild("SilverChest")
    )

    if chest then
        local rootPart = chest:FindFirstChild("RootPart")
        if rootPart then
            character:PivotTo(rootPart.CFrame)
            task.wait(0.1) -- Thêm một khoảng chờ nhỏ để tránh bị lag
            pcall(function()
                firesignal(rootPart.Touched, character.HumanoidRootPart)
            end)
        end
    else
        Teleport() -- Teleport nếu không tìm thấy rương
    end
end

-- Hàm chính để farm
task.spawn(function()
    while task.wait(1) do -- Giảm tần suất lặp, chờ 1 giây mỗi vòng lặp
        if _G.Settings["Enable Farm"] then
            if not player.Character then continue end

            -- Xóa CrewBBG nếu tồn tại
            local crewTag = player.Character:FindFirstChild("CrewBBG", true)
            if crewTag then crewTag:Destroy() end

            -- Kiểm tra và snipe Legendary Item nếu được bật
            if _G.Settings.SnipeLegendaryItem then
                local hasLegendaryItem = player.Backpack:FindFirstChild("Fist of Darkness") or
                                         player.Character:FindFirstChild("Fist of Darkness") or
                                         player.Backpack:FindFirstChild("God's Chalice") or
                                         player.Character:FindFirstChild("God's Chalice") or
                                         game.ReplicatedStorage:FindFirstChild("rip_indra True Form [Lv. 5000] [Raid Boss]") or
                                         workspace.Enemies:FindFirstChild("rip_indra True Form [Lv. 5000] [Raid Boss]") or
                                         workspace.Enemies:FindFirstChild("Darkbeard [Lv. 1000] [Raid Boss]")

                if hasLegendaryItem then
                    print("Don't Hop, Have Legendary Item")
                else
                    findAndInteractWithChest()
                end
            else
                findAndInteractWithChest()
            end
        end
    end
end)

-- Tự động teleport sau 150 giây
task.spawn(function()
    task.wait(150)
    Teleport()
end)
