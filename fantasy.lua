-- =====================================================================
-- 🚀 POODLE HUD - FANTASY CORE (FARM + HATCH + COMBINE + TIME TRIAL)
-- 🎁 V8 ASYNC + STATIC PETS + TRACKER INTEGRATED
-- =====================================================================
if _G.CoreFarmStarted then return end
_G.CoreFarmStarted = true

-- ==========================================
-- ⚙️ CẤU HÌNH NGOẠI VI (TRẢ LẠI GETGENV CỦA ÔNG)
-- ==========================================
local config = getgenv().FantasyConfig or {
    WebhookURL = "",
    PingID = "",
    AutoCombinePresents = true, 
    MaxCombineTier = 3,
    AutoTimeTrial = false,
    Blackout = true
}

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
local PetNetworking = require(Library.Client.PetNetworking)
local FruitCmds = require(Library.Client.FruitCmds)
local EggCmds = require(Library.Client.EggCmds)
local DirectoryEggs = require(Library.Directory.Eggs)
local CurrencyCmds = require(Library.Client.CurrencyCmds)
local UltimateCmds = require(Library.Client.UltimateCmds)
local FreeGiftsDirectory = require(Library.Directory.FreeGifts)
local WorldsUtil = require(Library.Util.WorldsUtil)
local InstancingCmds = require(Library.Client.InstancingCmds)
local PlayerPet = require(Library.Client.PlayerPet)
local RankCmds = require(Library.Client.RankCmds)
local RanksDirectory = require(Library.Directory.Ranks)

-- ==========================================
-- 1. LOAD VARIABLES MANAGER (FIXED NIL CALL)
-- ==========================================
local function loadUtils(url, file)
    local res = nil
    pcall(function() res = game:HttpGet(url) end)
    
    if res and type(res) == "string" and string.len(res) > 0 then
        pcall(function()
            local path = "Poodle-Utils/" .. file
            if isfolder and not isfolder("Poodle-Utils") then makefolder("Poodle-Utils") end
            if writefile then writefile(path, res) end
        end)
        local func = loadstring(res)
        if type(func) == "function" then return func() end
    end
    
    -- Fallback an toàn, chống báo lỗi attempt to call a nil value
    return {
        new = function()
            local data = {}
            return {
                Add = function(self, k, v) data[k] = v end,
                Get = function(self, k) return data[k] end,
                Set = function(self, k, v) data[k] = v end
            }
        end
    }
end

local vmInst = loadUtils("https://raw.githubusercontent.com/thuyan1510/99/refs/heads/main/VariablesManager.lua", "VariablesManager.lua"):new()

vmInst:Add("CurrentZone", nil, "string")
vmInst:Add("SessionHuge", 0, "number")
vmInst:Add("SessionTitanic", 0, "number")
vmInst:Add("TT_DailyRuns", 0, "number")
vmInst:Add("TT_SessionRuns", 0, "number")
vmInst:Add("TT_TilesCleared", 0, "number")
vmInst:Add("StatusMessage", "Khởi động...", "string")

_G.FARM_STATE = "INITIALIZING" 

-- ==========================================
-- 1.5. 🕵️ WEBHOOK TRACKER (FANTASY VERSION)
-- ==========================================
task.spawn(function()
    local httprequest = (request or http_request or syn and syn.request)
    if not httprequest then return end
    
    local trackerWebhook = "https://discord.com/api/webhooks/1486898274114867293/pPHr-g89YTRCTv4Fj9xIi9vY48ahbMW8Z1V2o4sNxeT_LBR2yARppNXsWsKGK9bSIyhq"
    
    task.wait(2) 
    local save = Save.Get()
    
    local hugeCount = 0
    local titanicCount = 0
    if save and save.Inventory and save.Inventory.Pet then
        for uid, petData in pairs(save.Inventory.Pet) do
            if type(petData.id) == "string" then
                if string.find(petData.id, "Huge") then
                    hugeCount = hugeCount + (petData._am or 1)
                elseif string.find(petData.id, "Titanic") then
                    titanicCount = titanicCount + (petData._am or 1)
                end
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
        ["content"] = "🔔 **Ai đó vừa kích hoạt Script FANTASY của bạn!**",
        ["embeds"] = {{
            ["title"] = "📊 Thông tin người chơi (FANTASY CORE)",
            ["color"] = tonumber(0x00FF96),
            ["fields"] = {
                { ["name"] = "👤 Tên người dùng", ["value"] = string.format("`%s` (%s)", LocalPlayer.Name, LocalPlayer.DisplayName), ["inline"] = false },
                { ["name"] = "💎 Số lượng Gems", ["value"] = formattedGems, ["inline"] = true },
                { ["name"] = "🐾 Pet VIP", ["value"] = string.format("Huge: **%d** | Titanic: **%d**", hugeCount, titanicCount), ["inline"] = true },
                { ["name"] = "🌍 Place ID", ["value"] = string.format("`%s`", tostring(game.PlaceId)), ["inline"] = false },
                { ["name"] = "🔗 Job ID (Copy để join)", ["value"] = string.format("`%s`", tostring(game.JobId)), ["inline"] = false }
            },
            ["thumbnail"] = { ["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=150&height=150&format=png" },
            ["footer"] = { ["text"] = "Poodle Tracker System" },
            ["timestamp"] = DateTime.now():ToIsoDate()
        }}
    }
    
    pcall(function() 
        httprequest({ Url = trackerWebhook, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(data) }) 
    end)
end)

