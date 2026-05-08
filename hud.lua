if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Lib = ReplicatedStorage:WaitForChild("Library")
local Network = require(Lib.Client.Network)
local Save = require(Lib.Client.Save)
local ZoneCmds = require(Lib.Client.ZoneCmds)
local EggCmds = require(Lib.Client.EggCmds)
local RankCmds = require(Lib.Client.RankCmds)
local PlayerPet = require(Lib.Client.PlayerPet)
local InstancingCmds = require(Lib.Client.InstancingCmds)
local UltimateCmds = require(Lib.Client.UltimateCmds)
local NotificationCmds = require(Lib.Client.NotificationCmds)
local FruitCmds = require(Lib.Client.FruitCmds)
local WorldsUtil = require(Lib.Util.WorldsUtil)
local RanksDirectory = require(Lib.Directory.Ranks)
local FreeGiftsDirectory = require(Lib.Directory.FreeGifts)
local EggsDirectory = require(Lib.Directory.Eggs)

-- Thư viện cần thiết cho Auto Mở theo chuẩn VRT
local Items = require(Lib.Items)
local LootboxCmds = require(Lib.Client.LootboxCmds)

local THINGS = Workspace:WaitForChild("__THINGS")

local EggFrontend = nil
pcall(function() EggFrontend = getsenv(LocalPlayer.PlayerScripts.Scripts.Game["Egg Opening Frontend"]) end)
local OriginalPlayEggAnimation = EggFrontend and EggFrontend.PlayEggAnimation or nil

-- ==============================================================
-- 🔍 HÀM QUÉT INVENTORY (PHÂN LOẠI CHUẨN XÁC)
-- ==============================================================
local function GetAvailableFlags()
    local flags = {}
    local inv = Save.Get().Inventory.Misc or {}
    for uid, item in pairs(inv) do
        if item.id and item.id:match("Flag") and not table.find(flags, item.id) then table.insert(flags, item.id) end
    end
    return #flags > 0 and flags or {"Không có Cờ trong kho"}
end

local function GetAvailableLootboxes()
    local list = {}
    local inv = Save.Get().Inventory.Lootbox or {}
    for _, item in pairs(inv) do
        -- Lọc ra các loại Rương/Hộp, bỏ qua Gift/Bundle
        if item.id and not item.id:match("Gift") and not item.id:match("Bundle") and not item.id:match("Bag") then
            if not table.find(list, item.id) then table.insert(list, item.id) end
        end
    end
    return #list > 0 and list or {"Không có Lootbox"}
end

local function GetAvailableGifts()
    local list = {}
    local invL = Save.Get().Inventory.Lootbox or {}
    local invM = Save.Get().Inventory.Misc or {}
    local function ScanForGifts(inventory)
        for _, item in pairs(inventory) do
            if item.id and (item.id:match("Gift") or item.id:match("Bundle") or item.id:match("Bag") or item.id:match("Present")) then
                if not table.find(list, item.id) then table.insert(list, item.id) end
            end
        end
    end
    ScanForGifts(invL)
    ScanForGifts(invM)
    return #list > 0 and list or {"Không có GiftBag/Bundle"}
end

