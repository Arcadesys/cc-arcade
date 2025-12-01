from pathlib import Path
path = Path("menu.lua")
text = path.read_text()
marker = "local lastState = {}\r\nfor i, btn in ipairs(buttons) do\r\n  lastState[i] = redstone.getInput(btn.side)\r\nend\r\n\r\n-----------------------------\r\n-- APP LIST                 --\r\n" 
if marker not in text:
    raise SystemExit("marker not found")
insert = 'local diskCredits = require("disk_credits")\r\nlocal casinoConfig = {\r\n  depositSide = "top",             -- Side with the chest that holds diamonds to bank\r\n  diamondItem = "minecraft:diamond",\r\n  creditsPerDiamond = 25,\r\n  devModeFlag = "casino_dev.flag", -- Create this file to enable dev mode\r\n}\r\nlocal depositState = { lastCount = 0 }\r\nlocal devMode = false\r\n\r\n' 
