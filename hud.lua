if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
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
local EggsDirectory = require(Lib.Directory.Eggs)
local FreeGiftsDirectory = require(Lib.Directory.FreeGifts)
local RanksDirectory = require(Lib.Directory.Ranks)

local Items = require(Lib.Items)
local LootboxCmds = require(Lib.Client.LootboxCmds)

local THINGS = Workspace:WaitForChild("__THINGS")
local DEBRIS_FOLDER = Workspace:WaitForChild("__DEBRIS")

local EggFrontend = nil
pcall(function() EggFrontend = getsenv(LocalPlayer.PlayerScripts.Scripts.Game["Egg Opening Frontend"]) end)
local OriginalPlayEggAnimation = EggFrontend and EggFrontend.PlayEggAnimation or nil

local OriginalPetSpeed = PlayerPet.CalculateSpeedMultiplier
local OriginalSetTarget = PlayerPet.SetTarget

-- ==============================================================
-- 💾 HỆ THỐNG LƯU CONFIG
-- ==============================================================
local configFileName = "PoodleHub.json"

local defaultToggles = {
    FastFarm = false, AutoTimeTrial = false, AutoUnlock = false, BestZone = false, AutoLoot = false,
    AutoHatch = false, HideEgg = false, HookEgg = false, AutoGold = false, AutoRainbow = false,
    AutoFruit = false, AutoCombine = false, AutoFlag = false, AutoUltimate = false, AutoMisc = false, ClaimRank = false,
    Blackout = false, AntiAFK = false, AutoOpenLootbox = false, AutoOpenGift = false,
    OptimizeBreakables = false, OptimizePets = false
}

local savedConfig = { Toggles = {}, Dropdowns = { SelectedLootbox = "None", SelectedGift = "None", SelectedFlag = "None" } }

for k, v in pairs(defaultToggles) do savedConfig.Toggles[k] = v end

if isfile and isfile(configFileName) and readfile then
    pcall(function()
        local parsed = HttpService:JSONDecode(readfile(configFileName))
        if parsed then
            if parsed.Toggles then for k,v in pairs(parsed.Toggles) do savedConfig.Toggles[k] = v end end
            if parsed.Dropdowns then for k,v in pairs(parsed.Dropdowns) do savedConfig.Dropdowns[k] = v end end
        end
    end)
end

local function SaveCurrentConfig()
    local dataToSave = {
        Toggles = getgenv().v_settings.functionToggles,
        Dropdowns = {
            SelectedLootbox = getgenv().v_settings.functionToggles.SelectedLootbox or "None",
            SelectedGift = getgenv().v_settings.functionToggles.SelectedGift or "None",
            SelectedFlag = getgenv().v_settings.functionToggles.SelectedFlag or "None"
        }
    }
    if writefile then pcall(function() writefile(configFileName, HttpService:JSONEncode(dataToSave)) end) end
end

-- ==============================================================
-- 🔍 INVENTORY SCANNERS
-- ==============================================================
local function GetAvailableFlags()
    local flags = {}
    local inv = Save.Get().Inventory.Misc or {}
    for uid, item in pairs(inv) do if item.id and item.id:match("Flag") and not table.find(flags, item.id) then table.insert(flags, item.id) end end
    return #flags > 0 and flags or {"No Flags Found"}
end

local function GetAvailableLootboxes()
    local list = {}
    local inv = Save.Get().Inventory.Lootbox or {}
    for _, item in pairs(inv) do if item.id and not item.id:match("Gift") and not item.id:match("Bundle") and not item.id:match("Bag") then if not table.find(list, item.id) then table.insert(list, item.id) end end end
    return #list > 0 and list or {"No Lootboxes Found"}
end

local function GetAvailableGifts()
    local list = {}
    local invL = Save.Get().Inventory.Lootbox or {}; local invM = Save.Get().Inventory.Misc or {}
    local function Scan(inventory) for _, item in pairs(inventory) do if item.id and (item.id:match("Gift") or item.id:match("Bundle") or item.id:match("Bag") or item.id:match("Present")) then if not table.find(list, item.id) then table.insert(list, item.id) end end end end
    Scan(invL); Scan(invM)
    return #list > 0 and list or {"No Gifts/Bundles Found"}
end

