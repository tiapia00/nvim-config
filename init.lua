-- ============================================================
-- Basic setup
-- ============================================================
vim.g.mapleader = " "
vim.opt.fileformat = "unix"
vim.opt.fileformats = { "unix", "dos" }
vim.cmd("packadd nvim.undotree")
vim.keymap.set("n", "<leader>u", require("undotree").open)

-- Neovim Python provider
vim.g.python3_host_prog = [[C:\Users\mattiaan\AppData\Local\Programs\Python\Python312\python.exe]]

vim.opt.title = true
vim.opt.titlestring = "%t"
vim.opt.shell = "pwsh"
vim.opt.shellcmdflag = "-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command"
vim.opt.shellquote = ""
vim.opt.shellxquote = ""
vim.keymap.set("n", "<leader>tt", ":tabnew | terminal pwsh -NoExit -Command av<CR>", {
  noremap = true,
  silent = true,
})

local function quarto_cmp_enabled()
  local ft = vim.bo.filetype

  -- Disable completion entirely in standalone LaTeX files.
  if ft == "tex" or ft == "latex" then
    return false
  end

  -- Normal behavior outside Markdown/Quarto.
  if ft ~= "markdown" and ft ~= "quarto" then
    return true
  end

  -- Enable completion inside an injected code language.
  --
  -- In normal Quarto prose, the parser language is "markdown" or
  -- "markdown_inline". Inside a Python/R/etc. chunk, Treesitter reports
  -- the injected language.
  local ok, language_tree = pcall(
    vim.treesitter.get_parser,
    0
  )

  if ok and language_tree then
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local language = language_tree:language_for_range({
      row - 1,
      col,
      row - 1,
      col,
    }):lang()

    if language ~= "markdown" and language ~= "markdown_inline" then
      return true
    end
  end

  -- In normal Markdown, enable completion only while typing a reference.
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local before_cursor = line:sub(1, col)

  -- Matches:
  -- @
  -- @fig-
  -- @tbl-results
  -- [@citation
  -- see @fig-example
  return before_cursor:match("@[%w_:.%-]*$") ~= nil
end

local function jump_quarto_cell(direction)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_line = cursor[1]

  if direction == "next" then
    for i = current_line + 1, #lines do
      if lines[i]:match("^```%s*{") then
        vim.api.nvim_win_set_cursor(0, { i, 0 })
        vim.cmd("normal! zz")
        return
      end
    end

    vim.notify("No next Quarto cell", vim.log.levels.INFO)
  elseif direction == "prev" then
    for i = current_line - 1, 1, -1 do
      if lines[i]:match("^```%s*{") then
        vim.api.nvim_win_set_cursor(0, { i, 0 })
        vim.cmd("normal! zz")
        return
      end
    end

    vim.notify("No previous Quarto cell", vim.log.levels.INFO)
  end
end

vim.api.nvim_create_user_command("QuartoNextCell", function()
  jump_quarto_cell("next")
end, {})

vim.api.nvim_create_user_command("QuartoPrevCell", function()
  jump_quarto_cell("prev")
end, {})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "quarto", "qmd", "markdown" },
  callback = function(args)
    vim.keymap.set("n", "]ce", function()
      for _ = 1, vim.v.count1 do
        jump_quarto_cell("next")
      end
    end, {
      buffer = args.buf,
      desc = "Jump to next Quarto cell",
    })

    vim.keymap.set("n", "[ce", function()
      for _ = 1, vim.v.count1 do
        jump_quarto_cell("prev")
      end
    end, {
      buffer = args.buf,
      desc = "Jump to previous Quarto cell",
    })
  end,
})

vim.api.nvim_create_user_command("QuartoCell", function(opts)
  local target = tonumber(opts.args)

  if target == nil or target < 1 then
    vim.notify("Usage: :QuartoCell 5", vim.log.levels.ERROR)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local count = 0

  for i, line in ipairs(lines) do
    -- Match Quarto / Markdown code cells:
    -- ```{python}
    -- ```{r}
    -- ```{julia}
    -- ```{bash}
    if line:match("^```%s*{") then
      count = count + 1

      if count == target then
        vim.api.nvim_win_set_cursor(0, { i, 0 })
        vim.cmd("normal! zz")
        return
      end
    end
  end

  vim.notify("Cell " .. target .. " not found. Found only " .. count .. " cells.", vim.log.levels.WARN)
end, {
  nargs = 1,
  desc = "Jump to the i-th Quarto code cell",
})

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- ============================================================
-- Plugins
-- ============================================================
require("lazy").setup({
  { "SirVer/ultisnips", event = "InsertEnter" },
  { "tpope/vim-fugitive" },
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require("telescope").setup({})
    end,
  },
  {"folke/todo-comments.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    -- your configuration comes here
    -- or leave it empty to use the default settings
    -- refer to the configuration section below
    }
  },
  { "madox2/vim-ai" },
  { "lervag/vimtex" },
  {
    "JoosepAlviste/nvim-ts-context-commentstring",
    lazy = true,
  },

  {
    "numToStr/Comment.nvim",
    dependencies = {
      "JoosepAlviste/nvim-ts-context-commentstring",
    },
    opts = function()
      return {
        pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook(),
      }
    end,
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "mocha",
      })
      vim.cmd.colorscheme("catppuccin")
    end,
  },

{
  "williamboman/mason.nvim",
  config = true,
},

