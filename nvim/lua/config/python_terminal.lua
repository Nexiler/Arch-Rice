local M = {}

local function shell_name()
  return vim.fn.fnamemodify(vim.o.shell, ":t")
end

local function quoted(path)
  return vim.fn.shellescape(path)
end

local function activation_script(venv_path)
  if not venv_path or venv_path == "" then
    return nil
  end

  local shell = shell_name()
  if shell == "fish" then
    local script = venv_path .. "/bin/activate.fish"
    if vim.fn.filereadable(script) == 1 then
      return "source " .. quoted(script)
    end
    return nil
  end

  local script = venv_path .. "/bin/activate"
  if vim.fn.filereadable(script) == 1 then
    return "source " .. quoted(script)
  end

  return nil
end

function M.active_venv()
  local ok, venv_selector = pcall(require, "venv-selector")
  if ok then
    local venv = venv_selector.venv()
    if venv and venv ~= "" then
      return venv
    end
  end

  return vim.env.VIRTUAL_ENV
end

function M.activate_buffer(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  if vim.bo[bufnr].buftype ~= "terminal" then
    return false
  end

  local venv = M.active_venv()
  local command = activation_script(venv)
  if not command then
    return false
  end

  local chan = vim.bo[bufnr].channel
  if not chan or chan <= 0 then
    return false
  end

  vim.api.nvim_chan_send(chan, command .. "\n")
  return true
end

function M.activate_all()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "terminal" then
      M.activate_buffer(bufnr)
    end
  end
end

return M