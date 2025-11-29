-- update.lua
-- Pulls the latest repo contents from GitHub and rewrites any files that
-- differ locally. New files are added; unchanged files are left alone.

local owner = "Arcadesys"
local repo = "cc-arcade"
local branch = ({ ... })[1] or "main" -- allow overriding branch as first arg
local userAgent = "cc-arcade-updater"

local function ensureHttp()
  if not http or not http.get then
    error("HTTP API is disabled. Enable it in Mod Options or server config.", 0)
  end
end

local function httpGet(url)
  local res, err = http.get(url, { ["User-Agent"] = userAgent })
  if not res then
    return nil, "HTTP request failed: " .. (err or "unknown error")
  end

  local code = res.getResponseCode and res.getResponseCode() or 200
  local body = res.readAll()
  res.close()

  if code >= 400 then
    return nil, "HTTP " .. code .. " for " .. url
  end

  return body
end

local function fetchJson(url)
  local body, err = httpGet(url)
  if not body then
    return nil, err
  end

  local ok, data = pcall(textutils.unserializeJSON, body)
  if not ok or not data then
    return nil, "Invalid JSON returned by GitHub"
  end
  return data
end

local function isSafePath(path)
  if path:sub(1, 1) == "/" then
    return false
  end

  for part in string.gmatch(path, "[^/]+") do
    if part == ".." then
      return false
    end
  end

  return true
end

local function encodeSegment(seg)
  -- Wrap gsub call to return only the first result (string.gsub returns str, count)
  return (seg:gsub("([^%w%-%._~])", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

local function buildRawUrl(path)
  local encoded = {}
  for segment in string.gmatch(path, "[^/]+") do
    table.insert(encoded, encodeSegment(segment))
  end
  local safePath = table.concat(encoded, "/")
  return string.format(
    "https://raw.githubusercontent.com/%s/%s/%s/%s",
    owner,
    repo,
    branch,
    safePath
  )
end

local function listRepoFiles()
  local treeUrl = string.format(
    "https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1",
    owner,
    repo,
    branch
  )

  local data, err = fetchJson(treeUrl)
  if not data then
    return nil, err
  end

  if not data.tree then
    return nil, "GitHub tree listing missing"
  end

  local files = {}
  for _, node in ipairs(data.tree) do
    if node.type == "blob" and node.path then
      table.insert(files, node.path)
    end
  end

  return files
end

local function readFile(path)
  if not fs.exists(path) or fs.isDir(path) then
    return nil
  end
  local handle = fs.open(path, "r")
  if not handle then
    return nil
  end
  local data = handle.readAll()
  handle.close()
  return data
end

local function writeFile(path, contents)
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then
    fs.makeDir(dir)
  end

  local handle = fs.open(path, "w")
  if not handle then
    return false, "Cannot open " .. path .. " for writing"
  end

  handle.write(contents)
  handle.close()
  return true
end

local function updateFile(path, idx, total)
  if not isSafePath(path) then
    print("! Skipping unsafe path: " .. path)
    return false
  end

  local url = buildRawUrl(path)
  local remote, err = httpGet(url)
  if not remote then
    print(string.format("! [%d/%d] %s (%s)", idx, total, path, err or "unknown error"))
    return false
  end

  local localContent = readFile(path)
  if localContent == remote then
    print(string.format("= [%d/%d] %s (unchanged)", idx, total, path))
    return true, "unchanged"
  end

  local ok, writeErr = writeFile(path, remote)
  if not ok then
    print(string.format("! [%d/%d] %s (%s)", idx, total, path, writeErr))
    return false
  end

  local action = localContent and "updated" or "added"
  print(string.format("* [%d/%d] %s (%s)", idx, total, path, action))
  return true, action
end

local function main()
  ensureHttp()
  print(string.format("cc-arcade updater (branch: %s)", branch))
  print("Listing repository files…")

  local files, err = listRepoFiles()
  if not files then
    error("Failed to list files: " .. (err or "unknown error"), 0)
  end

  print("Found " .. #files .. " files. Checking for changes…")
  local total = #files
  local okCount, addedCount, updatedCount, unchangedCount = 0, 0, 0, 0

  for i, path in ipairs(files) do
    local ok, action = updateFile(path, i, total)
    if ok then
      okCount = okCount + 1
      if action == "added" then
        addedCount = addedCount + 1
      elseif action == "updated" then
        updatedCount = updatedCount + 1
      else
        unchangedCount = unchangedCount + 1
      end
    end
  end

  local failed = total - okCount
  print(string.format(
    "Done. Added: %d, Updated: %d, Unchanged: %d, Failed: %d.",
    addedCount,
    updatedCount,
    unchangedCount,
    failed
  ))
end

main()
