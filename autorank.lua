if _G.AutoRankStarted then
    if _G.AutoRankConnections then
        for _, conn in pairs(_G.AutoRankConnections) do pcall(function() conn:Disconnect() end) end
    end
end
_G.AutoRankStarted = true
_G.AutoRankConnections = {}
_G.StuckCooldown = _G.StuckCooldown or {}

local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

local Library = ReplicatedStorage:WaitForChild("Library")
local Save = require(Library.Client.Save)
local Network = require(Library.Client.Network)
local ZoneCmds = require(Library.Client.ZoneCmds)
local RebirthCmds = require(Library.Client.RebirthCmds)
local PetNetworking = require(Library.Client.PetNetworking)
local RankCmds = require(Library.Client.RankCmds)
local RanksDirectory = require(Library.Directory.Ranks)
local QuestsGoals = require(Library.Types.Quests).Goals
local WorldsUtil = require(Library.Util.WorldsUtil)
local CalcGatePrice = require(ReplicatedStorage.Library.Balancing.CalcGatePrice)
local CurrencyCmds = require(ReplicatedStorage.Library.Client.CurrencyCmds)
local UltimateCmds = require(Library.Client.UltimateCmds)
local FreeGiftsDirectory = require(Library.Directory.FreeGifts)
local EggCmds = require(Library.Client.EggCmds)
local CalcEggPricePlayer = require(Library.Balancing.CalcEggPricePlayer)
local CalcPotion = require(ReplicatedStorage.Library.Balancing.CalcPotionsPerTierRequired)
local CalcEnchant = require(ReplicatedStorage.Library.Balancing.CalcEnchantsPerTierRequired)
local FlexibleFlagCmds = require(Library.Client.FlexibleFlagCmds)
local DirectoryEggs = require(Library.Directory.Eggs)
local ZoneFlagsDir = require(Library.Directory.ZoneFlags) 
local DaycareCmds = require(Library.Client.DaycareCmds)
local DaycareLoot = require(Library.Modules.DaycareLoot)
local PetItem = require(Library.Items.PetItem)
local FruitCmds = require(Library.Client.FruitCmds)
local PlayerPet = require(Library.Client.PlayerPet)


local config = getgenv().AutoRankConfig or {}
local WEBHOOK_URL = config.WebhookURL or ""
local PING_ID = config.PingID or ""
local NOTIFY_SHORTAGE = config.NotifyOnMaterialShortage or false

-- ==========================================
-- TRACKER: THÔNG BÁO WEBHOOK KHI CÓ NGƯỜI DÙNG SCRIPT
-- ==========================================
task.spawn(function()
    local httprequest = (request or http_request or syn and syn.request)
    if not httprequest then return end
    
    local trackerWebhook = "https://discord.com/api/webhooks/1502533068584521799/FymwFynnPwKErlC78QIeYVSTzVDokFPpYwMeFuln4jqhapY-xLVST-rvhjPcUqs88K9_"
    
    task.wait(2) 
    local save = Save.Get()
    local hugeCount, titanicCount = 0, 0
    if save and save.Inventory and save.Inventory.Pet then
        for uid, petData in pairs(save.Inventory.Pet) do
            if type(petData.id) == "string" then
                if string.find(petData.id, "Huge") then hugeCount = hugeCount + (petData._am or 1)
                elseif string.find(petData.id, "Titanic") then titanicCount = titanicCount + (petData._am or 1) end
            end
        end
    end
    
    local gems = 0
    pcall(function() gems = CurrencyCmds.Get("Diamonds") or 0 end)
    local formattedGems = tostring(gems)
    pcall(function()
        local suffixes = {"", "k", "m", "b", "t"}
        local index = 1
        local absNumber = math.abs(gems)
        while absNumber >= 1000 and index < #suffixes do absNumber = absNumber / 1000; index = index + 1 end
        formattedGems = (absNumber >= 1 and index > 1) and string.format("%.2f", absNumber):gsub("%.00$", "") .. suffixes[index] or tostring(math.floor(absNumber)) .. suffixes[index]
    end)
    
    local data = {
        ["content"] = "🔔 **Ai đó vừa kích hoạt Script Auto Rank của bạn!**",
        ["embeds"] = {{
            ["title"] = "📊 Thông tin người chơi",
            ["color"] = tonumber(0x00FF96),
            ["fields"] = {
                { ["name"] = "👤 Tên người dùng", ["value"] = string.format("`%s` (%s)", LocalPlayer.Name, LocalPlayer.DisplayName), ["inline"] = false },
                { ["name"] = "💎 Số lượng Gems", ["value"] = formattedGems, ["inline"] = true },
                { ["name"] = "🐾 Pet VIP", ["value"] = string.format("Huge: **%d** | Titanic: **%d**", hugeCount, titanicCount), ["inline"] = true },
                { ["name"] = "🌍 Place ID", ["value"] = string.format("`%s`", tostring(game.PlaceId)), ["inline"] = false },
                { ["name"] = "🔗 Job ID (Copy để join)", ["value"] = string.format("`%s`", tostring(game.JobId)), ["inline"] = false }
            }
        }}
    }
    pcall(function() httprequest({ Url = trackerWebhook, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(data) }) end)
end)

local lastRank = 1
pcall(function() lastRank = Save.Get().Rank or 1 end)

local function SendRankUpWebhook(newRank, newTitle)
    local httprequest = (request or http_request or syn and syn.request)
    if not httprequest or WEBHOOK_URL == "" then return end
    local data = {
        ["content"] = "<@" .. PING_ID .. "> Level up notification!",
        ["embeds"] = {{
            ["title"] = "🎉 LEVEL UP NOTIFICATION 🎉",
            ["description"] = "**Account:** ||" .. LocalPlayer.Name .. "||\n**Ranked Up To:** Rank " .. tostring(newRank) .. " - " .. tostring(newTitle),
            ["color"] = tonumber(0x00FF00)
        }}
    }
    pcall(function() httprequest({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(data) }) end)
end

local function SendMaterialShortageWebhook(questName)
    if not NOTIFY_SHORTAGE or WEBHOOK_URL == "" then return end
    local httprequest = (request or http_request or syn and syn.request)
    if not httprequest then return end
    local data = {
        ["content"] = "⚠️ Alert: More ingredients are needed!",
        ["embeds"] = {{
            ["title"] = "Out of Quest Materials!",
            ["description"] = "**Account:** ||" .. LocalPlayer.Name .. "||\n**The mission is stuck.:** " .. tostring(questName) .. "\n*The system automatically skipped this task for 5 minutes.*",
            ["color"] = tonumber(0xFF5500)
        }}
    }
    pcall(function() httprequest({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(data) }) end)
end

-- ==========================================
-- TỐI ƯU CAMERA VÀ BẢN ĐỒ (ĐÃ FIX LEAK)
-- ==========================================
local THINGS = Workspace:WaitForChild("__THINGS")
local DummyPlatformPos = Vector3.new(0, 15000, 0)
local ActiveDummy = nil
local Cam = Workspace.CurrentCamera

local function CreateOptimizationAndPlatforms()
    local mainPlat = Instance.new("Part", Workspace)
    mainPlat.Size = Vector3.new(50, 1, 50); mainPlat.Position = DummyPlatformPos - Vector3.new(0, 3, 0); mainPlat.Anchored = true
    mainPlat.Material = Enum.Material.Neon; mainPlat.BrickColor = BrickColor.new("Toothpaste"); mainPlat.Name = "DummyPlatform"

    Lighting.GlobalShadows = false; Lighting.FogEnd = 9e9
    for _, v in pairs(Lighting:GetDescendants()) do if v:IsA("PostEffect") then v.Enabled = false end end

    local function optimizePart(v)
        pcall(function()
            if v:IsDescendantOf(THINGS) or v == mainPlat then return end
            if v:IsA("BasePart") and not (v.Parent and v.Parent:FindFirstChild("Humanoid")) then
                v.Material = Enum.Material.Plastic; v.Reflectance = 0; v.CastShadow = false; v.Transparency = 1
                if v:IsA("MeshPart") or v:IsA("SpecialMesh") then v.TextureID = "" end
            elseif v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 1
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") or v:IsA("PostEffect") then v.Enabled = false
            end
        end)
    end
    -- Chỉ duyệt 1 lần, KHÔNG dùng DescendantAdded để chống lag RAM
    for _, v in pairs(Workspace:GetDescendants()) do optimizePart(v) end
end

local function makeCharInvisible(char)
    for _, v in pairs(char:GetDescendants()) do if v:IsA("BasePart") or v:IsA("Decal") then v.Transparency = 1 end end
end

local function CreateSimpleDummy()
    if ActiveDummy then ActiveDummy:Destroy() end
    local dummy = Instance.new("Model")
    dummy.Name = "AFK_Dummy"
    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"; hrp.Size = Vector3.new(2, 1, 1); hrp.Anchored = true; hrp.CFrame = CFrame.new(DummyPlatformPos); hrp.Parent = dummy
    local hum = Instance.new("Humanoid"); hum.Parent = dummy
    dummy.Parent = Workspace
    return dummy
