-- slots.lua
-- 3-Button Slot Machine

local w, h = term.getSize()
local cx, cy = math.floor(w / 2), math.floor(h / 2)

-- 3-Button Config
local KEYS = {
    LEFT = { keys.left, keys.a },
    CENTER = { keys.up, keys.w, keys.space, keys.enter },
    RIGHT = { keys.right, keys.d }
}

local function isKey(key, set)
    for _, k in ipairs(set) do if key == k then return true end end
    return false
end

local function waitKey()
    while true do
        local e, p1 = os.pullEvent()
        if e == "key" then
            if isKey(p1, KEYS.LEFT) then return "LEFT" end
            if isKey(p1, KEYS.CENTER) then return "CENTER" end
            if isKey(p1, KEYS.RIGHT) then return "RIGHT" end
        elseif e == "redstone" then
            if redstone.getInput("left") then sleep(0.2) return "LEFT" end
            if redstone.getInput("top") or redstone.getInput("front") then sleep(0.2) return "CENTER" end
            if redstone.getInput("right") then sleep(0.2) return "RIGHT" end
        end
    end
end

--------------------------------------------------------------------------------
-- GAME CONFIG
--------------------------------------------------------------------------------

local SYMBOLS = {"Cherry", "Lemon", "Orange", "Plum", "Bell", "Bar", "7"}
local COLORS = {
    Cherry = colors.red, Lemon = colors.yellow, Orange = colors.orange,
    Plum = colors.purple, Bell = colors.gold or colors.yellow,
    Bar = colors.lightGray, ["7"] = colors.red
}
local CHARS = {
    Cherry = "@", Lemon = "O", Orange = "O", Plum = "%",
    Bell = "A", Bar = "=", ["7"] = "7"
}
local PAYOUTS = {
    Cherry = 5, Lemon = 10, Orange = 20, Plum = 50,
    Bell = 100, Bar = 250, ["7"] = 500
}

local REELS = {}
for i=1,3 do
    REELS[i] = {}
    for j=1,32 do
        local r = math.random()
        local s
        if r < 0.05 then s = "7"
        elseif r < 0.15 then s = "Bar"
        elseif r < 0.25 then s = "Bell"
        elseif r < 0.40 then s = "Plum"
        elseif r < 0.60 then s = "Orange"
        elseif r < 0.80 then s = "Lemon"
        else s = "Cherry" end
        table.insert(REELS[i], s)
    end
end

local credits = 100
local bet = 1
local reelPos = {1, 1, 1}
local message = "Press [C] to Spin!"

--------------------------------------------------------------------------------
-- DRAWING
--------------------------------------------------------------------------------

local function drawReel(idx, x, y)
    for i=0,2 do
        local pos = (reelPos[idx] + i - 1) % #REELS[idx] + 1
        local sym = REELS[idx][pos]
        term.setCursorPos(x, y + i*3)
        term.setBackgroundColor(colors.white)
        term.setTextColor(COLORS[sym])
        term.write(" " .. CHARS[sym] .. CHARS[sym] .. " ")
        term.setBackgroundColor(colors.black)
    end
end

local function drawUI()
    term.setBackgroundColor(colors.black)
    term.clear()
    
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.yellow)
    term.clearLine()
    term.setCursorPos(2, 1)
    term.write("SUPER SLOTS")
    
    -- Draw Reels
    local startX = cx - 8
    local startY = cy - 4
    for i=1,3 do
        drawReel(i, startX + (i-1)*6, startY)
    end
    
    -- Paylines
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.red)
    if bet >= 1 then term.setCursorPos(startX-2, startY+4) term.write(">") end -- Center
    if bet >= 2 then term.setCursorPos(startX-2, startY+1) term.write(">") end -- Top
    if bet >= 3 then term.setCursorPos(startX-2, startY+7) term.write(">") end -- Bottom
    
    -- Info
    term.setCursorPos(2, h-2)
    term.setTextColor(colors.white)
    term.write("Credits: " .. credits)
    term.setCursorPos(w-10, h-2)
    term.write("Bet: " .. bet)
    
    term.setCursorPos(1, h)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.black)
    term.clearLine()
    term.write(" [L] Bet   [C] Spin   [R] Exit")
    
    term.setCursorPos(2, h-4)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.write(message)
end

local function spin()
    if credits < bet then
        message = "Not enough credits!"
        return
    end
    credits = credits - bet
    message = "Spinning..."
    
    -- Animation
    for i=1,20 do
        for r=1,3 do reelPos[r] = (reelPos[r] % #REELS[r]) + 1 end
        drawUI()
        sleep(0.05)
    end
    
    -- Stop one by one
    for r=1,3 do
        for i=1,10 do
            reelPos[r] = (reelPos[r] % #REELS[r]) + 1
            for k=r+1,3 do reelPos[k] = (reelPos[k] % #REELS[k]) + 1 end
            drawUI()
            sleep(0.05 + i*0.01)
        end
    end
    
    -- Check Win
    local win = 0
    local function getSym(r, offset)
        return REELS[r][(reelPos[r] + offset - 1) % #REELS[r] + 1]
    end
    
    local function checkLine(offset)
        local s1, s2, s3 = getSym(1, offset), getSym(2, offset), getSym(3, offset)
        if s1 == s2 and s2 == s3 then return PAYOUTS[s1] end
        if s1 == "Cherry" and s2 == "Cherry" then return 5 end
        return 0
    end
    
    if bet >= 1 then win = win + checkLine(1) end -- Center (offset 1)
    if bet >= 2 then win = win + checkLine(0) end -- Top (offset 0)
    if bet >= 3 then win = win + checkLine(2) end -- Bottom (offset 2)
    
    if win > 0 then
        credits = credits + win
        message = "WINNER! " .. win
        for i=1,3 do
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

local function main()
    while true do
        drawUI()
        local action = waitKey()
        
        if action == "LEFT" then
            bet = (bet % 3) + 1
        elseif action == "CENTER" then
            spin()
        elseif action == "RIGHT" then
            break
        end
    end
    if fs.exists("menu.lua") then shell.run("menu.lua") end
end

main()
