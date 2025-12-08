-- cant_stop.lua
-- A push-your-luck dice game for the Arcade OS

local w, h = term.getSize()

-- 3-Button Config
local input = require("input")

local function waitKey()
    while true do
        local e, p1 = os.pullEvent()
        local button = input.getButton(e, p1)
        if button then
            if e == "redstone" then sleep(0.2) end
            return button
        end
    end
end

--------------------------------------------------------------------------------
-- GAME LOGIC
--------------------------------------------------------------------------------

local COL_LENGTHS = {
    [2]=3, [3]=5, [4]=7, [5]=9, [6]=11,
    [7]=13,
    [8]=11, [9]=9, [10]=7, [11]=5, [12]=3
}

local board = {} -- [col] = {p1=0, p2=0, owner=nil}
for i=2,12 do board[i] = {p1=0, p2=0, owner=nil} end

local currentPlayer = 1
local tempMarkers = {} -- [col] = current_step
local runnersUsed = 0
local MAX_RUNNERS = 3

local function rollDice()
    local d = {}
    for i=1,4 do table.insert(d, math.random(1,6)) end
    return d
end

local function getPairings(dice)
    -- 3 ways to pair 4 dice: (1+2, 3+4), (1+3, 2+4), (1+4, 2+3)
    local pairs = {
        { {dice[1], dice[2]}, {dice[3], dice[4]} },
        { {dice[1], dice[3]}, {dice[2], dice[4]} },
        { {dice[1], dice[4]}, {dice[2], dice[3]} }
    }
    -- Calculate sums
    local options = {}
    for _, p in ipairs(pairs) do
        local s1 = p[1][1] + p[1][2]
        local s2 = p[2][1] + p[2][2]
        table.insert(options, {s1, s2})
    end
    return options
end

local function canAdvance(col)
    if board[col].owner then return false end
    if runnersUsed >= MAX_RUNNERS and not tempMarkers[col] then
        -- Check if we have a base marker here? No, runners must be placed.
        -- If we have a base marker but no runner, we need a runner to advance.
        return false
    end
    -- Check if already at top
    local current = tempMarkers[col] or (currentPlayer == 1 and board[col].p1 or board[col].p2)
    if current >= COL_LENGTHS[col] then return false end
    return true
end

local function isValidOption(opt)
    -- An option is valid if at least one of the sums can be played
    return canAdvance(opt[1]) or canAdvance(opt[2])
end

--------------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------------

local function drawText(x, y, text, fg, bg)
    term.setCursorPos(x, y)
    if fg then term.setTextColor(fg) end
    if bg then term.setBackgroundColor(bg) end
    term.write(text)
end

