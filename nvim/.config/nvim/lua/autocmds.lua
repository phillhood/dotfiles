require "nvchad.autocmds"

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if vim.o.diff then
      return
    end

    require("nvim-tree.api").tree.open()
    vim.cmd "wincmd p"
  end,
})
