-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- File safety options to prevent corruption
vim.opt.backup = false         -- don't create backup files
vim.opt.writebackup = false    -- don't create backup before overwriting
vim.opt.swapfile = true        -- keep swap files for crash recovery
vim.opt.updatetime = 300       -- faster swap file writes (default is 4000ms)
vim.opt.undofile = true        -- persistent undo history

-- Ensure proper file encoding
vim.opt.fileencoding = "utf-8"

-- fsync after write to ensure data is flushed to disk
vim.opt.fsync = true
