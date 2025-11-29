-- install.lua
-- Simple network installer for CraftOS/CC:Tweaked that pulls every file in the
-- GitHub repository (Arcadesys/cc-arcade) onto the computer. Re-run any time
-- to refresh to the latest main branch.

local owner = "Arcadesys"
local repo = "cc-arcade"
local branch = ({ ... })[1] or "main" -- allow overriding branch as first arg
local userAgent = "cc-arcade-installer"

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
  return seg:gsub("([^%w%-%._~])", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
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

local function downloadFile(path, idx, total)
  if not isSafePath(path) then
    print("! Skipping unsafe path: " .. path)
    return false
  end

  local url = buildRawUrl(path)
  local body, err = httpGet(url)
  if not body then
    print(string.format("! [%d/%d] %s (%s)", idx, total, path, err or "unknown error"))
    return false
  end

  local ok, writeErr = writeFile(path, body)
  if not ok then
    print(string.format("! [%d/%d] %s (%s)", idx, total, path, writeErr))
    return false
  end

  print(string.format("[%d/%d] %s", idx, total, path))
  return true
end

local function main()
  ensureHttp()
  print(string.format("cc-arcade installer (branch: %s)", branch))
  print("Listing repository files…")

  local files, err = listRepoFiles()
  if not files then
    error("Failed to list files: " .. (err or "unknown error"), 0)
  end

  print("Found " .. #files .. " files. Downloading…")
  local okCount = 0

  for i, path in ipairs(files) do
    if downloadFile(path, i, #files) then
      okCount = okCount + 1
    end
  end

  print(string.format("Done. %d/%d files written.", okCount, #files))
  print("Run the programs (e.g., `blackjack`) to start playing.")
end

main()