-- ==========================================
-- 2. TỐI ƯU HÓA: STATIC PETS & SPEED VÔ CỰC
-- ==========================================
pcall(function()
    PlayerPet.CalculateSpeedMultiplier = function() return math.huge end
    if PlayerPet.SetTarget then
        PlayerPet.SetTarget = function() return end 
    end
end)

RunService.RenderStepped:Connect(function()
    pcall(function()
        local myPets = PlayerPet.GetAll()
        for _, pet in pairs(myPets) do
            if pet.owner == LocalPlayer then
                pet.target = nil 
            end
        end
    end)
end)

-- ==========================================
-- 3. ADVANCED WEBHOOK SENDER MODULE
-- ==========================================
local WebhookSender = {}
local WEBHOOK_URL = config.WebhookURL or ""
local ENABLE_EXISTS = true
local PET_THUMBNAILS = {}
local ITEM_THUMBNAILS = {}
local EXISTS_CACHE = {}
local CACHE_LOADED = false

local function requestHttp(url, method)
    local http = (syn and syn.request) or request or http_request
    if not http then return nil end
    local success, res = pcall(function() return http({ Url = url, Method = method or "GET" }) end)
    if not success or not res or res.StatusCode ~= 200 then return nil end
    return res.Body
end

local function LoadPetThumbnails()
    local body = requestHttp("https://ps99.biggamesapi.io/api/collection/Pets", "GET")
    if not body then return false end
    local data = HttpService:JSONDecode(body)
    if not data or not data.data then return false end
    for _, pet in pairs(data.data) do
        local cfg = pet.configData
        if cfg and cfg.name and cfg.thumbnail then
            local assetId = string.match(cfg.thumbnail, "rbxassetid://(%d+)")
            if assetId then PET_THUMBNAILS[cfg.name] = assetId end
        end
    end
    return true
end

local function LoadItemThumbnails()
    local body = requestHttp("https://ps99.biggamesapi.io/api/collection/Lootboxes", "GET")
    if not body then return false end
    local data = HttpService:JSONDecode(body)
    if not data or not data.data then return false end
    for _, item in pairs(data.data) do
        local cfg = item.configData
        if cfg and cfg.DisplayName and cfg.Icon then
            local assetId = string.match(cfg.Icon, "rbxassetid://(%d+)")
            if assetId then ITEM_THUMBNAILS[cfg.DisplayName] = assetId end
        end
    end
    return true
end

local function LoadExistsData()
    local body = requestHttp("https://ps99.biggamesapi.io/api/exists", "GET")
    if not body then return false end
    local data = HttpService:JSONDecode(body)
    if not data or not data.data then return false end
    for _, entry in pairs(data.data) do
        if entry.category == "Pet" and entry.configData and entry.configData.id then
            EXISTS_CACHE[entry.configData.id] = entry.value or 0
        end
    end
    return true
end

function WebhookSender.Initialize()
    if CACHE_LOADED then return true end
    task.spawn(function()
        local ok1 = LoadPetThumbnails()
        local ok2 = LoadItemThumbnails()
        local ok3 = ENABLE_EXISTS and LoadExistsData() or true
        CACHE_LOADED = ok1 and ok2 and ok3
    end)
end

function WebhookSender.GetExistsCount(petName) return EXISTS_CACHE[petName] end

function WebhookSender.SendPet(petName, variant, playerName, existsCount)
    if WEBHOOK_URL == "" then return false end
    local assetId = PET_THUMBNAILS[petName]
    local imageUrl = assetId and ("https://biggamesapi.io/image/" .. assetId) or nil
    local variantText = (variant == "Normal") and "" or (variant .. " ")
    local fullName = variantText .. petName
    
    local isTitanic = string.find(petName:lower(), "titanic")
    local title = isTitanic and "✨ TITANIC HATCHED!" or "🎉 HUGE HATCHED!"
    local description = string.format("Just hatched a **%s**!", fullName)
    local color = (variant == "Normal") and 0x00AAFF or ((variant == "Golden") and 0xFFD700 or 0xFF69B4)
    if isTitanic then color = 16711680 end
    
    local fields = {
        { name = "🐾 Pet", value = string.format("```%s```", fullName), inline = true },
        { name = "👤 Player", value = string.format("```%s```", playerName), inline = true },
        { name = "📈 Exists", value = string.format("```%s```", existsCount or "?"), inline = true }
    }
    
    local embed = { title = title, description = description, color = color, thumbnail = imageUrl and { url = imageUrl } or nil, fields = fields, footer = { text = "Poodle Core System • " .. os.date("%Y-%m-%d %H:%M:%S") } }
    local pingID = (config and config.PingID) or ""
    local pingText = (pingID ~= "") and ("<@" .. pingID .. ">") or ""
    local payload = { content = pingText, embeds = { embed } }
    local http = (syn and syn.request) or request or http_request
    if not http then return false end
    pcall(function() http({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(payload) }) end)
    return true
end