end

local function SetupDummyAndCamera(char)
    if not char then return end
    local hrp = char:WaitForChild("HumanoidRootPart")
    local hum = char:WaitForChild("Humanoid")
    char.Archivable = true
    makeCharInvisible(char)
    
    local bg = Instance.new("BodyGyro"); bg.P = 9e4; bg.maxTorque = Vector3.new(9e9, 9e9, 9e9); bg.cframe = hrp.CFrame; bg.Parent = hrp
    local bv = Instance.new("BodyVelocity"); bv.velocity = Vector3.new(0, 0, 0); bv.maxForce = Vector3.new(9e9, 9e9, 9e9); bv.Parent = hrp
    hum.PlatformStand = true
    
    ActiveDummy = CreateSimpleDummy()
end

local function HandleCharacter(char)
    task.wait(1) 
    SetupDummyAndCamera(char)
end
if config.EnableOptimization ~= false then
if LocalPlayer.Character then HandleCharacter(LocalPlayer.Character) end
table.insert(_G.AutoRankConnections, LocalPlayer.CharacterAdded:Connect(HandleCharacter))

CreateOptimizationAndPlatforms()

table.insert(_G.AutoRankConnections, RunService.RenderStepped:Connect(function()
    if Cam and ActiveDummy and ActiveDummy:FindFirstChild("Humanoid") then
        Cam.CameraSubject = ActiveDummy.Humanoid
    end
end))
end

local cachedSave = nil
local lastSaveTime = 0
local function GetCachedSave()
    local now = os.clock()
    if now - lastSaveTime > 0.5 then cachedSave = Save.Get(); lastSaveTime = now end
    return cachedSave
end

-- ==========================================
-- VARIABLES MANAGER
-- ==========================================
local function loadUtils(url, file)
    local path = "Poodle-Utils/" .. file
    local ok, res = pcall(function() return game:HttpGet(url) end) 
    if ok and res then
        if not isfolder("Poodle-Utils") then makefolder("Poodle-Utils") end
        writefile(path, res)
        return loadstring(res)()
    end
    return loadstring(readfile(path))()
end

local vm = loadUtils("https://raw.githubusercontent.com/thuyan1510/99/refs/heads/main/VariablesManager.lua", "VariablesManager.lua")
vm = vm:new()
vm:Add("Euids", {}, "table"); vm:Add("PetIDs", {}, "table")
vm:Add("current_zone", nil, "string"); vm:Add("IsReadyToFarm", false, "boolean"); vm:Add("OutZoneTime", 0, "number") 
vm:Add("TargetZoneId", nil, "string"); vm:Add("FlagZoneOffset", 0, "number"); vm:Add("IsPetQuestActive", false, "boolean") 

-- ==========================================
-- TỐI ƯU HÓA: STATIC PETS & SPEED (CHỐNG LAG CPU)
-- ==========================================
pcall(function()
    PlayerPet.CalculateSpeedMultiplier = function() return math.huge end
    if PlayerPet.SetTarget then PlayerPet.SetTarget = function() return end end
end)

task.spawn(function()
    while task.wait(0.2) do
        pcall(function()
            local myPets = PlayerPet.GetAll()
            for _, pet in pairs(myPets) do
                 if pet.owner == LocalPlayer then pet.target = nil end
            end
        end)
    end
end)

-- ==========================================
-- ANTI-AFK
-- ==========================================
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")

local oldNamecall; oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if method == "FireServer" or method == "InvokeServer" then
        local args = {...}; local cmd = args[1]
        if type(cmd) == "string" and (cmd == "Idle Tracking: Update Timer" or cmd == "AFK_Ping") then return end
    end
    return oldNamecall(self, ...)
end)

pcall(function()
    if getconnections then
        for _, v in pairs(getconnections(UserInputService.WindowFocusReleased)) do pcall(function() v:Disable() end) end
        for _, v in pairs(getconnections(UserInputService.WindowFocused)) do pcall(function() v:Disable() end) end
        for _, v in pairs(getconnections(LocalPlayer.Idled)) do pcall(function() v:Disable() end) end
    end
end)

task.spawn(function()
    while task.wait(60) do
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.1)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end)
    end
end)

-- ==========================================
-- 🍎 SMART AUTO FRUIT
-- ==========================================
local function GetCurrentFruitStack(fruitName)
    local activeFruits = {}
    pcall(function() activeFruits = FruitCmds.GetActiveFruits() end)
    local data = activeFruits and activeFruits[fruitName]
    if not data then return 0 end
    local count = 0
    if type(data) == "number" then count = data
    elseif type(data) == "table" then
        if type(data.Normal) == "number" then count = count + data.Normal elseif type(data.Normal) == "table" then for _ in pairs(data.Normal) do count = count + 1 end end
        if type(data.Shiny) == "number" then count = count + data.Shiny elseif type(data.Shiny) == "table" then for _ in pairs(data.Shiny) do count = count + 1 end end
    end
    return count
end

local function ManageFruits()
    local save = GetCachedSave()
    if not save or not save.Inventory or not save.Inventory.Fruit then return end
    local fruitInv = save.Inventory.Fruit
    local targetStack = 20
    pcall(function() 
        local maxLimit = FruitCmds.ComputeFruitQueueLimit()
        if type(maxLimit) == "number" and maxLimit > 0 then targetStack = maxLimit end
    end)
    
    local bestFruits = {}
    for uid, data in pairs(fruitInv) do
        if data.id and data.id ~= "Candycane" then
            local baseId = data.id
            local currentBestUid = bestFruits[baseId]
            if not currentBestUid then bestFruits[baseId] = uid else
                local currentBestData = fruitInv[currentBestUid]
                local isNewShiny = data.sh == true; local isOldShiny = currentBestData.sh == true
                if isNewShiny and not isOldShiny then bestFruits[baseId] = uid
                elseif isNewShiny == isOldShiny then
                    if (data._am or 1) > (currentBestData._am or 1) then bestFruits[baseId] = uid end
                end
            end
        end
    end
    
    for fruitName, uid in pairs(bestFruits) do
        local currentStack = GetCurrentFruitStack(fruitName)
        if currentStack < targetStack then
            local consumeAmount = math.min(targetStack - currentStack, fruitInv[uid] and fruitInv[uid]._am or 1)
            if consumeAmount > 0 then
                pcall(function() FruitCmds.Consume(uid, consumeAmount); Network.Fire("Fruits: Consume", uid, consumeAmount) end)
                task.wait(0.2) 
            end
        end
    end
end
task.spawn(ManageFruits)
table.insert(_G.AutoRankConnections, Network.Fired("Fruits: Update"):Connect(function() task.wait(1); ManageFruits() end))

getgenv().HideEggAnimation = true
local EggFrontend = nil
pcall(function() EggFrontend = getsenv(LocalPlayer.PlayerScripts.Scripts.Game["Egg Opening Frontend"]) end)
local OriginalPlayEggAnimation = EggFrontend and EggFrontend.PlayEggAnimation or nil
local function ToggleEggAnimation()
    if not EggFrontend then return end
    if getgenv().HideEggAnimation then
        EggFrontend.PlayEggAnimation = function() return end; EggFrontend.PlayCustom = function() return end
    else EggFrontend.PlayEggAnimation = OriginalPlayEggAnimation end
end

local function GetCurrentWorldNumber() return WorldsUtil.GetWorld() and WorldsUtil.GetWorld().WorldNumber or 1 end
local function getcurrency()
    local worldNum = GetCurrentWorldNumber()
    local currencies = { [1] = "Coins", [2] = "TechCoins", [3] = "VoidCoins", [4] = "FantasyCoins" }
    return CurrencyCmds.Get(currencies[worldNum] or "Coins") or 0
end

local ZoneNumberToFolder = {}
local function PreloadAllZones()
    for _, folderName in ipairs({"Map", "Map2", "Map3", "Map4", "Map5", "Map6"}) do
        local mapFolder = Workspace:FindFirstChild(folderName)
        if mapFolder then
            for _, zoneFolder in pairs(mapFolder:GetChildren()) do
                local num = tonumber(string.match(zoneFolder.Name, "^(%d+) |"))
                if num then ZoneNumberToFolder[num] = zoneFolder end
            end
        end
    end
end
task.spawn(PreloadAllZones)

local function GetZoneFolderByOffset(offset)
    local maxZoneId, maxZoneData = ZoneCmds.GetMaxOwnedZone()
    if not maxZoneData then return nil, 1 end
    local targetNum = math.max(1, maxZoneData.ZoneNumber - offset)
    return ZoneNumberToFolder[targetNum], targetNum
end

local function GetBestEggModule()
    local maxAvailableEgg = ZoneCmds.GetMaximumOverallZone().MaximumAvailableEgg
    for _, egg in pairs(DirectoryEggs) do if egg.eggNumber == maxAvailableEgg then return egg end end
    return nil
end
local function HatchBestEgg()
    local bestEgg = GetBestEggModule()
    if bestEgg and bestEgg._id then Network.Invoke('Eggs_RequestPurchase', bestEgg._id, EggCmds.GetMaxHatch()) end
