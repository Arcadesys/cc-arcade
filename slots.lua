-- slots.lua
-- A 3-reel, multi-line slot machine for the CC Arcade.

local function loadModule(name)
    local ok, mod = pcall(require, name)
    if ok and mod then return mod end
    local path = name .. ".lua"
    local chunk, err = loadfile(path)
    if not chunk then error(err) end
    return chunk()
end

local input = loadModule("input")

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------

local SYMBOLS = {
    "Cherry", "Lemon", "Orange", "Plum", "Bell", "Bar", "7"
}

local SYMBOL_COLORS = {
    Cherry = colors.red,
    Lemon = colors.yellow,
    Orange = colors.orange,
    Plum = colors.purple,
    Bell = colors.gold or colors.yellow, -- Fallback if gold isn't available
    Bar = colors.lightGray,
    ["7"] = colors.red
}

local SYMBOL_CHARS = {
    Cherry = "@",
    Lemon = "O",
    Orange = "O",
    Plum = "%",
    Bell = "A",
    Bar = "=",
    ["7"] = "7"
}

local PAYOUTS = {
    -- 3 of a kind payouts
    Cherry = 10,
    Lemon = 20,
    Orange = 30,
    Plum = 50,
    Bell = 100,
    Bar = 250,
    ["7"] = 500
}

-- Cherry also pays on 2 of a kind (any position on line)
local CHERRY_2_PAYOUT = 5

local REEL_LENGTH = 32
local REELS = {}

-- Generate weighted reels
local function generateReels()
    for i = 1, 3 do
        local strip = {}
        for _ = 1, REEL_LENGTH do
            -- Weighted random generation
            local r = math.random()
            local sym
            if r < 0.05 then sym = "7"        -- 5%
            elseif r < 0.15 then sym = "Bar"  -- 10%
            elseif r < 0.25 then sym = "Bell" -- 10%
            elseif r < 0.40 then sym = "Plum" -- 15%
            elseif r < 0.60 then sym = "Orange" -- 20%
            elseif r < 0.80 then sym = "Lemon" -- 20%
            else sym = "Cherry" end           -- 20%
            table.insert(strip, sym)
        end
        REELS[i] = strip
    end
end

generateReels()

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local credits = 100
local bet = 1 -- 1 to 3 lines
local reelPos = {1, 1, 1} -- Top visible index for each reel
local message = "Press DO to Spin!"
local lastWin = 0
local isSpinning = false
local winningLines = {} -- {1=true, 2=true, 3=true}

--------------------------------------------------------------------------------
-- GRAPHICS
--------------------------------------------------------------------------------

local w, h = term.getSize()
local cx, cy = math.floor(w / 2), math.floor(h / 2)

local function drawRect(x, y, width, height, color)
    term.setBackgroundColor(color)
    for i = 0, height - 1 do
        term.setCursorPos(x, y + i)
        term.write(string.rep(" ", width))
    end
end

