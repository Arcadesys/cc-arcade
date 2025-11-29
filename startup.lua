-- startup.lua
-- Boot entrypoint that launches the arcade menu.

local function main()
  local ok, err = pcall(function()
    if shell and shell.run then
      shell.run("menu")
    else
      dofile("menu.lua")
    end
  end)

  if not ok then
    print("Arcade menu failed to start:")
    print(tostring(err))
    print("Dropping to shell.")
  end
end

main()
