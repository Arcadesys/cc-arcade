---@alias Direction "up"|"down"|"left"|"right"

-- Map keyboard chars to logical arcade actions.
local charToAction = {
  a = "up",
  s = "left",
  d = "down",
  f = "right",
  g = "do",
  q = "quit", -- optional keyboard quit; real hardware will reuse the DO flow.
}

-- Button layout mirrors the mapping used by menu.lua and button_debug.lua.
local buttonSides = { "left", "right", "top", "front", "bottom" }
local buttonToAction = { "up", "left", "down", "right", "do" }

local hasRedstone = type(redstone) == "table" and type(redstone.getInput) == "function"
local lastState = {}
for i, _ in ipairs(buttonSides) do
  lastState[i] = false
end

local function readRedstoneInput(side)
  if not hasRedstone then
    return false
  end
  local ok, result = pcall(redstone.getInput, side)
  return (ok and result) or false
end

local function pollRedstone()
  if not hasRedstone then
    return nil
  end
  for i, side in ipairs(buttonSides) do
    local newState = readRedstoneInput(side)
    if newState and not lastState[i] then
      lastState[i] = true
      return buttonToAction[i]
    end
    lastState[i] = newState
  end
  return nil
end

---Blocks until a supported input is received, then returns a symbolic action.
---Later, this can be swapped to listen for button events instead of chars.
---@return string action  -- one of: "up", "down", "left", "right", "do", "quit"
local function readAction()
  while true do
    local event, ch = os.pullEvent()
    if event == "char" then
      local action = charToAction[string.lower(ch)]
      if action then
        return action
      end
    elseif event == "terminate" then
      return "quit"
    elseif event == "redstone" then
      local action = pollRedstone()
      if action then
        return action
      end
    end
  end
end

return {
  readAction = readAction,
}