local function drawTextCentered(y, text, fg, bg)
    term.setTextColor(fg)
    term.setBackgroundColor(bg)
    local x = math.floor((w - #text) / 2) + 1
    term.setCursorPos(x, y)
    term.write(text)
end

local function getSymbolAt(reelIdx, offset)
    local pos = reelPos[reelIdx] + offset
    -- Wrap around
    pos = ((pos - 1) % REEL_LENGTH) + 1
    return REELS[reelIdx][pos]
end

local function drawReel(reelIdx, x, y)
    -- Draw 3 rows visible
    for i = 0, 2 do
        local sym = getSymbolAt(reelIdx, i)
        local color = SYMBOL_COLORS[sym]
        local char = SYMBOL_CHARS[sym]
        
        term.setBackgroundColor(colors.white)
        term.setTextColor(color)
        
        -- Draw symbol box
        term.setCursorPos(x, y + (i * 4))
        term.write("      ")
        term.setCursorPos(x, y + (i * 4) + 1)
        term.write("  " .. char .. char .. "  ")
        term.setCursorPos(x, y + (i * 4) + 2)
        term.write("      ")
        
        -- Draw separator
        if i < 2 then
            term.setBackgroundColor(colors.black)
            term.setCursorPos(x, y + (i * 4) + 3)
            term.write("      ")
        end
    end
end

local function drawUI()
    term.setBackgroundColor(colors.black)
    term.clear()
    
    -- Header
    drawRect(1, 1, w, 3, colors.blue)
    drawTextCentered(2, "--- SUPER SLOTS ---", colors.yellow, colors.blue)
    
    -- Reel Frame
    local reelW = 6
    local spacing = 2
    local totalW = (reelW * 3) + (spacing * 2)
    local startX = cx - math.floor(totalW / 2)
    local startY = 5
    
    -- Draw Paylines Indicators
    local lineColors = {colors.red, colors.white, colors.red} -- Top, Center, Bottom
    if bet >= 1 then
        term.setTextColor(colors.red)
        term.setCursorPos(startX - 2, startY + 5) -- Center line
        term.write(">")
        term.setCursorPos(startX + totalW + 2, startY + 5)
        term.write("<")
    end
    if bet >= 2 then
        term.setTextColor(colors.red)
        term.setCursorPos(startX - 2, startY + 1) -- Top line
        term.write(">")
        term.setCursorPos(startX + totalW + 2, startY + 1)
        term.write("<")
    end
    if bet >= 3 then
        term.setTextColor(colors.red)
        term.setCursorPos(startX - 2, startY + 9) -- Bottom line
        term.write(">")
        term.setCursorPos(startX + totalW + 2, startY + 9)
        term.write("<")
    end
    
    -- Draw Reels
    for i = 1, 3 do
        local rx = startX + (i - 1) * (reelW + spacing)
        drawReel(i, rx, startY)
    end
    
    -- Footer Info
    local footerY = h - 2
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(2, footerY)
    term.write("Credits: " .. credits)
    
    term.setCursorPos(w - 12, footerY)
    term.write("Bet: " .. bet)
    
    drawTextCentered(footerY + 1, message, colors.yellow, colors.black)
    
    -- Win Highlight
    if lastWin > 0 then
        drawTextCentered(4, "WIN: " .. lastWin, colors.lime, colors.black)
    end
end

--------------------------------------------------------------------------------
-- LOGIC
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- LOGIC
--------------------------------------------------------------------------------

local isLeverActive = false

local function checkWin()
    local totalWin = 0
    winningLines = {}
    
    -- Helper to check a line (offset 0=top, 1=center, 2=bottom)
    local function checkLine(offset)
        local s1 = getSymbolAt(1, offset)
        local s2 = getSymbolAt(2, offset)
        local s3 = getSymbolAt(3, offset)
        
        if s1 == s2 and s2 == s3 then
            return PAYOUTS[s1] or 0
        elseif s1 == "Cherry" and s2 == "Cherry" then
            return CHERRY_2_PAYOUT
        end
        return 0
    end
    
    -- Line 1: Center (Always active if bet >= 1)
    if bet >= 1 then
        local win = checkLine(1)
        if win > 0 then
            totalWin = totalWin + win
            winningLines[1] = true
        end
    end
    
    -- Line 2: Top (Active if bet >= 2)
    if bet >= 2 then
        local win = checkLine(0)
        if win > 0 then
            totalWin = totalWin + win
            winningLines[2] = true
        end
    end
    
    -- Line 3: Bottom (Active if bet >= 3)
    if bet >= 3 then
        local win = checkLine(2)
        if win > 0 then
            totalWin = totalWin + win
            winningLines[3] = true
        end
    end
    
    if totalWin > 0 then
        credits = credits + totalWin
        lastWin = totalWin
        message = "WINNER!"
        -- Flash effect
        for _=1,3 do
            term.setBackgroundColor(colors.lime)
            term.clear()
            sleep(0.1)
            drawUI()
            sleep(0.1)
        end
    else
        message = "Try again!"
    end
end

local function startSpinning()
    if credits < bet then
        message = "Not enough credits!"
        return false
    end
    
    credits = credits - bet
    lastWin = 0
    winningLines = {}
    isSpinning = true
    message = "Spinning..."
    return true
end

local function stopSpinning()
    isSpinning = false
    
    -- Landing animation
    local stopReel = 0
    local spins = 0
    
    while stopReel < 3 do
        -- Update spinning reels
        for i = 1, 3 do
            if i > stopReel then
                reelPos[i] = (reelPos[i] % REEL_LENGTH) + 1
            end
        end
        
        drawUI()
        sleep(0.05)
        
        spins = spins + 1
        if spins > 10 and stopReel == 0 then stopReel = 1 spins = 0 end
        if spins > 10 and stopReel == 1 then stopReel = 2 spins = 0 end
        if spins > 15 and stopReel == 2 then stopReel = 3 end
    end
    
    checkWin()
end

local function checkRedstone()
    for _, side in ipairs(rs.getSides()) do
        if rs.getInput(side) then return true end
    end
    return false
end

local function main()
    -- Enable redstone events
    os.pullEvent = os.pullEventRaw 
    
    while true do
        drawUI()
        
        -- Non-blocking input check
        local event, p1 = os.pullEvent()
        
        if event == "key" then
            local key = p1
            if key == keys.q then
                term.setBackgroundColor(colors.black)
                term.clear()
                term.setCursorPos(1,1)
                print("Thanks for playing!")
                return
            elseif key == keys.up then
                if not isSpinning and bet < 3 then bet = bet + 1 end
            elseif key == keys.down then
                if not isSpinning and bet > 1 then bet = bet - 1 end
            elseif key == keys.enter or key == keys.space then
                -- Manual spin (one-shot)
                if not isSpinning then
                    if startSpinning() then
                        stopSpinning()
                    end
                end
            end
        elseif event == "redstone" then
            local active = checkRedstone()
            
            if active and not isSpinning then
                -- Lever pulled: Start
                startSpinning()
                isLeverActive = true
            elseif not active and isSpinning and isLeverActive then
                -- Lever reset: Stop
                stopSpinning()
                isLeverActive = false
            end
        elseif event == "timer" then
             -- Timer event for continuous spin
             if isSpinning and isLeverActive then
                -- Spin all reels
                for i = 1, 3 do
                    reelPos[i] = (reelPos[i] % REEL_LENGTH) + 1
                end
                os.startTimer(0.05)
             end
        end
        
        -- Ensure timer loop is running if lever is active
        if isSpinning and isLeverActive and event ~= "timer" then
             os.startTimer(0.05)
        end
    end
end

main()
