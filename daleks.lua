-- daleks.lua
-- Placeholder for Daleks arcade port with five-button controls.

-----------------------------
-- CONFIG: BUTTON MAPPING  --
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
-- DRAWING                 --
-----------------------------

local function drawFooter(active)
  local w, h = term.getSize()
  local labels = {"Move", "Wait", "Teleport", "???", "Quit"}
  local base = math.floor(w / 5)
  local x = 1

  for i = 1, 5 do
    local width = (i < 5) and base or (w - base * 4)
    local bg = colors.gray
    if active == i then
      bg = colors.lightBlue
    elseif i == 5 then
      bg = colors.blue
    end

    term.setBackgroundColor(bg)
    term.setTextColor(colors.black)
    for yy = h - 1, h do
      term.setCursorPos(x, yy)
      term.write(string.rep(" ", width))
    end

    local label = labels[i]
    local lx = x + math.floor((width - #label) / 2)
    term.setCursorPos(lx, h)
    term.write(label)

    x = x + width
  end

  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
end

local function drawScreen(message)
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1, 1)
  print("Daleks (work in progress)")
  print("Press buttons to test controls. BTN5 quits back to the menu.")
  print("")
  if message and message ~= "" then
    print(message)
  else
    print("No bots yet—this is a placeholder until the full game arrives.")
  end
  drawFooter(nil)
end

-----------------------------
-- INPUT                  --
-----------------------------

local function pollRedstone()
  local pressed = nil
  for i, btn in ipairs(buttons) do
    local newState = redstone.getInput(btn.side)
    if newState and not lastState[i] then
      pressed = i
    end
    lastState[i] = newState
  end
  return pressed
end

-----------------------------
-- MAIN LOOP              --
-----------------------------

local function main()
  drawScreen(nil)

  local lastMessage = nil

  while true do
    local event, p1 = os.pullEvent()
    local btn = nil

    if event == "redstone" then
      btn = pollRedstone()
    elseif event == "key" then
      btn = keyToButton[p1]
    end

    if btn then
      if btn == 5 then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.clear()
        term.setCursorPos(1, 1)
        print("Exiting Daleks placeholder.")
        return
      end

      local names = {
        "Step toward the closest Dalek.",
        "Wait one turn.",
        "Short-range teleport.",
        "Experimental gadget.",
      }
      lastMessage = names[btn] or lastMessage
      drawScreen(lastMessage)
      drawFooter(btn)
    end
  end
end

main()
