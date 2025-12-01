-- casino_menu.lua
-- Diamond Casino lobby.

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

local diskCredits = require("disk_credits")
local casinoConfig = {
  depositSide = "top",             -- Side with the chest that holds diamonds to bank
  diamondItem = "minecraft:diamond",
  creditsPerDiamond = 25,
  devModeFlag = "casino_dev.flag", -- Create this file to enable dev mode
}
local depositState = { lastCount = 0 }
local devMode = false
local HEADER_HEIGHT = 4 
local statusMessage = \" Insert a data disk or drop a dev flag to unlock "credits.\ 
 