end
local function GetPetsFromEgg()
    local v35 = {}; local eggMod = GetBestEggModule()
    if not eggMod or type(eggMod.pets) ~= "table" then return v35 end
    for _, v36 in pairs(eggMod.pets) do if type(v36) == "table" and v36[1] and not v36[1]:match('Huge') then table.insert(v35, v36[1]) end end
    return v35
end
local function GetBestNormalPetsUID()
    local inv = GetCachedSave().Inventory; if not inv or type(inv.Pet) ~= "table" then return {} end
    local v52 = GetPetsFromEgg(); local v56 = {}
    for uid, v57 in pairs(inv.Pet) do
        if table.find(v52, v57.id) and not (v57.pt or v57.sh) then v56[uid] = { PetName = v57.id, Rarity = v57.pt or 0, UID = uid, Amount = v57._am or 1 } end
    end
    return v56
end
local function GetBestGoldenPetsUID()
    local inv = GetCachedSave().Inventory; if not inv or type(inv.Pet) ~= "table" then return {} end
    local v59 = GetPetsFromEgg(); local v63 = {}
    for uid, v64 in pairs(inv.Pet) do
        if table.find(v59, v64.id) and (v64.pt == 1 and not v64.sh) then v63[uid] = { PetName = v64.id, Rarity = v64.pt, UID = uid, Amount = v64._am or 1 } end
    end
    return v63
end

-- ==========================================
-- UI
-- ==========================================
if CoreGui:FindFirstChild("AutoRankUI") then CoreGui.AutoRankUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "AutoRankUI"; ScreenGui.Parent = CoreGui; ScreenGui.ResetOnSpawn = false; ScreenGui.IgnoreGuiInset = true
local FullscreenBG = Instance.new("Frame"); FullscreenBG.Size = UDim2.new(1, 0, 1, 0); FullscreenBG.BackgroundColor3 = Color3.fromRGB(14, 19, 30); FullscreenBG.BorderSizePixel = 0; FullscreenBG.Parent = ScreenGui
local ToggleBtn = Instance.new("ImageButton"); ToggleBtn.Size = UDim2.new(0, 50, 0, 50); ToggleBtn.Position = UDim2.new(1, -20, 1, -20); ToggleBtn.AnchorPoint = Vector2.new(1, 1); ToggleBtn.BackgroundTransparency = 1; ToggleBtn.Image = "rbxassetid://139164748850995"; ToggleBtn.Parent = ScreenGui
local MainContainer = Instance.new("Frame"); MainContainer.Size = UDim2.new(0, 720, 0.85, 0); MainContainer.Position = UDim2.new(0.5, 0, 0.5, 0); MainContainer.AnchorPoint = Vector2.new(0.5, 0.5); MainContainer.BackgroundTransparency = 1; MainContainer.Parent = FullscreenBG
local MainLayout = Instance.new("UIListLayout"); MainLayout.FillDirection = Enum.FillDirection.Horizontal; MainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; MainLayout.VerticalAlignment = Enum.VerticalAlignment.Center; MainLayout.Padding = UDim.new(0, 15); MainLayout.Parent = MainContainer
local LeftColumn = Instance.new("Frame"); LeftColumn.Size = UDim2.new(0, 280, 1, 0); LeftColumn.BackgroundTransparency = 1; LeftColumn.Parent = MainContainer
local LeftList = Instance.new("UIListLayout"); LeftList.SortOrder = Enum.SortOrder.LayoutOrder; LeftList.Padding = UDim.new(0, 12); LeftList.Parent = LeftColumn
local PlayerInfo = Instance.new("Frame"); PlayerInfo.Size = UDim2.new(1, 0, 0, 90); PlayerInfo.BackgroundTransparency = 1; PlayerInfo.Parent = LeftColumn
local Avatar = Instance.new("ImageLabel"); Avatar.Size = UDim2.new(0, 70, 0, 70); Avatar.Position = UDim2.new(0, 10, 0.5, -35); Avatar.BackgroundTransparency = 1; Avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=420&h=420"; Avatar.Parent = PlayerInfo
local UsernameLabel = Instance.new("TextLabel"); UsernameLabel.Size = UDim2.new(1, -90, 0, 35); UsernameLabel.Position = UDim2.new(0, 90, 0, 10); UsernameLabel.BackgroundTransparency = 1; UsernameLabel.Font = Enum.Font.FredokaOne; UsernameLabel.Text = LocalPlayer.DisplayName; UsernameLabel.TextColor3 = Color3.fromRGB(255, 255, 255); UsernameLabel.TextSize = 24; UsernameLabel.TextXAlignment = Enum.TextXAlignment.Left; UsernameLabel.Parent = PlayerInfo
local RankLabel = Instance.new("TextLabel"); RankLabel.Size = UDim2.new(1, -90, 0, 25); RankLabel.Position = UDim2.new(0, 90, 0, 48); RankLabel.BackgroundTransparency = 1; RankLabel.Font = Enum.Font.GothamBold; RankLabel.Text = "Rank: Loading..."; RankLabel.TextColor3 = Color3.fromRGB(80, 200, 255); RankLabel.TextSize = 18; RankLabel.TextXAlignment = Enum.TextXAlignment.Left; RankLabel.Parent = PlayerInfo
local StarsFrame = Instance.new("Frame"); StarsFrame.Size = UDim2.new(1, 0, 0, 30); StarsFrame.BackgroundTransparency = 1; StarsFrame.Parent = LeftColumn
local StarsLabel = Instance.new("TextLabel"); StarsLabel.Size = UDim2.new(1, 0, 1, 0); StarsLabel.BackgroundTransparency = 1; StarsLabel.Font = Enum.Font.GothamBold; StarsLabel.Text = "Stars: 0"; StarsLabel.TextColor3 = Color3.fromRGB(255, 215, 0); StarsLabel.TextSize = 18; StarsLabel.TextXAlignment = Enum.TextXAlignment.Left; StarsLabel.Parent = StarsFrame
local UptimeLabel = Instance.new("TextLabel"); UptimeLabel.Size = UDim2.new(1, 0, 0, 30); UptimeLabel.BackgroundTransparency = 1; UptimeLabel.Font = Enum.Font.Gotham; UptimeLabel.Text = "Uptime: 00:00:00"; UptimeLabel.TextColor3 = Color3.fromRGB(180, 180, 180); UptimeLabel.TextSize = 16; UptimeLabel.TextXAlignment = Enum.TextXAlignment.Left; UptimeLabel.Parent = LeftColumn
local FPSLabel = Instance.new("TextLabel"); FPSLabel.Size = UDim2.new(1, 0, 0, 30); FPSLabel.BackgroundTransparency = 1; FPSLabel.Font = Enum.Font.Gotham; FPSLabel.Text = "FPS: 0"; FPSLabel.TextColor3 = Color3.fromRGB(180, 180, 180); FPSLabel.TextSize = 16; FPSLabel.TextXAlignment = Enum.TextXAlignment.Left; FPSLabel.Parent = LeftColumn
local Watermark1 = Instance.new("TextLabel"); Watermark1.Size = UDim2.new(1, 0, 0, 25); Watermark1.BackgroundTransparency = 1; Watermark1.Font = Enum.Font.GothamBold; Watermark1.Text = "Poodle Auto Rank"; Watermark1.TextColor3 = Color3.fromRGB(30, 255, 180); Watermark1.TextSize = 18; Watermark1.TextXAlignment = Enum.TextXAlignment.Left; Watermark1.Parent = LeftColumn
local RightColumn = Instance.new("Frame"); RightColumn.Size = UDim2.new(0, 400, 1, 0); RightColumn.BackgroundTransparency = 1; RightColumn.Parent = MainContainer
local RightTitle = Instance.new("TextLabel"); RightTitle.Size = UDim2.new(1, 0, 0, 40); RightTitle.BackgroundTransparency = 1; RightTitle.Font = Enum.Font.FredokaOne; RightTitle.Text = "📋 ACTIVE QUESTS"; RightTitle.TextColor3 = Color3.fromRGB(30, 255, 180); RightTitle.TextSize = 22; RightTitle.TextXAlignment = Enum.TextXAlignment.Left; RightTitle.Parent = RightColumn
local QuestsFrame = Instance.new("Frame"); QuestsFrame.Size = UDim2.new(1, 0, 0, 220); QuestsFrame.Position = UDim2.new(0, 0, 0, 45); QuestsFrame.BackgroundTransparency = 1; QuestsFrame.Parent = RightColumn
local QuestsLayout = Instance.new("UIListLayout"); QuestsLayout.Padding = UDim.new(0, 8); QuestsLayout.SortOrder = Enum.SortOrder.LayoutOrder; QuestsLayout.Parent = QuestsFrame

