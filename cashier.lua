-- cashier.lua
-- Arcade Cashier System
-- Handles Credit Cards (Floppy Disks) and Currency Exchange

local drive = peripheral.find("drive")
local inventories = { peripheral.find("inventory") }
local inputChest = nil
local vaultChest = nil

-- Monitor Mirroring (Run on both panels)
local monitors = { peripheral.find("monitor") }
if #monitors > 0 then
    local native = term.current()
    local mirror = {}
    
    -- Clone all functions from native term
    for k,v in pairs(native) do
        mirror[k] = function(...)
            local args = {...}
            -- 1. Execute on Native
            local res = { native[k](table.unpack(args)) }
            
            -- 2. Execute on Monitors (protected)
            for _, mon in ipairs(monitors) do
                if mon[k] then
                    -- Special handling for write to avid excessive errors? No, allow it.
                    pcall(mon[k], table.unpack(args)) 
                end
            end
            
            return table.unpack(res)
        end
    end
    
    -- Sync text scale to 1.0 everywhere
    for _, mon in ipairs(monitors) do
        mon.setTextScale(1)
        mon.clear()
        mon.setCursorPos(1,1)
    end
    
    term.redirect(mirror)
end

-- Filter inventories
local chests = {}
for _, inv in ipairs(inventories) do
    -- Ignore the disk drive itself if it shows up as an inventory
    if peripheral.getType(inv) ~= "drive" then
        table.insert(chests, inv)
    end
end

-- Assign chests (Heuristic: First found is Input, Second is Vault)
if #chests > 0 then inputChest = chests[1] end
if #chests > 1 then vaultChest = chests[2] end

-- Currency Config
local RATES = {
    ["minecraft:diamond"] = 1,
    ["minecraft:obsidian"] = 4,
    ["minecraft:ender_eye"] = 16
}

local function clear()
    term.clear()
    term.setCursorPos(1, 1)
end

