return {
  {
    "folke/flash.nvim",
    keys = {
      -- Disable default `s` and `S` by mapping them to false
      { "s", mode = { "n", "x", "o" }, false },
      { "S", mode = { "n", "x", "o" }, false },
      -- Provide alternative mappings for flash
      { "gs", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash Jump" },
      { "gS", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
    },
  },
}
