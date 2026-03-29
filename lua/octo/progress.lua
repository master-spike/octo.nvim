local config = require "octo.config"
local vim = vim

local M = {}

local client_id = nil
local token_counter = 0

---@private
local function ensure_client()
  if client_id and vim.lsp.get_client_by_id(client_id) then
    return client_id
  end

  client_id = vim.lsp.start_client({
    name = "octo",
    cmd = function(dispatchers)
      vim.schedule(function()
        dispatchers.on_init({ capabilities = {} })
      end)
      return {
        request = function(_, _, _) end,
        notify = function(_, _) end,
        write = function() end,
        is_closing = function() return false end,
        terminate = function() end,
      }
    end,
    root_dir = vim.fn.getcwd(),
    capabilities = {},
  })

  return client_id
end

---@private
---@param token string
---@param value table
local function send_progress(token, value)
  local handler = vim.lsp.handlers["$/progress"]
  if not handler then
    return
  end
  pcall(handler, nil, { token = token, value = value }, { client_id = client_id })
end

--- Begin a progress notification.
--- Returns a token (or nil if disabled) that must be passed to report/finish.
---@param title string e.g. "Loading issue #42"
---@param message? string optional sub-message
---@return string|nil token
function M.begin(title, message)
  local progress = config.values.progress
  if progress and progress.enabled == false then
    return nil
  end

  ensure_client()
  if not client_id then
    return nil
  end

  token_counter = token_counter + 1
  local token = "octo-progress-" .. token_counter

  send_progress(token, {
    kind = "begin",
    title = title,
    message = message,
  })

  return token
end

--- Update an in-progress notification.
---@param token string|nil
---@param message? string
---@param percentage? number 0-100
function M.report(token, message, percentage)
  if not token then
    return
  end

  send_progress(token, {
    kind = "report",
    message = message,
    percentage = percentage,
  })
end

--- Finish a progress notification.
---@param token string|nil
---@param message? string e.g. "Done"
function M.finish(token, message)
  if not token then
    return
  end

  send_progress(token, {
    kind = "end",
    message = message,
  })
end

return M
