-- blackjack.lua
-- Sequential Multiplayer Blackjack for Arcade OS
-- Visual Overhaul

local w, h = term.getSize()
local SUITS = {"H", "D", "C", "S"}
local RANKS = {"2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"}

-- Colors
local C_TABLE = colors.green
local C_TEXT = colors.white
local C_CARD_BG = colors.white
local C_CARD_RED = colors.red
local C_CARD_BLK = colors.black
local C_HIDDEN = colors.red
local C_LABEL = colors.yellow
local C_MSG = colors.cyan

-- Card Dimensions
local CARD_W = 4
local CARD_H = 3

-- 3-Button Config
local KEYS = {
    LEFT = { keys.left, keys.a, keys.q },
    CENTER = { keys.up, keys.w, keys.space, keys.enter },
    RIGHT = { keys.right, keys.d, keys.e }
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
-- GAME LOGIC
--------------------------------------------------------------------------------

local function createDeck()
    local deck = {}
    for _, s in ipairs(SUITS) do
        for _, r in ipairs(RANKS) do
            table.insert(deck, {suit=s, rank=r})
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
    if card.rank == "A" then return 11 end
    if card.rank == "K" or card.rank == "Q" or card.rank == "J" then return 10 end
    return tonumber(card.rank)
end

local function calculateHand(hand)
    local total = 0
    local aces = 0
    for _, card in ipairs(hand) do
        total = total + getCardValue(card)
        if card.rank == "A" then aces = aces + 1 end
    end
    while total > 21 and aces > 0 do
        total = total - 10
        aces = aces - 1
    end
    return total
end

local function drawCardDeck(deck)
    if #deck == 0 then deck = createDeck() end -- Reshuffle if empty
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

local function getSuitChar(suit)
    -- If using a font that supports symbols, we could use them.
    -- Standard CC font doesn't have suit symbols, so we use letters.
    return suit
end

local function drawGraphicalCard(x, y, card, hidden)
    -- Card Background
    term.setBackgroundColor(hidden and C_HIDDEN or C_CARD_BG)
    
    for i=0, CARD_H-1 do
        term.setCursorPos(x, y+i)
        term.write(string.rep(" ", CARD_W))
    end
    
    if hidden then
        -- Pattern for hidden card
        term.setTextColor(colors.white)
        term.setCursorPos(x, y+1)
        term.write(" ?? ")
    else
        -- Rank and Suit
        local sColor = getSuitColor(card.suit)
        term.setTextColor(sColor)
        
        local rankStr = card.rank
        if #rankStr == 1 then rankStr = rankStr .. " " end
        
        -- Top Left
        term.setCursorPos(x, y)
        term.write(rankStr)
        
        -- Center Suit
        term.setCursorPos(x+1, y+1)
        term.write(getSuitChar(card.suit))
        
        -- Bottom Right (Rotated/Inverted conceptually, but just text here)
        term.setCursorPos(x+CARD_W-#rankStr, y+CARD_H-1)
        term.write(rankStr)
    end
end

local function drawHandGraphical(centerX, y, name, hand, hideFirst, isActive, status)
    -- Calculate total width of hand to center it
    -- Overlap cards by 1 column if hand is large?
    -- Let's do simple spacing: CARD_W + 1
    local spacing = CARD_W + 1
    local totalW = (#hand * spacing) - 1
    local startX = math.floor(centerX - totalW/2)
    
    -- Draw Name Label
    local labelColor = isActive and colors.yellow or colors.lightGray
    drawText(startX, y - 1, name, labelColor, C_TABLE)
    
    -- Draw Status if present
    if status and status ~= "Playing" then
        local sColor = colors.lightGray
        if status == "Blackjack!" or string.find(status, "WIN") then sColor = colors.gold or colors.orange end
        if status == "Bust!" or string.find(status, "LOSE") then sColor = colors.red end
        drawText(startX + #name + 2, y - 1, status, sColor, C_TABLE)
    end
    
    -- Draw Cards
    for i, card in ipairs(hand) do
        local cx = startX + (i-1)*spacing
        local isHidden = hideFirst and (i == 1)
        drawGraphicalCard(cx, y, card, isHidden)
    end
    
    -- Draw Score
    if not hideFirst then
        local score = calculateHand(hand)
        drawText(startX, y + CARD_H, "Score: " .. score, colors.gray, C_TABLE)
    end
end

local function drawTable(players, dealerHand, currentPlayerIdx, message, showDealer)
    term.setBackgroundColor(C_TABLE)
    term.clear()
    
    -- Header
    drawCenter(1, " BLACKJACK ", colors.black, colors.lime)
    
    -- Dealer Area (Top Center)
    local dealerY = 3
    drawHandGraphical(w/2, dealerY, "DEALER", dealerHand, not showDealer, false, nil)
    
    -- Player Area (Bottom)
    -- Distribute players evenly
    local playerY = h - 6 -- Leave room for controls
    local sectionW = w / #players
    
    for i, p in ipairs(players) do
        local pCenterX = (i-1)*sectionW + sectionW/2
        local isActive = (i == currentPlayerIdx)
        -- Add indicator if active
        if isActive then
            drawText(math.floor(pCenterX)-2, playerY-2, " vvv ", colors.white, C_TABLE)
        end
        drawHandGraphical(pCenterX, playerY, "P"..i, p.hand, false, isActive, p.status)
    end
    
    -- Message / Controls Area (Bottom 2 lines)
    local footerY = h - 1
    term.setBackgroundColor(colors.black)
    term.setCursorPos(1, h-1)
    term.clearLine()
    term.setCursorPos(1, h)
    term.clearLine()
    
    if message then
        drawCenter(h-1, message, C_MSG, colors.black)
    end
    
    -- Draw 3-Column Footer
    local colW = math.floor(w / 3)
    local c1 = "Hit"
    local c2 = "Stand"
    local c3 = "Shift >"
    
    if currentPlayerIdx == 0 then
        c1 = "-"
        c2 = "Play Again"
        c3 = "Exit"
    elseif message and string.find(message, "ADV") then
        c1 = "Double"
        c2 = "Surrender"
        c3 = "Back"
    end
    
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

--------------------------------------------------------------------------------
-- MAIN LOOP
--------------------------------------------------------------------------------

local function main()
    term.setBackgroundColor(colors.black)
    term.clear()
    drawCenter(h/2 - 2, "BLACKJACK", colors.lime, colors.black)
    drawCenter(h/2, "Select Players: 1-4", colors.white, colors.black)
    drawCenter(h/2 + 2, "[L] -   [C] Start   [R] +", colors.gray, colors.black)
    
    local numPlayers = 1
    while true do
        term.setCursorPos(w/2 - 2, h/2 + 1)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.write("< " .. numPlayers .. " >")
        local key = waitKey()
        if key == "LEFT" and numPlayers > 1 then numPlayers = numPlayers - 1 end
        if key == "RIGHT" and numPlayers < 4 then numPlayers = numPlayers + 1 end
        if key == "CENTER" then break end
    end
    
    local deck = createDeck()
    
local creditsAPI = require("credits")

    while true do
        -- Check Credits
        if creditsAPI.get() < 10 then
            term.setBackgroundColor(colors.black)
            term.clear()
            drawCenter(h/2, "Not enough credits!", colors.red, colors.black)
            drawCenter(h/2+1, "Need 10 credits.", colors.white, colors.black)
            sleep(2)
            break
        end

        -- New Round
        local players = {}
        for i=1, numPlayers do
            table.insert(players, {hand={}, status="Playing", bet=10})
            creditsAPI.remove(10) -- Deduct bet immediately
        end
        local dealerHand = {}
        
        -- Initial Deal
        for _=1,2 do
            for _, p in ipairs(players) do table.insert(p.hand, drawCardDeck(deck)) end
            table.insert(dealerHand, drawCardDeck(deck))
        end
        
        -- Player Turns
        for i, p in ipairs(players) do
            while true do
                local score = calculateHand(p.hand)
                if score == 21 then
                    p.status = "Blackjack!"
                    break
                elseif score > 21 then
                    p.status = "Bust!"
                    break
                end
                
                drawTable(players, dealerHand, i, "Player " .. i .. "'s Turn", false)
                local action = waitKey()
                
                -- Normal Mode
                if action == "LEFT" then -- Hit
                    table.insert(p.hand, drawCardDeck(deck))
                elseif action == "CENTER" then -- Stand
                    p.status = "Stand"
                    break
                elseif action == "RIGHT" then -- Shift (Advanced Mode)
                    -- Show Advanced Options
                    drawTable(players, dealerHand, i, "ADV: [L] Dbl [C] Surr [R] Back", false)
                    local advAction = waitKey()
                    
                    if advAction == "LEFT" then -- Double Down
                        table.insert(p.hand, drawCardDeck(deck))
                        score = calculateHand(p.hand)
                        if score > 21 then p.status = "Bust!" else p.status = "Dbl Stand" end
                        break
                    elseif advAction == "CENTER" then -- Surrender
                         p.status = "Surrender"
                         break
                    elseif advAction == "RIGHT" then -- Back
                        -- Loop continues
                    end
                end
            end
            drawTable(players, dealerHand, i, "Player " .. i .. " Done", false)
            sleep(0.5)
        end
        
        -- Dealer Turn
        drawTable(players, dealerHand, 0, "Dealer's Turn...", true)
        sleep(1)
        while calculateHand(dealerHand) < 17 do
            table.insert(dealerHand, drawCardDeck(deck))
            drawTable(players, dealerHand, 0, "Dealer Hits...", true)
            sleep(1)
        end
        
        -- Resolve
        local dealerScore = calculateHand(dealerHand)
        local dealerBust = dealerScore > 21
        
            if p.status == "Bust!" then
                p.status = "LOSE"
            elseif p.status == "Surrender" then
                p.status = "SURRENDER"
                creditsAPI.add(math.floor(p.bet / 2))
            elseif dealerBust then
                p.status = "WIN!"
                creditsAPI.add(p.bet * 2)
            elseif pScore > dealerScore then
                p.status = "WIN!"
                creditsAPI.add(p.bet * 2)
            elseif pScore == dealerScore then
                p.status = "PUSH"
                creditsAPI.add(p.bet)
            else
                p.status = "LOSE"
            end
        end
        
        drawTable(players, dealerHand, 0, "Round Over!", true)
        
        local endAction = waitKey()
        if endAction == "RIGHT" then
            break
        end
    end
    
    -- Exit to Menu
    term.setBackgroundColor(colors.black)
    term.clear()
    if fs.exists("menu.lua") then shell.run("menu.lua") end
end

main()
