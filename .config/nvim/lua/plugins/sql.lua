-- vim-dadbod / DBUI (from the lang.sql extra): wire the repo's Postgres
-- connections without hardcoding secrets. The URLs are read from the
-- project's `.env` (DATABASE_URL / APP_DATABASE_URL) at startup.
--
-- If the value is missing, the connection is simply not registered.

---@param envfile string
---@param key string
local function env_get(envfile, key)
  local f = io.open(envfile, "r")
  if not f then
    return nil
  end
  for line in f:lines() do
    -- strip a leading `export ` (Lua `or` truncates multiple returns, so
    -- only one `match` per line and no `or` chaining)
    line = line:gsub("^%s*export%s+", "")
    local k, v = line:match("^([%w_]+)%s*=%s*(.-)%s*$")
    if k == key and v ~= "" then
      f:close()
      return v:gsub('^"', ""):gsub('"$', ""):gsub("^'", ""):gsub("'$", "")
    end
  end
  f:close()
end

local function setup_project_dbs()
  if vim.g.dbs then
    return
  end
  local envfile =
    vim.fs.find({ ".env" }, { path = vim.fn.getcwd(), upward = true })[1]
  if not envfile then
    return
  end
  local dbs = {}
  local owner = env_get(envfile, "DATABASE_URL")
  if owner then
    dbs["listacai (owner)"] = owner
  end
  local app = env_get(envfile, "APP_DATABASE_URL")
  if app then
    dbs["listacai (app)"] = app
  end
  if next(dbs) then
    vim.g.dbs = dbs
  end
end

setup_project_dbs()

return {}