{
  "williamboman/mason-lspconfig.nvim",
  dependencies = {
    "williamboman/mason.nvim",
    "neovim/nvim-lspconfig",
  },
  config = function()
    require("mason-lspconfig").setup({
      ensure_installed = {
        "basedpyright",
        "ruff",
      },
    })
  end,
},
{
  "neovim/nvim-lspconfig",
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
  },
  config = function()
    local capabilities = require("cmp_nvim_lsp").default_capabilities()

    -- Python language server: basedpyright
    vim.lsp.config("basedpyright", {
      capabilities = capabilities,
      settings = {
        basedpyright = {
          analysis = {
            autoImportCompletions = true,
            typeCheckingMode = "basic",
            diagnosticMode = "workspace",
          },
        },
      },
    })

    -- Ruff language server
    vim.lsp.config("ruff", {
      capabilities = capabilities,
    })

    vim.lsp.enable({
      "basedpyright",
      "ruff",
    })

    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(event)
        local opts = { buffer = event.buf }

        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "gD", function()
          vim.cmd("vsplit")
          vim.lsp.buf.definition()
        end, { desc = "Go to definition in vertical split" })
        vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
        vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
      end,
    })

  vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = "*.py",
    callback = function()
      -- Fix all auto-fixable Ruff problems
      vim.lsp.buf.code_action({
        context = {
          only = { "source.fixAll.ruff" },
          diagnostics = {},
        },
        apply = true,
      })

      -- Organize imports with Ruff
      vim.lsp.buf.code_action({
        context = {
          only = { "source.organizeImports.ruff" },
          diagnostics = {},
        },
        apply = true,
      })

      -- Format with Ruff
      vim.lsp.buf.format({
        async = false,
        filter = function(client)
          return client.name == "ruff"
        end,
      })
    end,
  })
  end,
  },
{
  "ibhagwan/fzf-lua",
  config = function()
    local fzf = require("fzf-lua")

    fzf.setup({
      files = {
        fd_opts = table.concat({
          "--color=never",
          "--type f",
          "--hidden",
          "--follow",
          "--exclude .git",
          "--exclude .venv",
          "--exclude __pycache__",
          "--exclude .pytest_cache",
          "--exclude .mypy_cache",
          "--exclude .ruff_cache",
          "--exclude node_modules",
        }, " "),
      },

      grep = {
        rg_opts = table.concat({
          "--column",
          "--line-number",
          "--no-heading",
          "--color=always",
          "--smart-case",
          "--hidden",
          "--glob !.git/**",
          "--glob !.venv/**",
          "--glob !__pycache__/**",
          "--glob !.pytest_cache/**",
          "--glob !.mypy_cache/**",
          "--glob !.ruff_cache/**",
          "--glob !node_modules/**",
        }, " "),
      },
    })
  end,
},
 {
    "urtzienriquez/citeref.nvim",
    ft = { "markdown", "rmd", "quarto", "pandoc", "tex", "latex" },
    config = function()
      require("citeref").setup({
        backend = "fzf",

        bib_files = {
          "C:/Users/mattiaan/Documents/TEX/refs.bib",
        },
      })
    end,
  },
{
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  version = false,
  lazy = false,
  build = ":TSUpdate",

  dependencies = {
    {
      "nvim-treesitter/nvim-treesitter-textobjects",
      branch = "main",
      version = false,
    },
  },

  config = function()
    require("nvim-treesitter").setup({
      install_dir = vim.fn.stdpath("data") .. "/site",
    })

    require("nvim-treesitter").install({
      "python",
      "markdown",
      "markdown_inline",
      "lua",
      "vim",
      "latex",
      "vimdoc",
      "html",
      "query",
    })

    vim.api.nvim_create_autocmd("FileType", {
      pattern = {
        "python",
        "markdown",
        "quarto",
        "lua",
        "vim",
      },
      callback = function()
        vim.treesitter.start()
      end,
    })

  vim.keymap.set({ "x", "o" }, "af", function()
    require("nvim-treesitter-textobjects.select")
      .select_textobject("@function.outer", "textobjects")
  end, { desc = "Select outer function" })

  vim.keymap.set({ "x", "o" }, "if", function()
    require("nvim-treesitter-textobjects.select")
      .select_textobject("@function.inner", "textobjects")
  end, { desc = "Select inner function" })

  vim.keymap.set({ "x", "o" }, "ac", function()
    require("nvim-treesitter-textobjects.select")
      .select_textobject("@class.outer", "textobjects")
  end, { desc = "Select outer class" })

  vim.keymap.set({ "x", "o" }, "ic", function()
    require("nvim-treesitter-textobjects.select")
      .select_textobject("@class.inner", "textobjects")
  end, { desc = "Select inner class" })

  vim.keymap.set("n", "]f", function()
    require("nvim-treesitter-textobjects.move")
      .goto_next_start("@function.outer", "textobjects")
  end, { desc = "Next function start" })

  vim.keymap.set("n", "[f", function()
    require("nvim-treesitter-textobjects.move")
      .goto_previous_start("@function.outer", "textobjects")
  end, { desc = "Previous function start" })

  vim.keymap.set("n", "]c", function()
    require("nvim-treesitter-textobjects.move")
      .goto_next_start("@class.outer", "textobjects")
  end, { desc = "Next class start" })

  vim.keymap.set("n", "[c", function()
    require("nvim-treesitter-textobjects.move")
      .goto_previous_start("@class.outer", "textobjects")
  end, { desc = "Previous class start" })
end
},

  {
    "quarto-dev/quarto-nvim",
    dependencies = {
      "jmbuhr/otter.nvim",
      "nvim-treesitter/nvim-treesitter",
      "jpalardy/vim-slime",
    },
    ft = { "quarto", "markdown" },
    config = function()
      require("quarto").setup({
        lspFeatures = {
          enabled = true,
          chunks = "curly",
          languages = { "python", "r", "julia", "bash" },
        },
        codeRunner = {
          enabled = true,
          default_method = "slime",
        },
      })
    end,
  },

  { "jmbuhr/otter.nvim" },
  { "willothy/wezterm.nvim" },

  {
    "stevearc/aerial.nvim",
    opts = {
      backends = { "treesitter", "markdown", "lsp" },
    },
  },
{
  "olimorris/codecompanion.nvim",
  event = "VeryLazy",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "bassamsdata/fs-monitor.nvim",
    "kkharji/sqlite.lua",
  },
  config = function()
    require("codecompanion").setup({
      extensions = {
        fs_monitor = {
          enabled = true,
          opts = {
            keymap = "gF",
          },
        },
      },

      adapters = {
        http = {
          ntnu = function()
            return require("codecompanion.adapters").extend("openai_compatible", {
              env = {
                url = "https://llm.hpc.ntnu.no",
                api_key = "NTNU_LLM_API_KEY",
                chat_url = "/v1/chat/completions",
              },
              headers = {
                ["Content-Type"] = "application/json",
                ["Authorization"] = "Bearer ${api_key}",
              },
              schema = {
                model = {
                  default = "nvidia/GLM-5.2-NVFP4",
                },
                temperature = {
                  default = 0.2,
                },
                max_tokens = {
                  default = 4096,
                },
              },
            })
          end,
        },
      },

      -- FIXED: Combined everything under the proper 'strategies' schema
      strategies = {
        chat = { adapter = "ntnu" },
        inline = { adapter = "ntnu" },
        cli = {
          agent = "codex",
          agents = {
            codex = {
              cmd = "codex",
              args = {}, 
              description = "Codex CLI",
              provider = "terminal",
            },
          },
        },
      },
    })
  end,
},
{
  "MagicDuck/grug-far.nvim",
  cmd = "GrugFar",
  config = function()
    require("grug-far").setup({})
  end,
  keys = {
    {
      "<leader>sr",
      function()
        require("grug-far").open()
      end,
      desc = "Search and replace",
    },
    {
      "<leader>sw",
      function()
        require("grug-far").open({
          prefills = {
            search = vim.fn.expand("<cword>"),
          },
        })
      end,
      desc = "Search word under cursor",
    },
  },
},
{
  "kevinhwang91/nvim-ufo",
  dependencies = {
    "kevinhwang91/promise-async",
  },
  event = { "BufReadPost", "BufNewFile" },

  init = function()
    vim.o.foldcolumn = "1"
    vim.o.foldlevel = 99
    vim.o.foldlevelstart = 99
    vim.o.foldenable = true
  end,

  config = function()
    local ufo = require("ufo")

    -- --------------------------------------------------
    -- UFO setup
    -- --------------------------------------------------
    ufo.setup({
      provider_selector = function(_, filetype, _)
          return { "treesitter", "indent" }
        end,
    })

    vim.keymap.set("n", "zR", ufo.openAllFolds, {
      desc = "Open all folds",
    })

    vim.keymap.set("n", "zM", ufo.closeAllFolds, {
      desc = "Close all folds",
    })

    vim.keymap.set("n", "zr", ufo.openFoldsExceptKinds, {
      desc = "Open folds except kinds",
    })

    vim.keymap.set("n", "zm", ufo.closeFoldsWith, {
      desc = "Close folds with level",
    })
  end,
},
{
  "hrsh7th/nvim-cmp",
  event = "InsertEnter",
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    "hrsh7th/cmp-cmdline",
    "L3MON4D3/LuaSnip",
    "saadparwaiz1/cmp_luasnip",
  },
  config = function()
    local cmp = require("cmp")
    local luasnip = require("luasnip")

    cmp.setup({
      enabled = quarto_cmp_enabled,

      snippet = {
        expand = function(args)
          luasnip.lsp_expand(args.body)
        end,
      },

      mapping = cmp.mapping.preset.insert({
        ["<C-Space>"] = cmp.mapping.complete(),

        ["<CR>"] = cmp.mapping.confirm({
          select = true,
        }),

        ["<S-Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_prev_item()
          elseif luasnip.jumpable(-1) then
            luasnip.jump(-1)
          else
            fallback()
          end
        end, { "i", "s" }),
      }),

      sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "path" },
        { name = "luasnip" },
        { name = "buffer" },
      }),
    })

    cmp.setup.filetype({ "markdown", "quarto" }, {
      enabled = quarto_cmp_enabled,

      sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "buffer" },
      }),
    })

    cmp.setup.cmdline(":", {
      mapping = cmp.mapping.preset.cmdline(),
      sources = cmp.config.sources({
        { name = "path" },
        { name = "cmdline" },
      }),
    })
  end,
},
{
  "richwomanbtc/overleaf.nvim",
  build = "cd node && npm install", -- Compiles the Node WebSocket bridge
  config = function()
    require("overleaf").setup({
        cookie = "overleaf_session2=s%3A3o4HbfP51qC5ZoXZnjhK_RjplQ1eNryQ.dRhXutB9EWMEjpifNaVGpjJZMBRE%2FASuTi07k5HDa9g" ,
    })
  end
},
{
  "stevearc/oil.nvim",
  lazy = false,
  priority = 1000,
  opts = {
    default_file_explorer = true,
  },
  keys = {
    { "-", "<cmd>Oil<CR>", desc = "Open parent directory" },
  },
}
})