-- ==============================================================
-- ⚙️ GLOBAL SETTINGS & FUNCTIONS
-- ==============================================================
getgenv().v_settings = {
    functionToggles = savedConfig.Toggles,
    OptimizeBreakablesConn = nil,
    functions = {
        OptimizePets = function()
            pcall(function()
                PlayerPet.CalculateSpeedMultiplier = function() return math.huge end
                if PlayerPet.SetTarget then PlayerPet.SetTarget = function() return end end
                for _, pet in pairs(PlayerPet.GetAll()) do
                    if pet.owner == LocalPlayer then pet.target = nil end
                end
            end)
        end,

        BuyPetSlots = function() local purchased = Save.Get().PetSlotsPurchased; Network.Invoke("PetSlots_RequestPurchase", purchased + 1) end,
        BuyEggSlots = function() local purchased = Save.Get().EggSlotsPurchased; Network.Invoke("EggSlots_RequestPurchase", purchased + 1) end,

        AutoHatch = function()
            local mz = ZoneCmds.GetMaximumOverallZone()
            if not mz then return end; local be = nil
            for _,e in pairs(EggsDirectory) do if e.eggNumber == mz.MaximumAvailableEgg then be = e._id break end end
            if be then Network.Invoke('Eggs_RequestPurchase', be, EggCmds.GetMaxHatch()) end
        end,
        
        HandleEggAnimation = function()
            if not EggFrontend then return end
            if getgenv().v_settings.functionToggles.HideEgg then EggFrontend.PlayEggAnimation = function() end
            elseif getgenv().v_settings.functionToggles.HookEgg then EggFrontend.PlayEggAnimation = function(en) NotificationCmds.Message.Bottom({Message="Still Openin "..tostring(en).." x"..tostring(EggCmds.GetMaxHatch()), Color=Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255))}) end
            else EggFrontend.PlayEggAnimation = OriginalPlayEggAnimation end
        end,

        AutoFruit = function()
            local sv = Save.Get(); if not sv or not sv.Inventory.Fruit then return end
            local ts = 20; pcall(function() local ml=FruitCmds.ComputeFruitQueueLimit(); if ml>0 then ts=ml end end)
            local bf = {}; for u,d in pairs(sv.Inventory.Fruit) do if d.id and d.id~="Candycane" then local bi=d.id; if not bf[bi] then bf[bi]=u else local cd=sv.Inventory.Fruit[bf[bi]] if d.sh and not cd.sh then bf[bi]=u elseif d.sh==cd.sh and (d._am or 1)>(cd._am or 1) then bf[bi]=u end end end end
            local af = {}; pcall(function() af=FruitCmds.GetActiveFruits() end)
            for fn,u in pairs(bf) do local c=0; local d=af and af[fn] if type(d)=="table" then if type(d.Normal)=="table" then for _ in pairs(d.Normal) do c=c+1 end end if type(d.Shiny)=="table" then for _ in pairs(d.Shiny) do c=c+1 end end end if c<ts then local ca=math.min(ts-c, sv.Inventory.Fruit[u]._am or 1) if ca>0 then pcall(function() Network.Fire("Fruits: Consume",u,ca) end); task.wait(0.2) end end end
        end,

        FastFarm = function()
            if InstancingCmds.GetInstanceID()=="TimeTrial" then return end
            local r = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not r then return end; local t={}
            for _,b in ipairs(THINGS.Breakables:GetChildren()) do if b:IsA("Model") and b.PrimaryPart and (b.PrimaryPart.Position-r.Position).Magnitude<100 then table.insert(t,b.Name); if #t>=25 then break end end end
            if #t>0 then for i=1,math.min(#t,8) do Network.UnreliableFire("Breakables_PlayerDealDamage",t[i]) end local m={}; for e,p in pairs(PlayerPet.GetAll()) do if p.owner==LocalPlayer then table.insert(m,e) end end if #m>0 then local bk={}; for i=1,#m do bk[m[i]]=t[((i-1)%#t)+1] end; Network.Fire("Breakables_JoinPetBulk",bk) end end
        end,
        
        AutoTimeTrial = function()
            if InstancingCmds.GetInstanceID() ~= "TimeTrial" then InstancingCmds.Enter("TimeTrial") else
                local tiles = {Vector3.new(-18358.97,16.49,-557.41), Vector3.new(-18302.69,16.49,-699.98), Vector3.new(-18219.80,16.49,-601.27), Vector3.new(-18213.07,16.49,-453.58), Vector3.new(-18081.36,16.49,-482.34)}
                local boss = Vector3.new(-18097.52,16.49,-659.96)
                local hrp = LocalPlayer.Character.HumanoidRootPart; local cTile = 1
                for i, pos in ipairs(tiles) do local c = 0; for _, b in ipairs(THINGS.Breakables:GetChildren()) do if b.PrimaryPart and (b.PrimaryPart.Position - pos).Magnitude <= 70 then c = c + 1 end end if c > 0 then cTile = i; break end end
                if cTile <= #tiles then hrp.CFrame = CFrame.new(tiles[cTile]) + Vector3.new(0,3,0) else hrp.CFrame = CFrame.new(boss) + Vector3.new(0,3,0) end
            end
        end,
        
        AutoUnlock = function() local nx, _ = ZoneCmds.GetNextZone(); if nx then Network.Invoke("Zones_RequestPurchase", nx) end end,
        
        BestZone = function()
            local _, mx = ZoneCmds.GetMaxOwnedZone()
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not mx or not hrp then return end
            
            local currentWorld = WorldsUtil.GetWorld()
            if mx.WorldNumber and currentWorld and mx.WorldNumber ~= currentWorld.WorldNumber then
                pcall(function() Network.Invoke("World" .. mx.WorldNumber .. "Teleport") end)
                task.wait(4)
                return
            end

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
        
        AutoGold = function() local inv = Save.Get().Inventory.Pet or {}; for u, d in pairs(inv) do if not d.pt and (d._am or 1) >= 10 then Network.Invoke("GoldMachine_Activate", u, 1); break end end end,
        AutoRainbow = function() local inv = Save.Get().Inventory.Pet or {}; for u, d in pairs(inv) do if d.pt == 1 and (d._am or 1) >= 10 then Network.Invoke("RainbowMachine_Activate", u, 1); break end end end,
        AutoCombine = function() local inv = Save.Get().Inventory.Lootboxes; if not inv then return end local pt = {"Small Fantasy Present", "Medium Fantasy Present", "Large Fantasy Present", "X-Large Fantasy Present"} for t = 1, 4 do for u, d in pairs(inv) do if d.id == pt[t] and (d._am or 1) >= 10 then Network.Invoke("FantasyCombineOMatic_Activate", u, math.floor(d._am/10)) end end end end,
        AutoFlag = function() local sf=getgenv().v_settings.functionToggles.SelectedFlag; if not sf or sf=="None" then return end local i=Save.Get().Inventory.Misc or {}; for u,it in pairs(i) do if it.id==sf then require(Lib.Client.FlexibleFlagCmds).Consume(it.id,u,1); break end end end,
        AutoUltimate = function() local u = UltimateCmds.GetEquippedItem(); if u and u._data and u._data.id then UltimateCmds.Activate(u._data.id) end end,
        AutoMisc = function() Network.Invoke('Mailbox: Claim All'); local red = Save.Get().FreeGiftsRedeemed or {}; local cT = Save.Get().FreeGiftsTime or 0; for _, g in pairs(FreeGiftsDirectory) do if g.WaitTime <= cT and not table.find(red, g._id) then Network.Invoke('Redeem Free Gift', g._id); break end end end,
        ClaimRank = function() local s = Save.Get(); local rw = RanksDirectory[RankCmds.GetTitle()].Rewards; local ts = 0; for i, v in pairs(rw) do ts = ts + v.StarsRequired; if s.RankStars >= ts and not s.RedeemedRankRewards[tostring(i)] then Network.Fire("Ranks_ClaimReward", i) end end end,
        Blackout = function() game:GetService("Lighting").GlobalShadows = false; for _, v in pairs(Workspace:GetDescendants()) do if v:IsA("BasePart") and not v:IsDescendantOf(THINGS) then v.Material = Enum.Material.Plastic; v.CastShadow = false end end end,
        AntiAFK = function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game) end
    }
}