local function drawHeader()
    term.setBackgroundColor(colors.green)
    term.setTextColor(colors.white)
    term.setCursorPos(1, 1)
    term.clearLine()
    term.setCursorPos(2, 1)
    term.write("ARCADE CASHIER")
    
    -- Status Bar
    term.setBackgroundColor(colors.black)
    term.setCursorPos(1, 2)
    term.clearLine()
    local status = "Vault: " .. (vaultChest and "ONLINE" or "OFFLINE")
    term.setTextColor(vaultChest and colors.lime or colors.red)
    term.setCursorPos(term.getSize() - #status, 1)
    term.write(status)
end

local function formatNum(n)
    return tostring(n)
end

-- Scan input chest for valid items
-- Returns: totalValue, itemList (list of {slot=i, name=id, count=c, value=v})
local function scanInputChest()
    if not inputChest then return 0, {} end
    
    local totalValue = 0
    local foundItems = {}
    
    local list = inputChest.list()
    for slot, item in pairs(list) do
        local rate = RATES[item.name]
        if rate then
            local val = rate * item.count
            totalValue = totalValue + val
            table.insert(foundItems, {
                slot = slot,
                name = item.name,
                count = item.count,
                value = val,
                rate = rate
            })
        end
    end
    
    return totalValue, foundItems
end

-- Move detected items to vault
-- Returns: total CREDITS successfully deposited
local function processDeposit(itemList)
    if not vaultChest then return 0 end
    
    local totalDepositedValue = 0
    local inputName = peripheral.getName(inputChest)
    
    for _, item in ipairs(itemList) do
        -- vaultChest.pullItems(fromName, fromSlot, limit)
        -- returns number of items moved
        local countMoved = vaultChest.pullItems(inputName, item.slot, item.count)
        
        if countMoved > 0 then
             local val = countMoved * item.rate
             totalDepositedValue = totalDepositedValue + val
        end
    end
    return totalDepositedValue
end

local function processWithdrawal(amountCredits)
    if not vaultChest then return false, "No Vault Connected" end
    if not inputChest then return false, "No Input/Output Chest" end

    -- We only cash out in Diamonds (Rate: 1)
    local neededDiamonds = amountCredits -- 1:1
    
    -- Check vault balance
    local diamondsAvailable = 0
    local list = vaultChest.list()
    local diamondSlots = {}
    
    for slot, item in pairs(list) do
        if item.name == "minecraft:diamond" then
            diamondsAvailable = diamondsAvailable + item.count
            table.insert(diamondSlots, {slot=slot, count=item.count})
        end
    end
    
    if diamondsAvailable < neededDiamonds then
        return false, "Vault Low on Diamonds"
    end
    
    -- Move items
    local remaining = neededDiamonds
    local vaultName = peripheral.getName(vaultChest)
    
    for _, slotInfo in ipairs(diamondSlots) do
        if remaining <= 0 then break end
        local toMove = math.min(remaining, slotInfo.count)
        
        -- inputChest.pullItems(vaultName, slot, count)
        inputChest.pullItems(vaultName, slotInfo.slot, toMove)
        
        remaining = remaining - toMove
    end
    
    return true
end

local function saveCard(name, credits)
    local data = {
        name = name,
        credits = credits,
        in_game = false
    }
    local f = fs.open("disk/credits.json", "w")
    f.write(textutils.serializeJSON(data))
    f.close()
    
    drive.setDiskLabel(name .. "'s Card")
end

-- MENU: New Card
local function menuNewCard()
    clear()
    drawHeader()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    
    term.setCursorPos(2, 3)
    print("NEW CARD DETECTED")
    
    term.setCursorPos(2, 5)
    write("Enter Name: ")
    local name = read()
    if name == "" then name = "Player" end
    
    term.setCursorPos(2, 7)
    print("Initial Deposit:")
    print("Please place items in the chest.")
    print("Checking...")
    sleep(1)
    
    local val, items = scanInputChest()
    if val == 0 then
        print("No valid items found.")
        print("Starting with 0 Credits.")
    else
        print("Found items worth: " .. val .. " Credits.")
        if vaultChest then
            print("Depositing items...")
            local actualVal = processDeposit(items)
            val = actualVal -- Update to what was actually moved
        else
            print("WARNING: No Vault. Items start in chest.")
        end
    end
    
    print(" Creating Card...")
    saveCard(name, val)
    sleep(1)
    print(" Done!")
    sleep(1)
end

-- MENU: Existing Card
local function menuExisting(data)
    while true do
        clear()
        drawHeader()
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        
        term.setCursorPos(2, 3)
        print("Welcome, " .. data.name)
        term.setCursorPos(2, 4)
        print("Credits: " .. data.credits)
        
        term.setCursorPos(2, 6)
        print("[1] Cash Out (Diamonds)")
        print("[2] Re-up (Deposit Items)")
        print("[3] Eject Card")
        
        local event, key = os.pullEvent("key")
        if key == keys.one or key == keys.numPad1 or key == keys.d then
            -- CASH OUT
            clear()
            drawHeader()
            term.setCursorPos(2, 3)
            print("CASH OUT (1 Diamond = 1 Credit)")
            print("Current Credits: " .. data.credits)
            print("Enter amount to withdraw (0 to cancel):")
            term.setCursorPos(2, 6)
            write("> ")
            local amt = tonumber(read())
            
            if amt and amt > 0 then
                if amt > data.credits then
                    print("Insufficient credits!")
                    sleep(2)
                else
                    local success, err = processWithdrawal(amt)
                    if success then
                        data.credits = data.credits - amt
                        saveCard(data.name, data.credits)
                        print("Withdrawal Complete!")
                        print("Please collect items.")
                        sleep(2)
                    else
                        print("Error: " .. (err or "Unknown"))
                        sleep(2)
                    end
                end
            end
            
        elseif key == keys.two or key == keys.numPad2 or key == keys.u then
            -- RE-UP
            clear()
            drawHeader()
            term.setCursorPos(2, 3)
            print("DEPOSIT ITEMS")
            print("Place items in Input Chest.")
            print("Rates:")
            print(" Diamond: 1, Obsidian: 4, Eye: 16")
            print("")
            print("Press [ENTER] to Scan & Deposit")
            print("Press [BACKSPACE] to Cancel")
            
            while true do
                local e, k = os.pullEvent("key")
                if k == keys.enter then
                    local val, items = scanInputChest()
                    if val > 0 then
                        local deposited = processDeposit(items)
                        if deposited > 0 then
                            data.credits = data.credits + deposited
                            saveCard(data.name, data.credits)
                            print("Success! Added " .. deposited .. " credits.")
                            sleep(2)
                        else
                             print("Error: Deposit Failed (Vault Full?).")
                             sleep(2)
                        end
                    else
                        print("No valid items found.")
                        sleep(1)
                    end
                    break
                elseif k == keys.backspace then
                    break
                end
            end
            
        elseif key == keys.three or key == keys.numPad3 or key == keys.q then
            drive.ejectDisk()
            return
        end
    end
end

local function main()
    while true do
        clear()
        drawHeader()
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        
        term.setCursorPos(2, 3)
        print("INSERT CARD TO BEGIN")
        
        if not drive then
            print("Error: No Drive Found")
            sleep(5)
            return
        end
        
        while not drive.isDiskPresent() do
            os.pullEvent("disk")
        end
        
        sleep(0.5)
        
        -- Load Card
        if fs.exists("disk/credits.json") then
            local f = fs.open("disk/credits.json", "r")
            local content = f.readAll()
            f.close()
            local data = textutils.unserializeJSON(content)
            
            if data then
                if data.in_game then
                     -- Handle locked card?
                     clear()
                     drawHeader()
                     term.setBackgroundColor(colors.black)
                     term.setTextColor(colors.red)
                     term.setCursorPos(2, 5)
                     print("ERROR: Card Locked!")
                     print("Player is currently in a game.")
                     sleep(2)
                     drive.ejectDisk()
                else
                    menuExisting(data)
                end
            else
                -- Corrupt? Treat as new?
                menuNewCard()
            end
        else
            menuNewCard()
        end
        
        -- Eject if not already ejected manually
        if drive.isDiskPresent() then
            drive.ejectDisk()
        end
        sleep(1)
    end
end

main()