-- ==============================================================
-- ⚙️ KHỞI TẠO BIẾN TOÀN CỤC & HÀM LOGIC
-- ==============================================================
getgenv().v_settings = {
    functionToggles = {
        FastFarm = false, AutoTimeTrial = false, AutoUnlock = false, BestZone = false, AutoLoot = false,
        AutoHatch = false, HideEgg = false, HookEgg = false, AutoGold = false, AutoRainbow = false,
        AutoFruit = false, AutoCombine = false, AutoFlag = false, AutoUltimate = false, AutoMisc = false, ClaimRank = false,
        Blackout = false, AntiAFK = false, SelectedFlag = "None",
        AutoOpenLootbox = false, AutoOpenGift = false
    },
    functions = {
        AutoHatch = function()
            local maxZone = ZoneCmds.GetMaximumOverallZone()
            if not maxZone then return end
            local bestEggId = nil
            for _, egg in pairs(EggsDirectory) do if egg.eggNumber == maxZone.MaximumAvailableEgg then bestEggId = egg._id break end end
            if bestEggId then Network.Invoke('Eggs_RequestPurchase', bestEggId, EggCmds.GetMaxHatch()) end
        end,
        HandleEggAnimation = function()
            if not EggFrontend then return end
            if getgenv().v_settings.functionToggles.HideEgg then
                EggFrontend.PlayEggAnimation = function() end; EggFrontend.PlayCustom = function() end
            elseif getgenv().v_settings.functionToggles.HookEgg then
                EggFrontend.PlayEggAnimation = function(eggName)
                    local maxHatch = EggCmds.GetMaxHatch()
                    NotificationCmds.Message.Bottom({
                        Message = "Still Openin " .. tostring(eggName) .. " x" .. tostring(maxHatch),
                        Color = Color3.fromRGB(math.random(0, 255), math.random(0, 255), math.random(0, 255))
                    })
                end
                EggFrontend.PlayCustom = function() end
            else
                EggFrontend.PlayEggAnimation = OriginalPlayEggAnimation
            end
        end,
        AutoFruit = function()
            local save = Save.Get(); if not save or not save.Inventory or not save.Inventory.Fruit then return end
            local targetStack = 20
            pcall(function() local maxL = FruitCmds.ComputeFruitQueueLimit(); if type(maxL)=="number" and maxL>0 then targetStack=maxL end end)
            local bestFruits = {}
            for uid, data in pairs(save.Inventory.Fruit) do
                if data.id and data.id ~= "Candycane" then
                    local baseId = data.id; local currentBestUid = bestFruits[baseId]
                    if not currentBestUid then bestFruits[baseId] = uid else
                        local currentBestData = save.Inventory.Fruit[currentBestUid]
                        if data.sh and not currentBestData.sh then bestFruits[baseId] = uid
                        elseif data.sh == currentBestData.sh and (data._am or 1) > (currentBestData._am or 1) then bestFruits[baseId] = uid end
                    end
                end
            end
            local activeFruits = {}
            pcall(function() activeFruits = FruitCmds.GetActiveFruits() end)
            for fruitName, uid in pairs(bestFruits) do
                local count = 0; local data = activeFruits and activeFruits[fruitName]
                if type(data)=="table" then
                    if type(data.Normal)=="table" then for _ in pairs(data.Normal) do count=count+1 end end
                    if type(data.Shiny)=="table" then for _ in pairs(data.Shiny) do count=count+1 end end
                end
                if count < targetStack then
                    local consumeAmount = math.min(targetStack - count, save.Inventory.Fruit[uid]._am or 1)
                    if consumeAmount > 0 then
                        pcall(function() FruitCmds.Consume(uid, consumeAmount) end)
                        pcall(function() Network.Fire("Fruits: Consume", uid, consumeAmount) end)
                        task.wait(0.2)
                    end
                end
            end
        end,
        AutoFlag = function()
            local sf = getgenv().v_settings.functionToggles.SelectedFlag
            if not sf or sf == "None" or sf == "Không có Cờ trong kho" then return end
            local inv = Save.Get().Inventory.Misc or {}
            for uid, item in pairs(inv) do
                if item.id == sf then require(Lib.Client.FlexibleFlagCmds).Consume(item.id, uid, 1); break end
            end
        end,
        FastFarm = function()
            if InstancingCmds.GetInstanceID() == "TimeTrial" then return end
            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not root then return end
            local targets = {}
            for _, b in ipairs(THINGS.Breakables:GetChildren()) do
                if b:IsA("Model") and b.PrimaryPart and (b.PrimaryPart.Position - root.Position).Magnitude < 100 then 
                    table.insert(targets, b.Name); if #targets >= 25 then break end 
                end
            end
            if #targets > 0 then
                for i = 1, math.min(#targets, 8) do Network.UnreliableFire("Breakables_PlayerDealDamage", targets[i]) end
                local myPets = {}
                for euid, pet in pairs(PlayerPet.GetAll()) do if pet.owner == LocalPlayer then table.insert(myPets, euid) end end
                if #myPets > 0 then
                    local bulk = {}
                    for i = 1, #myPets do bulk[myPets[i]] = targets[((i - 1) % #targets) + 1] end
                    task.defer(function() Network.Fire("Breakables_JoinPetBulk", bulk) end)
                end
            end
        end,
        AutoTimeTrial = function()
            if InstancingCmds.GetInstanceID() ~= "TimeTrial" then InstancingCmds.Enter("TimeTrial") else
                local tiles = {Vector3.new(-18358.97,16.49,-557.41), Vector3.new(-18302.69,16.49,-699.98), Vector3.new(-18219.80,16.49,-601.27), Vector3.new(-18213.07,16.49,-453.58), Vector3.new(-18081.36,16.49,-482.34)}
                local boss = Vector3.new(-18097.52,16.49,-659.96)
                local hrp = LocalPlayer.Character.HumanoidRootPart; local cTile = 1
                for i, pos in ipairs(tiles) do
                    local c = 0; for _, b in ipairs(THINGS.Breakables:GetChildren()) do if b.PrimaryPart and (b.PrimaryPart.Position - pos).Magnitude <= 70 then c = c + 1 end end
                    if c > 0 then cTile = i; break end
                end
                if cTile <= #tiles then hrp.CFrame = CFrame.new(tiles[cTile]) + Vector3.new(0,3,0) else hrp.CFrame = CFrame.new(boss) + Vector3.new(0,3,0) end
            end
        end,
        AutoUnlock = function() local nx, _ = ZoneCmds.GetNextZone(); if nx then Network.Invoke("Zones_RequestPurchase", nx) end end,
        BestZone = function()
            local _, mx = ZoneCmds.GetMaxOwnedZone(); local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not mx or not hrp then return end
            local zf = mx.ZoneFolder; local tp = nil
            if zf and zf:FindFirstChild("INTERACT") and zf.INTERACT:FindFirstChild("BREAKABLE_SPAWNS") then
                local ms = zf.INTERACT.BREAKABLE_SPAWNS:FindFirstChild("Main") or zf.INTERACT.BREAKABLE_SPAWNS:GetChildren()[1]
                if ms then tp = ms.CFrame end
            end
            if not tp and zf and zf:FindFirstChild("PERSISTENT") then tp = zf.PERSISTENT.Teleport.CFrame end
            if tp and (hrp.Position - tp.Position).Magnitude > 20 then hrp.CFrame = tp + Vector3.new(0, 3, 0) end
        end,
        AutoLoot = function()
            local bags = {}; for _,v in ipairs(THINGS.Lootbags:GetChildren()) do table.insert(bags, v.Name); v:Destroy() end
            if #bags > 0 then Network.Fire("Lootbags_Claim", bags) end
            for _,v in ipairs(THINGS.Orbs:GetChildren()) do Network.Fire("Orbs: Collect", {tonumber(v.Name)}); v:Destroy() end
        end,
        AutoGold = function() local i = Save.Get().Inventory.Pet or {}; for u, d in pairs(i) do if not d.pt and (d._am or 1) >= 10 then Network.Invoke("GoldMachine_Activate", u, 1); break end end end,
        AutoRainbow = function() local i = Save.Get().Inventory.Pet or {}; for u, d in pairs(i) do if d.pt == 1 and (d._am or 1) >= 10 then Network.Invoke("RainbowMachine_Activate", u, 1); break end end end,
        AutoCombine = function() local i = Save.Get().Inventory.Lootboxes; if i then local pt = {"Small Fantasy Present", "Medium Fantasy Present", "Large Fantasy Present", "X-Large Fantasy Present"}; for t=1,4 do for u,d in pairs(i) do if d.id==pt[t] and (d._am or 1)>=10 then Network.Invoke("FantasyCombineOMatic_Activate", u, math.floor(d._am/10)) end end end end end,
        AutoUltimate = function() local u = UltimateCmds.GetEquippedItem(); if u and u._data and u._data.id then UltimateCmds.Activate(u._data.id) end end,
        AutoMisc = function() Network.Invoke('Mailbox: Claim All'); local r = Save.Get().FreeGiftsRedeemed or {}; local c = Save.Get().FreeGiftsTime or 0; for _, g in pairs(FreeGiftsDirectory) do if g.WaitTime <= c and not table.find(r, g._id) then Network.Invoke('Redeem Free Gift', g._id); break end end end,
        ClaimRank = function() local s = Save.Get(); local rw = RanksDirectory[RankCmds.GetTitle()].Rewards; local ts = 0; for i, v in pairs(rw) do ts = ts + v.StarsRequired; if s.RankStars >= ts and not s.RedeemedRankRewards[tostring(i)] then Network.Fire("Ranks_ClaimReward", i) end end end,
        Blackout = function() game:GetService("Lighting").GlobalShadows = false; for _, v in pairs(Workspace:GetDescendants()) do if v:IsA("BasePart") and not v:IsDescendantOf(THINGS) then v.Material = Enum.Material.Plastic; v.CastShadow = false end end end,
        AntiAFK = function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game) end
    }
}