-- Khôi phục cấu hình từ file
getgenv().v_settings.functionToggles.SelectedLootbox = savedConfig.Dropdowns.SelectedLootbox
getgenv().v_settings.functionToggles.SelectedGift = savedConfig.Dropdowns.SelectedGift
getgenv().v_settings.functionToggles.SelectedFlag = savedConfig.Dropdowns.SelectedFlag

-- ==============================================================
-- 🔄 AUTO START BACKGROUND LOOPS
-- ==============================================================

local LoopsToStart = {
    {Flag = "AutoTimeTrial", Func = getgenv().v_settings.functions.AutoTimeTrial, Wait = 1},
    {Flag = "AutoUnlock", Func = getgenv().v_settings.functions.AutoUnlock, Wait = 2},
    {Flag = "BestZone", Func = getgenv().v_settings.functions.BestZone, Wait = 2},
    {Flag = "AutoLoot", Func = getgenv().v_settings.functions.AutoLoot, Wait = 0.5},
    {Flag = "AutoHatch", Func = getgenv().v_settings.functions.AutoHatch, Wait = 2.5},
    {Flag = "AutoGold", Func = getgenv().v_settings.functions.AutoGold, Wait = 5},
    {Flag = "AutoRainbow", Func = getgenv().v_settings.functions.AutoRainbow, Wait = 5},
    {Flag = "AutoFruit", Func = getgenv().v_settings.functions.AutoFruit, Wait = 5},
    {Flag = "AutoCombine", Func = getgenv().v_settings.functions.AutoCombine, Wait = 3},
    {Flag = "AutoFlag", Func = getgenv().v_settings.functions.AutoFlag, Wait = 5},
    {Flag = "AutoUltimate", Func = getgenv().v_settings.functions.AutoUltimate, Wait = 1},
    {Flag = "AutoMisc", Func = getgenv().v_settings.functions.AutoMisc, Wait = 15},
    {Flag = "ClaimRank", Func = getgenv().v_settings.functions.ClaimRank, Wait = 5},
    {Flag = "Blackout", Func = getgenv().v_settings.functions.Blackout, Wait = 10},
    {Flag = "AntiAFK", Func = getgenv().v_settings.functions.AntiAFK, Wait = 60},
    {Flag = "OptimizePets", Func = getgenv().v_settings.functions.OptimizePets, Wait = 0.5}
}