-- ============================================================
-- Lua
-- ============================================================
--
vim.keymap.set({ "n", "v" }, "<leader>oa", function()
  require("overleaf.reviews").add_comment()
end, { desc = "[O]verleaf [A]dd Comment" })

vim.keymap.set("n", "<leader>ff", function()
  require("fzf-lua").files()
end, { desc = "Find files" })

vim.keymap.set("n", "<leader>fg", function()
  require("fzf-lua").live_grep()
end, { desc = "Live grep project" })

vim.keymap.set("n", "<leader>fb", function()
  require("fzf-lua").buffers()
end, { desc = "Find buffers" })

vim.keymap.set("n", "<leader>fr", function()
  require("fzf-lua").oldfiles()
end, { desc = "Recent files" })

vim.keymap.set("n", "<leader>fs", function()
  require("fzf-lua").lsp_document_symbols()
end, { desc = "Document symbols" })

vim.keymap.set("n", "<leader>fS", function()
  require("fzf-lua").lsp_workspace_symbols()
end, { desc = "Workspace symbols" })

-- ============================================================
-- General settings
-- ============================================================
vim.api.nvim_create_autocmd("FileType", {
  pattern = "codecompanion",
  callback = function()
    vim.keymap.set("i", "<C-Space>", "<C-x><C-o>", {
      buffer = true,
      desc = "Trigger CodeCompanion completion",
    })
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "quarto" },
  callback = function()
    vim.opt_local.conceallevel = 0
  end,
})

