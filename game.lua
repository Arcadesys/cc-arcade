-- game.lua
-- Terminal prototype: three-floor dungeon crawl tuned for ASDFG controls.

local function loadModule(name)
  local ok, mod = pcall(require, name)
  if ok and mod then return mod end
  local path = name .. ".lua"
  local chunk, err = loadfile(path)
  if not chunk then error(err) end
  return chunk()
end

local input = loadModule("input")
local dungeon = loadModule("dungeon")

local seed = (os.epoch and os.epoch("utc")) or os.time()
math.randomseed(seed)
math.random(); math.random() -- warm up

local termWidth, termHeight = term.getSize()
local mapWidth = termWidth
local mapHeight = math.max(1, termHeight - 2) -- leave two lines for status

local state = dungeon.create(mapWidth, mapHeight)
local currentFloor = state.startFloor or 1
local player = {
  x = (state.startPos and state.startPos.x) or math.floor(mapWidth / 2),
  y = (state.startPos and state.startPos.y) or math.floor(mapHeight / 2),
}

local statusMessage = "Reach the goal (X) on floor 3. DO uses stairs."
local pendingQuit = false

local function currentFloorData()
  return state.floors[currentFloor]
end

local function ellipsize(text, width)
  if width <= 3 then
    return text:sub(1, width)
  end
  if #text > width then
    return text:sub(1, width - 3) .. "..."
  end
  return text
end

local function writeLine(y, text, width)
  term.setCursorPos(1, y)
  local line = ellipsize(text or "", width)
  term.write(line)
  local remaining = width - #line
  if remaining > 0 then
    term.write(string.rep(" ", remaining))
  end
end

local function describeTile(tile)
  if tile == ">" then
    return "Stairs down: DO to descend."
  elseif tile == "<" then
    return "Stairs up: DO to ascend."
  elseif tile == "X" then
    return "Goal: DO to win."
  else
    return "Explore and find the goal on floor 3."
  end
end

local function updateStatusFromTile()
  local floor = currentFloorData()
  local tile = dungeon.getTile(floor, player.x, player.y)
  statusMessage = describeTile(tile)
end

local function render()
  local floor = currentFloorData()
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()

  for y = 1, floor.height do
    local row = floor.grid[y]
    local chars = {}
    for x = 1, floor.width do
      if x == player.x and y == player.y then
        chars[x] = "@"
      else
        chars[x] = row[x]
      end
    end
    term.setCursorPos(1, y)
    term.write(table.concat(chars))
  end

  local controls = string.format(
    "Floor %d/3 | a/s/d/f move | g=DO (double=quit) | q=quit",
    currentFloor
  )
  if pendingQuit then
    controls = "Confirm quit: press DO again or move to cancel."
  end
  writeLine(floor.height + 1, controls, floor.width)
  writeLine(floor.height + 2, statusMessage or "", floor.width)
end

local function exitWithMessage(msg)
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1, 1)
  print(msg)
end

local function moveToFloor(newFloor, destPos)
  currentFloor = newFloor
  local floor = currentFloorData()
  local target = destPos or floor.spawn or { x = math.floor(floor.width / 2), y = math.floor(floor.height / 2) }
  player.x, player.y = target.x, target.y
  pendingQuit = false
  statusMessage = string.format("Arrived on floor %d. %s", currentFloor, describeTile(dungeon.getTile(floor, player.x, player.y)))
end

local function tryMove(dx, dy)
  local floor = currentFloorData()
  local nx, ny = player.x + dx, player.y + dy
  local tile = dungeon.getTile(floor, nx, ny)
  if dungeon.isWalkable(tile) then
    player.x, player.y = nx, ny
    pendingQuit = false
    updateStatusFromTile()
  else
    pendingQuit = false
    statusMessage = "You bump into a wall."
  end
end

local function handleDo()
  local floor = currentFloorData()
  local tile = dungeon.getTile(floor, player.x, player.y)

  if tile == ">" and currentFloor < #state.floors then
    local targetFloor = currentFloor + 1
    local dest = state.floors[targetFloor].up or state.floors[targetFloor].spawn
    moveToFloor(targetFloor, dest)
    return
  elseif tile == "<" and currentFloor > 1 then
    local targetFloor = currentFloor - 1
    local dest = state.floors[targetFloor].down or state.floors[targetFloor].spawn
    moveToFloor(targetFloor, dest)
    return
  elseif tile == "X" then
    exitWithMessage("You found the goal on floor 3! Victory.")
    return "win"
  end

  if pendingQuit then
    exitWithMessage("You leave the dungeon.")
    return "quit"
  else
    pendingQuit = true
    statusMessage = "Press DO again to quit. Move to cancel."
  end
end

local function gameLoop()
  updateStatusFromTile()
  while true do
    render()
    local action = input.readAction()

    if action == "quit" then
      exitWithMessage("Exiting dungeon crawl.")
      return
    elseif action == "up" then
      tryMove(0, -1)
    elseif action == "down" then
      tryMove(0, 1)
    elseif action == "left" then
      tryMove(-1, 0)
    elseif action == "right" then
      tryMove(1, 0)
    elseif action == "do" then
      local result = handleDo()
      if result == "win" or result == "quit" then return end
    end
  end
end

gameLoop()
