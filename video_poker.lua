-- video_poker.lua
-- Five-button Jacks or Better video poker for CraftOS/CC:T.

-----------------------------
-- CONFIG: BUTTON MAPPING   --
-----------------------------

local buttons = {
  [1] = { side = "left",   label = "BTN1" },
  [2] = { side = "right",  label = "BTN2" },
  [3] = { side = "top",    label = "BTN3" },
  [4] = { side = "front",  label = "BTN4" },
  [5] = { side = "bottom", label = "BTN5" },
}

local keyToButton = {
  [keys.a] = 1,
  [keys.s] = 2,
  [keys.d] = 3,
  [keys.f] = 4,
  [keys.g] = 5,
}

local lastState = {}
for i, btn in ipairs(buttons) do
  lastState[i] = redstone.getInput(btn.side)
end

-----------------------------
-- GAME STATE               --
-----------------------------

local bankroll = 100
local bet = 5
local minBet = 1

local deck = {}
local hand = {}
local holds = { false, false, false, false, false }
local selectedCard = 1
local mode = "betting" -- "betting", "holding", "settled"
local message = "Adjust bet, then DEAL."

-----------------------------
-- HELPERS                  --
-----------------------------

local function clamp(n, lo, hi) return math.max(lo, math.min(hi, n)) end

local function seedRng()
  local seed = os.epoch and os.epoch("utc") or os.time()
  math.randomseed(seed)
  math.random(); math.random(); math.random()
end

local function fillRect(x, y, w, h, bg, char)
  if w <= 0 or h <= 0 then return end
  char = char or " "
  term.setBackgroundColor(bg)
  local line = string.rep(char, w)
  for yy = y, y + h - 1 do
    term.setCursorPos(x, yy)
    term.write(line)
  end
end

local function fitText(text, maxWidth)
  if #text <= maxWidth then return text end
  if maxWidth <= 3 then return string.sub(text, 1, maxWidth) end
  return string.sub(text, 1, maxWidth - 3) .. "..."
end

