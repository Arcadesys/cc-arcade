-- slots.lua
-- 3-Button Slot Machine (Multiplayer Edition)

local w, h = term.getSize()
local cx, cy = math.floor(w / 2), math.floor(h / 2)

local input = require("input")
local creditsAPI = require("credits")
local audio = require("audio")

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

local function drawText(x, y, text, fg, bg)
    term.setCursorPos(x, y)
    if fg then term.setTextColor(fg) end
    if bg then term.setBackgroundColor(bg) end
    term.write(text)
end

local function drawCenter(y, text, fg, bg)
    local x = math.floor((w - #text)/2) + 1
    drawText(x, y, text, fg, bg)
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

--------------------------------------------------------------------------------
-- DRAWING
--------------------------------------------------------------------------------

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

local reelPos = {1, 1, 1}

local function drawReel(idx, x, y)
    -- Draw Frame around reel
    term.setBackgroundColor(colors.gray)
    for i=-1, 3 do
        term.setCursorPos(x-1, y+i*3-1)
        term.write("      ") -- Clear/Bg
    end
    
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

local function drawMachine(bet, message, currentPlayerName, currentCredits)
    term.setBackgroundColor(colors.black)
    term.clear()
    
    -- Title
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.yellow)
    term.clearLine()
    drawCenter(1, " SUPER SLOTS ", colors.yellow, colors.blue)
    
    -- Machine Box
    local boxW, boxH = 26, 13
    local bx, by = cx - 13, cy - 6
    term.setBackgroundColor(colors.lightGray)
    for i=0, boxH do
        term.setCursorPos(bx, by+i)
        term.write(string.rep(" ", boxW))
    end
    
    -- Draw Reels
    local startX = cx - 8
    local startY = cy - 4
    for i=1,3 do
        drawReel(i, startX + (i-1)*6, startY)
    end
    
    -- Payline Indicators
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.red)
    if bet >= 1 then term.setCursorPos(startX-2, startY+3) term.write(">") end -- Center
    if bet >= 2 then term.setCursorPos(startX-2, startY+0) term.write(">") end -- Top
    if bet >= 3 then term.setCursorPos(startX-2, startY+6) term.write(">") end -- Bottom
    
    -- Player Info
    term.setBackgroundColor(colors.black)
    term.setCursorPos(1, h-2)
    term.setTextColor(colors.white)
    if currentPlayerName then
        term.write("Player: " .. currentPlayerName)
        drawText(1, h-3, "Credits: " .. currentCredits, colors.gold, colors.black)
    end
    
    term.setCursorPos(w-10, h-2)
    term.write("Bet: " .. bet)
    
    -- Message
    term.setCursorPos(2, h-4)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    drawCenter(h-4, message, colors.yellow, colors.black)
    
    -- Footer
    drawFooter("Bet", "Spin", "Exit")
end

local function spin(player)
    if creditsAPI.get(player.mountPath) < player.bet then
        return "Not enough credits!"
    end
    
    creditsAPI.remove(player.bet, player.mountPath)
    
    -- Animation
    for i=1,20 do
        for r=1,3 do reelPos[r] = (reelPos[r] % #REELS[r]) + 1 end
        drawMachine(player.bet, "Spinning...", player.name, creditsAPI.get(player.mountPath))
        audio.playShuffle()
        sleep(0.05)
    end
    
    -- Stop one by one
    for r=1,3 do
        for i=1,10 do
            reelPos[r] = (reelPos[r] % #REELS[r]) + 1
            for k=r+1,3 do reelPos[k] = (reelPos[k] % #REELS[k]) + 1 end
            drawMachine(player.bet, "Spinning...", player.name, creditsAPI.get(player.mountPath))
            sleep(0.05 + i*0.01)
        end
        audio.playSlotStop()
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
    
    if player.bet >= 1 then win = win + checkLine(1) end -- Center (offset 1)
    if player.bet >= 2 then win = win + checkLine(0) end -- Top (offset 0)
    if player.bet >= 3 then win = win + checkLine(2) end -- Bottom (offset 2)
    
    if win > 0 then
        creditsAPI.add(win, player.mountPath)
        audio.playWin()
        
        -- Flash Effect
        for i=1,3 do
            drawMachine(player.bet, "WINNER! " .. win, player.name, creditsAPI.get(player.mountPath))
            sleep(0.1)
            term.setBackgroundColor(colors.lime)
            term.clear()
            sleep(0.1)
        end
        return "WINNER! " .. win
    else
        audio.playLose()
        return "Try again!"
    end
end

--------------------------------------------------------------------------------
-- MAIN LOOP
--------------------------------------------------------------------------------

local function main()
    while true do
        term.setBackgroundColor(colors.black)
        term.clear()
        drawCenter(h/2 - 2, "SUPER SLOTS", colors.gold, colors.black)
        drawCenter(h/2, "Insert Cards (Max 3)", colors.white, colors.black)
        drawCenter(h/2 + 2, "[C] Start Game   [R] Exit", colors.gray, colors.black)
        
        -- Lobby Loop
        local detectedCards = {}
        while true do
            local event, p1 = os.pullEvent()
            if event == "key" then
                local key = keys.getName(p1)
                if key == "enter" or key == "space" then -- Start
                    if #detectedCards > 0 then break end
                    drawCenter(h/2 + 4, "No players detected!", colors.red, colors.black)
                    sleep(1)
                    term.setCursorPos(1, h/2+4) term.clearLine()
                elseif key == "backspace" or key == "e" then -- Exit
                     term.setBackgroundColor(colors.black)
                     term.clear()
                     if fs.exists("menu.lua") then shell.run("menu.lua") end
                     return
                end
            elseif event == "disk" or event == "disk_eject" then
                -- Refresh cards
                detectedCards = creditsAPI.findCards()
                term.setCursorPos(1, h/2 + 4)
                term.clearLine()
                local msg = "Players: "
                for i, c in ipairs(detectedCards) do
                    msg = msg .. c.name .. " "
                end
                drawCenter(h/2 + 4, msg, colors.yellow, colors.black)
            end
            
            -- Initial scan
             if #detectedCards == 0 then
                 detectedCards = creditsAPI.findCards()
                 if #detectedCards > 0 then
                    term.setCursorPos(1, h/2 + 4)
                    term.clearLine()
                    local msg = "Players: "
                    for i, c in ipairs(detectedCards) do
                        msg = msg .. c.name .. " "
                    end
                    drawCenter(h/2 + 4, msg, colors.yellow, colors.black)
                end
            end
        end
        
        local players = {}
        for i, card in ipairs(detectedCards) do
            if i > 3 then break end
            creditsAPI.lock(card.path)
            table.insert(players, {
                bet=1, 
                name=card.name,
                mountPath=card.path 
            })
        end
        
        -- Game Loop
        local msg = "Welcome!"
        while true do
            local allQuit = false
            
            for i, p in ipairs(players) do
                while true do
                    drawMachine(p.bet, p.name .. ": " .. msg, p.name, creditsAPI.get(p.mountPath))
                    local action = waitKey()
                    
                    if action == "LEFT" then
                        p.bet = (p.bet % 3) + 1
                        audio.playChip()
                        msg = "Bet changed"
                    elseif action == "CENTER" then
                        msg = spin(p)
                        break -- Turn done
                    elseif action == "RIGHT" then
                        -- Player leaving?
                        allQuit = true
                        break
                    end
                end
                if allQuit then break end
            end
            
            if allQuit then break end
        end
        
        -- Unlock cards
        for _, p in ipairs(players) do
            creditsAPI.unlock(p.mountPath)
        end
    end
end

main()