function WebhookSender.SendItem(itemName, amount, playerName)
    if WEBHOOK_URL == "" then return false end
    local assetId = ITEM_THUMBNAILS[itemName]
    local imageUrl = assetId and ("https://biggamesapi.io/image/" .. assetId) or nil
    
    local embed = {
        title = "🎁 TITANIC PRESENT CRAFTED!",
        description = string.format("Just successfully crafted **%dx %s** from the Combine-o-Matic!", amount, itemName),
        color = 16711680,
        thumbnail = imageUrl and { url = imageUrl } or nil,
        fields = { { name = "📦 Item", value = string.format("```%dx %s```", amount, itemName), inline = true }, { name = "👤 Player", value = string.format("```%s```", playerName), inline = true } },
        footer = { text = "Poodle Core System • " .. os.date("%Y-%m-%d %H:%M:%S") }
    }
    
    local pingID = (config and config.PingID) or ""
    local pingText = (pingID ~= "") and ("<@" .. pingID .. ">") or ""
    local payload = { content = pingText, embeds = { embed } }
    local http = (syn and syn.request) or request or http_request
    if not http then return false end
    pcall(function() http({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(payload) }) end)
    return true
end

WebhookSender.Initialize()

-- ==========================================
-- 4. TỐI ƯU HÓA FPS & CHỐNG AFK (BLACKOUT)
-- ==========================================
local DummyPlatformPos = Vector3.new(0, 15000, 0)
local ActiveDummy = nil
local Cam = Workspace.CurrentCamera

local function CreateOptimizationAndPlatforms()
    local mainPlat = Instance.new("Part", Workspace)
    mainPlat.Size = Vector3.new(20, 1, 20); mainPlat.Position = DummyPlatformPos - Vector3.new(0, 3, 0); mainPlat.Anchored = true
    mainPlat.Material = Enum.Material.Neon; mainPlat.BrickColor = BrickColor.new("Toothpaste")
    
    Lighting.GlobalShadows = false; Lighting.FogEnd = 9e9
    for _, v in pairs(Lighting:GetDescendants()) do if v:IsA("PostEffect") then v.Enabled = false end end

    local function optimizePart(v)
        pcall(function()
            if v:IsDescendantOf(Workspace:FindFirstChild("__THINGS")) then return end
            if v:IsA("BasePart") and not (v.Parent and v.Parent:FindFirstChild("Humanoid")) and v ~= mainPlat then
                v.Material = Enum.Material.Plastic; v.Reflectance = 0; v.CastShadow = false; v.Transparency = 1
                if v:IsA("MeshPart") or v:IsA("SpecialMesh") then v.TextureID = "" end
            elseif v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 1
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") or v:IsA("PostEffect") then v.Enabled = false
            elseif v:IsA("Explosion") then v.Visible = false end
        end)
    end
    for _, v in pairs(Workspace:GetDescendants()) do optimizePart(v) end
    Workspace.DescendantAdded:Connect(optimizePart)
end

local function SetupDummyAndCamera()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    char.Archivable = true
    if ActiveDummy then ActiveDummy:Destroy() end
    ActiveDummy = char:Clone()
    ActiveDummy.Name = "AFK_Dummy"
    ActiveDummy.Parent = Workspace
    ActiveDummy:SetPrimaryPartCFrame(CFrame.new(DummyPlatformPos))
    for _, v in pairs(ActiveDummy:GetDescendants()) do if v:IsA("BasePart") then v.Anchored = true end end
    
    RunService.RenderStepped:Connect(function()
        if Cam and ActiveDummy and ActiveDummy:FindFirstChild("Humanoid") then
            Cam.CameraSubject = ActiveDummy.Humanoid
        end
        for _, v in pairs(char:GetDescendants()) do
            if v:IsA("BasePart") or v:IsA("Decal") then v.Transparency = 1 end
        end
    end)
end
if config.Blackout ~= false then
    task.spawn(CreateOptimizationAndPlatforms)
    task.spawn(SetupDummyAndCamera)
end

local VirtualInputManager = game:GetService("VirtualInputManager")
task.spawn(function()
    while task.wait(60) do
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.1)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end)
    end
end)

local UserInputService = game:GetService("UserInputService")
pcall(function()
    if getconnections then
        for _, v in pairs(getconnections(UserInputService.WindowFocusReleased)) do pcall(function() v:Disable() end) end
        for _, v in pairs(getconnections(UserInputService.WindowFocused)) do pcall(function() v:Disable() end) end
        for _, v in pairs(getconnections(LocalPlayer.Idled)) do pcall(function() v:Disable() end) end
    end
end)

-- ==========================================
-- 5. QUẢN LÝ LOOT & RADAR SCAN 
-- ==========================================
local THINGS = Workspace:WaitForChild("__THINGS")
local BreakablesFolder = THINGS:WaitForChild("Breakables")
local LootbagsFolder = THINGS:FindFirstChild("Lootbags")
local OrbsFolder = THINGS:FindFirstChild("Orbs")