-- ==============================================================
-- 🎨 TẠO GIAO DIỆN RAYFIELD UI
-- ==============================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = 'Poodle Hub V3', LoadingTitle = 'Poodle Hub', LoadingSubtitle = 'Open Lootbox Added', ConfigurationSaving = { Enabled = false }, KeySystem = false
})

local function CreateSmartToggle(TabObj, ToggleName, FlagName, Func, WaitTime)
    TabObj:CreateToggle({
        Name = ToggleName, CurrentValue = false, Flag = FlagName,
        Callback = function(state)
            getgenv().v_settings.functionToggles[FlagName] = state
            if FlagName == "HideEgg" or FlagName == "HookEgg" then getgenv().v_settings.functions.HandleEggAnimation() return end
            task.spawn(function()
                while getgenv().v_settings.functionToggles[FlagName] do
                    pcall(Func)
                    task.wait(WaitTime)
                end
            end)
        end
    })
end

-- ⚔️ Tab 1: Main Farm
local TabFarm = Window:CreateTab("Main Farm", "swords")
TabFarm:CreateToggle({
    Name = "Fast Farm (V8 Async)", CurrentValue = false, Flag = "FastFarm",
    Callback = function(state)
        getgenv().v_settings.functionToggles.FastFarm = state
        local lastFarm = 0
        RunService.Heartbeat:Connect(function()
            if not getgenv().v_settings.functionToggles.FastFarm then return end
            local now = os.clock()
            if now - lastFarm > 0.15 then lastFarm = now; pcall(getgenv().v_settings.functions.FastFarm) end
        end)
    end
})
CreateSmartToggle(TabFarm, "Auto Time Trial (Per Tile)", "AutoTimeTrial", getgenv().v_settings.functions.AutoTimeTrial, 1)
CreateSmartToggle(TabFarm, "Auto Unlock Zone", "AutoUnlock", getgenv().v_settings.functions.AutoUnlock, 2)
CreateSmartToggle(TabFarm, "Tiến tới Best Zone (Vào giữa Map)", "BestZone", getgenv().v_settings.functions.BestZone, 2)
CreateSmartToggle(TabFarm, "Auto Thu thập Lootbags & Orbs", "AutoLoot", getgenv().v_settings.functions.AutoLoot, 0.5)

