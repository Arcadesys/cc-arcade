-- 5-button debug harness with Create redstone links + ASDFG keyboard fallback
-- Each button lights up its 1/5 of the bottom two lines when pressed.

-----------------------------
-- CONFIG: BUTTON MAPPING  --
-----------------------------

-- Logical buttons 1–5 mapped to computer sides + labels
local buttons = {
  [1] = { side = "left",   label = "BTN1" },
  [2] = { side = "right",  label = "BTN2" },
  [3] = { side = "top",    label = "BTN3" },
  [4] = { side = "front",  label = "BTN4" },
  [5] = { side = "bottom", label = "BTN5" },
}

-- Keyboard fallback: A S D F G -> 1 2 3 4 5
local keyToButton = {
  [keys.a] = 1,
  [keys.s] = 2,
  [keys.d] = 3,
  [keys.f] = 4,
  [keys.g] = 5,
}

-- Track last redstone state for rising-edge detection
local lastState = {}
for i, btn in ipairs(buttons) do
  lastState[i] = redstone.getInput(btn.side)
end

-----------------------------
-- SCREEN LAYOUT           --
-----------------------------

local function getSegments()
  local w, h = term.getSize()
  local segs = {}
  local base = math.floor(w / 5)
  local x = 1
  for i = 1, 5 do
    local width = (i < 5) and base or (w - base * 4)
    segs[i] = { x1 = x, x2 = x + width - 1 }
    x = x + width
  end
  return segs, h - 1, h  -- y1, y2 (bottom two lines)
end

-----------------------------
-- DRAWING                 --
-----------------------------

local function drawButtons(activeIndex)
  local segs, y1, y2 = getSegments()

  -- Base: dark background, grey labels
  for i = 1, 5 do
    local seg = segs[i]
    local label = buttons[i].label

    -- Choose background: highlighted if active, black otherwise
    if i == activeIndex then
      term.setBackgroundColor(colors.lightBlue)
      term.setTextColor(colors.black)
    else
      term.setBackgroundColor(colors.black)
      term.setTextColor(colors.gray)
    end

    -- Line y1
    term.setCursorPos(seg.x1, y1)
    term.write(string.rep(" ", seg.x2 - seg.x1 + 1))

    -- Centered label on line y2
    term.setCursorPos(seg.x1, y2)
    term.write(string.rep(" ", seg.x2 - seg.x1 + 1))

    local width = seg.x2 - seg.x1 + 1
    local labelX = seg.x1 + math.floor((width - #label) / 2)
    term.setCursorPos(labelX, y2)
    term.write(label)
  end

  -- Reset colors for rest of screen
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
end

local function drawHeader()
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1, 1)
  print("Five-Button Debug Harness")
  print("Press gold buttons (links on left/right/top/front/bottom)")
  print("…or use keyboard A S D F G as buttons 1–5.")
end

-----------------------------
-- INPUT HANDLING          --
-----------------------------

local function pollRedstone()
  local pressedIndex = nil
  for i, btn in ipairs(buttons) do
    local newState = redstone.getInput(btn.side)
    if newState and not lastState[i] then
      -- Rising edge -> press
      pressedIndex = i
    end
    lastState[i] = newState
  end
  return pressedIndex
end

-----------------------------
-- MAIN LOOP               --
-----------------------------

local function main()
  drawHeader()
  drawButtons(nil)

  local activeIndex = nil

  while true do
    local event, p1 = os.pullEvent()

    if event == "redstone" then
      local idx = pollRedstone()
      if idx then
        activeIndex = idx
        drawButtons(activeIndex)
      end

    elseif event == "key" then
      local btnIndex = keyToButton[p1]
      if btnIndex then
        activeIndex = btnIndex
        drawButtons(activeIndex)
      end
    end
  end
end

main()
