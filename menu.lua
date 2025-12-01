-- menu.lua
-- Simple five-button launcher that lists installed arcade apps.

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
-- APP LIST                 --
-----------------------------

local apps = {
  {
    id = "blackjack",
    name = "Blackjack",
    description = "Five-button blackjack table.",
    command = "blackjack",
  },
  {
    id = "video_poker",
    name = "Video Poker",
    description = "Jacks or Better draw poker with holds.",
    command = "video_poker",
  },
  {
    id = "dungeon_crawl",
    name = "Dungeon Crawl",
    description = "Three-floor ASDFG dungeon prototype.",
    command = "game",
  },
  {
    id = "daleks",
    name = "Daleks",
    description = "Grid chase with teleport + dalek collisions.",
    command = "daleks",
  },
  {
    id = "button_debug",
    name = "Button Debug",
    description = "Light up each button to test wiring/links.",
    command = "button_debug",
  },
  {
    id = "quiz_show",
    name = "Quiz Show",
    description = "Host-led buzzer quiz with JSON questions.",
    command = "quiz_show",
  },
}

local availableApps = {}
local missingCount = 0
local selectedIndex = 1
local statusMessage = "Select a game and press Launch."

-----------------------------
-- HELPERS                  --
-----------------------------

local function clamp(n, lo, hi) return math.max(lo, math.min(hi, n)) end

local function centerText(y, text, fg, bg)
  local w = select(1, term.getSize())
  local x = math.floor((w - #text) / 2) + 1
  term.setBackgroundColor(bg or colors.black)
  term.setTextColor(fg or colors.white)
  term.setCursorPos(x, y)
  term.write(text)
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

local function resolveProgram(cmd)
  if shell and shell.resolveProgram then
    local resolved = shell.resolveProgram(cmd)
    if resolved then return resolved end
  end
  if fs.exists(cmd) then return cmd end
  if fs.exists(cmd .. ".lua") then return cmd .. ".lua" end
  return nil
end

local function rebuildAppList()
  availableApps = {}
  missingCount = 0

  for _, app in ipairs(apps) do
    local path = resolveProgram(app.command)
    if path then
      table.insert(availableApps, {
        id = app.id,
        name = app.name,
        description = app.description,
        command = app.command,
        path = path,
      })
    else
      missingCount = missingCount + 1
    end
  end

  if #availableApps == 0 then
    selectedIndex = 0
    statusMessage = "No playable apps found. Refresh after installing."
  else
    selectedIndex = clamp(selectedIndex, 1, #availableApps)
    if missingCount > 0 then
      statusMessage = string.format("Select a game (%d missing installs).", missingCount)
    else
      statusMessage = "Select a game and press Launch."
    end
  end
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

-----------------------------
-- DRAWING                  --
-----------------------------

local function drawHeader()
  local w = select(1, term.getSize())
  local status = statusMessage or ""
  local maxStatus = math.max(5, w - 4)
  if #status > maxStatus then
    status = status:sub(1, maxStatus - 3) .. "..."
  end

  fillRect(1, 1, w, 3, colors.blue, " ")
  term.setBackgroundColor(colors.blue)
  term.setTextColor(colors.white)
  term.setCursorPos(2, 2)
  term.write("Arcade Menu")
  term.setCursorPos(2, 3)
  term.write(status)
end

local function drawList()
  local w, h = term.getSize()
  local listTop = 5
  local maxVisible = math.floor((h - listTop - 2) / 2)
  if maxVisible < 1 then maxVisible = 1 end

  if #availableApps == 0 then
    centerText(listTop, "No installed games found.", colors.red, colors.black)
    return
  end

  local total = #availableApps
  local startIndex = 1
  if total > maxVisible then
    startIndex = clamp(selectedIndex - math.floor(maxVisible / 2), 1, total - maxVisible + 1)
  end

  local y = listTop
  for offset = 0, maxVisible - 1 do
    local idx = startIndex + offset
    if idx > total then break end
    local app = availableApps[idx]
    local selected = idx == selectedIndex
    local bg = selected and colors.lightBlue or colors.gray
    local fg = selected and colors.black or colors.white
    local descColor = selected and colors.black or colors.lightGray

    fillRect(1, y, w, 2, bg, " ")
    term.setBackgroundColor(bg)
    term.setTextColor(fg)
    term.setCursorPos(3, y)
    local name = app.name or "?"
    if #name > w - 6 then
      name = name:sub(1, w - 9) .. "..."
    end
    term.write(name)

    term.setTextColor(descColor)
    term.setCursorPos(3, y + 1)
    local desc = app.description or ""
    local maxDesc = math.max(10, w - 6)
    if #desc > maxDesc then
      desc = desc:sub(1, maxDesc - 3) .. "..."
    end
    term.write(desc)

    y = y + 2
  end

  if total > maxVisible then
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.lightGray)
    term.setCursorPos(w - 6, h - 2)
    term.write(string.format("%d/%d", selectedIndex, total))
  end
end

local function drawButtonBar(activeIndex)
  local segs = getSegments()
  local hasApps = #availableApps > 0
  local actions = {
    { label = "Prev", enabled = hasApps and #availableApps > 1 },
    { label = "Next", enabled = hasApps and #availableApps > 1 },
    { label = "Launch", enabled = hasApps },
    { label = "Refresh", enabled = true },
    { label = "Exit", enabled = true },
  }

  for i = 1, 5 do
    local seg = segs[i]
    local act = actions[i]
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

local function render(activeButton)
  term.setBackgroundColor(colors.black)
  term.clear()
  drawHeader()
  drawList()
  drawButtonBar(activeButton)
end

-----------------------------
-- ACTIONS                  --
-----------------------------

local function moveSelection(delta)
  if #availableApps == 0 then return end
  local newIndex = ((selectedIndex - 1 + delta) % #availableApps) + 1
  selectedIndex = newIndex
  statusMessage = "Selected: " .. availableApps[selectedIndex].name
end

local function launchSelected()
  local app = availableApps[selectedIndex]
  if not app then
    statusMessage = "No app to launch."
    return
  end

  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1, 1)
  print("Launching " .. app.name .. "…")

  local ok, err = pcall(function()
    if shell and shell.run then
      shell.run(app.command)
    else
      os.run({}, app.command)
    end
  end)

  if not ok then
    statusMessage = "Failed: " .. tostring(err)
  else
    statusMessage = "Exited " .. app.name .. "."
  end
end

local function handleButton(btn)
  if btn == 1 then
    moveSelection(-1)
  elseif btn == 2 then
    moveSelection(1)
  elseif btn == 3 then
    launchSelected()
  elseif btn == 4 then
    rebuildAppList()
    if #availableApps > 0 then
      statusMessage = "App list refreshed."
    end
  elseif btn == 5 then
    return "exit"
  end
end

-----------------------------
-- MAIN LOOP                --
-----------------------------

local function main()
  rebuildAppList()
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
      if action == "exit" then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.clear()
        term.setCursorPos(1, 1)
        print("Exiting arcade menu.")
        return
      end
      render(pressed)
    end
  end
end

main()