for _, lData in ipairs(LoopsToStart) do
    task.spawn(function()
        while task.wait(lData.Wait) do
            if getgenv().v_settings.functionToggles[lData.Flag] then pcall(lData.Func) end
        end
    end)
end

-- Khởi động VRT Optimize Breakables (Auto Load)
if getgenv().v_settings.functionToggles.OptimizeBreakables then
    getgenv().v_settings.OptimizeBreakablesConn = DEBRIS_FOLDER.ChildAdded:Connect(function(child)
        pcall(function() Debris:AddItem(child, 0) end)
    end)
end

-- Vòng lặp FastFarm
local lastFastFarm = 0
RunService.Heartbeat:Connect(function()
    if getgenv().v_settings.functionToggles.FastFarm then
        local now = os.clock()
        if now - lastFastFarm > 0.15 then
            lastFastFarm = now
            pcall(getgenv().v_settings.functions.FastFarm)
        end
    end
end)

-- Vòng lặp Mở Hộp
task.spawn(function()
    while task.wait(1.5) do
        if getgenv().v_settings.functionToggles.AutoOpenLootbox then
            local sL = getgenv().v_settings.functionToggles.SelectedLootbox
            if sL ~= "None" and sL ~= "No Lootboxes Found" then
                local i=Save.Get().Inventory.Lootbox; local tU,tA=nil,0
                for u,it in pairs(i) do if it.id==sL then tU=u; tA=it._am or 1; break end end
                if tU then pcall(function() local am=math.min(tA,8); local bO=Items.Lootbox(sL); bO._uid=tU; LootboxCmds.Open(bO,am) end) 
                else getgenv().v_settings.functionToggles.AutoOpenLootbox=false end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(1.5) do
        if getgenv().v_settings.functionToggles.AutoOpenGift then
            local sG = getgenv().v_settings.functionToggles.SelectedGift
            if sG ~= "None" and sG ~= "No Gifts/Bundles Found" then
                local iL=Save.Get().Inventory.Lootbox; local iM=Save.Get().Inventory.Misc; local tU,tA=nil,0
                for u,it in pairs(iL) do if it.id==sG then tU=u; tA=it._am or 1; break end end
                if not tU then for u,it in pairs(iM) do if it.id==sG then tU=u; tA=it._am or 1; break end end end
                if tU then pcall(function() Network.Invoke("GiftBag_Open",sG,math.min(tA,100)) end) 
                else getgenv().v_settings.functionToggles.AutoOpenGift=false end
            end
        end
    end
end)

