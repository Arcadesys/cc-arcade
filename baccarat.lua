-- baccarat.lua
-- Multiplayer Baccarat for Arcade OS
-- "Easy Game" - betting focused

local w, h = term.getSize()
local SUITS = {"H", "D", "C", "S"}
local RANKS = {"2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"}

-- Colors
local C_TABLE = colors.green
local C_TEXT = colors.white
local C_CARD_BG = colors.white
local C_CARD_RED = colors.red
local C_CARD_BLK = colors.black
local C_HIDDEN = colors.red -- Red back for cards
local C_MSG = colors.cyan

-- Card Dimensions
local CARD_W = 4
local CARD_H = 3

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

--------------------------------------------------------------------------------
-- GAME LOGIC
--------------------------------------------------------------------------------

local function createShoe(numDecks)
    local deck = {}
    for i=1, numDecks do
        for _, s in ipairs(SUITS) do
            for _, r in ipairs(RANKS) do
                table.insert(deck, {suit=s, rank=r})
            end
        end
    end
    -- Shuffle
    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

local function getCardValue(card)
    if card.rank == "A" then return 1 end
    if card.rank == "K" or card.rank == "Q" or card.rank == "J" or card.rank == "10" then return 0 end
    return tonumber(card.rank)
end

local function calculateScore(hand)
    local total = 0
    for _, card in ipairs(hand) do
        total = total + getCardValue(card)
    end
    return total % 10
end

local function drawCard(deck)
    if #deck == 0 then 
        deck = createShoe(6) -- Reshuffle
    end
    return table.remove(deck, 1)
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