vim.o.foldcolumn = "0" -- '0' is not bad
vim.o.foldlevel = 99   -- Using ufo provider need a large value, feel free to decrease the value
vim.o.foldlevelstart = 99
vim.o.foldenable = true
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.autoread = true
vim.opt.encoding = "utf-8"
vim.opt.splitright = true
vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.termguicolors = true
vim.opt.background = "dark"

vim.cmd("filetype plugin indent on")
vim.cmd("syntax on")

vim.api.nvim_create_autocmd("VimResized", {
  callback = function()
    vim.cmd("wincmd =")
  end,
})
vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })

-- ============================================================
-- Appearance
-- ============================================================
vim.api.nvim_set_hl(0, "SpellBad", {
  fg = "#f38ba8",
  bg = "#3b1f2b",
  underline = false,
})
vim.api.nvim_set_hl(0, "SpellCap", {
  fg = "#f9e2af",
  bg = "#3b3320",
  underline = false,
})
vim.api.nvim_set_hl(0, "SpellRare", {
  fg = "#89b4fa",
  bg = "#1f2f45",
  underline = false,
})
vim.api.nvim_set_hl(0, "SpellLocal", {
  fg = "#a6e3a1",
  bg = "#203828",
  underline = false,
})
vim.api.nvim_set_hl(0, "LineNr", {
  fg = "#6c7086",
  bg = "NONE",
})
vim.api.nvim_set_hl(0, "LineNrAbove", {
  fg = "#89b4fa",
  bg = "NONE",
})
vim.api.nvim_set_hl(0, "LineNrBelow", {
  fg = "#89b4fa",
  bg = "NONE",
})
vim.api.nvim_set_hl(0, "CursorLineNr", {
  fg = "#f9e2af",
  bg = "NONE",
  bold = true,
})

-- ============================================================
-- Treesitter
-- ============================================================
vim.treesitter.language.register("markdown", "quarto")

local function hover_in_split()
  local params = vim.lsp.util.make_position_params(0, "utf-8")

  vim.lsp.buf_request(0, "textDocument/hover", params, function(err, result, _, _)
    if err then
      vim.notify("LSP hover error: " .. err.message, vim.log.levels.ERROR)
      return
    end

    if not result or not result.contents then
      vim.notify("No hover information available", vim.log.levels.INFO)
      return
    end

    local lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
    lines = vim.lsp.util.trim_empty_lines(lines)

    if vim.tbl_isempty(lines) then
      vim.notify("No hover information available", vim.log.levels.INFO)
      return
    end

    for i, line in ipairs(lines) do
      line = line:gsub("&nbsp;", " ")
      line = line:gsub("&amp;", "&")
      line = line:gsub("&lt;", "<")
      line = line:gsub("&gt;", ">")
      lines[i] = line
    end

    vim.cmd("topleft split")
    vim.cmd("resize 12")

    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_win_set_buf(win, buf)

    vim.bo[buf].filetype = "markdown"
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "text"
    vim.bo[buf].modifiable = true

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    vim.bo[buf].modifiable = false

    vim.wo[win].wrap = true
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    pcall(vim.treesitter.start, buf, "markdown")

    vim.keymap.set("n", "q", "<cmd>close<CR>", {
      buffer = buf,
      silent = true,
      desc = "Close hover split",
    })
  end)
end

vim.keymap.set("n", "K", hover_in_split, {
  desc = "Show LSP hover in top split",
})
--
-- ============================================================
-- LSP keymaps
-- ============================================================
vim.keymap.set("n", "gr", vim.lsp.buf.references, { desc = "References" })
vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })
vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })

-- ============================================================
-- Diagnostics
-- ============================================================
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float)
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev)
vim.keymap.set("n", "]d", vim.diagnostic.goto_next)

vim.keymap.set("n", "<leader>de", function()
    vim.diagnostic.setloclist()
end)

-- ============================================================
-- Quarto keymaps
-- ============================================================
vim.keymap.set("n", "<leader>qr", function()
  require("quarto.runner").run_cell()
end, { desc = "Quarto run current cell" })

vim.keymap.set("n", "<leader>qa", function()
  require("quarto.runner").run_all()
end, { desc = "Quarto run all cells" })

vim.keymap.set("n", "<leader>qb", function()
  require("quarto.runner").run_above()
end, { desc = "Quarto run cells above" })

vim.keymap.set("v", "<leader>qR", function()
  require("quarto.runner").run_range()
end, { desc = "Quarto run selected range" })

-- -----------------------------
-- vim-slime config for internal Neovim terminal
-- -----------------------------
vim.g.slime_target = "neovim"
vim.g.slime_python_ipython = 1
vim.g.slime_dont_ask_default = 1
vim.g.slime_bracketed_paste = 1

_G.ipython_slime = {
  buf = nil,
  jobid = nil,
}

local function open_and_attach_ipython_slime()
  local source_buf = vim.api.nvim_get_current_buf()
  local source_win = vim.api.nvim_get_current_win()

  -- Reuse existing IPython terminal if possible
  if _G.ipython_slime.buf and vim.api.nvim_buf_is_valid(_G.ipython_slime.buf) then
    local jobid = vim.b[_G.ipython_slime.buf].terminal_job_id

    if not jobid then
      vim.notify("Existing IPython buffer has no terminal_job_id", vim.log.levels.ERROR)
      return
    end

    _G.ipython_slime.jobid = jobid

    vim.api.nvim_buf_call(source_buf, function()
      vim.b.slime_config = {
        jobid = jobid,
      }
    end)

    vim.g.slime_default_config = {
      jobid = jobid,
    }

    vim.notify("Attached buffer to existing IPython jobid: " .. tostring(jobid))
    return
  end

  -- Open new tab with IPython terminal
  vim.cmd("tabnew")
  vim.cmd("terminal ipython --no-autoindent")

  local term_buf = vim.api.nvim_get_current_buf()
  local jobid = vim.b[term_buf].terminal_job_id

  if not jobid then
    vim.notify("Could not get terminal_job_id", vim.log.levels.ERROR)
    return
  end

  _G.ipython_slime.buf = term_buf
  _G.ipython_slime.jobid = jobid

  vim.api.nvim_buf_set_name(term_buf, "IPython Slime REPL")

  -- Attach the original source buffer to the IPython terminal
  vim.api.nvim_buf_call(source_buf, function()
    vim.b.slime_config = {
      jobid = jobid,
    }
  end)

  -- Also set global default, to avoid stale fallback configs
  vim.g.slime_default_config = {
    jobid = jobid,
  }

  -- Go back to the source buffer/window
  vim.api.nvim_set_current_win(source_win)

  vim.notify("Started IPython and attached buffer to jobid: " .. tostring(jobid))