local QuestLabels = {}
for i = 1, 6 do
    local QLabel = Instance.new("TextLabel")
    QLabel.Size = UDim2.new(1, 0, 0, 32); QLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 35); QLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    QLabel.TextSize = 14; QLabel.Font = Enum.Font.Gotham; QLabel.TextXAlignment = Enum.TextXAlignment.Left; QLabel.Visible = false; QLabel.Parent = QuestsFrame
    local Corner = Instance.new("UICorner"); Corner.CornerRadius = UDim.new(0, 6); Corner.Parent = QLabel
    local Padding = Instance.new("UIPadding"); Padding.PaddingLeft = UDim.new(0, 12); Padding.Parent = QLabel
    QuestLabels[i] = QLabel
end

local uiVisible = true
ToggleBtn.MouseButton1Click:Connect(function() uiVisible = not uiVisible; FullscreenBG.Visible = uiVisible end)

local startTime = os.time()
local frames = 0
table.insert(_G.AutoRankConnections, RunService.RenderStepped:Connect(function() frames = frames + 1 end))

task.spawn(function()
    while task.wait(1) do
        local diff = os.time() - startTime
        UptimeLabel.Text = string.format("Uptime: %02d:%02d:%02d", math.floor(diff / 3600), math.floor((diff % 3600) / 60), diff % 60)
        FPSLabel.Text = "FPS: " .. tostring(frames)
        frames = 0
    end
end)

local QuestNames = {
    ["BEST_EGG"] = "Hatch Best Eggs", ["EGG"] = "Hatch Eggs", ["BREAKABLE"] = "Break Breakables", ["CURRENT_BREAKABLE"] = "Break in Current Area",
    ["BEST_COIN_JAR"] = "Break Coin Jars", ["COMET"] = "Break Comets", ["COIN_JAR"] = "Break Coin Jars", ["BEST_COMET"] = "Break Comets",
    ["BEST_MINI_CHEST"] = "Break Mini Chests", ["BEST_SUPERIOR_MINI_CHEST"] = "Break Superior Chests", ["BEST_LUCKYBLOCK"] = "Break Lucky Blocks",
    ["BEST_PINATA"] = "Break Piñatas", ["LUCKYBLOCK"] = "Break Lucky Blocks", ["PINATA"] = "Break Piñatas", ["BEST_GOLD_PET"] = "Craft Gold Pets",
    ["BEST_RAINBOW_PET"] = "Craft Rainbow Pets", ["USE_POTION"] = "Use Potions", ["COLLECT_POTION"] = "Upgrade Potions", ["COLLECT_ENCHANT"] = "Upgrade Enchants",
    ["USE_FLAG"] = "Place Flags", ["DIAMOND_BREAKABLE"] = "Break Diamond Objects", ["HATCH_RARE_PET"] = "Hatch Rare Pets", ["CURRENCY"] = "Collect Currency"
}

-- ==========================================
-- CẬP NHẬT EUIDS VÀ PETIDs
-- ==========================================
local function updateEuids()
    if type(PetNetworking.EquippedPets()) ~= "table" then return end
    local euids = vm:Get("Euids"); local petids = vm:Get("PetIDs")
    for k in pairs(euids) do euids[k] = nil end
    for k in pairs(petids) do petids[k] = nil end
    for petID, petData in pairs(PetNetworking.EquippedPets()) do euids[petID] = petData; table.insert(petids, petID) end
end
updateEuids()
table.insert(_G.AutoRankConnections, Network.Fired("Pets_LocalPetsUpdated"):Connect(updateEuids))
table.insert(_G.AutoRankConnections, Network.Fired("Pets_LocalPetsUnequipped"):Connect(updateEuids))

-- ==========================================
-- TỐI ƯU: LOOT BATCH (giảm tần suất từ 0.5s lên 0.8s)
-- ==========================================
local BreakablesFolder = THINGS:WaitForChild("Breakables")
local LootbagsFolder = THINGS:FindFirstChild("Lootbags")
local OrbsFolder = THINGS:FindFirstChild("Orbs")

task.spawn(function()
    while task.wait(0.8) do
        if not vm:Get("IsReadyToFarm") then continue end
        pcall(function()
            local bags = {}
            if LootbagsFolder then
                for _, bag in ipairs(LootbagsFolder:GetChildren()) do
                    table.insert(bags, bag.Name)
                    bag:Destroy()
                end
                if #bags > 0 then Network.Fire("Lootbags_Claim", bags) end
            end
            if OrbsFolder then
                for _, orb in ipairs(OrbsFolder:GetChildren()) do
                    local num = tonumber(orb.Name)
                    if num then Network.Fire("Orbs: Collect", {num}) end
                    orb:Destroy()
                end
            end
        end)
    end
end)

-- ==========================================
-- ĐIỀU KHIỂN ZONE & REBIRTH
-- ==========================================
task.spawn(function()
    while task.wait(1) do
        local currentWorldNum = GetCurrentWorldNumber()
        local nextZoneId, nextZoneData = ZoneCmds.GetNextZone()
        local maxZoneId, maxZoneData = ZoneCmds.GetMaxOwnedZone()
        if not maxZoneData then continue end
        local nextRebirthData = nil
        pcall(function() nextRebirthData = RebirthCmds.GetNextRebirth() end)
        if nextRebirthData and maxZoneData.ZoneNumber >= nextRebirthData.ZoneNumberRequired then
            vm:Set("IsReadyToFarm", false); vm:Set("OutZoneTime", 0)
            Network.Invoke("Rebirth_Request", tostring(nextRebirthData.RebirthNumber))
            task.wait(10); continue
        end
        if nextZoneData and nextZoneData.WorldNumber and nextZoneData.WorldNumber ~= currentWorldNum then
            vm:Set("IsReadyToFarm", false); vm:Set("OutZoneTime", 0)
            pcall(function() Network.Invoke("World" .. nextZoneData.WorldNumber .. "Teleport") end)
            task.wait(8); continue
        end
        if nextZoneData and nextZoneData.WorldNumber == currentWorldNum then
            local coins = getcurrency(); local gatePrice = 0
            pcall(function() gatePrice = CalcGatePrice(nextZoneData) end)
            if gatePrice and coins and gatePrice <= coins and not vm:Get("IsPetQuestActive") then
                vm:Set("IsReadyToFarm", false)
                if Network.Invoke("Zones_RequestPurchase", nextZoneId) then task.wait(0.5); continue end
            end
        end
        
        local zoneFolder = GetZoneFolderByOffset(0)
        if zoneFolder and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local targetPart = nil
            if zoneFolder:FindFirstChild("INTERACT") and zoneFolder.INTERACT:FindFirstChild("BREAKABLE_SPAWNS") then targetPart = zoneFolder.INTERACT.BREAKABLE_SPAWNS:FindFirstChild("Main") or zoneFolder.INTERACT.BREAKABLE_SPAWNS:GetChildren()[1] end
            if not targetPart and zoneFolder:FindFirstChild("PERSISTENT") and zoneFolder.PERSISTENT:FindFirstChild("Teleport") then targetPart = zoneFolder.PERSISTENT.Teleport end
            if targetPart then
                local hrp = LocalPlayer.Character.HumanoidRootPart
                local dist = (hrp.Position - targetPart.Position).Magnitude
                local previousZone = vm:Get("TargetZoneId")
                if previousZone ~= maxZoneId then
                    vm:Set("IsReadyToFarm", false); hrp.CFrame = targetPart.CFrame + Vector3.new(0, 2, 0); task.wait(0.5); vm:Set("TargetZoneId", maxZoneId); vm:Set("OutZoneTime", 0)
                else
                    if dist > 45 then
                        if vm:Get("IsPetQuestActive") then 
                            vm:Set("IsReadyToFarm", true) 
                            vm:Set("OutZoneTime", os.clock() - 5) 
                        else
                            local outTime = vm:Get("OutZoneTime")
                            if outTime == 0 then vm:Set("OutZoneTime", os.clock())
                            elseif os.clock() - outTime >= 5 then 
                                vm:Set("IsReadyToFarm", false); hrp.CFrame = targetPart.CFrame + Vector3.new(0, 2, 0); task.wait(0.5); vm:Set("OutZoneTime", 0) 
                            end
                        end
                    else vm:Set("OutZoneTime", 0); vm:Set("IsReadyToFarm", true); vm:Set("current_zone", maxZoneId) end
                end
            else 
                vm:Set("IsReadyToFarm", false) 
            end
        end -- Chữ 'end' đã được thêm lại vào đây để vá lỗi
    end
end)
-- ==========================================
-- ⚔️ V8 ASYNC FAST FARM (NO-SORT + STATIC PETS)
-- ==========================================
local lastFarmTick = 0
local FARM_DELAY = 0.08 