if getgenv().v_settings.functionToggles.HideEgg or getgenv().v_settings.functionToggles.HookEgg then
    pcall(getgenv().v_settings.functions.HandleEggAnimation)
end

-- ==============================================================
-- 🎨 RAYFIELD UI SETUP 
-- ==============================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = 'Poodle Hub V3',
    LoadingTitle = 'Poodle Hub',
    LoadingSubtitle = 'Debris Optimization Applied',
    ConfigurationSaving = { Enabled = false }, 
    KeySystem = false
})

local function CreateSmartToggle(TabObj, ToggleName, FlagName)
    TabObj:CreateToggle({
        Name = ToggleName, 
        CurrentValue = getgenv().v_settings.functionToggles[FlagName] or false, 
        Flag = FlagName,
        Callback = function(state)
            getgenv().v_settings.functionToggles[FlagName] = state
            if FlagName=="HideEgg" or FlagName=="HookEgg" then pcall(getgenv().v_settings.functions.HandleEggAnimation) end
            if FlagName=="OptimizePets" and not state then
                pcall(function()
                    PlayerPet.CalculateSpeedMultiplier = OriginalPetSpeed
                    if OriginalSetTarget then PlayerPet.SetTarget = OriginalSetTarget end
                end)
            end
        end
    })
end

-- ⚔️ Tab 1: Main Farm
local TabFarm = Window:CreateTab("Main Farm", "swords")
TabFarm:CreateSection("Farming Controls")
TabFarm:CreateToggle({
    Name = "Fast Farm (V8 Async)", 
    CurrentValue = getgenv().v_settings.functionToggles["FastFarm"] or false, 
    Flag = "FastFarm",
    Callback = function(state) getgenv().v_settings.functionToggles.FastFarm = state end
})
CreateSmartToggle(TabFarm, "Auto Time Trial (Per Tile)", "AutoTimeTrial")
CreateSmartToggle(TabFarm, "Auto Unlock Zone", "AutoUnlock")
CreateSmartToggle(TabFarm, "Go To Best Zone (Center Map)", "BestZone")
CreateSmartToggle(TabFarm, "Auto Collect Lootbags & Orbs", "AutoLoot")

TabFarm:CreateSection("Optimization")
TabFarm:CreateToggle({
    Name = "Optimize Breakables", 
    CurrentValue = getgenv().v_settings.functionToggles["OptimizeBreakables"] or false, 
    Flag = "OptimizeBreakables",
    Callback = function(state) 
        getgenv().v_settings.functionToggles.OptimizeBreakables = state 
        if state then
            if not getgenv().v_settings.OptimizeBreakablesConn then
                getgenv().v_settings.OptimizeBreakablesConn = DEBRIS_FOLDER.ChildAdded:Connect(function(child)
                    pcall(function() Debris:AddItem(child, 0) end)
                end)
                for _, v in pairs(DEBRIS_FOLDER:GetChildren()) do pcall(function() v:Destroy() end) end
            end
        else
            if getgenv().v_settings.OptimizeBreakablesConn then
                getgenv().v_settings.OptimizeBreakablesConn:Disconnect()
                getgenv().v_settings.OptimizeBreakablesConn = nil
            end
        end
    end
})
CreateSmartToggle(TabFarm, "Optimize Pets (Static/No Render)", "OptimizePets")

TabFarm:CreateSection("Mastery & Slots")
TabFarm:CreateButton({ Name = "Buy Pet Slots (Auto Detection)", Callback = function() getgenv().v_settings.functions.BuyPetSlots() end })
TabFarm:CreateButton({ Name = "Buy Egg Slots (Auto Detection)", Callback = function() getgenv().v_settings.functions.BuyEggSlots() end })