end

vim.api.nvim_create_user_command(
  "IPythonSlime",
  open_and_attach_ipython_slime,
  {}
)

-- ============================================================
-- Indentation defaults
-- ============================================================
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.smartindent = true
vim.opt.autoindent = true
vim.opt.breakindent = true

vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.opt_local.expandtab = true
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.softtabstop = 4
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "lua",
  callback = function()
    vim.opt_local.expandtab = true
    vim.opt_local.tabstop = 2
    vim.opt_local.shiftwidth = 2
    vim.opt_local.softtabstop = 2
  end,
})

-- ============================================================
-- Navigation and mappings
-- ============================================================
vim.keymap.set("n", "j", "gj", { noremap = true })
vim.keymap.set("n", "k", "gk", { noremap = true })

-- Buffers
vim.keymap.set("n", "<leader>b", "<cmd>Buffers<CR>", { noremap = true, desc = "FZF buffers" })
vim.keymap.set("n", "<leader>n", "<cmd>bnext<CR>", { noremap = true, desc = "Next buffer" })
vim.keymap.set("n", "<leader>p", "<cmd>bprevious<CR>", { noremap = true, desc = "Previous buffer" })

-- FZF
vim.keymap.set("n", "<leader>f", "<cmd>Files<CR>", { noremap = true, desc = "FZF files" })
vim.keymap.set("n", "<leader>rg", "<cmd>Rg<CR>", { noremap = true, desc = "Ripgrep" })

-- ============================================================
-- UltiSnips
-- ============================================================
vim.g.UltiSnipsSnippetDirectories = {
  [[C:\Users\mattiaan\OneDrive - NTNU\Configs\UltiSnips]],
}
vim.g.UltiSnipsExpandTrigger = "<tab>"
vim.g.UltiSnipsJumpForwardTrigger = "<c-n>"
vim.g.UltiSnipsJumpBackwardTrigger = "<c-p>"

-- ============================================================
-- VimTeX
-- ============================================================
vim.g.vimtex_compiler_method = "latexmk"
vim.g.vimtex_view_method = "general"
vim.g.vimtex_view_general_viewer = "sioyek"

vim.g.vimtex_view_general_options =
  '--inverse-search "C:\\Users\\mattiaan\\Programs\\sioyek-inverse.cmd %1 %2" '
  .. "--forward-search-file @tex "
  .. "--forward-search-line @line "
  .. "@pdf"
-- vim.g.vimtex_view_general_viewer = "SumatraPDF"
-- vim.g.vimtex_view_general_options = "-reuse-instance -forward-search @tex @line @pdf"

vim.g.vimtex_quickfix_open_on_warning = 0
vim.g.vimtex_complete_enabled = 1
vim.g.vimtex_fold_enabled = 1

vim.g.vimtex_complete_bib = {
  menu = 1,
  abbr = 1,
  info = 0,
}

vim.g.vimtex_toc_config = {
  layer_status = {
    content = 1,
    label = 1,
    todo = 1,
    include = 0,
  },
  show_help = 0,
}

vim.keymap.set("x", "se", "<plug>(vimtex-env-surround-visual)", { remap = true })

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = "*.tex",
  callback = function()
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "en_us"
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "tex",
  callback = function()
    vim.keymap.set("n", "<C-]>", ":tjump <C-R><C-W><CR>", {
      buffer = true,
      noremap = true,
    })
  end,
})

vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { noremap = true, silent = true })

-- ============================================================
-- netrw
-- ============================================================
vim.g.netrw_winsize = 30


-- ============================================================
-- Overleaf comments integration
-- ============================================================
--
-- Requirements:
--   - Neovim >= 0.10
--   - telescope.nvim
--   - olcli installed and authenticated
--   - Git remote pointing to Overleaf
--
-- Normal mappings:
--
--   <leader>oc    Open cached comments
--   <leader>ou    Update comments from Overleaf
--   <leader>oC    Update + open comments
--
-- Telescope mappings:
--
--   Enter         Jump to commented text
--   Ctrl-p        Reply, keep thread open
--   Ctrl-r        Optional reply + resolve
--
-- ============================================================


-- ============================================================
-- Telescope
-- ============================================================

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")


-- ============================================================
-- JSON
-- ============================================================

local function read_json_file(path)
  local fd = io.open(path, "r")

  if not fd then
    return nil
  end

  local content = fd:read("*a")
  fd:close()

  local ok, data = pcall(
    vim.json.decode,
    content
  )

  if not ok then
    return nil
  end

  return data
end


-- ============================================================
-- Comment helpers
-- ============================================================

local function comment_message(comment)
  if not comment.messages
    or #comment.messages == 0
  then
    return "(no message)"
  end

  return comment.messages[
    #comment.messages
  ].content or "(no message)"
end


-- ============================================================
-- Git root
-- ============================================================

local function get_git_root()
  local result = vim.system({
    "git",
    "rev-parse",
    "--show-toplevel",
  }, {
    text = true,
  }):wait()

  if result.code ~= 0 then
    return nil
  end

  return vim.trim(
    result.stdout or ""
  )