local function centerText(y, text, fg, bg)
  local w = select(1, term.getSize())
  local clipped = fitText(text, math.max(1, w - 2))
  local x = math.floor((w - #clipped) / 2) + 1
  term.setBackgroundColor(bg or colors.black)
  term.setTextColor(fg or colors.white)
  term.setCursorPos(x, y)
  term.write(clipped)
end

-----------------------------
-- DECK / HAND LOGIC        --
-----------------------------

local ranks = { "A", "K", "Q", "J", "10", "9", "8", "7", "6", "5", "4", "3", "2" }
local suits = { "S", "H", "D", "C" }
local rankValue = { A = 14, K = 13, Q = 12, J = 11, ["10"] = 10, ["9"] = 9, ["8"] = 8, ["7"] = 7, ["6"] = 6, ["5"] = 5, ["4"] = 4, ["3"] = 3, ["2"] = 2 }

local function buildDeck()
  deck = {}
  for _, s in ipairs(suits) do
    for _, r in ipairs(ranks) do
      table.insert(deck, { rank = r, suit = s })
    end
  end
  for i = #deck, 2, -1 do
    local j = math.random(i)
    deck[i], deck[j] = deck[j], deck[i]
  end
end

local function ensureDeck(countNeeded)
  if #deck < countNeeded then
    buildDeck()
  end
end

local function dealCard()
  if #deck == 0 then buildDeck() end
  return table.remove(deck)
end

local function resetHand()
  hand = {}
  holds = { false, false, false, false, false }
  selectedCard = 1
end

local function isFlush(handCards)
  local seen = {}
  for _, c in ipairs(handCards) do
    seen[c.suit] = (seen[c.suit] or 0) + 1
  end
  for _, count in pairs(seen) do
    if count == 5 then return true end
  end
  return false
end

local function straightInfo(counts)
  local uniq = {}
  for value in pairs(counts) do
    table.insert(uniq, value)
  end
  table.sort(uniq)
  if #uniq ~= 5 then return false end

  local first = uniq[1]
  local consec = true
  for i = 2, 5 do
    if uniq[i] ~= first + (i - 1) then
      consec = false
      break
    end
  end

  if consec then
    return true, uniq[5]
  end

  local wheel = uniq[1] == 2 and uniq[2] == 3 and uniq[3] == 4 and uniq[4] == 5 and uniq[5] == 14
  if wheel then
    return true, 5
  end

  return false
end

local function evaluateHand(handCards)
  local counts = {}
  for _, c in ipairs(handCards) do
    local v = rankValue[c.rank] or 0
    counts[v] = (counts[v] or 0) + 1
  end

  local isStraight, straightHigh = straightInfo(counts)
  local flush = isFlush(handCards)

  local pairsCount, trips, quads, highPair = 0, 0, 0, false
  for value, ct in pairs(counts) do
    if ct == 4 then quads = quads + 1
    elseif ct == 3 then trips = trips + 1
    elseif ct == 2 then
      pairsCount = pairsCount + 1
      if value >= 11 or value == 14 then highPair = true end
    end
  end

  if isStraight and flush then
    if straightHigh == 14 then return "Royal Flush", 250 end
    return "Straight Flush", 50
  end
  if quads > 0 then return "Four of a Kind", 25 end
  if trips > 0 and pairsCount > 0 then return "Full House", 9 end
  if flush then return "Flush", 6 end
  if isStraight then return "Straight", 4 end
  if trips > 0 then return "Three of a Kind", 3 end
  if pairsCount >= 2 then return "Two Pair", 2 end
  if highPair then return "Jacks or Better", 1 end
  return "No win", 0
end

-----------------------------
-- RENDERING                --
-----------------------------

local CARD_W, CARD_H = 7, 5

local function getSegments()
  local w, h = term.getSize()
  local segs = {}
  local base = math.floor(w / 5)
  local x = 1
  for i = 1, 5 do
    local width = (i < 5) and base or (w - base * 4)
    segs[i] = { x1 = x, x2 = x + width - 1, y1 = h - 1, y2 = h }
    x = x + width
  end
  return segs
end

local function drawBackground()
  local w, h = term.getSize()
  for y = 1, h - 2 do
    local stripe = (y % 4 == 0) and colors.brown or colors.green
    fillRect(1, y, w, 1, stripe, " ")
  end
end

local function drawHeader()
  local w = select(1, term.getSize())
  fillRect(1, 1, w, 3, colors.blue, " ")
  term.setBackgroundColor(colors.blue)
  term.setTextColor(colors.white)

  term.setCursorPos(2, 2)
  local header = string.format("Video Poker  |  Bank: $%d  Bet: $%d", bankroll, bet)
  term.write(fitText(header, w - 2))

  term.setCursorPos(2, 3)
  local sub = "Jacks or Better. Quit returns to menu."
  if mode == "holding" then
    sub = "Select cards to HOLD, then DRAW."
  elseif mode == "settled" then
    sub = "Result shown. Adjust bet or DEAL again."
  end
  term.write(fitText(sub, w - 2))
end

local function drawMessage()
  local w = select(1, term.getSize())
  local y = 4
  fillRect(1, y, w, 1, colors.black, " ")
  centerText(y, message, colors.yellow, colors.black)
end

local function drawCard(x, y, card, held, selected)
  local bg = held and colors.lightGray or colors.white
  if selected then bg = colors.lightBlue end
  fillRect(x, y, CARD_W, CARD_H, bg, " ")

  term.setBackgroundColor(bg)
  term.setTextColor(colors.black)

  local rankText = card.rank
  term.setCursorPos(x + 1, y + 1)
  term.write(rankText)
  term.setCursorPos(x + CARD_W - 2, y + 1)
  term.write(card.suit)

  local centerX = x + math.floor(CARD_W / 2)
  local centerY = y + math.floor(CARD_H / 2)
  term.setCursorPos(centerX, centerY)
  term.write(card.suit)

  if held then
    term.setTextColor(colors.orange)
    term.setCursorPos(x + 1, y + CARD_H - 1)
    term.write("HOLD")
  elseif mode == "holding" then
    term.setTextColor(colors.lightGray)
    term.setCursorPos(x + 1, y + CARD_H - 1)
    term.write("DRAW")
  end
end

local function drawHandArea()
  local w = select(1, term.getSize())
  if #hand == 0 then
    centerText(8, "Press DEAL to start.", colors.white, colors.green)
    return
  end

  local totalWidth = #hand * CARD_W + math.max(0, #hand - 1)
  local startX = math.floor((w - totalWidth) / 2) + 1
  local y = 6

  for i, card in ipairs(hand) do
    local x = startX + (i - 1) * (CARD_W + 1)
    local held = holds[i]
    local selected = (mode == "holding") and (i == selectedCard)
    drawCard(x, y, card, held, selected)
  end
end

local function drawButtonBar(activeIndex)
  local segs = getSegments()
  local actions

  if mode == "holding" then
    actions = {
      { label = "Prev" },
      { label = "Next" },
      { label = "Hold/Drop" },
      { label = "Draw" },
      { label = "Quit" },
    }
  else
    actions = {
      { label = "Bet -1", enabled = bankroll > minBet },
      { label = "Bet +1", enabled = bankroll > bet },
      { label = "Deal", enabled = bankroll > 0 },
      { label = "Max", enabled = bankroll > 0 },
      { label = "Quit", enabled = true },
    }
  end

  for i = 1, 5 do
    local seg = segs[i]
    local act = actions[i] or { label = "", enabled = false }
    local enabled = act.enabled ~= false
    local bg = enabled and colors.lightBlue or colors.gray
    if activeIndex == i then bg = colors.yellow end

    term.setBackgroundColor(bg)
    term.setTextColor(colors.black)
    for y = seg.y1, seg.y2 do
      term.setCursorPos(seg.x1, y)
      term.write(string.rep(" ", seg.x2 - seg.x1 + 1))
    end

    local label = fitText(act.label or "", seg.x2 - seg.x1 + 1)
    local width = seg.x2 - seg.x1 + 1
    local labelX = seg.x1 + math.floor((width - #label) / 2)
    term.setCursorPos(labelX, seg.y2)
    term.write(label)
  end

  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
end

local function render(activeButton)
  term.setBackgroundColor(colors.black)
  term.clear()

  drawBackground()
  drawHeader()
  drawMessage()
  drawHandArea()
  drawButtonBar(activeButton)
end

-----------------------------
-- GAME FLOW                --
-----------------------------

local function adjustBet(delta)
  if mode == "holding" then
    message = "Finish draw before adjusting bet."
    return
  end
  bet = clamp(bet + delta, minBet, math.max(bankroll, minBet))
  message = "Bet: $" .. bet
end

local function setMaxBet()
  if mode == "holding" then
    message = "Finish draw before max bet."
    return
  end
  bet = clamp(bankroll, minBet, bankroll)
  message = "Max bet: $" .. bet
end

local function moveSelection(delta)
  if #hand == 0 then return end
  selectedCard = ((selectedCard - 1 + delta) % #hand) + 1
  local action = holds[selectedCard] and "Held" or "Drawing"
  message = action .. " card " .. selectedCard .. "."
end

local function toggleHold()
  if mode ~= "holding" then return end
  if #hand == 0 then return end
  holds[selectedCard] = not holds[selectedCard]
  if holds[selectedCard] then
    message = "Holding card " .. selectedCard .. "."
  else
    message = "Will draw card " .. selectedCard .. "."
  end
end

local function dealHand()
  if mode == "holding" then
    message = "Already dealt. Draw or cancel holds."
    return
  end

  if bankroll <= 0 then
    bankroll = 100
    message = "Bankroll refilled to $100."
  end

  bet = clamp(bet, minBet, bankroll)
  bankroll = bankroll - bet

  ensureDeck(15)
  resetHand()

  for i = 1, 5 do
    hand[i] = dealCard()
  end

  mode = "holding"
  message = "Toggle holds, then DRAW."
end

local function drawFinal()
  if mode ~= "holding" then
    message = "Deal first, then draw."
    return
  end

  for i = 1, 5 do
    if not holds[i] then
      hand[i] = dealCard()
    end
  end

  local label, mult = evaluateHand(hand)
  local payout = bet * mult
  bankroll = bankroll + payout

  mode = "settled"
  message = string.format("%s pays $%d.", label, payout)
end

-----------------------------
-- INPUT HANDLING           --
-----------------------------

local function pollRedstone()
  local pressedIndex = nil
  for i, btn in ipairs(buttons) do
    local newState = redstone.getInput(btn.side)
    if newState and not lastState[i] then
      pressedIndex = i
    end
    lastState[i] = newState
  end
  return pressedIndex
end

local function handleButton(btn)
  if mode == "holding" then
    if btn == 1 then
      moveSelection(-1)
    elseif btn == 2 then
      moveSelection(1)
    elseif btn == 3 then
      toggleHold()
    elseif btn == 4 then
      drawFinal()
    elseif btn == 5 then
      return "quit"
    end
  else
    if btn == 1 then
      adjustBet(-1)
    elseif btn == 2 then
      adjustBet(1)
    elseif btn == 3 then
      dealHand()
    elseif btn == 4 then
      setMaxBet()
    elseif btn == 5 then
      return "quit"
    end
  end
end

-----------------------------
-- MAIN LOOP                --
-----------------------------

local function main()
  seedRng()
  buildDeck()
  render(nil)

  while true do
    local event, p1 = os.pullEvent()
    local pressed = nil

    if event == "redstone" then
      pressed = pollRedstone()
    elseif event == "key" then
      pressed = keyToButton[p1]
    end

    if pressed then
      local action = handleButton(pressed)
      if action == "quit" then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.clear()
        term.setCursorPos(1, 1)
        print("Exiting Video Poker.")
        return
      end
      render(pressed)
    end
  end
end

main()
