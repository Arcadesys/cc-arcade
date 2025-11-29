-- daleks.lua
-- Classic Daleks-style survival for five-button controller + keyboard fallback.

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
-- LAYOUT / HELPERS         --
-----------------------------

local gridW, gridH = 20, 12
local gridYStart = 3
local footerY = 0

local function clamp(n, lo, hi)
  return math.max(lo, math.min(hi, n))
end

local function sign(n)
  if n > 0 then return 1 elseif n < 0 then return -1 else return 0 end
end

local function adjustTextScale()
  if term.setTextScale then
    term.setTextScale(0.5)
  end
end

local function recomputeLayout()
  local w, h = term.getSize()
  gridW = clamp(w, 10, 40)
  gridH = clamp(h - 4, 6, 30)
  gridYStart = 3
  footerY = gridYStart + gridH + 1
  if footerY > h then
    gridH = math.max(3, h - 4)
    footerY = gridYStart + gridH + 1
  end
end

local function writeLine(y, text, fg, bg)
  local w = select(1, term.getSize())
  local padded = text or ""
  if #padded > w then
    padded = padded:sub(1, w - 3) .. "..."
  end
  if #padded < w then
    padded = padded .. string.rep(" ", w - #padded)
  end
  term.setCursorPos(1, y)
  term.setTextColor(fg or colors.white)
  term.setBackgroundColor(bg or colors.black)
  term.write(padded)
end

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

-----------------------------
-- GAME STATE               --
-----------------------------

local player = { x = 1, y = 1 }
local daleks = {}
local heaps = {}
local message = "Evade the daleks and let them crash!"
local gameOver = false
local statusLine = ""
local lastBtn5Time = 0

local function seedRng()
  local seed = os.epoch and os.epoch("utc") or os.time()
  math.randomseed(seed)
  math.random(); math.random(); math.random()
end

local function key(x, y)
  return x .. "," .. y
end

local function resetGame()
  recomputeLayout()
  seedRng()
  player.x = math.floor(gridW / 2)
  player.y = math.floor(gridH / 2) + 1
  daleks = {}
  heaps = {}
  gameOver = false
  message = "Evade the daleks and let them crash!"
  statusLine = ""

  local dalekCount = clamp(math.floor((gridW * gridH) / 25), 6, 35)
  for i = 1, dalekCount do
    local dx, dy
    repeat
      dx = math.random(1, gridW)
      dy = math.random(1, gridH)
    until (dx ~= player.x or dy ~= player.y)
    table.insert(daleks, { x = dx, y = dy })
  end
end

-----------------------------
-- RENDERING                --
-----------------------------

local function drawHeader()
  writeLine(1, "DALEKS - Five-Button Survival")
  local alive = #daleks
  local heapCount = 0
  for _ in pairs(heaps) do heapCount = heapCount + 1 end
  local info = string.format("Daleks: %d  Heaps: %d  Grid: %dx%d", alive, heapCount, gridW, gridH)
  writeLine(2, info)
end

local function drawGrid()
  local w = select(1, term.getSize())
  for yy = 1, gridH do
    local line = {}
    for xx = 1, gridW do
      line[xx] = "."
    end

    for _, d in ipairs(daleks) do
      if d.x >= 1 and d.x <= gridW and d.y == yy then
        line[d.x] = "D"
      end
    end

    for k, _ in pairs(heaps) do
      local hx, hy = k:match("^(%-?%d+),(%-?%d+)$")
      hx, hy = tonumber(hx), tonumber(hy)
      if hy == yy and hx >= 1 and hx <= gridW then
        line[hx] = "#"
      end
    end

    if player.y == yy then
      line[player.x] = gameOver and "X" or "@"
    end

    local row = table.concat(line)
    if #row < w then
      row = row .. string.rep(" ", w - #row)
    elseif #row > w then
      row = row:sub(1, w)
    end

    writeLine(gridYStart + yy - 1, row)
  end
end

local function drawFooter()
  local legend = "BTN1 Left  BTN2 Right  BTN3 Up  BTN4 Down  BTN5 Teleport (double=Quit)"
  writeLine(footerY, legend, colors.white, colors.gray)
  writeLine(footerY - 1, message)
end

local function redraw()
  term.setBackgroundColor(colors.black)
  term.clear()
  drawHeader()
  drawGrid()
  drawFooter()
end

-----------------------------
-- GAME LOGIC               --
-----------------------------

local function randomEmptyCell()
  local attempts = gridW * gridH * 2
  for _ = 1, attempts do
    local x = math.random(1, gridW)
    local y = math.random(1, gridH)
    local cellKey = key(x, y)
    if not heaps[cellKey] then
      local occupied = false
      for _, d in ipairs(daleks) do
        if d.x == x and d.y == y then occupied = true break end
      end
      if not (player.x == x and player.y == y) and not occupied then
        return x, y
      end
    end
  end
  return nil
end

local function advanceDaleks()
  local newDaleks = {}
  local collisions = {}
  local updatedHeaps = {}
  local playerHit = false

  for k, v in pairs(heaps) do
    if v then updatedHeaps[k] = true end
  end

  for _, d in ipairs(daleks) do
    local nx = clamp(d.x + sign(player.x - d.x), 1, gridW)
    local ny = clamp(d.y + sign(player.y - d.y), 1, gridH)
    local destKey = key(nx, ny)

    if nx == player.x and ny == player.y then
      playerHit = true
    end

    if updatedHeaps[destKey] then
      updatedHeaps[destKey] = true
    else
      collisions[destKey] = (collisions[destKey] or 0) + 1
      table.insert(newDaleks, { x = nx, y = ny, destKey = destKey })
    end
  end

  daleks = {}

  for _, d in ipairs(newDaleks) do
    local count = collisions[d.destKey]
    if count and count > 1 then
      updatedHeaps[d.destKey] = true
      collisions[d.destKey] = nil
    else
      table.insert(daleks, { x = d.x, y = d.y })
    end
  end

  heaps = updatedHeaps

  if playerHit then
    gameOver = true
    message = "A dalek got you! BTN5 double-tap to quit or any move to restart."
    statusLine = ""
    return
  end

  if #daleks == 0 then
    gameOver = true
    message = "You win! BTN5 double-tap to quit or move to play again."
  else
    local heapCount = 0
    for _ in pairs(heaps) do heapCount = heapCount + 1 end
    statusLine = string.format("Daleks left: %d  Heaps: %d", #daleks, heapCount)
  end
end

local function movePlayer(dx, dy)
  if gameOver then
    resetGame()
    redraw()
    return
  end

  local nx = clamp(player.x + dx, 1, gridW)
  local ny = clamp(player.y + dy, 1, gridH)
  if heaps[key(nx, ny)] then
    message = "Rubble blocks that path."
    redraw()
    return
  end

  player.x, player.y = nx, ny
  advanceDaleks()
  redraw()
end

local function teleport()
  if gameOver then
    resetGame()
    redraw()
    return
  end
  local tx, ty = randomEmptyCell()
  if not tx then
    message = "Nowhere safe to teleport!"
  else
    player.x, player.y = tx, ty
    message = "Zapped to safety!"
    advanceDaleks()
  end
  redraw()
end

-----------------------------
-- MAIN LOOP                --
-----------------------------

local function handleButton(btn)
  if not btn then return end
  if btn == 1 then
    movePlayer(-1, 0)
  elseif btn == 2 then
    movePlayer(1, 0)
  elseif btn == 3 then
    movePlayer(0, -1)
  elseif btn == 4 then
    movePlayer(0, 1)
  elseif btn == 5 then
    local now = os.clock()
    if now - lastBtn5Time < 0.7 then
      term.setTextColor(colors.white)
      term.setBackgroundColor(colors.black)
      term.clear()
      term.setCursorPos(1,1)
      print("Exiting Daleks…")
      error("quit", 0)
    end
    lastBtn5Time = now
    teleport()
  end
end

local function main()
  adjustTextScale()
  resetGame()
  redraw()

  while true do
    local event, p1 = os.pullEvent()
    local btn = nil
    if event == "redstone" then
      btn = pollRedstone()
    elseif event == "key" then
      btn = keyToButton[p1]
    end
    handleButton(btn)
  end
end

main()