end


-- ============================================================
-- Overleaf project ID
-- ============================================================

local function get_overleaf_project_id()
  local result = vim.system({
    "git",
    "remote",
    "get-url",
    "origin",
  }, {
    text = true,
  }):wait()

  if result.code ~= 0 then
    return nil
  end

  local remote = vim.trim(
    result.stdout or ""
  )

  -- Examples:
  --
  -- https://git@git.overleaf.com/PROJECT_ID
  -- https://git.overleaf.com/PROJECT_ID
  -- https://git.overleaf.com/PROJECT_ID.git
  -- https://www.overleaf.com/project/PROJECT_ID

  local project_id =
    remote:match(
      "git%.overleaf%.com/([%w]+)"
    )
    or remote:match(
      "/project/([%w]+)"
    )

  return project_id
end


-- ============================================================
-- Comments cache
-- ============================================================

local function comments_file()
  local root = get_git_root()

  if not root then
    return nil
  end

  return root .. "/.olcomments.json"
end


-- ============================================================
-- Refresh comments
-- ============================================================

local function refresh_overleaf_comments(callback)
  local project_id =
    get_overleaf_project_id()

  local output_file =
    comments_file()

  if not project_id then
    vim.notify(
      "Could not determine Overleaf project ID from Git remote",
      vim.log.levels.ERROR
    )

    return
  end

  if not output_file then
    vim.notify(
      "Not inside a Git repository",
      vim.log.levels.ERROR
    )

    return
  end

  vim.notify(
    "Refreshing Overleaf comments...",
    vim.log.levels.INFO
  )

  vim.system({
    "olcli",
    "comments",
    "list",
    "--status",
    "open",
    "--json",
    project_id,
  }, {
    text = true,
  }, function(result)

    if result.code ~= 0 then
      vim.schedule(function()
        vim.notify(
          "Failed to refresh Overleaf comments:\n"
            .. (result.stderr or ""),
          vim.log.levels.ERROR
        )
      end)

      return
    end

    local fd =
      io.open(output_file, "w")

    if not fd then
      vim.schedule(function()
        vim.notify(
          "Could not write "
            .. output_file,
          vim.log.levels.ERROR
        )
      end)

      return
    end

    fd:write(
      result.stdout or ""
    )

    fd:close()

    vim.schedule(function()
      vim.notify(
        "Overleaf comments refreshed",
        vim.log.levels.INFO
      )

      if callback then
        callback()
      end
    end)
  end)
end


-- ============================================================
-- Send reply
-- ============================================================

local function send_overleaf_reply(
  comment,
  reply,
  callback
)
  local project_id =
    get_overleaf_project_id()

  if not project_id then
    vim.notify(
      "Could not determine Overleaf project ID",
      vim.log.levels.ERROR
    )

    return
  end

  if not comment
    or not comment.threadId
  then
    vim.notify(
      "Comment has no threadId",
      vim.log.levels.ERROR
    )

    return
  end

  vim.system({
    "olcli",
    "comments",
    "reply",
    comment.threadId,
    reply,
    project_id,
  }, {
    text = true,
  }, function(result)

    vim.schedule(function()

      if result.code ~= 0 then
        vim.notify(
          "Failed to reply:\n"
            .. (result.stderr or ""),
          vim.log.levels.ERROR
        )

        return
      end

      vim.notify(
        "Reply sent",
        vim.log.levels.INFO
      )

      if callback then
        callback()
      end
    end)
  end)
end


-- ============================================================
-- Interactive reply
-- ============================================================

local function reply_to_overleaf_comment(
  comment,
  callback
)
  vim.ui.input({
    prompt = "Reply: ",
  }, function(reply)

    -- ESC
    if reply == nil then
      return
    end

    reply = vim.trim(reply)

    if reply == "" then
      return
    end

    send_overleaf_reply(
      comment,
      reply,
      callback
    )
  end)
end


-- ============================================================
-- Resolve comment
-- ============================================================

local function resolve_overleaf_comment(
  comment,
  callback
)
  local project_id =
    get_overleaf_project_id()

  if not project_id then
    vim.notify(
      "Could not determine Overleaf project ID",
      vim.log.levels.ERROR
    )

    return
  end

  if not comment
    or not comment.threadId
  then
    vim.notify(
      "Comment has no threadId",
      vim.log.levels.ERROR
    )

    return
  end

  vim.system({
    "olcli",
    "comments",
    "resolve",
    comment.threadId,
    project_id,
  }, {
    text = true,
  }, function(result)

    vim.schedule(function()

      if result.code ~= 0 then
        vim.notify(
          "Failed to resolve comment:\n"
            .. (result.stderr or ""),
          vim.log.levels.ERROR
        )

        return
      end

      vim.notify(
        "Overleaf comment resolved",
        vim.log.levels.INFO
      )

      if callback then
        callback()
      end
    end)
  end)
end


-- ============================================================
-- Reply optionally, then resolve
-- ============================================================

local function reply_and_resolve_comment(
  comment,
  callback
)
  vim.ui.input({
    prompt =
      "Reply before resolving (empty = no reply): ",
  }, function(reply)

    -- ESC
    if reply == nil then
      return
    end

    reply = vim.trim(reply)

    local function do_resolve()
      resolve_overleaf_comment(
        comment,
        callback
      )
    end

    -- Empty input:
    -- resolve directly
    if reply == "" then
      do_resolve()
      return
    end

    -- Otherwise reply first
    send_overleaf_reply(
      comment,
      reply,
      do_resolve
    )
  end)
end


-- ============================================================
-- Find commented text in current buffer
-- ============================================================
--
-- IMPORTANT:
--
-- Overleaf's cached line number may become stale after you
-- modify the local file.
--
-- Therefore:
--
--   1. selectedText is used as the primary anchor
--   2. all matching occurrences are found
--   3. the occurrence closest to the original Overleaf line
--      is selected
--   4. cached line/column is only the fallback
--
-- ============================================================