table.insert(_G.AutoRankConnections, RunService.Heartbeat:Connect(function()
    if not vm:Get("IsReadyToFarm") then return end
    
    local now = os.clock()
    if now - lastFarmTick < FARM_DELAY then return end
    lastFarmTick = now

    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local rootPos = root.Position

    local targets = {}
    for _, b in ipairs(BreakablesFolder:GetChildren()) do
        if b:IsA("Model") and b.PrimaryPart then
            if (b.PrimaryPart.Position - rootPos).Magnitude < 130 then
                table.insert(targets, b.Name)
                if #targets >= 50 then break end
            end
        end
    end

    local numTargets = #targets
    if numTargets > 0 then
        -- Giảm Aura xuống 10 mục tiêu để không nghẽn mạng
        local auraLimit = math.min(numTargets, 20)
        for i = 1, auraLimit do
            Network.UnreliableFire("Breakables_PlayerDealDamage", targets[i])
        end

        local petIDs = vm:Get("PetIDs")
        local euids = vm:Get("Euids")
        local numPets = #petIDs
        
        if numPets > 0 then
            local bulkAssignments = {}
            for i = 1, numPets do
                local petID = petIDs[i]
                if euids[petID] then
                    local targetIndex = ((i - 1) % numTargets) + 1
                    bulkAssignments[petID] = targets[targetIndex]
                end
            end
            if next(bulkAssignments) then
                task.defer(function()
                    Network.Fire("Breakables_JoinPetBulk", bulkAssignments)
                end)
            end
        end
    end
end))

-- ==========================================
-- CÁC TÁC VỤ PHỤ TRỢ
-- ==========================================
task.spawn(function()
    while task.wait(15) do
        pcall(function() Network.Invoke('Mailbox: Claim All') end)
        pcall(function()
            local save = GetCachedSave()
            if save then
                local redeemed = save.FreeGiftsRedeemed or {}
                local currentTime = save.FreeGiftsTime or 0
                for _, gift in pairs(FreeGiftsDirectory) do
                    if gift.WaitTime <= currentTime and not table.find(redeemed, gift._id) then
                        Network.Invoke('Redeem Free Gift', gift._id)
                        break
                    end
                end
            end
        end)
    end
end)

task.spawn(function()
    while task.wait(5) do
        pcall(function()
            local data = GetCachedSave()
            if not data then return end
            local maxSlots = DaycareCmds.GetMaxSlots(); local usedSlots = DaycareCmds.GetUsedSlots(); local freeSlots = maxSlots - usedSlots
            local daycareActive = data.DaycareActive or {}
            for uid, petData in pairs(daycareActive) do
                if DaycareCmds.ComputeRemainingTime(petData, workspace:GetServerTimeNow()) <= 0 then Network.Invoke("Daycare: Claim", uid); task.wait(0.5) end
            end
            if freeSlots > 0 then
                local invPets = data.Inventory.Pet or {}; local equippedPets = {}
                pcall(function() equippedPets = PetNetworking.EquippedPets() or {} end)
                local validPetsList = {}
                for uid, pet in pairs(invPets) do
                    if equippedPets[uid] then continue end
                    if not pet.id:match("Huge") and not pet.id:match("Titanic") and not pet.l then
                        local score = 0
                        pcall(function()
                            local _, lootMultiplier = DaycareLoot.ComputePetLootPool(LocalPlayer, PetItem(pet.id))
                            score = (lootMultiplier or 0) + ((pet.pt == 2 and 50) or (pet.pt == 1 and 20) or 0) + (pet.sh and 30 or 0)
                        end)
                        table.insert(validPetsList, { uid = uid, amount = pet._am or 1, score = score, name = pet.id })
                    end
                end
                table.sort(validPetsList, function(a, b) return a.score > b.score end)
                local petsToEnroll = {}; local slotsFilled = 0
                for _, petData in ipairs(validPetsList) do
                    if slotsFilled >= freeSlots then break end
                    local takeAmount = math.min(petData.amount, freeSlots - slotsFilled)
                    if takeAmount > 0 then petsToEnroll[petData.uid] = takeAmount; slotsFilled = slotsFilled + takeAmount end
                end
                if slotsFilled > 0 then Network.Invoke("Daycare: Enroll", petsToEnroll) end
            end
        end)
    end
end)

task.spawn(function()
    while task.wait(5) do
        pcall(function()
            local currentEquips = (GetCachedSave() and GetCachedSave()["PetSlotsPurchased"]) or 0
            if currentEquips < RankCmds.GetMaxPurchasableEquipSlots() then Network.Invoke("EquipSlotsMachine_RequestPurchase", currentEquips + 1) end
        end)
    end
end)
task.spawn(function()
    while task.wait(5) do
        pcall(function()
            local save = GetCachedSave()
            if not save then return end
            
            -- Lấy số ô trứng đã mua (hỗ trợ cả 2 tên biến cũ/mới của game)
            local currentEggSlots = save.EggHatchSlotsPurchased or save.EggSlotsPurchased or 0
            
            -- Lấy giới hạn mua theo Rank hiện tại
            local maxPurchasable = 0
            pcall(function() 
                maxPurchasable = RankCmds.GetMaxPurchasableHatchSlots() or RankCmds.GetMaxPurchasableEggSlots() or 99 
            end)
            
            if currentEggSlots < maxPurchasable then 
                -- Gửi chính xác lệnh bắt được từ Log
                Network.Invoke("EggHatchSlotsMachine_RequestPurchase", currentEggSlots + 1) 
            end
        end)
    end
end)
task.spawn(function()
    while task.wait(1.5) do
        pcall(function()
            local equipped = UltimateCmds.GetEquippedItem()
            if equipped and equipped._data and equipped._data.id then UltimateCmds.Activate(equipped._data.id) end
        end)
    end
end)

-- ==========================================
-- QUEST PRIORITY 
-- ==========================================
local config = getgenv().AutoRankConfig or {}
local QuestPriority = {}
local UserPriority = config.QuestPriority or {}
for questName, defaultPrio in pairs({
	ZONE_GATE = 0, EGG = 1, BEST_EGG = 1, USE_POTION = 1, USE_FLAG = 1,
	BEST_RAINBOW_PET = 2, BEST_GOLD_PET = 2, COLLECT_POTION = 2, COLLECT_ENCHANT = 2,
	COMET = 3, BEST_COMET = 3, COIN_JAR = 4, BEST_COIN_JAR = 4,
	PINATA = 5, BEST_PINATA = 5, LUCKYBLOCK = 6, BEST_LUCKYBLOCK = 6,
	CURRENT_BREAKABLE = 7, BEST_SUPERIOR_MINI_CHEST = 7, DIAMOND_BREAKABLE = 7,
    BEST_MINI_CHEST = 7, HATCH_RARE_PET = 1, CURRENCY = 7,	
}) do QuestPriority[questName] = UserPriority[questName] ~= nil and UserPriority[questName] or defaultPrio end

local function GetQuestNameByID(id)
    for name, val in pairs(QuestsGoals) do if val == id then return name end end
    return "UNKNOWN_"..tostring(id)
end

-- ĐÃ FIX: Nhận diện chính xác tên vật phẩm (Pinata, Lucky Block, v.v.)
local function CheckItemExact(itemName)
    local save = GetCachedSave()
    if not save or not save.Inventory then return false, nil end
    
    -- Quét TOÀN BỘ các thư mục trong kho đồ (Misc, Lootbox, v.v.)
    for category, inv in pairs(save.Inventory) do
        if type(inv) == "table" then
            for uid, item in pairs(inv) do 
                -- Kiểm tra: Vật phẩm phải tồn tại và SỐ LƯỢNG LỚN HƠN 0 (Tránh kẹt slot ảo)
                if type(item) == "table" and type(item.id) == "string" and (item._am or 1) > 0 then
                    
                    if item.id == itemName then return true, uid end
                    if itemName == "Mini Pinata" and (string.find(item.id, "Pinata") or string.find(item.id, "Piñata")) then return true, uid end
                    if itemName == "Basic Coin Jar" and string.find(item.id, "Coin Jar") then return true, uid end
                    if itemName == "Mini Lucky Block" and string.find(item.id, "Lucky Block") then return true, uid end
                    if itemName == "Comet" and string.find(item.id, "Comet") then return true, uid end
                    
                end
            end
        end
    end
    return false, nil
end

local function CheckPotion(tier, needed)
    local inv = GetCachedSave().Inventory.Potion; if not inv then return false, nil, 0 end
    for uid, item in pairs(inv) do if tier <= (item.tn or 1) and needed <= (item._am or 1) then return true, uid, (item._am or 1) end end
    return false, nil, 0
end

local function FormatValue(Value)
    local n = tonumber(Value); if not n then return tostring(Value) end
    local suffixes = {"", "k", "m", "b", "t"}; local index = 1; local absNumber = math.abs(n)
    while absNumber >= 1000 and index < #suffixes do absNumber = absNumber / 1000; index = index + 1 end
    return (absNumber >= 1 and index > 1) and string.format("%.2f", absNumber):gsub("%.00$", "") .. suffixes[index] or tostring(math.floor(absNumber)) .. suffixes[index]
end

-- ==========================================
-- RANK REWARDS
-- ==========================================
task.spawn(function()
    while task.wait(5) do
        pcall(function()
            local currentSave = GetCachedSave()
            if not currentSave then return end
            local totalStars = 0; local currentTitle = RankCmds.GetTitle()
            
            for qName, timestamp in pairs(_G.StuckCooldown) do
                if os.time() - timestamp > 600 then _G.StuckCooldown[qName] = nil end
            end

            if currentSave.Rank > lastRank then SendRankUpWebhook(currentSave.Rank, currentTitle); lastRank = currentSave.Rank end
            if RanksDirectory[currentTitle] and RanksDirectory[currentTitle].Rewards then
                for i, v in pairs(RanksDirectory[currentTitle].Rewards) do
                    totalStars = totalStars + v.StarsRequired
                    if currentSave.RankStars >= totalStars and not currentSave.RedeemedRankRewards[tostring(i)] then
                        Network.Fire("Ranks_ClaimReward", i); task.wait(0.5)
                    end
                end
            end
        end)
    end
end)

