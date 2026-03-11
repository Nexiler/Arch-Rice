return {
  {
    "zbirenbaum/copilot.lua",
    enabled = function()
      return vim.fn.executable("node") == 1 and vim.fn.executable("curl") == 1
    end,
    cmd = "Copilot",
    event = "InsertEnter",
    opts = {
      copilot_node_command = "node",
      suggestion = { enabled = false },
      panel = { enabled = false },
    },
  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    enabled = function()
      return vim.fn.executable("node") == 1 and vim.fn.executable("curl") == 1
    end,
    branch = "main",
    dependencies = {
      { "zbirenbaum/copilot.lua" },
      { "nvim-lua/plenary.nvim" },
    },
    opts = {
      -- Only valid models will be returned by the plugin, but we can set a safe default.
      -- If 'gpt-4' is not found, the plugin will warn, but 'select' should still work if auth'd.
      model = nil, 
      show_help = false,
      auto_insert_mode = true,
      window = {
        layout = "float",
        relative = "editor",
        width = 0.5,
        height = 0.3,
        border = "rounded",
        title = " Copilot Inline ",
      },
      mappings = {
        complete = {
          detail = "Use @<Tab> for tools",
          insert = "<Tab>",
        },
        close = {
          normal = "q",
          insert = "<C-c>",
        },
        submit_prompt = {
          normal = "<CR>",
          insert = "<CR>",
        },
        accept_diff = {
          normal = "<C-y>",
          insert = "<C-y>",
        },
      },
    },
    keys = {
      {
        "<leader>cp",
        ":CopilotChat<CR>",
        mode = { "n", "v" },
        desc = "Copilot: Prompt",
      },
      {
        "<leader>cm",
        ":CopilotChatModels<CR>",
        mode = "n",
        desc = "Copilot: Select Model",
      },
      {
        "<leader>ci",
        ":CopilotChatFix<CR>",
        mode = "v",
        desc = "Copilot: Fix Selection",
      },
    },
  },
}