local function find_comment_location(
  bufnr,
  comment
)
  local selected =
    comment.selectedText or ""

  selected =
    selected:gsub("\r", "")

  if selected == "" then
    return nil
  end

  local selected_lines =
    vim.split(
      selected,
      "\n",
      {
        plain = true,
      }
    )

  if #selected_lines == 0 then
    return nil
  end

  local first_line =
    selected_lines[1]

  if not first_line
    or first_line == ""
  then
    return nil
  end

  local buffer_lines =
    vim.api.nvim_buf_get_lines(
      bufnr,
      0,
      -1,
      false
    )

  local candidates = {}

  -- ----------------------------------------------------------
  -- Find all occurrences of first selected line
  -- ----------------------------------------------------------

  for line_number, line in ipairs(
    buffer_lines
  ) do
    local search_from = 1

    while true do
      local start_col =
        line:find(
          first_line,
          search_from,
          true
        )

      if not start_col then
        break
      end

      table.insert(
        candidates,
        {
          line = line_number,
          column = start_col - 1,
        }
      )

      search_from =
        start_col + 1
    end
  end


  if #candidates == 0 then
    return nil
  end


  -- ----------------------------------------------------------
  -- If there is only one match, use it
  -- ----------------------------------------------------------

  if #candidates == 1 then
    return candidates[1]
  end


  -- ----------------------------------------------------------
  -- Multiple matches:
  -- choose the one closest to cached Overleaf line
  -- ----------------------------------------------------------

  local original_line =
    comment.line or 1

  table.sort(
    candidates,
    function(a, b)
      local distance_a =
        math.abs(
          a.line - original_line
        )

      local distance_b =
        math.abs(
          b.line - original_line
        )

      return distance_a
        < distance_b
    end
  )

  return candidates[1]
end


-- ============================================================
-- Jump to comment
-- ============================================================

local function jump_to_overleaf_comment(
  root,
  comment
)
  if not comment.path then
    vim.notify(
      "Comment has no source path",
      vim.log.levels.ERROR
    )

    return
  end

  local filepath =
    root .. "/" .. comment.path

  vim.cmd(
    "edit "
      .. vim.fn.fnameescape(
        filepath
      )
  )

  local bufnr =
    vim.api.nvim_get_current_buf()


  -- ----------------------------------------------------------
  -- Try selectedText first
  -- ----------------------------------------------------------

  local location =
    find_comment_location(
      bufnr,
      comment
    )

  if location then
    vim.api.nvim_win_set_cursor(
      0,
      {
        location.line,
        location.column,
      }
    )

    vim.cmd("normal! zz")

    return
  end


  -- ----------------------------------------------------------
  -- Fallback:
  -- use cached Overleaf line/column
  -- ----------------------------------------------------------

  local line_count =
    vim.api.nvim_buf_line_count(
      bufnr
    )

  local line =
    math.min(
      math.max(
        comment.line or 1,
        1
      ),
      line_count
    )

  local column =
    math.max(
      (comment.column or 1) - 1,
      0
    )


  -- Prevent invalid column
  local line_text =
    vim.api.nvim_buf_get_lines(
      bufnr,
      line - 1,
      line,
      false
    )[1] or ""

  column =
    math.min(
      column,
      #line_text
    )


  vim.api.nvim_win_set_cursor(
    0,
    {
      line,
      column,
    }
  )

  vim.cmd("normal! zz")

  vim.notify(
    "Selected text not found; using cached Overleaf position",
    vim.log.levels.WARN
  )
end


-- ============================================================
-- Telescope comments picker
-- ============================================================

