-- startup.lua
-- Launches the Arcade Menu OS

term.clear()
term.setCursorPos(1, 1)
print("Booting ArcadeOS...")
sleep(0.5)

if fs.exists("menu.lua") then
    shell.run("menu.lua")
else
    print("Error: menu.lua not found!")
end