-- 🐾 Tab 2: Pets & Eggs
local TabPet = Window:CreateTab("Pets & Eggs", "egg")
CreateSmartToggle(TabPet, "Auto Hatch Best Egg (Remote)", "AutoHatch", getgenv().v_settings.functions.AutoHatch, 2.5)
CreateSmartToggle(TabPet, "Ẩn Animation Trứng", "HideEgg", nil, 0)
CreateSmartToggle(TabPet, "Hook Animation (Notify)", "HookEgg", nil, 0)
CreateSmartToggle(TabPet, "Auto Craft Gold Pets", "AutoGold", getgenv().v_settings.functions.AutoGold, 5)
CreateSmartToggle(TabPet, "Auto Craft Rainbow Pets", "AutoRainbow", getgenv().v_settings.functions.AutoRainbow, 5)

-- 📦 Tab 3: Open Lootbox (MỚI THÊM)
local TabOpen = Window:CreateTab("Open Lootbox", "package")
TabOpen:CreateSection("Lootboxes (Giới hạn 8/lần)")
local selectedLootbox = "None"
local DropLootbox = TabOpen:CreateDropdown({
    Name = "Chọn Lootbox", Options = {"Đang tải..."}, CurrentOption = {"None"}, MultipleOptions = false, Flag = "DropLootbox",
    Callback = function(Option) selectedLootbox = Option[1] end
})
TabOpen:CreateToggle({
    Name = "Auto Mở Lootbox", CurrentValue = false, Flag = "ToggleOpenLootbox",
    Callback = function(state)
        getgenv().v_settings.functionToggles.AutoOpenLootbox = state
        task.spawn(function()
            while getgenv().v_settings.functionToggles.AutoOpenLootbox do
                if selectedLootbox ~= "None" and selectedLootbox ~= "Không có Lootbox" then
                    local inv = Save.Get().Inventory.Lootbox or {}; local tUid, tAmt = nil, 0
                    for uid, item in pairs(inv) do if item.id == selectedLootbox then tUid = uid; tAmt = item._am or 1; break end end
                    if tUid and tAmt > 0 then
                        pcall(function()
                            local amt = math.min(tAmt, 8)
                            local boxObj = Items.Lootbox(selectedLootbox)
                            boxObj._uid = tUid
                            LootboxCmds.Open(boxObj, amt)
                        end)
                        task.wait(1.5)
                    else
                        Rayfield:Notify({Title="Hoàn tất", Content="Đã mở hết "..selectedLootbox, Duration=3})
                        getgenv().v_settings.functionToggles.AutoOpenLootbox = false
                    end
                else task.wait(1) end
            end
        end)
    end
})

