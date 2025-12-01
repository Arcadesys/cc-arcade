-- settings.lua
-- System Settings for writing games to disks.

local apps = {
  {
    id = "blackjack",
    name = "Blackjack",
    command = "blackjack",
  },
  {
    id = "video_poker",
    name = "Video Poker",
    command = "video_poker",
  },
  {
    id = "dungeon_crawl",
    name = "Dungeon Crawl",
    command = "game",
  },
  {
    id = "daleks",
    name = "Daleks",
    command = "daleks",
  },
}

local selectedIndex = 1
local statusMessage = "Select a game to write to disk."

local function drawHeader()
  local w, h = term.getSize()
  term.setBackgroundColor(colors.gray)
  term.setTextColor(colors.white)
  term.setCursorPos(1, 1)
  term.clearLine()
  term.setCursorPos(2, 1)
  term.write("System Settings - Disk Writer")
end

local function drawList()
  local w, h = term.getSize()
  for i, app in ipairs(apps) do
    local y = 3 + i
    if y > h - 2 then break end
    
    if i == selectedIndex then
      term.setBackgroundColor(colors.blue)
      term.setTextColor(colors.white)
    else
      term.setBackgroundColor(colors.black)
      term.setTextColor(colors.white)
    end
    
    term.setCursorPos(2, y)
    term.clearLine()
    term.write(app.name)
  end
end

local function drawStatus()
  local w, h = term.getSize()
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.yellow)
  term.setCursorPos(2, h)
  term.clearLine()
  term.write(statusMessage)
end

local function writeToDisk(app)
  local drive = peripheral.find("drive")
  if not drive or not drive.isDiskPresent() then
    statusMessage = "No disk found. Insert a floppy."
    return
  end

  if drive.getMountPath then
    local path = drive.getMountPath()
    if not path then
      statusMessage = "Disk not mounted."
      return
    end

    statusMessage = "Writing " .. app.name .. "..."
    drawStatus()

    -- 1. Copy game file
    local gamePath = shell.resolveProgram(app.command)
    if not gamePath then
        statusMessage = "Error: Game file not found."
        return
    end
    
    local destGamePath = fs.combine(path, fs.getName(gamePath))
    -- Remove existing files on disk to ensure clean state?
    -- The prompt says "A floppy has one (and only one) game".
    -- I should probably clear the disk first.
    local list = fs.list(path)
    for _, file in ipairs(list) do
        fs.delete(fs.combine(path, file))
    end

    fs.copy(gamePath, destGamePath)
    
    -- 2. Create startup launcher
    local startupPath = fs.combine(path, "startup")
    local h = fs.open(startupPath, "w")
    if h then
        h.writeLine('shell.run("/' .. fs.getName(gamePath) .. '")')
        h.close()
        statusMessage = "Success! Wrote " .. app.name
    else
        statusMessage = "Error writing startup."
    end
  else
     statusMessage = "Drive does not support mounting."
  end
end

local function handleClick(x, y)
  local w, h = term.getSize()
  -- Check list clicks
  for i, app in ipairs(apps) do
    local itemY = 3 + i
    if y == itemY then
      selectedIndex = i
      return
    end
  end
  
  -- Check "Write" button (bottom right)
  if y == h - 2 and x >= w - 10 then
      writeToDisk(apps[selectedIndex])
  end
  
  -- Back button
  if y == 1 and x >= w - 3 then
      return "exit"
  end
end

local function drawInterface()
    term.setBackgroundColor(colors.black)
    term.clear()
    drawHeader()
    drawList()
    
    local w, h = term.getSize()
    -- Draw Write Button
    term.setBackgroundColor(colors.green)
    term.setTextColor(colors.black)
    term.setCursorPos(w - 8, h - 2)
    term.write(" WRITE ")
    
    -- Draw Exit Button
    term.setBackgroundColor(colors.red)
    term.setTextColor(colors.white)
    term.setCursorPos(w - 3, 1)
    term.write(" X ")
    
    drawStatus()
end

while true do
    drawInterface()
    local event, button, x, y = os.pullEvent("mouse_click")
    local action = handleClick(x, y)
    if action == "exit" then break end
end