-- 🐾 Tab 2: Pets & Eggs
local TabPet = Window:CreateTab("Pets & Eggs", "egg")
CreateSmartToggle(TabPet, "Auto Hatch Best Egg (Remote)", "AutoHatch")
CreateSmartToggle(TabPet, "Hide Egg Animation", "HideEgg")
CreateSmartToggle(TabPet, "Hook Egg Animation (Notify)", "HookEgg")
CreateSmartToggle(TabPet, "Auto Craft Gold Pets", "AutoGold")
CreateSmartToggle(TabPet, "Auto Craft Rainbow Pets", "AutoRainbow")

-- 📦 Tab 3: Open Lootboxes
local TabOpen = Window:CreateTab("Open Lootboxes", "package")
TabOpen:CreateSection("Lootboxes (Max 8/tick)")
local DL=TabOpen:CreateDropdown({
    Name="Select Lootbox", Options={"Loading..."}, 
    CurrentOption={getgenv().v_settings.functionToggles.SelectedLootbox},
    Flag="DropLootbox", Callback=function(O) getgenv().v_settings.functionToggles.SelectedLootbox = O[1] end
})
TabOpen:CreateToggle({
    Name="Auto Open Lootbox", CurrentValue=getgenv().v_settings.functionToggles.AutoOpenLootbox, 
    Flag="ToggleOpenLootbox", Callback=function(st) getgenv().v_settings.functionToggles.AutoOpenLootbox = st end
})

TabOpen:CreateSection("GiftBags & Bundles (Max 100/tick)")
local DG=TabOpen:CreateDropdown({
    Name="Select GiftBag/Bundle", Options={"Loading..."}, 
    CurrentOption={getgenv().v_settings.functionToggles.SelectedGift},
    Flag="DropGift", Callback=function(O) getgenv().v_settings.functionToggles.SelectedGift = O[1] end
})
TabOpen:CreateToggle({
    Name="Auto Open GiftBag/Bundle", CurrentValue=getgenv().v_settings.functionToggles.AutoOpenGift, 
    Flag="ToggleOpenGift", Callback=function(st) getgenv().v_settings.functionToggles.AutoOpenGift = st end
})
TabOpen:CreateButton({Name="🔄 Refresh Inventory", Callback=function() DL:Refresh(GetAvailableLootboxes(),true); DG:Refresh(GetAvailableGifts(),true) end})

-- 🎒 Tab 4: Items & Events
local TabItem = Window:CreateTab("Items & Events", "backpack")
CreateSmartToggle(TabItem, "Smart Auto Fruit (Maintain Max Buffs)", "AutoFruit")
CreateSmartToggle(TabItem, "Auto Combine Fantasy Presents", "AutoCombine")

local DF = TabItem:CreateDropdown({
    Name="Select Flag", Options={"Loading..."}, 
    CurrentOption={getgenv().v_settings.functionToggles.SelectedFlag},
    Callback=function(O) getgenv().v_settings.functionToggles.SelectedFlag = O[1] end
})
TabItem:CreateButton({Name="🔄 Refresh Flags", Callback=function() DF:Refresh(GetAvailableFlags(),true) end})
task.delay(2, function() DL:Refresh(GetAvailableLootboxes(),true); DG:Refresh(GetAvailableGifts(),true); DF:Refresh(GetAvailableFlags(),true) end)

CreateSmartToggle(TabItem, "Auto Place Flag", "AutoFlag")
CreateSmartToggle(TabItem, "Auto Use Ultimate", "AutoUltimate")
CreateSmartToggle(TabItem, "Auto Claim Free Gifts & Mailbox", "AutoMisc")
CreateSmartToggle(TabItem, "Auto Claim Rank Rewards", "ClaimRank")

-- ⚙️ Tab 5: Settings
local TabSet = Window:CreateTab("Settings", "settings")
TabSet:CreateSection("Config Management")
TabSet:CreateButton({
    Name = "💾 Save File",
    Callback = function() 
        SaveCurrentConfig()
        Rayfield:Notify({Title="System", Content="Configuration saved to Phone Storage!", Duration=3})
    end
})
TabSet:CreateLabel("💡 The system will automatically start the saved features upon runtime..")

TabSet:CreateSection("System")
CreateSmartToggle(TabSet, "Blackout Mode (FPS Boost)", "Blackout")
CreateSmartToggle(TabSet, "Anti-AFK", "AntiAFK")