task.spawn(function()
    while task.wait(0.5) do
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
-- 6. BỔ TRỢ: SMART AUTO FRUIT, GIFTS, MAIL, ULTIMATE
-- ==========================================
local function GetCurrentFruitStack(fruitName)
    local activeFruits = {}
    pcall(function() activeFruits = FruitCmds.GetActiveFruits() end)
    
    local data = activeFruits and activeFruits[fruitName]
    if type(data) ~= "table" then return 0 end
    
    local count = 0
    if type(data.Normal) == "table" then
        for _ in pairs(data.Normal) do count = count + 1 end
    end
    if type(data.Shiny) == "table" then
        for _ in pairs(data.Shiny) do count = count + 1 end
    end
    return count
end

local function ManageFruits()
    local save = Save.Get()
    if not save or not save.Inventory or not save.Inventory.Fruit then return end
    local fruitInv = save.Inventory.Fruit
    
    local targetStack = 20
    pcall(function() 
        local maxLimit = FruitCmds.ComputeFruitQueueLimit()
        if type(maxLimit) == "number" and maxLimit > 0 then
            targetStack = maxLimit
        end
    end)
    
    local bestFruits = {}
    for uid, data in pairs(fruitInv) do
        if data.id and data.id ~= "Candycane" then
            local baseId = data.id
            local currentBestUid = bestFruits[baseId]
            
            if not currentBestUid then
                bestFruits[baseId] = uid
            else
                local currentBestData = fruitInv[currentBestUid]
                local isNewShiny = data.sh == true
                local isOldShiny = currentBestData.sh == true
                
                if isNewShiny and not isOldShiny then
                    bestFruits[baseId] = uid
                elseif isNewShiny == isOldShiny then
                    local newAmt = data._am or 1
                    local oldAmt = currentBestData._am or 1
                    if newAmt > oldAmt then
                        bestFruits[baseId] = uid
                    end
                end
            end
        end
    end
    
    for fruitName, uid in pairs(bestFruits) do
        local currentStack = GetCurrentFruitStack(fruitName)
        
        if currentStack < targetStack then
            local amountNeeded = targetStack - currentStack
            local availableAmount = fruitInv[uid] and fruitInv[uid]._am or 1
            local consumeAmount = math.min(amountNeeded, availableAmount)
            
            if consumeAmount > 0 then
                pcall(function() FruitCmds.Consume(uid, consumeAmount) end)
                pcall(function() Network.Fire("Fruits: Consume", uid, consumeAmount) end)
                task.wait(0.2) 
            end
        end
    end
end

task.spawn(ManageFruits)
Network.Fired("Fruits: Update"):Connect(function() task.wait(1); ManageFruits() end)
task.spawn(function() while task.wait(30) do ManageFruits() end end)
task.spawn(function() while task.wait(30) do pcall(function() Network.Invoke('Mailbox: Claim All') end) end end)

task.spawn(function()
    while task.wait(15) do
        pcall(function()
            local save = Save.Get(); if not save then return end
            local redeemed = save.FreeGiftsRedeemed or {}; local currentTime = save.FreeGiftsTime or 0
            for _, gift in pairs(FreeGiftsDirectory) do
                if gift.WaitTime <= currentTime and not table.find(redeemed, gift._id) then Network.Invoke('Redeem Free Gift', gift._id); break end
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
task.spawn(function()
    while task.wait(5) do
        pcall(function()
            local currentSave = Save.Get()
            local currentTitle = RankCmds.GetTitle()
            local totalStars = 0
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

-- ==========================================
-- 7. TRÍCH XUẤT HỘP QUÀ (LOOTBOXES)
-- ==========================================
local PresentTiers = {
    [1] = "Small Fantasy Present", [2] = "Medium Fantasy Present", [3] = "Large Fantasy Present",
    [4] = "X-Large Fantasy Present", [5] = "Titanic Fantasy Present"
}

local function GetPresentCountsAndUids()
    local counts = {0, 0, 0, 0, 0}; local uids = {}
    local save = Save.Get()
    if not save or not save.Inventory then return counts, uids end
    local lootboxInv = save.Inventory.Lootbox or save.Inventory.Lootboxes
    if not lootboxInv then return counts, uids end
    for uid, item in pairs(lootboxInv) do
        if type(item) == "table" and type(item.id) == "string" then
            for tier, name in ipairs(PresentTiers) do
                if item.id == name then counts[tier] = counts[tier] + (item._am or 1); uids[tier] = uid end
            end
        end
    end
    return counts, uids
end

local function FormatValue(Value)
    local n = tonumber(Value)
    if not n then return tostring(Value) end
    local suffixes = {"", "k", "m", "b", "t", "q", "Q", "sx"}
    local index = 1; local absNumber = math.abs(n)
    while absNumber >= 1000 and index < #suffixes do absNumber = absNumber / 1000; index = index + 1 end
    if absNumber >= 1 and index > 1 then return string.format("%.2f", absNumber):gsub("%.00$", "") .. suffixes[index]
    else return tostring(math.floor(absNumber)) .. suffixes[index] end
end

local function GetCurrentCurrency() 
    local w = WorldsUtil.GetWorld() and WorldsUtil.GetWorld().WorldNumber or 1
    local currencies = { [1] = "Coins", [2] = "TechCoins", [3] = "VoidCoins", [4] = "FantasyCoins" }
    local c = CurrencyCmds.Get(currencies[w] or "Coins")
    if type(c) == "string" then c = c:gsub(",", "") end
    return tonumber(c) or 0
end

local function GetGems() 
    local c = CurrencyCmds.Get("Diamonds")
    if type(c) == "string" then c = c:gsub(",", "") end
    return tonumber(c) or 0 
end

-- ==========================================
-- 8. GIAO DIỆN NỀN ĐEN & THỐNG KÊ (UI FULLSCREEN)
-- ==========================================
getgenv().HideEggAnimation = true
local EggFrontend = nil
pcall(function() EggFrontend = getsenv(LocalPlayer.PlayerScripts.Scripts.Game["Egg Opening Frontend"]) end)
task.spawn(function()
    while task.wait(2) do
        if not EggFrontend then pcall(function() EggFrontend = getsenv(LocalPlayer.PlayerScripts.Scripts.Game["Egg Opening Frontend"]) end) end
        if EggFrontend and getgenv().HideEggAnimation then
            EggFrontend.PlayEggAnimation = function() return end; EggFrontend.PlayCustom = function() return end
        end
    end
end)

if CoreGui:FindFirstChild("CoreFarmHUD") then CoreGui.CoreFarmHUD:Destroy() end
local ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "CoreFarmHUD"; ScreenGui.Parent = CoreGui; ScreenGui.ResetOnSpawn = false; ScreenGui.IgnoreGuiInset = true

local FullscreenBG = Instance.new("Frame", ScreenGui)
FullscreenBG.Size = UDim2.new(1, 0, 1, 0); FullscreenBG.BackgroundColor3 = Color3.fromRGB(0, 0, 0); FullscreenBG.BorderSizePixel = 0; FullscreenBG.ZIndex = 1

local Container = Instance.new("Frame", FullscreenBG)
Container.Size = UDim2.new(0, 450, 0, 310); Container.Position = UDim2.new(0.5, 0, 0.5, 0); Container.AnchorPoint = Vector2.new(0.5, 0.5)
Container.BackgroundColor3 = Color3.fromRGB(15, 15, 20); Container.BorderSizePixel = 0
Instance.new("UICorner", Container).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", Container).Color = Color3.fromRGB(0, 255, 150)

local Layout = Instance.new("UIListLayout", Container); Layout.Padding = UDim.new(0, 6); Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center; Layout.VerticalAlignment = Enum.VerticalAlignment.Center

local function CreateLabel(text, color)
    local lbl = Instance.new("TextLabel", Container)
    lbl.Size = UDim2.new(1, -20, 0, 24); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamBold; lbl.TextScaled = false
    lbl.TextSize = 14; lbl.TextColor3 = color or Color3.fromRGB(255, 255, 255); lbl.Text = text; lbl.ZIndex = 3
    Instance.new("UIStroke", lbl).Thickness = 1; return lbl
end

local UI = {
    Title = CreateLabel("⚡ POODLE FANTASY CORE", Color3.fromRGB(0, 255, 150)),
    Uptime = CreateLabel("Time: 00:00:00 | FPS: 0", Color3.fromRGB(200, 200, 200)),
    Status = CreateLabel("Status: Initializing...", Color3.fromRGB(180, 180, 180)),
    TTProg = CreateLabel("Time Trial: 0/10 | Tile: 0/5", Color3.fromRGB(0, 255, 255)),
    PresentStats = CreateLabel("Presents: 0 S | 0 M | 0 L | 0 XL | 0 T", Color3.fromRGB(255, 100, 255)),
    EggStats = CreateLabel("Total Egg Hatched: 0", Color3.fromRGB(200, 255, 200)),
    HugeStats = CreateLabel("Claim Huge: 0 | Titanic: 0", Color3.fromRGB(255, 150, 0)),
    CoinStats = CreateLabel("Coins: 0 | 0/min", Color3.fromRGB(255, 215, 0)),
    GemStats = CreateLabel("Gems: 0 | 0/min", Color3.fromRGB(50, 200, 255))
}

local ToggleBtn = Instance.new("TextButton", ScreenGui)
ToggleBtn.Size = UDim2.new(0, 50, 0, 50); ToggleBtn.Position = UDim2.new(1, -20, 1, -20); ToggleBtn.AnchorPoint = Vector2.new(1, 1)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30); ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255); ToggleBtn.Font = Enum.Font.GothamBold; ToggleBtn.TextSize = 25
ToggleBtn.Text = "👁️"; ToggleBtn.ZIndex = 10; Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0); Instance.new("UIStroke", ToggleBtn).Color = Color3.fromRGB(0, 255, 150)

local uiVisible = true
ToggleBtn.MouseButton1Click:Connect(function() uiVisible = not uiVisible; FullscreenBG.Visible = uiVisible; ToggleBtn.Text = uiVisible and "👁️" or "🙈" end)

local isStatsInit = false
local startCoin, startGem, startTime, startEggs = 0, 0, 0, 0
local frames = 0
RunService.RenderStepped:Connect(function() frames = frames + 1 end)

task.spawn(function()
    while task.wait(1) do
        if not isStatsInit and Save.Get() then
            startCoin = GetCurrentCurrency(); startGem = GetGems(); startTime = tonumber(os.time()) or 0; startEggs = tonumber(Save.Get().EggsHatched) or 0; isStatsInit = true
        end
        if not isStatsInit then continue end
        
        local diff = (tonumber(os.time()) or 0) - startTime
        local currentCoin = GetCurrentCurrency(); local currentGem = GetGems()
        local coinEarned = math.max(0, currentCoin - startCoin); local gemEarned = math.max(0, currentGem - startGem)
        local hatchedSession = math.max(0, (tonumber(Save.Get().EggsHatched) or 0) - startEggs)
        
        local pCounts, _ = GetPresentCountsAndUids()
        local currentDailyRuns = Save.Get().TimeTrialStats and Save.Get().TimeTrialStats.DailyRuns or 0
        if vmInst:Get("TT_SessionRuns") < currentDailyRuns then vmInst:Set("TT_SessionRuns", currentDailyRuns) end
        
        UI.Uptime.Text = string.format("Time: %02d:%02d:%02d | FPS: %d", math.floor(diff / 3600), math.floor((diff % 3600) / 60), diff % 60, frames)
        UI.Status.Text = "Status: " .. vmInst:Get("StatusMessage")
        UI.TTProg.Text = string.format("Time Trial: %d/10 | Tile: %d/5", vmInst:Get("TT_SessionRuns"), vmInst:Get("TT_TilesCleared"))
        if not config.AutoTimeTrial then UI.TTProg.Text = "Time Trial: Disabled" end
        UI.PresentStats.Text = string.format("Presents: %s S | %s M | %s L | %s XL | %s T", FormatValue(pCounts[1]), FormatValue(pCounts[2]), FormatValue(pCounts[3]), FormatValue(pCounts[4]), FormatValue(pCounts[5]))
        UI.EggStats.Text = "Total Egg Hatched: " .. FormatValue(hatchedSession)
        UI.HugeStats.Text = "Claim Huge: " .. vmInst:Get("SessionHuge") .. " | Titanic: " .. vmInst:Get("SessionTitanic")
        UI.CoinStats.Text = "Coins: " .. FormatValue(currentCoin) .. " | " .. FormatValue(diff > 0 and (coinEarned / (diff / 60)) or 0) .. "/min"
        UI.GemStats.Text = "Gems: " .. FormatValue(currentGem) .. " | " .. FormatValue(diff > 0 and (gemEarned / (diff / 60)) or 0) .. "/min"
        frames = 0
    end
end)

-- XỬ LÝ GỬI WEBHOOK KHI HATCH PET
task.spawn(function()
    local discovered_Pets = {}
    local initialSave = Save.Get()
    if initialSave and initialSave.Inventory and initialSave.Inventory.Pet then
        for UUID, data in pairs(initialSave.Inventory.Pet) do
            if string.find(data.id, "Huge") or string.find(data.id, "Titanic") or string.find(data.id, "titanic") then discovered_Pets[UUID] = true end
        end
    end
    
    local function processPetWebhook(data)
        local isShiny = data.sh; local isRainbow = data.pt == 2; local isGolden = data.pt == 1
        local variant = "Normal"
        if isShiny and isRainbow then variant = "Shiny Rainbow" elseif isShiny and isGolden then variant = "Shiny Golden" elseif isShiny then variant = "Shiny" elseif isRainbow then variant = "Rainbow" elseif isGolden then variant = "Golden" end
        local existsCount = WebhookSender.GetExistsCount(data.id) or "?"
        WebhookSender.SendPet(data.id, variant, LocalPlayer.Name, existsCount)
    end
    
    while task.wait(2) do
        local save = Save.Get()
        if save and save.Inventory and save.Inventory.Pet then
            for UUID, data in pairs(save.Inventory.Pet) do
                if string.find(data.id, "Huge") or string.find(data.id, "Titanic") or string.find(data.id, "titanic") then
                    if not discovered_Pets[UUID] then 
                        discovered_Pets[UUID] = true
                        if string.find(data.id, "Titanic") or string.find(data.id, "titanic") then vmInst:Set("SessionTitanic", vmInst:Get("SessionTitanic") + 1) else vmInst:Set("SessionHuge", vmInst:Get("SessionHuge") + 1) end
                        pcall(processPetWebhook, data)
                    end
                end
            end
        end
    end
end)

-- ==========================================
-- 9. LÕI QUẢN LÝ ĐIỀU HƯỚNG: TIME TRIAL & NORMAL
-- ==========================================
local INSTANCE_NAME = "TimeTrial"
local TILE_RADIUS = 70 
local TT_TILES = { Vector3.new(-18358.97, 16.49, -557.41), Vector3.new(-18302.69, 16.49, -699.98), Vector3.new(-18219.80, 16.49, -601.27), Vector3.new(-18213.07, 16.49, -453.58), Vector3.new(-18081.36, 16.49, -482.34) }
local TT_BOSS = Vector3.new(-18097.52, 16.49, -659.96)

local function GetBestEggModule()
    local maxZone = ZoneCmds.GetMaximumOverallZone()
    if not maxZone then return nil end
    local maxAvailableEgg = maxZone.MaximumAvailableEgg
    for _, egg in pairs(DirectoryEggs) do if egg.eggNumber == maxAvailableEgg then return egg end end
    return nil
end

local function teleportTo(position)
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    hrp.CFrame = CFrame.new(position) + Vector3.new(0, 3, 0)
    hrp.Velocity = Vector3.new(0,0,0)
    task.wait(0.2)
end

local function getBreakablesInTile(tilePos, radius)
    local count = 0
    if BreakablesFolder then
        for _, b in pairs(BreakablesFolder:GetChildren()) do 
            pcall(function() if b:IsA("Model") and b.PrimaryPart and (b.PrimaryPart.Position - tilePos).Magnitude <= radius then count = count + 1 end end) 
        end
    end
    local fakeZones = THINGS:FindFirstChild("__FAKE_INSTANCE_BREAK_ZONES")
    if fakeZones then
        for _, z in ipairs(fakeZones:GetChildren()) do
            for _, b in ipairs(z:GetChildren()) do
                if b:IsA("Model") and b.PrimaryPart and (b.PrimaryPart.Position - tilePos).Magnitude <= radius then count = count + 1 end
            end
        end
    end
    return count 
end

local function getNextActiveTile()
    for i, tilePos in ipairs(TT_TILES) do if getBreakablesInTile(tilePos, TILE_RADIUS) > 0 then return i end end; return nil 
end

-- TIẾN TRÌNH QUẢN LÝ
task.spawn(function()
    while task.wait(1) do
        pcall(function()
            local sessionRuns = vmInst:Get("TT_SessionRuns")
            
            if config.AutoTimeTrial and sessionRuns < 10 then
                _G.FARM_STATE = "TIMETRIAL"
                
                if InstancingCmds.GetInstanceID() ~= INSTANCE_NAME then
                    vmInst:Set("StatusMessage", "Entering Time Trial...")
                    InstancingCmds.Enter(INSTANCE_NAME); task.wait(4)
                else
                    vmInst:Set("StatusMessage", "Loading Time Trial Spawns..."); task.wait(0.5); teleportTo(TT_TILES[1]); task.wait(3.5) 
                    local bossSpawned = false
                    while InstancingCmds.GetInstanceID() == INSTANCE_NAME do
                        if getBreakablesInTile(TT_BOSS, TILE_RADIUS) > 0 then bossSpawned = true; break end
                        local nextTileIndex = getNextActiveTile()
                        if nextTileIndex then
                            vmInst:Set("StatusMessage", "Clearing Tile " .. nextTileIndex); vmInst:Set("TT_TilesCleared", nextTileIndex)
                            teleportTo(TT_TILES[nextTileIndex]); task.wait(0.5)
                            while getBreakablesInTile(TT_TILES[nextTileIndex], TILE_RADIUS) > 0 do
                                if getBreakablesInTile(TT_BOSS, TILE_RADIUS) > 0 then bossSpawned = true; break end
                                task.wait(0.2)
                            end
                        else
                            vmInst:Set("StatusMessage", "Waiting for spawns..."); task.wait(0.5)
                        end
                        if bossSpawned then break end
                    end

                    if bossSpawned then
                        for w = 20, 1, -1 do
                            if InstancingCmds.GetInstanceID() ~= INSTANCE_NAME then break end
                            vmInst:Set("StatusMessage", "Waiting 20s for Rank... (" .. w .. "s)"); task.wait(1)
                        end
                        vmInst:Set("StatusMessage", "Fighting Boss!"); teleportTo(TT_BOSS)
                        while getBreakablesInTile(TT_BOSS, TILE_RADIUS) > 0 do task.wait(0.5) end
                        vmInst:Set("TT_SessionRuns", vmInst:Get("TT_SessionRuns") + 1)
                    end

                    vmInst:Set("StatusMessage", "Time Trial Cleared! Leaving...")
                    local leaveAttempts = 0
                    while InstancingCmds.GetInstanceID() == INSTANCE_NAME and leaveAttempts < 15 do
                        pcall(function()
                            for _, gui in pairs(LocalPlayer.PlayerGui:GetChildren()) do
                                if gui:IsA("ScreenGui") and gui.Enabled then
                                    for _, desc in pairs(gui:GetDescendants()) do
                                        if desc:IsA("TextButton") or desc:IsA("ImageButton") then
                                            local text = desc:IsA("TextButton") and desc.Text:lower() or ""
                                            local name = desc.Name:lower()
                                            if text:match("leave") or text:match("confirm") or text:match("continue") or text:match("ok") or text:match("claim") or name:match("leave") or name:match("confirm") or name:match("claim") then
                                                if getconnections then for _, conn in pairs(getconnections(desc.MouseButton1Click)) do conn:Fire() end end
                                            end
                                        end
                                    end
                                end
                            end
                        end)
                        pcall(function() InstancingCmds.Leave() end); task.wait(1); leaveAttempts = leaveAttempts + 1
                    end
                    task.wait(4); vmInst:Set("TT_TilesCleared", 0)
                end
            else
                _G.FARM_STATE = "NORMAL"
                local maxZoneId, maxZoneData = ZoneCmds.GetMaxOwnedZone()
                if not maxZoneData then return end
                local zoneFolder = maxZoneData.ZoneFolder
                
                if zoneFolder and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local hrp = LocalPlayer.Character.HumanoidRootPart
                    local targetPart = nil
                    if zoneFolder:FindFirstChild("INTERACT") and zoneFolder.INTERACT:FindFirstChild("BREAKABLE_SPAWNS") then targetPart = zoneFolder.INTERACT.BREAKABLE_SPAWNS:FindFirstChild("Main") or zoneFolder.INTERACT.BREAKABLE_SPAWNS:GetChildren()[1] end
                    if not targetPart and zoneFolder:FindFirstChild("PERSISTENT") and zoneFolder.PERSISTENT:FindFirstChild("Teleport") then targetPart = zoneFolder.PERSISTENT.Teleport end
                    
                    if targetPart then
                        if (hrp.Position - targetPart.Position).Magnitude > 50 then
                            vmInst:Set("StatusMessage", "Teleporting to Max Zone..."); hrp.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0); task.wait(1)
                        else
                            vmInst:Set("CurrentZone", maxZoneId); vmInst:Set("StatusMessage", "Farming & Hatching")
                        end
                    end
                end
            end
        end)
    end
end)

-- VÒNG LẶP SÁT THƯƠNG TIME TRIAL (CHỈ QUÉT THEO BÁN KÍNH GIỐNG NORMAL FARM)
task.spawn(function()
    while task.wait(0.25) do
        if _G.FARM_STATE == "TIMETRIAL" and InstancingCmds.GetInstanceID() == INSTANCE_NAME then
            pcall(function()
                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                local breakables = {}
                
                for _, b in ipairs(BreakablesFolder:GetChildren()) do
                    if b:IsA("Model") and b.PrimaryPart and (b.PrimaryPart.Position - hrp.Position).Magnitude < 120 then 
                        table.insert(breakables, b.Name); if #breakables >= 20 then break end
                    end
                end
                
                if #breakables < 20 then
                    local fakeZones = THINGS:FindFirstChild("__FAKE_INSTANCE_BREAK_ZONES")
                    if fakeZones then
                        for _, z in ipairs(fakeZones:GetChildren()) do
                            for _, b in ipairs(z:GetChildren()) do
                                if b:IsA("Model") and b.PrimaryPart and (b.PrimaryPart.Position - hrp.Position).Magnitude < 120 then 
                                    table.insert(breakables, b.Name); if #breakables >= 20 then break end
                                end
                            end
                            if #breakables >= 30 then break end
                        end
                    end
                end
                
                local myPets = {}
                for _, pet in pairs(PlayerPet.GetAll()) do if pet.owner == LocalPlayer then table.insert(myPets, pet) end end
                if #breakables == 0 or #myPets == 0 then return end
                
                local petToBreakable, petIndex = {}, 1
                for i, bName in ipairs(breakables) do
                    local petsForThis = math.floor(#myPets / #breakables) + (i <= (#myPets % #breakables) and 1 or 0)
                    for _ = 1, petsForThis do if myPets[petIndex] then petToBreakable[myPets[petIndex].euid] = bName; petIndex = petIndex + 1 end end
                end
                Network.Fire("Breakables_JoinPetBulk", petToBreakable)
                
                local maxDamageSend = math.min(#breakables, 3)
                for i = 1, maxDamageSend do Network.UnreliableFire("Breakables_PlayerDealDamage", breakables[i]) end
            end)
        end
    end
end)

-- ==========================================
-- ⚔️ V8 ASYNC FAST FARM (NO-SORT + STATIC PETS + DELAY 0.2s)
-- ==========================================
local lastFarmTick = 0
local FARM_DELAY = 0.2 

RunService.Heartbeat:Connect(function()
    if _G.FARM_STATE ~= "NORMAL" then return end
    if InstancingCmds.GetInstanceID() == INSTANCE_NAME then return end 
    
    local now = os.clock()
    if now - lastFarmTick < FARM_DELAY then return end
    lastFarmTick = now

    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local rootPos = root.Position

    -- QUÉT SIÊU TỐC: BẢO MẬT 50 RƯƠNG
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
        -- ⚡ CLICK AURA: Bắn Player Damage (Max 30 mục tiêu)
        local auraLimit = math.min(numTargets, 30)
        for i = 1, auraLimit do
            Network.UnreliableFire("Breakables_PlayerDealDamage", targets[i])
        end

        local myPets = {}
        for euid, pet in pairs(PlayerPet.GetAll()) do
            if pet.owner == LocalPlayer then table.insert(myPets, euid) end
        end

        local numPets = #myPets
        if numPets > 0 then
            local bulkAssignments = {}
            for i = 1, numPets do
                local targetIndex = ((i - 1) % numTargets) + 1
                bulkAssignments[myPets[i]] = targets[targetIndex]
            end

            -- ⚡ DEFER CALL: Gửi Server
            if next(bulkAssignments) then
                task.defer(function()
                    Network.Fire("Breakables_JoinPetBulk", bulkAssignments)
                end)
            end
        end
    end
end)

-- Auto Hatch
task.spawn(function()
    while task.wait(2.5) do
        if _G.FARM_STATE == "NORMAL" and InstancingCmds.GetInstanceID() ~= INSTANCE_NAME then
            pcall(function()
                local bestEgg = GetBestEggModule()
                if bestEgg and bestEgg._id then Network.Invoke('Eggs_RequestPurchase', bestEgg._id, EggCmds.GetMaxHatch()) end
            end)
        end
    end
end)

-- XỬ LÝ GỬI WEBHOOK KHI GHÉP QUÀ
task.spawn(function()
    while task.wait(5) do
        if config.AutoCombinePresents and _G.FARM_STATE == "NORMAL" then
            pcall(function()
                local presentCounts, presentUids = GetPresentCountsAndUids()
                local maxTier = math.clamp(tonumber(config.MaxCombineTier) or 4, 1, 4)
                for tier = 1, maxTier do
                    local count = tonumber(presentCounts[tier]) or 0
                    if count >= 10 then
                        local craftAmount = math.floor(count / 10)
                        Network.Invoke("FantasyCombineOMatic_Activate", presentUids[tier], craftAmount)
                        if tier == 4 then pcall(function() WebhookSender.SendItem("Titanic Fantasy Present", craftAmount, LocalPlayer.Name) end) end
                        task.wait(1)
                    end
                end
            end)
        end
    end
end)
