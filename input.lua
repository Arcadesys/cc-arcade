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
    end
  end
end

return {
  readAction = readAction,
}