local function overleaf_comments()
  local root =
    get_git_root()

  local file =
    comments_file()

  if not root then
    vim.notify(
      "Not inside a Git repository",
      vim.log.levels.ERROR
    )

    return
  end

  if not file then
    return
  end

  local comments =
    read_json_file(file)

  if not comments then
    vim.notify(
      "Could not read .olcomments.json. Run <leader>ou first.",
      vim.log.levels.ERROR
    )

    return
  end

  if #comments == 0 then
    vim.notify(
      "No open Overleaf comments",
      vim.log.levels.INFO
    )

    return
  end


  -- ==========================================================
  -- Telescope entries
  -- ==========================================================

  local entries = {}

  for _, comment in ipairs(
    comments
  ) do

    local message =
      comment_message(comment)

    local short_message =
      message
        :gsub("\r", "")
        :gsub("\n", " ")

    if #short_message > 90 then
      short_message =
        short_message:sub(
          1,
          87
        ) .. "..."
    end

    local location =
      string.format(
        "%s:%d",
        comment.path or "?",
        comment.line or 0
      )

    table.insert(
      entries,
      {
        value = comment,

        display =
          string.format(
            "%-28s %s",
            location,
            short_message
          ),

        ordinal =
          table.concat(
            {
              comment.path or "",
              tostring(
                comment.line or ""
              ),
              comment.selectedText or "",
              short_message,
            },
            " "
          ),
      }
    )
  end


  -- ==========================================================
  -- Telescope
  -- ==========================================================

  pickers.new({}, {
    prompt_title =
      "Overleaf Comments",

    layout_strategy =
      "vertical",

    layout_config = {
      width = 0.95,
      height = 0.90,

      vertical = {
        preview_height = 0.65,
        preview_cutoff = 1,
        mirror = true,
      },
    },


    -- --------------------------------------------------------
    -- Finder
    -- --------------------------------------------------------

    finder =
      finders.new_table({
        results = entries,

        entry_maker =
          function(entry)
            return entry
          end,
      }),

    sorter =
      conf.generic_sorter({}),


    -- --------------------------------------------------------
    -- Preview
    -- --------------------------------------------------------

    previewer =
      previewers.new_buffer_previewer({
        title = "Comment",

        define_preview =
          function(self, entry)

            local c =
              entry.value

            local msg =
              comment_message(c)

            local lines = {
              string.format(
                "%s:%d:%d",
                c.path or "?",
                c.line or 0,
                c.column or 1
              ),

              "",
              "COMMENT",
              "-------",
            }


            -- -----------------------------------------------
            -- Latest comment
            -- -----------------------------------------------

            for _, line in ipairs(
              vim.split(
                (msg or "")
                  :gsub("\r", ""),
                "\n",
                {
                  plain = true,
                }
              )
            ) do
              table.insert(
                lines,
                line
              )
            end


            -- -----------------------------------------------
            -- Selected source
            -- -----------------------------------------------

            table.insert(
              lines,
              ""
            )

            table.insert(
              lines,
              "SELECTED TEXT"
            )

            table.insert(
              lines,
              "-------------"
            )


            for _, line in ipairs(
              vim.split(
                (c.selectedText or "")
                  :gsub("\r", ""),
                "\n",
                {
                  plain = true,
                }
              )
            ) do
              table.insert(
                lines,
                line
              )
            end


            -- -----------------------------------------------
            -- Full thread
            -- -----------------------------------------------

            if c.messages
              and #c.messages > 1
            then
              table.insert(
                lines,
                ""
              )

              table.insert(
                lines,
                "THREAD"
              )

              table.insert(
                lines,
                "------"
              )


              for _, message
                in ipairs(c.messages)
              do

                local username =
                  "Unknown"

                if message.user then
                  username =
                    message.user.first_name
                    or message.user.email
                    or "Unknown"
                end


                table.insert(
                  lines,
                  username .. ":"
                )


                local content =
                  (message.content or "")
                    :gsub("\r", "")


                for _, line in ipairs(
                  vim.split(
                    content,
                    "\n",
                    {
                      plain = true,
                    }
                  )
                ) do
                  table.insert(
                    lines,
                    "  " .. line
                  )
                end


                table.insert(
                  lines,
                  ""
                )
              end
            end


            -- -----------------------------------------------
            -- Key help
            -- -----------------------------------------------

            table.insert(
              lines,
              ""
            )

            table.insert(
              lines,
              "KEYS"
            )

            table.insert(
              lines,
              "----"
            )

            table.insert(
              lines,
              "Enter   open source"
            )

            table.insert(
              lines,
              "Ctrl-y  reply"
            )

            table.insert(
              lines,
              "Ctrl-r  reply + resolve"
            )


            vim.api.nvim_buf_set_lines(
              self.state.bufnr,
              0,
              -1,
              false,
              lines
            )


            -- -----------------------------------------------
            -- Wrap preview
            -- -----------------------------------------------

            if self.state.winid
              and vim.api.nvim_win_is_valid(
                self.state.winid
              )
            then

              vim.api.nvim_set_option_value(
                "wrap",
                true,
                {
                  win =
                    self.state.winid,
                }
              )

              vim.api.nvim_set_option_value(
                "linebreak",
                true,
                {
                  win =
                    self.state.winid,
                }
              )
            end
          end,
      }),


    -- --------------------------------------------------------
    -- Telescope mappings
    -- --------------------------------------------------------

    attach_mappings =
      function(
        prompt_bufnr,
        map
      )


        -- ====================================================
        -- ENTER
        -- ====================================================

        actions.select_default:replace(
          function()

            local entry =
              action_state
                .get_selected_entry()

            if not entry then
              return
            end

            local comment =
              entry.value

            actions.close(
              prompt_bufnr
            )

            jump_to_overleaf_comment(
              root,
              comment
            )
          end
        )


        -- ====================================================
        -- CTRL-P
        -- Reply, keep open
        -- ====================================================

        local function reply_selected()

          local entry =
            action_state
              .get_selected_entry()

          if not entry then
            return
          end

          local comment =
            entry.value

          actions.close(
            prompt_bufnr
          )


          reply_to_overleaf_comment(
            comment,
            function()

              refresh_overleaf_comments(
                function()
                  overleaf_comments()
                end
              )

            end
          )
        end


        map(
          "i",
          "<C-y>",
          reply_selected
        )

        map(
          "n",
          "<C-y>",
          reply_selected
        )


        -- ====================================================
        -- CTRL-R
        -- Reply optionally + resolve
        -- ====================================================

        local function resolve_selected()

          local entry =
            action_state
              .get_selected_entry()

          if not entry then
            return
          end

          local comment =
            entry.value

          actions.close(
            prompt_bufnr
          )


          reply_and_resolve_comment(
            comment,
            function()

              refresh_overleaf_comments(
                function()
                  overleaf_comments()
                end
              )

            end
          )
        end


        map(
          "i",
          "<C-r>",
          resolve_selected
        )

        map(
          "n",
          "<C-r>",
          resolve_selected
        )


        return true
      end,

  }):find()
end


-- ============================================================
-- Commands
-- ============================================================

vim.api.nvim_create_user_command(
  "OLProject",
  function()

    local project_id =
      get_overleaf_project_id()

    if project_id then
      vim.notify(
        "Overleaf project: "
          .. project_id
      )
    else
      vim.notify(
        "No Overleaf project detected",
        vim.log.levels.ERROR
      )
    end
  end,
  {}
)


vim.api.nvim_create_user_command(
  "OLComments",
  function()
    overleaf_comments()
  end,
  {}
)


vim.api.nvim_create_user_command(
  "OLCommentsUpdate",
  function()
    refresh_overleaf_comments()
  end,
  {}
)


-- ============================================================
-- Keybindings
-- ============================================================

-- Open cached comments
vim.keymap.set(
  "n",
  "<leader>oc",
  overleaf_comments,
  {
    desc =
      "Open Overleaf comments",
  }
)


-- Update comments
vim.keymap.set(
  "n",
  "<leader>ou",
  function()
    refresh_overleaf_comments()
  end,
  {
    desc =
      "Update Overleaf comments",
  }
)


-- Update + open
vim.keymap.set(
  "n",
  "<leader>oC",
  function()

    refresh_overleaf_comments(
      function()
        overleaf_comments()
      end
    )

  end,
  {
    desc =
      "Refresh and open Overleaf comments",
  }
)
