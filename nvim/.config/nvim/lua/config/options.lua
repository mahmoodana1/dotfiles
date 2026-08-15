vim.opt.directory = vim.fn.stdpath("state") .. "/swap//"

vim.opt.shortmess:append("A")

vim.g.python3_host_prog = vim.fn.expand("~/.virtualenvs/nvim/bin/python")