local function drawFooter(c1, c2, c3)
    local colW = math.floor(w / 3)
    
    -- Left Button
    term.setCursorPos(1, h)
    term.setBackgroundColor(colors.red)
    term.setTextColor(colors.white)
    term.write(string.rep(" ", colW))
    drawText(math.floor(colW/2 - #c1/2)+1, h, c1, colors.white, colors.red)
    
    -- Center Button
    term.setCursorPos(colW + 1, h)
    term.setBackgroundColor(colors.yellow)
    term.setTextColor(colors.black)
    term.write(string.rep(" ", colW))
    drawText(colW + math.floor(colW/2 - #c2/2)+1, h, c2, colors.black, colors.yellow)
    
    -- Right Button
    term.setCursorPos(colW * 2 + 1, h)
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
    term.write(string.rep(" ", w - (colW*2)))
    drawText(colW*2 + math.floor((w - colW*2)/2 - #c3/2)+1, h, c3, colors.white, colors.blue)
end

local function drawBoard(showTemp)
    term.setBackgroundColor(colors.black)
    term.clear()
    
    -- Draw Columns
    local startX = 2
    for col=2,12 do
        local x = startX + (col-2)*3
        local len = COL_LENGTHS[col]
        local owner = board[col].owner
        
        -- Header
        term.setCursorPos(x, 1)
        if owner == 1 then term.setTextColor(colors.blue)
        elseif owner == 2 then term.setTextColor(colors.red)
        else term.setTextColor(colors.white) end
        term.write(tostring(col))
        
        -- Track
        for step=1, len do
            local y = h - 2 - step
            term.setCursorPos(x, y)
            
            local char = "."
            local fg = colors.gray
            
            -- Check markers
            local p1 = board[col].p1
            local p2 = board[col].p2
            local temp = tempMarkers[col]
            
            if showTemp and temp and temp == step then
                char = "X"
                fg = (currentPlayer == 1) and colors.cyan or colors.orange
            elseif p1 == step and p2 == step then
                char = "B" -- Both
                fg = colors.magenta
            elseif p1 == step then
                char = "1"
                fg = colors.blue
            elseif p2 == step then
                char = "2"
                fg = colors.red
            end
            
            term.setTextColor(fg)
            term.write(char)
        end
    end
    
    -- Status
    term.setCursorPos(1, h)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.black)
    term.clearLine()
    term.write(" P" .. currentPlayer .. "'s Turn")
end



local function drawActionMenu()
    term.setCursorPos(1, h-2)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clearLine()
    term.write("Action:")
    
    drawFooter("Roll Again", "Stop (Save)", "View Board")
end

--------------------------------------------------------------------------------
-- MAIN LOOP
--------------------------------------------------------------------------------

local creditsAPI = require("credits")
local audio = require("audio")

local function main()
    if creditsAPI.get() < 5 then
        term.clear()
        term.setCursorPos(1, h/2)
        term.setTextColor(colors.red)
        term.write("Insert Coin: 5 Credits")
        sleep(2)
        return
    end
    creditsAPI.remove(5)

    -- Player Selection
    local numPlayers = 1
    while true do
        term.setBackgroundColor(colors.black)
        term.clear()
        drawText(cx - 5, cy - 2, "CANT STOP", colors.lime, colors.black)
        drawText(cx - 8, cy, "Select Players: " .. numPlayers, colors.white, colors.black)
        drawText(cx - 10, cy + 2, "[L] -   [C] Start   [R] +", colors.gray, colors.black)
        
        local key = waitKey()
        if key == "LEFT" and numPlayers > 1 then numPlayers = numPlayers - 1 end
        if key == "RIGHT" and numPlayers < 3 then numPlayers = numPlayers + 1 end
        if key == "CENTER" then break end
    end

    -- Initialize Board for N players
    -- board[col] = { positions = {0, 0, 0}, owner = nil }
    for i=2,12 do 
        board[i] = { positions={}, owner=nil } 
        for p=1, numPlayers do board[i].positions[p] = 0 end
    end

    local currentPlayer = 1
    
    -- Redefine drawBoard to handle N players
    local function drawBoard(showTemp)
        term.setBackgroundColor(colors.black)
        term.clear()
        
        -- Draw Columns
        local startX = 2
        for col=2,12 do
            local x = startX + (col-2)*3
            local len = COL_LENGTHS[col]
            local owner = board[col].owner
            
            -- Header
            term.setCursorPos(x, 1)
            if owner == 1 then term.setTextColor(colors.blue)
            elseif owner == 2 then term.setTextColor(colors.red)
            elseif owner == 3 then term.setTextColor(colors.green)
            else term.setTextColor(colors.white) end
            term.write(tostring(col))
            
            -- Track
            for step=1, len do
                local y = h - 2 - step
                term.setCursorPos(x, y)
                
                local char = "."
                local fg = colors.gray
                
                -- Check markers
                local temp = tempMarkers[col]
                
                if showTemp and temp and temp == step then
                    char = "X"
                    if currentPlayer == 1 then fg = colors.cyan
                    elseif currentPlayer == 2 then fg = colors.orange
                    else fg = colors.lime end
                else
                    -- Check player positions
                    local occupants = {}
                    for p=1, numPlayers do
                        if board[col].positions[p] == step then table.insert(occupants, p) end
                    end
                    
                    if #occupants > 0 then
                        if #occupants > 1 then
                            char = "*" -- Multiple
                            fg = colors.magenta
                        else
                            char = tostring(occupants[1])
                            if occupants[1] == 1 then fg = colors.blue
                            elseif occupants[1] == 2 then fg = colors.red
                            elseif occupants[1] == 3 then fg = colors.green end
                        end
                    end
                end
                
                term.setTextColor(fg)
                term.write(char)
            end
        end
        
        -- Status
        term.setCursorPos(1, h)
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.black)
        term.clearLine()
        local pColor = "Blue"
        if currentPlayer == 2 then pColor = "Red" elseif currentPlayer == 3 then pColor = "Green" end
        term.write(" P" .. currentPlayer .. " ("..pColor..") Turn")
    end

    while true do
        -- Turn Start
        tempMarkers = {}
        runnersUsed = 0
        local turnOver = false
        
        while not turnOver do
            -- Roll Dice
            audio.playShuffle()
            local dice = rollDice()
            local options = getPairings(dice)
            
            -- Helper to check advance with new board structure
            local function canAdvance(col)
                if board[col].owner then return false end
                if runnersUsed >= MAX_RUNNERS and not tempMarkers[col] then
                    return false
                end
                local current = tempMarkers[col] or board[col].positions[currentPlayer]
                if current >= COL_LENGTHS[col] then return false end
                return true
            end

            -- Check for Bust (No valid moves at all)
            local canMove = false
            -- Need to redefine isValidOption locally or pass canAdvance
            local function isValidOption(opt)
                return canAdvance(opt[1]) or canAdvance(opt[2])
            end

            for _, opt in ipairs(options) do
                if isValidOption(opt) then canMove = true break end
            end
            
            if not canMove then
                drawBoard(true)
                term.setCursorPos(1, h-2)
                term.setTextColor(colors.red)
                term.write("BUST! No valid moves.")
                audio.playLose()
                sleep(2)
                turnOver = true
            else
                -- Selection Phase (Direct Selection)
                local chosen = nil
                while not chosen do
                    drawBoard(true)
                    
                    -- Draw Options at bottom
                    local y = h - 5
                    term.setCursorPos(1, y)
                    term.setBackgroundColor(colors.black)
                    term.setTextColor(colors.white)
                    term.clearLine()
                    term.write("Choose Pair (1-3):")
                    
                    for i, opt in ipairs(options) do
                        local s1, s2 = opt[1], opt[2]
                        local valid = isValidOption(opt)
                        local str = string.format("[%d] %d & %d", i, s1, s2)
                        if not valid then str = str .. " (X)" end
                        
                        term.setCursorPos(2 + (i-1)*13, y+1)
                        if valid then term.setTextColor(colors.yellow) else term.setTextColor(colors.gray) end
                        term.write(str)
                    end
                    
                    term.setCursorPos(1, h)
                    drawFooter("Opt 1", "Opt 2", "Opt 3")
                    
                    local key = waitKey()
                    local selIdx = 0
                    if key == "LEFT" then selIdx = 1
                    elseif key == "CENTER" then selIdx = 2
                    elseif key == "RIGHT" then selIdx = 3 end
                    
                    if selIdx > 0 and selIdx <= #options then
                        if isValidOption(options[selIdx]) then
                            chosen = options[selIdx]
                        end
                    end
                end
                
                -- Apply Move
                local function advance(col)
                    if not canAdvance(col) then return end
                    if not tempMarkers[col] then
                        -- New runner
                        runnersUsed = runnersUsed + 1
                        local start = board[col].positions[currentPlayer]
                        tempMarkers[col] = start + 1
                    else
                        tempMarkers[col] = tempMarkers[col] + 1
                    end
                end
                
                advance(chosen[1])
                advance(chosen[2])
                audio.playChip()
                
                -- Action Phase (Roll or Stop)
                local actionChosen = false
                while not actionChosen do
                    drawBoard(true)
                    drawActionMenu()
                    
                    local key = waitKey()
                    if key == "LEFT" then -- Roll Again
                        actionChosen = true
                    elseif key == "CENTER" then -- Stop
                        -- Save Progress
                        for col, step in pairs(tempMarkers) do
                            board[col].positions[currentPlayer] = step
                            
                            -- Check Column Win
                            if step >= COL_LENGTHS[col] then
                                board[col].owner = currentPlayer
                                audio.playWin()
                            end
                        end
                        turnOver = true
                        actionChosen = true
                        audio.playConfirm()
                    elseif key == "RIGHT" then
                        -- View Board (Toggle) - Actually just redraws since loop continues
                    end
                end
            end
        end
        
        -- Check Game Win (3 Columns)
        local owned = 0
        for col=2,12 do if board[col].owner == currentPlayer then owned = owned + 1 end end
        if owned >= 3 then
            term.clear()
            term.setCursorPos(1, h/2)
            term.write("PLAYER " .. currentPlayer .. " WINS!")
            audio.playWin()
            sleep(3)
            break
        end
        
        -- Switch Player
        currentPlayer = (currentPlayer % numPlayers) + 1
    end
    
    if fs.exists("menu.lua") then shell.run("menu.lua") end
end

main()
