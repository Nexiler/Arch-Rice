return {
  {
    "echasnovski/mini.surround",
    version = "*", -- Use for stability (recommended by the author)
    config = function()
      require("mini.surround").setup({
        -- You can customize default mappings here if you want, 
        -- but leaving it empty uses the sensible defaults.
        mappings = {
          add = 'gza', -- Add surrounding
          delete = 'gzd', -- Delete surrounding
          replace = 'gzr', -- Replace surrounding
          find = 'gzf', -- Find surrounding (to the right)
          find_left = 'gzF', -- Find surrounding (to the left)
          highlight = 'gzh', -- Highlight surrounding
          update_n_lines = 'gzn', -- Update `n_lines`
          suffix_last = '', 
          suffix_next = '', 
        },
      })

      -- Add VS Code-like behavior: select text and press a quote or bracket to surround
      local pairs = { '(', '[', '{', "'", '"', '`' }
      for _, char in ipairs(pairs) do
        -- Visual mode: select text and press the bracket/quote to surround it
        vim.keymap.set("x", char, "gza" .. char, { remap = true, desc = "Surround with " .. char })
        
        -- Normal mode: press gza + bracket/quote to instantly surround the current word (no 'iw' needed!)
        vim.keymap.set("n", "gza" .. char, "gzaiw" .. char, { remap = true, desc = "Surround word with " .. char })
      end
    end,
  }
}