local function drawCenter(y, text, fg, bg)
    local x = math.floor((w - #text)/2) + 1
    drawText(x, y, text, fg, bg)
end

local function getSuitColor(suit)
    if suit == "H" or suit == "D" then return C_CARD_RED else return C_CARD_BLK end
end

local function drawGraphicalCard(x, y, card, hidden)
    term.setBackgroundColor(hidden and C_HIDDEN or C_CARD_BG)
    for i=0, CARD_H-1 do
        term.setCursorPos(x, y+i)
        term.write(string.rep(" ", CARD_W))
    end
    
    if hidden then
        term.setTextColor(colors.white)
        term.setCursorPos(x, y+1)
        term.write(" ?? ")
    else
        local sColor = getSuitColor(card.suit)
        term.setTextColor(sColor)
        
        local rankStr = card.rank
        if #rankStr == 1 then rankStr = rankStr .. " " end
        
        term.setCursorPos(x, y)
        term.write(rankStr)
        
        term.setCursorPos(x+1, y+1)
        term.write(card.suit)
        
        term.setCursorPos(x+CARD_W-#rankStr, y+CARD_H-1)
        term.write(rankStr)
    end
end

local function drawHand(centerX, y, label, hand)
    local spacing = CARD_W + 1
    local totalW = (#hand * spacing) - 1
    local startX = math.floor(centerX - totalW/2)
    
    drawText(startX, y-1, label, colors.yellow, C_TABLE)
    
    for i, card in ipairs(hand) do
        drawGraphicalCard(startX + (i-1)*spacing, y, card, false)
    end
    
    if #hand > 0 then
        local score = calculateScore(hand)
        drawText(startX, y+CARD_H, "Val: " .. score, colors.white, C_TABLE)
    end
end

local function animateSparkles(x, y, width, height)
    local duration = 1.0
    local startTime = os.clock()
    local colorsList = {colors.yellow, colors.orange, colors.white}
    while os.clock() - startTime < duration do
        local rx = math.random(x, x + width - 1)
        local ry = math.random(y, y + height - 1)
        term.setCursorPos(rx, ry)
        term.setTextColor(colorsList[math.random(1, #colorsList)])
        term.write("*")
        sleep(0.05)
    end
end

local function drawTable(players, bankersHand, playersHand, message, controls)
    term.setBackgroundColor(C_TABLE)
    term.clear()
    
    drawCenter(1, " BACCARAT ", colors.black, colors.lime)
    
    -- Hands
    -- Banker Top
    drawHand(w/2, 3, "BANKER", bankersHand)
    
    -- Player Bottom
    drawHand(w/2, 3 + CARD_H + 2, "PLAYER", playersHand)
    
    -- Users/Bets Footer
    local playerY = h - 5
    local sectionW = w / #players
    
    for i, p in ipairs(players) do
        local pCenterX = (i-1)*sectionW + sectionW/2
        local x = math.floor(pCenterX) - 5
        
        -- Name
        drawText(x, playerY, p.name, colors.white, C_TABLE)
        -- Bet
        local betStr = "Bet: " .. (p.choice or "...")
        local bColor = colors.lightGray
        if p.win then bColor = colors.yellow end
        drawText(x, playerY+1, betStr, bColor, C_TABLE)
        -- Credits
        drawText(x, playerY+2, "$" .. creditsAPI.get(p.mountPath), colors.gold, C_TABLE)
        
        if p.win then
            drawText(x, playerY+3, "WIN!", colors.lime, C_TABLE)
        elseif p.loss then
            drawText(x, playerY+3, "LOSE", colors.red, C_TABLE)
        end
    end
    
    -- Message
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(1, h-1)
    term.clearLine()
    term.setCursorPos(1, h)
    term.clearLine()
    
    if message then
        drawCenter(h-1, message, C_MSG, colors.black)
    end
    
    if controls then
        -- 3 columns
        local colW = math.floor(w/3)
        term. setCursorPos(1, h)
        term.write(string.rep(" ", w))
        
        if controls[1] then
            term.setBackgroundColor(colors.red)
            term.setCursorPos(1, h)
            term.write(controls[1]) 
        end
        if controls[2] then
            term.setBackgroundColor(colors.yellow)
            term.setTextColor(colors.black)
            term.setCursorPos(colW+1, h)
            term.write(controls[2])
        end
        if controls[3] then
            term.setBackgroundColor(colors.blue)
            term.setTextColor(colors.white)
            term.setCursorPos(colW*2+1, h)
            term.write(controls[3])
        end
    end
end

--------------------------------------------------------------------------------
-- MAIN LOOP
--------------------------------------------------------------------------------

local function main()
    local deck = createShoe(6)
    
    while true do
        term.setBackgroundColor(colors.black)
        term.clear()
        drawCenter(h/2 - 2, "BACCARAT", colors.lime, colors.black)
        drawCenter(h/2, "Insert Cards (Max 3)", colors.white, colors.black)
        drawCenter(h/2 + 2, "[C] Start Game   [R] Exit", colors.gray, colors.black)
        
        local detectedCards = {}
        -- Lobby
        while true do
            local e, p1 = os.pullEvent()
            if e == "key" then
                local k = keys.getName(p1)
                if k == "enter" or k == "space" then
                    if #detectedCards > 0 then break end
                    drawCenter(h/2+4, "No players!", colors.red, colors.black)
                    sleep(1)
                elseif k == "backspace" or k == "e" then
                    return
                end
            elseif e == "disk" or e == "disk_eject" then
                detectedCards = creditsAPI.findCards()
                drawCenter(h/2+4, "Players: " .. #detectedCards, colors.yellow, colors.black)
            end
            
             if #detectedCards == 0 then
                 detectedCards = creditsAPI.findCards()
                 if #detectedCards > 0 then
                    drawCenter(h/2+4, "Players: " .. #detectedCards, colors.yellow, colors.black)
                end
            end
        end
        
        -- Init Rounds
        local players = {}
        for i, card in ipairs(detectedCards) do
            if i > 3 then break end
            creditsAPI.lock(card.path)
            table.insert(players, {
                name = card.name,
                mountPath = card.path,
                betAmt = 10,
                choice = nil -- "PLAYER", "BANKER", "TIE"
            })
            if creditsAPI.get(card.path) < 10 then
                drawCenter(h/2+5, card.name.." poor!", colors.red, colors.black)
                creditsAPI.unlock(card.path)
                sleep(2)
                return
            end
        end
        
        -- Betting Phase
        for i, p in ipairs(players) do
            creditsAPI.remove(p.betAmt, p.mountPath)
            while true do
                drawTable(players, {}, {}, p.name..": Choose Bet", {"[L] PLAYER", "[C] BANKER", "[R] TIE"})
                local btn = waitKey()
                if btn == "LEFT" then p.choice = "PLAYER"; break
                elseif btn == "CENTER" then p.choice = "BANKER"; break
                elseif btn == "RIGHT" then p.choice = "TIE"; break
                end
            end
        end
        
        -- Dealing
        drawTable(players, {}, {}, "Dealing...", {})
        local pHand = {}
        local bHand = {}
        
        -- Deal 2 cards each
        audio.playDeal(); table.insert(pHand, drawCard(deck)); sleep(0.5)
        drawTable(players, bHand, pHand, "Dealing...", {})
        audio.playDeal(); table.insert(bHand, drawCard(deck)); sleep(0.5)
        drawTable(players, bHand, pHand, "Dealing...", {})
        audio.playDeal(); table.insert(pHand, drawCard(deck)); sleep(0.5)
        drawTable(players, bHand, pHand, "Dealing...", {})
        audio.playDeal(); table.insert(bHand, drawCard(deck)); sleep(0.5)
        
        -- Check Naturals
        local pScore = calculateScore(pHand)
        local bScore = calculateScore(bHand)
        local natural = false
        if pScore >= 8 or bScore >= 8 then
            natural = true
        end
        
        drawTable(players, bHand, pHand, natural and "Natural!" or "Checking...", {})
        sleep(1)
        
        if not natural then
            -- Player draws?
            local pThird = nil
            if pScore <= 5 then
                audio.playDeal()
                pThird = drawCard(deck)
                table.insert(pHand, pThird)
                pScore = calculateScore(pHand)
                drawTable(players, bHand, pHand, "Player Draws", {})
                sleep(1)
            else
                drawTable(players, bHand, pHand, "Player Stands", {})
                sleep(1)
            end
            
            -- Banker draws?
            local bDraw = false
            if pThird == nil then
                 if bScore <= 5 then bDraw = true end
            else
                local val = getCardValue(pThird)
                if bScore <= 2 then bDraw = true
                elseif bScore == 3 and val ~= 8 then bDraw = true
                elseif bScore == 4 and (val >= 2 and val <= 7) then bDraw = true
                elseif bScore == 5 and (val >= 4 and val <= 7) then bDraw = true
                elseif bScore == 6 and (val >= 6 and val <= 7) then bDraw = true
                end
            end
            
            if bDraw then
                audio.playDeal()
                table.insert(bHand, drawCard(deck))
                bScore = calculateScore(bHand)
                drawTable(players, bHand, pHand, "Banker Draws", {})
                sleep(1)
            else
                drawTable(players, bHand, pHand, "Banker Stands", {})
                sleep(1)
            end
        end
        
        -- Resolve
        pScore = calculateScore(pHand)
        bScore = calculateScore(bHand)
        
        local winner = "TIE"
        if pScore > bScore then winner = "PLAYER"
        elseif bScore > pScore then winner = "BANKER"
        end
        
        local msg = "Result: " .. winner .. " Wins!"
        drawTable(players, bHand, pHand, msg, {"[C] Continue"})
        
        if winner == "PLAYER" or winner == "BANKER" then
            audio.playWin()
        end
        
        -- Awards
        for _, p in ipairs(players) do
            p.win = false
            p.loss = false
            
            if p.choice == winner then
                p.win = true
                local payout = 0
                if winner == "TIE" then
                    payout = p.betAmt * 9 -- 8:1 + original
                else
                    payout = p.betAmt * 2 -- 1:1 + original
                end
                creditsAPI.add(payout, p.mountPath)
                animateSparkles(w/2, h/2, 1, 1) -- just a flash
            else
                p.loss = true
            end
        end
        
        drawTable(players, bHand, pHand, msg .. " [R] Exit [C] Again", {})
        
        local endBtn = waitKey()
        for _, p in ipairs(players) do creditsAPI.unlock(p.mountPath) end
        
        if endBtn == "RIGHT" then break end
    end
    
    -- Exit
    if fs.exists("menu.lua") then shell.run("menu.lua") end
end

main()
