return {
  {
    "linux-cultist/venv-selector.nvim",
    cmd = { "VenvSelect", "VenvSelectCached" },
    ft = { "python" },
    dependencies = {
      "neovim/nvim-lspconfig",
      "nvim-telescope/telescope.nvim",
      "nvim-lua/plenary.nvim",
    },
    opts = {
      options = {
        picker = "telescope",
        fd_binary_name = "fd",
        search_timeout = 3,
        enable_default_searches = true,
        enable_cached_venvs = true,
        cached_venv_automatic_activation = true,
        require_lsp_activation = true,
        notify_user_on_venv_activation = true,
        log_level = "NONE",
        on_telescope_result_callback = function(path)
          return path:gsub(vim.env.HOME or "", "~"):gsub("/bin/python$", "")
        end,
        on_venv_activate_callback = function()
          local ok, dap_python = pcall(require, "dap-python")
          local ok_vs, venv_selector = pcall(require, "venv-selector")
          local ok_lsp, python_lsp = pcall(require, "config.python_lsp")
          local ok_term, python_terminal = pcall(require, "config.python_terminal")

          if ok and ok_vs then
            local python = venv_selector.python()
            if python and python ~= "" then
              dap_python.setup(python)
              if ok_lsp then
                vim.schedule(function()
                  python_lsp.sync_all(python)
                end)
              end
              if ok_term then
                vim.schedule(function()
                  python_terminal.activate_all()
                end)
              end
            end
          end
        end,
      },
      search = {
        project_local = {
          command = "$FD '(^|/)(\\.venv|venv|\\.env)/bin/python$' '$CWD' --full-path --color never -HI -a -L -E /proc -E .git/ -E site-packages/ -E node_modules/",
        },
        cwd = {
          command = "$FD '/bin/python$' '$CWD' --full-path --color never -HI -a -L -E /proc -E .git/ -E site-packages/ -E node_modules/",
        },
        workspace = {
          command = "$FD '/bin/python$' '$WORKSPACE_PATH' --full-path --color never -HI -a -L -E /proc -E .git/ -E site-packages/ -E node_modules/",
        },
        file = {
          command = "$FD '/bin/python$' '$FILE_DIR' --full-path --color never -HI -a -L -E /proc -E .git/ -E site-packages/ -E node_modules/",
        },
        pipenv_project = {
          command = "if [ -f '$CWD/Pipfile' ] && command -v pipenv >/dev/null 2>&1; then cd '$CWD' && pipenv --venv 2>/dev/null | sed 's#$#/bin/python#'; fi",
        },
        workspace_pipenv = {
          command = "if [ -n '$WORKSPACE_PATH' ] && [ -f '$WORKSPACE_PATH/Pipfile' ] && command -v pipenv >/dev/null 2>&1; then cd '$WORKSPACE_PATH' && pipenv --venv 2>/dev/null | sed 's#$#/bin/python#'; fi",
        },
        pipenv_home = {
          command = "$FD '/bin/python$' ~/.local/share/virtualenvs --no-ignore-vcs --full-path --color never",
        },
        pyenv_home = {
          command = "$FD '/bin/python$' ~/.pyenv/versions --no-ignore-vcs --full-path --color never -E pkgs/ -E envs/ -L",
        },
        uv_project = {
          command = "if [ -x '$CWD/.venv/bin/python' ] && { [ -f '$CWD/uv.lock' ] || [ -f '$CWD/pyproject.toml' ]; }; then printf '%s\n' '$CWD/.venv/bin/python'; fi",
        },
      },
    },
    keys = {
      { "<leader>cv", "<cmd>VenvSelect<cr>", desc = "Select Python venv" },
      { "<leader>cV", "<cmd>VenvSelectCached<cr>", desc = "Select cached venv" },
      { "<leader>cL", "<cmd>VenvSelectLog<cr>", desc = "Venv selector log" },
    },
  },
  {
    "mfussenegger/nvim-dap-python",
    ft = "python",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      local ok, venv_selector = pcall(require, "venv-selector")
      local ok_lsp, python_lsp = pcall(require, "config.python_lsp")
      local python = ok and venv_selector.python() or nil
      if not python or python == "" then
        python = ok_lsp and python_lsp.current_python() or vim.fn.exepath("python3")
      end
      require("dap-python").setup(python)
    end,
  },
  {
    "leoluz/nvim-dap-go",
    ft = "go",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      require("dap-go").setup()
    end,
  },
}