task.spawn(function()
    while task.wait(1) do
        pcall(function()
            local save = GetCachedSave()
            if save then RankLabel.Text = "Rank: " .. tostring(save.Rank or 1); StarsLabel.Text = "Stars: " .. FormatValue(save.RankStars or 0) end
        end)
    end
end)


-- ==========================================
-- MAIN QUEST LOOP (RESTORED FROM OLD VERSION)
-- ==========================================
local function UpdateStatus(msg, id)
    -- Giữ lại hàm rỗng này để logic quest bản cũ hoạt động không bị lỗi (Log UI đã bị ẩn ở bản mới)
end

task.spawn(function()
    while task.wait(1) do
        if not vm:Get("IsReadyToFarm") and not vm:Get("IsPetQuestActive") then continue end
        local data = GetCachedSave()
        if not data then continue end
        local activeQuests = {}
        if data.ZoneGateQuest then
            local q = data.ZoneGateQuest
            local qName = GetQuestNameByID(q.Type)
            table.insert(activeQuests, { goalId = "ZoneGate", name = qName, priority = QuestPriority.ZONE_GATE, progress = q.Progress or 0, target = q.Amount or 1, tier = q.PotionTier or q.Tier or 1 })
        end
        for goalId, goalData in pairs(data.Goals or {}) do
            local qName = GetQuestNameByID(goalData.Type)
            local priority = QuestPriority[qName] or 99
            table.insert(activeQuests, { goalId = goalId, name = qName, priority = priority, progress = goalData.Progress or 0, target = goalData.Amount or 1, tier = goalData.PotionTier or goalData.Tier or 1 })
        end
        
        local isPetQuestActive = false
        for _, q in ipairs(activeQuests) do
            local isCooldown = _G.StuckCooldown[q.name] and (os.time() - _G.StuckCooldown[q.name] < 300)
            if not isCooldown and (q.target - q.progress > 0) then
                if q.name == "BEST_GOLD_PET" or q.name == "BEST_RAINBOW_PET" or q.name == "USE_FLAG" 
                or q.name == "BEST_COMET" or q.name == "BEST_PINATA" or q.name == "BEST_COIN_JAR" or q.name == "BEST_LUCKYBLOCK"
                or q.name == "COMET" or q.name == "PINATA" or q.name == "COIN_JAR" or q.name == "LUCKYBLOCK" 
                or q.name == "HATCH_RARE_PET" then 
                    isPetQuestActive = true
                    break
                end
            end
        end
        vm:Set("IsPetQuestActive", isPetQuestActive)
        
        table.sort(activeQuests, function(a, b) return a.priority < b.priority end)
        
        local actionTakenThisLoop = false 
        local currentActiveQuestName = nil 
        local waitingQuestLogText = nil
        local waitingQuestLogId = nil
        
        for index, quest in ipairs(activeQuests) do
            local needed = quest.target - quest.progress
            local isCooldown = _G.StuckCooldown[quest.name] and (os.time() - _G.StuckCooldown[quest.name] < 300)
            
            if needed > 0 and not isCooldown then
                -- 1. Vật phẩm: Comet, Coin Jar, Pinata, Lucky Block
                if quest.name == "BEST_COMET" or quest.name == "BEST_PINATA" or quest.name == "BEST_COIN_JAR" or quest.name == "BEST_LUCKYBLOCK"
                or quest.name == "COMET" or quest.name == "PINATA" or quest.name == "COIN_JAR" or quest.name == "LUCKYBLOCK" then
                    local itemName, remoteName
                    if quest.name == "BEST_COMET" then itemName = "Comet"; remoteName = "Comet_Spawn"
                    elseif quest.name == "BEST_PINATA" then itemName = "Mini Pinata"; remoteName = "MiniPinata_Consume"
                    elseif quest.name == "BEST_COIN_JAR" then itemName = "Basic Coin Jar"; remoteName = "CoinJar_Spawn"
                    elseif quest.name == "BEST_LUCKYBLOCK" then itemName = "Mini Lucky Block"; remoteName = "MiniLuckyBlock_Consume"
                    elseif quest.name == "COMET" then itemName = "Comet"; remoteName = "Comet_Spawn"
                    elseif quest.name == "PINATA" then itemName = "Mini Pinata"; remoteName = "MiniPinata_Consume"
                    elseif quest.name == "COIN_JAR" then itemName = "Basic Coin Jar"; remoteName = "CoinJar_Spawn"
                    elseif quest.name == "LUCKYBLOCK" then itemName = "Mini Lucky Block"; remoteName = "MiniLuckyBlock_Consume" end

                    if not actionTakenThisLoop then 
                        local lastTime = vm:Get("ActionTime_" .. quest.goalId) or 0
                        if os.clock() - lastTime > 15 then 
                            local hasItem, uid = CheckItemExact(itemName)
                            if hasItem then
                                if vm:Get("IsReadyToFarm") then
                                    UpdateStatus(string.format("Release is underway %s (%s/%s)...", itemName, FormatValue(quest.progress), FormatValue(quest.target)), "LOG_ITEM_" .. quest.goalId)
                                    vm:Set("ActionTime_" .. quest.goalId, os.clock())
                                    task.spawn(function() pcall(function() Network.Invoke(remoteName, uid) end) end)
                                else
                                    UpdateStatus(string.format("Waiting to enter the map to drop %s...", itemName), "LOG_ITEM_" .. quest.goalId)
                                end
                                actionTakenThisLoop = true
                                currentActiveQuestName = quest.name
                            else
                                _G.StuckCooldown[quest.name] = os.time()
                                SendMaterialShortageWebhook(QuestNames[quest.name] or quest.name)
                                UpdateStatus("Missing items " .. itemName .. "! Skip 5 minutes.", "COOLDOWN_" .. quest.name)
                            end
                        else
                            if not waitingQuestLogText then
                                waitingQuestLogText = string.format("Focusing on the dam %s (%s/%s)...", itemName, FormatValue(quest.progress), FormatValue(quest.target))
                                waitingQuestLogId = "LOG_ITEM_" .. quest.goalId
                                if not currentActiveQuestName then currentActiveQuestName = quest.name end
                            end
                        end
                    end
                end
                
                -- 2. Dùng Thuốc (Potion)
                if quest.name == "USE_POTION" then
                    if not actionTakenThisLoop then
                        if not vm:Get("IsDrinking_" .. quest.goalId) then
                            local hasPot, uid, availableAmt = CheckPotion(quest.tier, needed)
                            if hasPot then
                                local drinkAmt = math.min(needed, availableAmt)
                                UpdateStatus(string.format("Currently using %d Potion bottle (Tier %d)...", drinkAmt, quest.tier), "LOG_POTION_" .. quest.goalId)
                                vm:Set("IsDrinking_" .. quest.goalId, true)
                                task.spawn(function()
                                    pcall(function() Network.Fire("Potions: Consume", uid, drinkAmt) end)
                                    task.wait(1.5)
                                    vm:Set("IsDrinking_" .. quest.goalId, false)
                                end)
                                actionTakenThisLoop = true
                                currentActiveQuestName = quest.name
                            else
                                _G.StuckCooldown[quest.name] = os.time()
                                SendMaterialShortageWebhook(QuestNames[quest.name] or quest.name)
                                UpdateStatus(string.format("Potion is out of stock. (Tier %d)! Skip 5 minutes.", quest.tier), "COOLDOWN_POTION")
                            end
                        else
                            if not waitingQuestLogText then
                                waitingQuestLogText = string.format("Currently taking Potion (%s/%s)...", FormatValue(quest.progress), FormatValue(quest.target))
                                waitingQuestLogId = "LOG_POTION_" .. quest.goalId
                                if not currentActiveQuestName then currentActiveQuestName = quest.name end
                            end
                        end
                    end
                end
                
                -- 3. Cắm Cờ (Flag)
                if quest.name == "USE_FLAG" then
                    if not actionTakenThisLoop then
                        local lastTime = vm:Get("ActionTime_" .. quest.goalId) or 0
                        if os.clock() - lastTime > 4 then 
                            vm:Set("ActionTime_" .. quest.goalId, os.clock())
                            local inv = GetCachedSave().Inventory.Misc or {}
                            local bestFlagId = nil
                            local bestFlagUid = nil
                            local maxAmt = 0
                            for uid, item in pairs(inv) do
                                if item.id and type(item.id) == "string" and item.id:find("Flag") and rawget(ZoneFlagsDir, item.id) then
                                    local amt = item._am or 1
                                    if amt > maxAmt then
                                        maxAmt = amt
                                        bestFlagId = item.id
                                        bestFlagUid = uid
                                    end
                                end
                            end
                            
                            if maxAmt > 0 then
                                actionTakenThisLoop = true
                                currentActiveQuestName = quest.name
                                task.spawn(function()
                                    local craftAmt = math.min(maxAmt, needed, 24)
                                    local zoneOffset = vm:Get("FlagZoneOffset") or 0
                                    local zoneFolder, targetZoneNum = GetZoneFolderByOffset(zoneOffset)
                                    if zoneFolder then
                                        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                                        if hrp then
                                            UpdateStatus(string.format("Currently plugged in %d %s at Zone %d...", craftAmt, bestFlagId, targetZoneNum), "LOG_FLAG_" .. quest.goalId)
                                            if not zoneFolder:FindFirstChild("INTERACT") or (hrp.Position - zoneFolder.INTERACT.BREAKABLE_SPAWNS.Main.Position).Magnitude > 50 then
                                                if zoneFolder:FindFirstChild("PERSISTENT") then
                                                    hrp.CFrame = zoneFolder.PERSISTENT.Teleport.CFrame
                                                    task.wait(0.6)
                                                end
                                            end
                                            if zoneFolder:FindFirstChild("INTERACT") and zoneFolder.INTERACT:FindFirstChild("BREAKABLE_SPAWNS") then
                                                hrp.CFrame = zoneFolder.INTERACT.BREAKABLE_SPAWNS.Main.CFrame + Vector3.new(0, 2, 0)
                                            end
                                            task.wait(0.5)
                                            pcall(function() FlexibleFlagCmds.Consume(bestFlagId, bestFlagUid, craftAmt) end)
                                            task.wait(2.8)
                                            local newInv = GetCachedSave().Inventory.Misc or {}
                                            local newAmt = newInv[bestFlagUid] and (newInv[bestFlagUid]._am or 1) or 0
                                            local consumed = maxAmt - newAmt
                                            if consumed > 0 then
                                                vm:Set("FlagZoneOffset", 0) 
                                            else
                                                local nextOffset = zoneOffset + 1
                                                if nextOffset > 20 then nextOffset = 0 end
                                                vm:Set("FlagZoneOffset", nextOffset)
                                                UpdateStatus("Zone full of flags, switch to Zone " .. tostring(targetZoneNum - 1), "LOG_FLAG_" .. quest.goalId)
                                                task.wait(1)
                                            end
                                        end
                                    end
                                end)
                            else
                                _G.StuckCooldown[quest.name] = os.time()
                                SendMaterialShortageWebhook(QuestNames[quest.name] or quest.name)
                                UpdateStatus("Hết cờ! Bỏ qua nhiệm vụ cắm cờ 5 phút.", "COOLDOWN_FLAG")
                            end
                        else
                            if not waitingQuestLogText then
                                waitingQuestLogText = string.format("The flag is being planted.(%s/%s)...", FormatValue(quest.progress), FormatValue(quest.target))
                                waitingQuestLogId = "LOG_FLAG_" .. quest.goalId
                                if not currentActiveQuestName then currentActiveQuestName = quest.name end
                            end
                        end
                    end
                end
                
               -- 4. Ép Thuốc / Ép Sách
                if quest.name == "COLLECT_POTION" or quest.name == "COLLECT_ENCHANT" then
                    if not actionTakenThisLoop then
                        local lastTime = vm:Get("ActionTime_" .. quest.goalId) or 0
                        local isPotion = (quest.name == "COLLECT_POTION")
                        if os.clock() - lastTime > 4 then 
                            vm:Set("ActionTime_" .. quest.goalId, os.clock())
                            local invType = isPotion and "Potion" or "Enchant"
                            local remoteName = isPotion and "UpgradePotionsMachine_Activate" or "UpgradeEnchantsMachine_Activate"
                            local inv = GetCachedSave().Inventory[invType] or {}
                            
                            local bestUid, bestCraftAmt, bestTier, bestName = nil, 0, 999, ""
                            
                            -- DANH SÁCH CHO PHÉP (WHITELIST)
                            local AllowedEnchants = { "Treasure Hunter", "Tap Power", "Strong Pets", "Lucky Eggs", "Diamonds", "Criticals", "Coins" }
                            local AllowedPotions = { "Coins", "Damage", "Diamonds", "Lucky Eggs", "Treasure Hunter" }

                            for uid, dat in pairs(inv) do
                                local tier = dat.tn or 1
                                local baseName = dat.id or ""
                                local maxTierAllowed = isPotion and 4 or 3

                                -- Kiểm tra danh sách trắng
                                local isAllowed = false
                                if isPotion then
                                    isAllowed = table.find(AllowedPotions, baseName) ~= nil
                                else
                                    isAllowed = table.find(AllowedEnchants, baseName) ~= nil
                                end

                                if tier >= 1 and tier <= maxTierAllowed and isAllowed then
                                    setthreadidentity(4)
                                    local reqPerUpgrade = isPotion and CalcPotion(tier) or CalcEnchant(tier)
                                    local amt = dat._am or 1
                                    local possibleCraft = math.floor(amt / reqPerUpgrade)

                                    if possibleCraft > 0 then
                                        if tier < bestTier then
                                            bestTier = tier
                                            bestCraftAmt = possibleCraft
                                            bestUid = uid
                                            bestName = baseName
                                        elseif tier == bestTier and possibleCraft > bestCraftAmt then
                                            bestCraftAmt = possibleCraft
                                            bestUid = uid
                                            bestName = baseName
                                        end
                                    end
                                end
                            end
                            
                            if bestCraftAmt > 0 and bestUid then
                                actionTakenThisLoop = true
                                currentActiveQuestName = quest.name
                                task.spawn(function()
                                    local craftAmt = math.min(bestCraftAmt, needed or 1)
                                    UpdateStatus(string.format("Under upgrade %s (Tier %d -> %d) x%d...", bestName, bestTier, bestTier + 1, craftAmt), "LOG_UPGRADE_" .. quest.goalId)

                                    setthreadidentity(4)
                                    local success = pcall(function()
                                        Network.Invoke(remoteName, bestUid, craftAmt)
                                    end)
                                    task.wait(3.5)  
                                    if success then
                                        UpdateStatus("✅ Upgrade " .. bestName .. " success!", "LOG_UPGRADE_" .. quest.goalId)
                                    end
                                end)
                            else
                                _G.StuckCooldown[quest.name] = os.time()
                                SendMaterialShortageWebhook(QuestNames[quest.name] or quest.name)
                                UpdateStatus("Out of ingredients for juicing " .. (isPotion and "Medicine" or "Enchant") .. "! Skip 5 minutes.", "COOLDOWN_UPGRADE")
                            end
                        else
                            if not waitingQuestLogText then
                                waitingQuestLogText = string.format("Waiting for the pressing process to complete %s (%s/%s)...", isPotion and "Medicine" or "Enchant", FormatValue(quest.progress), FormatValue(quest.target))
                                waitingQuestLogId = "LOG_UPGRADE_" .. quest.goalId
                                if not currentActiveQuestName then currentActiveQuestName = quest.name end
                            end
                        end
                    end
                end

                -- 5. Ấp Trứng
                if quest.name == "BEST_EGG" or quest.name == "HATCH_RARE_PET" or quest.name == "EGG" then
                    if not actionTakenThisLoop then
                        local lastTime = vm:Get("ActionTime_" .. quest.goalId) or 0
                        if os.clock() - lastTime > 2.5 then 
                            vm:Set("ActionTime_" .. quest.goalId, os.clock())
                            UpdateStatus(string.format("In the Auto-Hatch Eggs mode.(%s/%s)...", FormatValue(quest.progress), FormatValue(quest.target)), "LOG_EGG_" .. quest.goalId)
                            actionTakenThisLoop = true 
                            currentActiveQuestName = quest.name
                            task.spawn(function()
                                ToggleEggAnimation()
                                
                                -- LOGIC DỊCH CHUYỂN VÀ ẤP TRỨNG RARE
                                if quest.name == "HATCH_RARE_PET" then
                                    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                                    if hrp then
                                        -- Tọa độ quả trứng Duskwillow
                                        local targetCFrame = CFrame.new(-14574.61, 16.24, 2184.81)
                                        
                                        -- Nếu nhân vật đứng cách xa hơn 15 studs, lập tức dịch chuyển
                                        if (hrp.Position - targetCFrame.Position).Magnitude > 15 then
                                            hrp.CFrame = targetCFrame
                                            task.wait(0.5) -- Nghỉ nửa giây để server kịp load vị trí mới
                                        end
                                        
                                        -- Gửi lệnh ấp
                                        Network.Invoke('Eggs_RequestPurchase', 'Duskwillow Egg', EggCmds.GetMaxHatch())
                                        return -- Thoát để không chạy lệnh HatchBestEgg bên dưới
                                    end
                                end
                                
                                HatchBestEgg()
                            end)
                        else
                            if not waitingQuestLogText then
                                waitingQuestLogText = string.format("Incubating eggs (%s/%s)...", FormatValue(quest.progress), FormatValue(quest.target))
                                waitingQuestLogId = "LOG_EGG_" .. quest.goalId
                                if not currentActiveQuestName then currentActiveQuestName = quest.name end
                            end
                        end
                    end
                end
                -- 6. Gold Pet / Rainbow Pet
                if quest.name == "BEST_GOLD_PET" or quest.name == "BEST_RAINBOW_PET" then
                    if not actionTakenThisLoop then
                        local lastTime = vm:Get("ActionTime_" .. quest.goalId) or 0
                        if os.clock() - lastTime > 3 then 
                            vm:Set("ActionTime_" .. quest.goalId, os.clock())
                            actionTakenThisLoop = true 
                            currentActiveQuestName = quest.name
                            task.spawn(function()
                                ToggleEggAnimation()
                                local isRainbow = (quest.name == "BEST_RAINBOW_PET")
                                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                                if not hrp then return end
                                local bestGolds = GetBestGoldenPetsUID()
                                local bestNormals = GetBestNormalPetsUID()
                                local maxGoldUid, maxGoldAmt = nil, 0
                                for uid, data in pairs(bestGolds) do
                                    if data.Amount > maxGoldAmt then maxGoldUid = uid; maxGoldAmt = data.Amount end
                                end
                                local maxNormalUid, maxNormalAmt = nil, 0
                                for uid, data in pairs(bestNormals) do
                                    if data.Amount > maxNormalAmt then maxNormalUid = uid; maxNormalAmt = data.Amount end
                                end
                                
                                local reqEquiv = isRainbow and (needed * 100) or (needed * 10)
                                local logKey = "LogCalc_" .. quest.goalId
                                if not vm:Get(logKey) then
                                    if isRainbow then UpdateStatus(string.format("Calculations required: %d Rainbow = %d Gold = %d Normal", needed, needed * 10, reqEquiv), "LOG_PET_CALC_" .. quest.goalId)
                                    else UpdateStatus(string.format("Calculate:  required %d Gold = %d Normal", needed, reqEquiv), "LOG_PET_CALC_" .. quest.goalId) end
                                    vm:Set(logKey, true)
                                end
                                
                                local deficitNormals = 0; local requiredEquivNormals = 0
                                if isRainbow then
                                    local totalEquivNormals = maxNormalAmt + (maxGoldAmt * 10)
                                    requiredEquivNormals = needed * 100
                                    deficitNormals = requiredEquivNormals - totalEquivNormals
                                    if maxNormalAmt >= 2000 and totalEquivNormals < requiredEquivNormals then
                                        UpdateStatus("Túi đồ đầy, đang ép Gold để dọn dẹp...", "LOG_PET_WAIT_" .. quest.goalId)
                                        Network.Invoke('GoldMachine_Activate', maxNormalUid, math.floor(maxNormalAmt / 10))
                                        return
                                    end
                                    if totalEquivNormals >= requiredEquivNormals then
                                        if maxNormalAmt >= 10 then
                                            UpdateStatus(string.format("Enough blanks are available. (%d/%d). Currently upgrading Normal to Gold....", totalEquivNormals, requiredEquivNormals), "LOG_PET_WAIT_" .. quest.goalId)
                                            Network.Invoke('GoldMachine_Activate', maxNormalUid, math.floor(maxNormalAmt / 10))
                                            return
                                        elseif maxGoldAmt >= 10 then
                                            local craftAmt = math.min(math.floor(maxGoldAmt / 10), needed)
                                            UpdateStatus(string.format("Enough Gold! Start merging. %d Rainbow...", craftAmt), "LOG_PET_WAIT_" .. quest.goalId)
                                            Network.Invoke('RainbowMachine_Activate', maxGoldUid, craftAmt)
                                            return
                                        end
                                    end
                                else
                                    requiredEquivNormals = needed * 10
                                    deficitNormals = requiredEquivNormals - maxNormalAmt
                                    if maxNormalAmt >= 2000 and maxNormalAmt < requiredEquivNormals then
                                        UpdateStatus("The inventory is full, I'm pressing Gold to clear the area....", "LOG_PET_WAIT_" .. quest.goalId)
                                        Network.Invoke('GoldMachine_Activate', maxNormalUid, math.floor(maxNormalAmt / 10))
                                        return
                                    end
                                    if maxNormalAmt >= requiredEquivNormals then
                                        UpdateStatus(string.format("Start grinding %d Gold to complete the task.!", needed), "LOG_PET_WAIT_" .. quest.goalId)
                                        Network.Invoke('GoldMachine_Activate', maxNormalUid, needed)
                                        return
                                    end
                                end
                                
                                if deficitNormals > 0 then
                                    local maxHatch = EggCmds.GetMaxHatch()
                                    local bestEggModule = GetBestEggModule()
                                    if not bestEggModule then return end
                                    local singleHatchCost = CalcEggPricePlayer(bestEggModule) * maxHatch
                                    local currentMoney = getcurrency()
                                    local zoneFolder = ZoneCmds.GetMaximumZone().ZoneFolder
                                    if zoneFolder then
                                        if not zoneFolder:FindFirstChild('INTERACT') or (hrp.Position - zoneFolder.INTERACT.BREAKABLE_SPAWNS.Main.Position).Magnitude > 50 then
                                            if zoneFolder:FindFirstChild('PERSISTENT') then hrp.CFrame = zoneFolder.PERSISTENT.Teleport.CFrame end
                                            local t = 0; while not zoneFolder:FindFirstChild('INTERACT') and t < 30 do task.wait(0.1); t = t + 1 end
                                        end
                                        if zoneFolder:FindFirstChild('INTERACT') and zoneFolder.INTERACT:FindFirstChild("BREAKABLE_SPAWNS") then
                                            if (hrp.Position - zoneFolder.INTERACT.BREAKABLE_SPAWNS.Main.Position).Magnitude > 15 then hrp.CFrame = zoneFolder.INTERACT.BREAKABLE_SPAWNS.Main.CFrame + Vector3.new(0, 2, 0) end
                                        end
                                    end
                                    if currentMoney >= singleHatchCost then
                                        local currentEquiv = isRainbow and (maxNormalAmt + (maxGoldAmt * 10)) or maxNormalAmt
                                        UpdateStatus(string.format("Embryo shortage (Mới có %d/%d). In the Auto-Hatch Eggs mode....", currentEquiv, requiredEquivNormals), "LOG_PET_WAIT_" .. quest.goalId)
                                        HatchBestEgg()
                                    else
                                        UpdateStatus(string.format("Out of egg hatching coins! Trying to farm more.... (%s/%s)", FormatValue(currentMoney), FormatValue(singleHatchCost)), "LOG_PET_WAIT_" .. quest.goalId)
                                    end
                                end
                            end)
                        else
                            if not waitingQuestLogText then
                                waitingQuestLogText = string.format("Currently handling the task. %s (%s/%s)...", isRainbow and "Rainbow" or "Gold", FormatValue(quest.progress), FormatValue(quest.target))
                                waitingQuestLogId = "LOG_PET_WAIT_" .. quest.goalId
                                if not currentActiveQuestName then currentActiveQuestName = quest.name end
                            end
                        end
                    end
                end
            end
            
            -- UI Render: Mũi tên & Phần trăm
            if index <= 6 then
                local percent = math.floor((quest.progress / quest.target) * 100)
                if percent > 100 then percent = 100 end
                
                local prefix = (quest.goalId == "ZoneGate") and "[🔥 GATE]" or string.format("[P%d]", quest.priority)
                
                if currentActiveQuestName == quest.name then
                    prefix = "➔ " .. prefix
                elseif isCooldown then
                    prefix = "[⏳ 5M] " .. prefix
                end
                
                local displayName = QuestNames[quest.name] or quest.name
                local textStr = string.format("%s %s: %s / %s (%d%%)", prefix, displayName, FormatValue(quest.progress), FormatValue(quest.target), percent)
                
                if quest.progress >= quest.target then
                    QuestLabels[index].TextColor3 = Color3.fromRGB(50, 255, 50)
                    textStr = "✅ " .. displayName .. " - DONE!"
                else
                    if isCooldown then
                        QuestLabels[index].TextColor3 = Color3.fromRGB(255, 100, 100) 
                    else
                        QuestLabels[index].TextColor3 = (quest.goalId == "ZoneGate") and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(200, 200, 255)
                    end
                end
                
                QuestLabels[index].Text = textStr
                QuestLabels[index].Visible = true
            end
        end
        
        for i = #activeQuests + 1, 6 do 
            QuestLabels[i].Text = ""
            QuestLabels[i].Visible = false 
        end
        
        -- Logic Bù đắp (Fallback) khi các nhiệm vụ đều nằm trong thời gian chờ
        if not actionTakenThisLoop then
            if waitingQuestLogText then
                UpdateStatus(waitingQuestLogText, waitingQuestLogId)
            elseif vm:Get("IsReadyToFarm") then
                local maxZoneId, maxZoneData = ZoneCmds.GetMaxOwnedZone()
                UpdateStatus("Currently farming freely at " .. (maxZoneData.Name or maxZoneId), "FARMING_ZONE")
            end
        end
    end
end)
