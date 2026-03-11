return {
  -- Configure LSP
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        clangd = false,
        rust_analyzer = false,
        pyright = {
          disableOrganizeImports = true,
          before_init = function(_, config)
            local python = require("config.python_lsp").current_python()
            config.settings = config.settings or {}
            config.settings.python = vim.tbl_deep_extend("force", config.settings.python or {}, {
              pythonPath = python,
            })
          end,
          settings = {
            python = {
              analysis = {
                autoImportCompletions = true,
                autoSearchPaths = true,
                diagnosticMode = "openFilesOnly",
                typeCheckingMode = "standard",
                useLibraryCodeForTypes = true,
              },
            },
          },
        },
        gopls = {
          settings = {
            gopls = {
              analyses = { unusedparams = true },
              completeUnimported = true,
              usePlaceholders = true,
              gofumpt = true,
              staticcheck = true,
            },
          },
        },
        ruff = {},
      },
    },
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        go = { "goimports", "gofumpt" },
        python = { "ruff_fix", "ruff_format" },
      },
    },
  },
  -- Configure Mason
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "gopls",
        "pyright",
        "ruff",
        "gofumpt",
        "goimports",
        "golangci-lint",
        "delve",
        "debugpy",
      },
    },
  },
}