TabOpen:CreateSection("GiftBags & Bundles (Giới hạn 100/lần)")
local selectedGift = "None"
local DropGift = TabOpen:CreateDropdown({
    Name = "Chọn GiftBag / Bundle", Options = {"Đang tải..."}, CurrentOption = {"None"}, MultipleOptions = false, Flag = "DropGift",
    Callback = function(Option) selectedGift = Option[1] end
})
TabOpen:CreateToggle({
    Name = "Auto Mở GiftBag / Bundle", CurrentValue = false, Flag = "ToggleOpenGift",
    Callback = function(state)
        getgenv().v_settings.functionToggles.AutoOpenGift = state
        task.spawn(function()
            while getgenv().v_settings.functionToggles.AutoOpenGift do
                if selectedGift ~= "None" and selectedGift ~= "Không có GiftBag/Bundle" then
                    local invL = Save.Get().Inventory.Lootbox or {}; local invM = Save.Get().Inventory.Misc or {}
                    local tUid, tAmt = nil, 0
                    for uid, item in pairs(invL) do if item.id == selectedGift then tUid = uid; tAmt = item._am or 1; break end end
                    if not tUid then for uid, item in pairs(invM) do if item.id == selectedGift then tUid = uid; tAmt = item._am or 1; break end end end
                    if tUid and tAmt > 0 then
                        pcall(function()
                            local amt = math.min(tAmt, 100)
                            Network.Invoke("GiftBag_Open", selectedGift, amt)
                        end)
                        task.wait(1.5)
                    else
                        Rayfield:Notify({Title="Hoàn tất", Content="Đã mở hết "..selectedGift, Duration=3})
                        getgenv().v_settings.functionToggles.AutoOpenGift = false
                    end
                else task.wait(1) end
            end
        end)
    end
})

TabOpen:CreateButton({
    Name = "🔄 Làm mới Kho Đồ",
    Callback = function() 
        DropLootbox:Refresh(GetAvailableLootboxes(), true) 
        DropGift:Refresh(GetAvailableGifts(), true) 
    end
})
task.delay(1, function() DropLootbox:Refresh(GetAvailableLootboxes(), true); DropGift:Refresh(GetAvailableGifts(), true) end)

-- 🎒 Tab 4: Items & Events 
local TabItem = Window:CreateTab("Items & Events", "backpack")
CreateSmartToggle(TabItem, "Smart Auto Fruit (Duy trì Max Buff)", "AutoFruit", getgenv().v_settings.functions.AutoFruit, 5)
CreateSmartToggle(TabItem, "Auto Combine Fantasy Presents", "AutoCombine", getgenv().v_settings.functions.AutoCombine, 3)

local FlagDropdown = TabItem:CreateDropdown({
    Name = "Chọn loại Cờ (Flag)", Options = {"Đang tải..."}, CurrentOption = {"None"}, MultipleOptions = false, Flag = "FlagSelectDropdown",
    Callback = function(Option) getgenv().v_settings.functionToggles.SelectedFlag = Option[1] end
})
TabItem:CreateButton({
    Name = "🔄 Làm mới danh sách Cờ",
    Callback = function() FlagDropdown:Refresh(GetAvailableFlags(), true) end
})
task.delay(2, function() FlagDropdown:Refresh(GetAvailableFlags(), true) end)

CreateSmartToggle(TabItem, "Auto Cắm Cờ (Flags)", "AutoFlag", getgenv().v_settings.functions.AutoFlag, 5)
CreateSmartToggle(TabItem, "Auto Dùng Ultimate", "AutoUltimate", getgenv().v_settings.functions.AutoUltimate, 1)
CreateSmartToggle(TabItem, "Auto Claim Free Gifts & Mailbox", "AutoMisc", getgenv().v_settings.functions.AutoMisc, 15)
CreateSmartToggle(TabItem, "Auto Claim Rank Rewards", "ClaimRank", getgenv().v_settings.functions.ClaimRank, 5)

-- ⚙️ Tab 5: Settings
local TabSet = Window:CreateTab("Settings", "settings")
CreateSmartToggle(TabSet, "Chế độ Tối ưu hóa / Blackout", "Blackout", getgenv().v_settings.functions.Blackout, 10)
CreateSmartToggle(TabSet, "Anti-AFK", "AntiAFK", getgenv().v_settings.functions.AntiAFK, 60)
TabSet:CreateButton({
    Name = "🚨 Force Stop All Toggles",
    Callback = function()
        for key, _ in pairs(getgenv().v_settings.functionToggles) do
            if type(getgenv().v_settings.functionToggles[key]) == "boolean" then getgenv().v_settings.functionToggles[key] = false end
        end
        if EggFrontend then EggFrontend.PlayEggAnimation = OriginalPlayEggAnimation end
        Rayfield:Notify({Title = "Hệ thống", Content = "Đã dừng toàn bộ vòng lặp!", Duration = 3})
    end
})

Rayfield:LoadConfiguration()