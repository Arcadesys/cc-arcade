local Dungeon = {}

local function newGrid(width, height, fill)
  local grid = {}
  for y = 1, height do
    grid[y] = {}
    for x = 1, width do
      grid[y][x] = fill
    end
  end
  return grid
end

local function carveRoom(grid, x, y, w, h)
  for yy = y, y + h - 1 do
    for xx = x, x + w - 1 do
      grid[yy][xx] = "."
    end
  end
end

local function carveCorridor(grid, x1, y1, x2, y2)
  local minX, maxX = math.min(x1, x2), math.max(x1, x2)
  for x = minX, maxX do
    grid[y1][x] = "."
  end

  local minY, maxY = math.min(y1, y2), math.max(y1, y2)
  for y = minY, maxY do
    grid[y][x2] = "."
  end
end

local function clamp(n, lo, hi)
  if hi < lo then hi = lo end
  if n < lo then return lo end
  if n > hi then return hi end
  return n
end

local function randomOpenTile(grid, width, height, avoidKeys)
  local function key(x, y) return y .. ":" .. x end

  for _ = 1, 200 do
    local x = math.random(1, width)
    local y = math.random(1, height)
    if grid[y][x] ~= "#" and (not avoidKeys or not avoidKeys[key(x, y)]) then
      return { x = x, y = y }
    end
  end

  for y = 1, height do
    for x = 1, width do
      if grid[y][x] ~= "#" and (not avoidKeys or not avoidKeys[key(x, y)]) then
        return { x = x, y = y }
      end
    end
  end

  return { x = math.floor(width / 2), y = math.floor(height / 2) }
end

local function generateFloor(width, height, opts)
  opts = opts or {}
  local grid = newGrid(width, height, "#")
  local rooms = {}
  local margin = 2

  local minRoomW = 4
  local minRoomH = 3
  local maxRoomW = clamp(math.floor(width / 3), minRoomW, math.min(12, math.max(minRoomW, width - 2 * margin)))
  local maxRoomH = clamp(math.floor(height / 3), minRoomH, math.min(8, math.max(minRoomH, height - 2 * margin)))

  local area = width * height
  local roomCount = clamp(math.floor(area / 120), 4, 10)

  for _ = 1, roomCount do
    local rw = math.random(minRoomW, maxRoomW)
    local rh = math.random(minRoomH, maxRoomH)
    local rx = math.random(margin, math.max(margin, width - rw - margin))
    local ry = math.random(margin, math.max(margin, height - rh - margin))
    carveRoom(grid, rx, ry, rw, rh)
    table.insert(rooms, { x = rx, y = ry, w = rw, h = rh })
  end

  if #rooms == 0 then
    local cx = math.floor(width / 2)
    local cy = math.floor(height / 2)
    carveRoom(grid, clamp(cx - 2, 2, width - 3), clamp(cy - 1, 2, height - 2), 5, 3)
  end

  for i = 2, #rooms do
    local r1 = rooms[i - 1]
    local r2 = rooms[i]
    local cx1 = math.floor(r1.x + r1.w / 2)
    local cy1 = math.floor(r1.y + r1.h / 2)
    local cx2 = math.floor(r2.x + r2.w / 2)
    local cy2 = math.floor(r2.y + r2.h / 2)
    carveCorridor(grid, cx1, cy1, cx2, cy2)
  end

  for _ = 1, math.floor(roomCount / 2) do
    local a = rooms[math.random(1, #rooms)]
    local b = rooms[math.random(1, #rooms)]
    if a and b and a ~= b then
      local ax = math.floor(a.x + a.w / 2)
      local ay = math.floor(a.y + a.h / 2)
      local bx = math.floor(b.x + b.w / 2)
      local by = math.floor(b.y + b.h / 2)
      carveCorridor(grid, ax, ay, bx, by)
    end
  end

  local avoid = {}
  local spawn
  if rooms[1] then
    spawn = {
      x = math.floor(rooms[1].x + rooms[1].w / 2),
      y = math.floor(rooms[1].y + rooms[1].h / 2),
    }
  else
    spawn = randomOpenTile(grid, width, height)
  end
  avoid[spawn.y .. ":" .. spawn.x] = true

  local upPos, downPos, goalPos
  if opts.placeUp then
    upPos = randomOpenTile(grid, width, height, avoid)
    avoid[upPos.y .. ":" .. upPos.x] = true
    grid[upPos.y][upPos.x] = "<"
  end
  if opts.placeDown then
    downPos = randomOpenTile(grid, width, height, avoid)
    avoid[downPos.y .. ":" .. downPos.x] = true
    grid[downPos.y][downPos.x] = ">"
  end
  if opts.placeGoal then
    goalPos = randomOpenTile(grid, width, height, avoid)
    avoid[goalPos.y .. ":" .. goalPos.x] = true
    grid[goalPos.y][goalPos.x] = "X"
  end

  return {
    width = width,
    height = height,
    grid = grid,
    spawn = spawn,
    up = upPos,
    down = downPos,
    goal = goalPos,
  }
end

---Creates a full three-floor dungeon layout.
---@return table dungeonState { floors = {...}, startFloor = 1, startPos = {x,y} }
function Dungeon.create(width, height)
  local floors = {}
  floors[1] = generateFloor(width, height, { placeDown = true })
  floors[2] = generateFloor(width, height, { placeUp = true, placeDown = true })
  floors[3] = generateFloor(width, height, { placeUp = true, placeGoal = true })

  return {
    floors = floors,
    startFloor = 1,
    startPos = floors[1].spawn,
  }
end

function Dungeon.getTile(floor, x, y)
  if not floor or not floor.grid then return nil end
  local row = floor.grid[y]
  return row and row[x] or nil
end

function Dungeon.isWalkable(tile)
  return tile and tile ~= "#"
end

return Dungeon
