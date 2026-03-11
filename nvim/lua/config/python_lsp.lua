local M = {}

local pyright_names = {
  pyright = true,
  basedpyright = true,
}

function M.current_python()
  local ok, venv_selector = pcall(require, "venv-selector")
  if ok then
    local python = venv_selector.python()
    if python and python ~= "" then
      return python
    end
  end

  local venv = vim.env.VIRTUAL_ENV
  if venv and venv ~= "" then
    local python = venv .. "/bin/python"
    if vim.fn.executable(python) == 1 then
      return python
    end
  end

  local python3 = vim.fn.exepath("python3")
  if python3 ~= "" then
    return python3
  end

  local python = vim.fn.exepath("python")
  if python ~= "" then
    return python
  end

  return "python3"
end

function M.sync_client(client, python)
  if not client or not pyright_names[client.name] then
    return
  end

  local interpreter = python or M.current_python()
  client.config.settings = client.config.settings or {}
  client.config.settings.python = vim.tbl_deep_extend("force", client.config.settings.python or {}, {
    pythonPath = interpreter,
  })

  client.notify("workspace/didChangeConfiguration", {
    settings = client.config.settings,
  })
end

function M.sync_all(python)
  local interpreter = python or M.current_python()
  for _, client in ipairs(vim.lsp.get_clients()) do
    if pyright_names[client.name] then
      M.sync_client(client, interpreter)
    end
  end
  return interpreter
end

return M