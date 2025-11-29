-- blackjack.lua
-- Five-button blackjack table with simple graphics for CraftOS/CC:Tweaked.
-- Buttons are the same mapping as button_debug.lua (redstone links + ASDFG fallback).

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
-- GAME STATE              --
-----------------------------

local bankroll = 100
local bet = 10
local activeBet = bet
local minBet = 1

local deck = {}
local playerHand = {}
local dealerHand = {}
local dealerHoleHidden = true
local mode = "betting" -- "betting" or "player"
local message = "Set your bet, then DEAL."
local allowDouble = true
local allowSurrender = true

-----------------------------
-- HELPERS                 --
-----------------------------

local function clamp(n, lo, hi) return math.max(lo, math.min(hi, n)) end

local function seedRng()
  local seed = os.epoch and os.epoch("utc") or os.time()
  math.randomseed(seed)
  -- warm-up throws to shake out predictable seeds
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

local function centerText(y, text, fg, bg)
  local w = select(1, term.getSize())
  local x = math.floor((w - #text) / 2) + 1
  term.setBackgroundColor(bg or colors.black)
  term.setTextColor(fg or colors.white)
  term.setCursorPos(x, y)
  term.write(text)
end

-----------------------------
-- DECK / HAND LOGIC        --
-----------------------------

local ranks = { "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K" }
local suits = { "S", "H", "D", "C" } -- spades, hearts, diamonds, clubs (ASCII to keep it portable)

local function buildDeck()
  deck = {}
  for _, s in ipairs(suits) do
    for _, r in ipairs(ranks) do
      table.insert(deck, { rank = r, suit = s })
    end
  end
  -- Fisher-Yates shuffle
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

local function cardValue(card)
  if card.rank == "A" then return 11 end
  if card.rank == "K" or card.rank == "Q" or card.rank == "J" or card.rank == "10" then
    return 10
  end
  return tonumber(card.rank) or 0
end

local function handValue(hand)
  local total, aces = 0, 0
  for _, c in ipairs(hand) do
    total = total + cardValue(c)
    if c.rank == "A" then aces = aces + 1 end
  end
  while total > 21 and aces > 0 do
    total = total - 10
    aces = aces - 1
  end
  return total
end

local function isBlackjack(hand)
  return #hand == 2 and handValue(hand) == 21
end

local function dealCard(hand)
  if #deck == 0 then buildDeck() end
  local c = table.remove(deck)
  table.insert(hand, c)
  return c
end

-----------------------------
-- RENDERING                --
-----------------------------

local CARD_W, CARD_H = 7, 5

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
  local stake = (mode == "player") and activeBet or bet
  term.write("Blackjack  |  Bank: $" .. bankroll .. "  Bet: $" .. stake .. "  Deck: " .. #deck .. " cards")
  term.setCursorPos(2, 3)
  local stateText = (mode == "player") and "Your turn: Hit / Stand / Double / Surrender." or "Betting: adjust then DEAL."
  term.write(stateText)
end

local function cardColors(card)
  if card.suit == "H" or card.suit == "D" then
    return colors.red, colors.white
  else
    return colors.black, colors.white
  end
end

local function drawCard(x, y, card, hidden)
  local fg, bg = colors.black, colors.white
  if hidden then
    bg = colors.lightBlue
    fg = colors.white
  else
    fg, bg = cardColors(card)
  end

  fillRect(x, y, CARD_W, CARD_H, bg, " ")

  term.setBackgroundColor(bg)
  term.setTextColor(fg)

  if hidden then
    local pattern = { "////", "\\\\\\\\", "////" }
    for i = 1, #pattern do
      term.setCursorPos(x + 1, y + i)
      term.write(pattern[i])
    end
    return
  end

  local rank = card.rank
  local suit = card.suit

  term.setCursorPos(x + 1, y + 1)
  term.write(rank)
  term.setCursorPos(x + CARD_W - #rank, y + CARD_H - 1)
  term.write(rank)

  local centerX = x + math.floor(CARD_W / 2)
  local centerY = y + math.floor(CARD_H / 2)
  term.setCursorPos(centerX, centerY)
  term.write(suit)
end

local function drawHand(hand, y, label, hideHole)
  local w = select(1, term.getSize())
  local count = math.max(1, #hand)
  local totalWidth = count * CARD_W + math.max(0, count - 1)
  local startX = math.floor((w - totalWidth) / 2) + 1

  term.setBackgroundColor(colors.green)
  term.setTextColor(colors.white)
  centerText(y - 1, label, colors.white, colors.green)

  for i, card in ipairs(hand) do
    local x = startX + (i - 1) * (CARD_W + 1)
    local hidden = hideHole and i == 2
    drawCard(x, y, card, hidden)
  end

  if #hand == 0 then
    centerText(y + math.floor(CARD_H / 2), "(empty)", colors.lightGray, colors.green)
  end
end

local function drawMessage()
  local w = select(1, term.getSize())
  local y = 4
  fillRect(1, y, w, 1, colors.black, " ")
  centerText(y, message, colors.yellow, colors.black)
end

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

local function drawButtonBar(actions, activeIndex)
  local segs = getSegments()
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
    local label = act.label or ""
    local width = seg.x2 - seg.x1 + 1
    local labelX = seg.x1 + math.floor((width - #label) / 2)
    term.setCursorPos(labelX, seg.y2)
    term.write(label)
  end
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
end

local function formatHandLabel(hand, hide, name)
  local value = "--"
  if #hand > 0 then
    value = hide and "??" or tostring(handValue(hand))
  end
  return name .. " (" .. value .. ")"
end

local function render(activeButton)
  term.setBackgroundColor(colors.black)
  term.clear()

  drawBackground()
  drawHeader()
  drawMessage()

  local dealerY = 6
  local playerY = dealerY + CARD_H + 4
  local hideDealer = dealerHoleHidden and mode == "player"

  drawHand(dealerHand, dealerY, formatHandLabel(dealerHand, hideDealer, "DEALER"), dealerHoleHidden)
  drawHand(playerHand, playerY, formatHandLabel(playerHand, false, "YOU"), false)

  local actions
  if mode == "player" then
    local doubleEnabled = allowDouble and #playerHand == 2 and activeBet * 2 <= bankroll
    local surrenderEnabled = allowSurrender and #playerHand == 2
    actions = {
      { label = "Hit" },
      { label = "Stand" },
      { label = "Double", enabled = doubleEnabled },
      { label = "Surrender", enabled = surrenderEnabled },
      { label = "Rules" },
    }
  else
    actions = {
      { label = "Bet -1", enabled = bankroll > 0 },
      { label = "Bet +1", enabled = bet < bankroll },
      { label = "Bet +5", enabled = bet < bankroll },
      { label = "Deal", enabled = bankroll > 0 },
      { label = "Max", enabled = bankroll > 0 },
    }
  end

  drawButtonBar(actions, activeButton)
end

-----------------------------
-- ROUND FLOW              --
-----------------------------

local function endRound(outcome, reason)
  dealerHoleHidden = false
  mode = "betting"
  allowDouble = true
  allowSurrender = true

  if outcome == "player" then
    bankroll = bankroll + activeBet
    message = "You win! " .. (reason or "")
  elseif outcome == "player_blackjack" then
    local win = math.floor(activeBet * 1.5 + 0.5)
    bankroll = bankroll + win
    message = "Blackjack! +" .. win .. ". " .. (reason or "")
  elseif outcome == "push" then
    message = "Push. " .. (reason or "")
  elseif outcome == "surrender" then
    local loss = math.ceil(activeBet / 2)
    bankroll = bankroll - loss
    message = "You surrendered. -" .. loss .. ". " .. (reason or "")
  else
    bankroll = bankroll - activeBet
    message = "Dealer wins. " .. (reason or "")
  end

  if bankroll <= 0 then
    message = message .. " Bankroll empty: next deal refills to $100."
  end

  bet = clamp(bet, minBet, math.max(bankroll, minBet))
  activeBet = bet
end

local function dealerPlay()
  dealerHoleHidden = false
  local dealerTotal = handValue(dealerHand)
  while dealerTotal < 17 do
    dealCard(dealerHand)
    dealerTotal = handValue(dealerHand)
  end
  return dealerTotal
end

local function settleAgainstDealer()
  local playerTotal = handValue(playerHand)
  if playerTotal > 21 then
    endRound("dealer", "You bust with " .. playerTotal .. ".")
    return
  end

  local dealerTotal = dealerPlay()

  if dealerTotal > 21 then
    endRound("player", "Dealer busts with " .. dealerTotal .. ".")
  elseif dealerTotal > playerTotal then
    endRound("dealer", "Dealer " .. dealerTotal .. " vs your " .. playerTotal .. ".")
  elseif dealerTotal < playerTotal then
    endRound("player", "You " .. playerTotal .. " vs dealer " .. dealerTotal .. ".")
  else
    endRound("push", "Both at " .. playerTotal .. ".")
  end
end

local function startRound()
  if bankroll <= 0 then
    bankroll = 100
    message = "Refilled bankroll to $100."
  end

  bet = clamp(bet, minBet, bankroll)
  activeBet = bet
  ensureDeck(15)

  playerHand = {}
  dealerHand = {}
  dealerHoleHidden = true
  allowDouble = true
  allowSurrender = true

  dealCard(playerHand)
  dealCard(dealerHand)
  dealCard(playerHand)
  dealCard(dealerHand) -- hole card (hidden until dealer turn)

  mode = "player"
  message = "Hit, Stand, Double, or Surrender."

  local playerBJ = isBlackjack(playerHand)
  local dealerBJ = isBlackjack(dealerHand)
  if playerBJ or dealerBJ then
    dealerHoleHidden = false
    if playerBJ and dealerBJ then
      endRound("push", "Both have blackjack.")
    elseif playerBJ then
      endRound("player_blackjack", "Payout 3:2.")
    else
      endRound("dealer", "Dealer blackjack.")
    end
  end
end

local function hit()
  if mode ~= "player" then return end
  dealCard(playerHand)
  allowDouble = false
  allowSurrender = false
  local total = handValue(playerHand)
  if total > 21 then
    settleAgainstDealer()
  else
    message = "You hit: total " .. total .. "."
  end
end

local function stand()
  if mode ~= "player" then return end
  message = "Standing..."
  allowDouble = false
  allowSurrender = false
  settleAgainstDealer()
end

local function doubleDown()
  if mode ~= "player" then return end
  if not (allowDouble and #playerHand == 2) then
    message = "Double only on first decision."
    return
  end
  if activeBet * 2 > bankroll then
    message = "Not enough bankroll to double."
    return
  end
  activeBet = activeBet * 2
  allowDouble = false
  allowSurrender = false
  dealCard(playerHand)
  message = "Double down!"
  settleAgainstDealer()
end

local function surrender()
  if mode ~= "player" then return end
  if not (allowSurrender and #playerHand == 2) then
    message = "Surrender only as first choice."
    return
  end
  endRound("surrender", "Half bet lost.")
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

local function adjustBet(delta)
  bet = clamp(bet + delta, minBet, math.max(bankroll, minBet))
  activeBet = bet
  message = "Bet: $" .. bet
end

local function handleButton(btn)
  if mode == "player" then
    if btn == 1 then
      hit()
    elseif btn == 2 then
      stand()
    elseif btn == 3 then
      doubleDown()
    elseif btn == 4 then
      surrender()
    elseif btn == 5 then
      message = "Rules: beat 21 without busting. Blackjack pays 3:2."
    end
  else
    if btn == 1 then
      adjustBet(-1)
    elseif btn == 2 then
      adjustBet(1)
    elseif btn == 3 then
      adjustBet(5)
    elseif btn == 4 then
      startRound()
    elseif btn == 5 then
      bet = clamp(bankroll, minBet, bankroll)
      activeBet = bet
      message = "Max bet set: $" .. bet
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
      handleButton(pressed)
      render(pressed)
    end
  end
end

main()
