---@type LazySpec
return {
  -- Keep the default AstroNvim setup lean; the symbols outline is not part of the
  -- workflow and has been a source of Tree-sitter compatibility churn.
  { "stevearc/aerial.nvim", enabled = false },

  -- Language servers, formatters and debuggers come from mise
  -- (~/.config/mise/conf.d), which manages them uniformly across macOS and the
  -- Linux servers. Mason would be a second, competing installer with its own
  -- PATH precedence and versions, so it is disabled outright rather than left
  -- as an ambiguous fallback.
  { "mason-org/mason.nvim", enabled = false },
  { "mason-org/mason-lspconfig.nvim", enabled = false },
  { "WhoIsSethDaniel/mason-tool-installer.nvim", enabled = false },
  { "jay-babu/mason-null-ls.nvim", enabled = false },
  { "jay-babu/mason-nvim-dap.nvim", enabled = false },

  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = "markdown",
    build = function(plugin)
      vim.cmd("source " .. vim.fn.fnameescape(plugin.dir .. "/autoload/mkdp/util.vim"))
      vim.fn["mkdp#util#install_sync"](true)
    end,
    keys = {
      { "<Leader>mp", "<Cmd>MarkdownPreviewToggle<CR>", desc = "Toggle Markdown preview" },
    },
  },

  {
    "AstroNvim/astrocore",
    opts = function(_, opts)
      opts.mappings.n["<Leader>tu"] = vim.fn.executable "mise" == 1
          and {
            function() require("astrocore").toggle_term_cmd { cmd = "mise exec gdu -- gdu", direction = "float" } end,
            desc = "ToggleTerm gdu",
          }
        or false
    end,
  },

  {
    "mrjones2014/smart-splits.nvim",
    opts = function(_, opts)
      local herdr_pane = vim.env.HERDR_PANE_ID
      if herdr_pane then
        opts.at_edge = function(ctx)
          vim.system {
            vim.env.HERDR_BIN_PATH or "herdr",
            "pane",
            "focus",
            "--direction",
            ctx.direction,
            "--pane",
            herdr_pane,
          }
        end
      end
    end,
  },

  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      filesystem = {
        commands = {
          open_keep_focus = function(state)
            local tree_win = state.winid
            require("neo-tree.sources.filesystem.commands").open(state)

            if vim.api.nvim_win_is_valid(tree_win) then vim.api.nvim_set_current_win(tree_win) end
          end,
        },
        window = {
          mappings = {
            ["go"] = "open_keep_focus",
          },
        },
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = false,
        },
      },
    },
  },

  {
    "m4xshen/hardtime.nvim",
    lazy = false,
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {
      enabled = true,
      hint = true,
      notification = true,
      timeout = 5000,
      restriction_mode = "hint",
      disable_mouse = false,
    },
  },

  -- AstroNvim v6 uses snacks.nvim for the dashboard, picker and notifier.
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      opts.dashboard = opts.dashboard or {}
      opts.dashboard.preset = opts.dashboard.preset or {}
      opts.dashboard.preset.header = table.concat({
        "                                                     ",
        "  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ",
        "  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║ ",
        "  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║ ",
        "  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║ ",
        "  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║ ",
        "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ",
        "                                                     ",
      }, "\n")

      -- Open these pickers even when they return nothing, instead of closing
      -- and firing a "No results found for `x`" toast. They are all
      -- context-dependent and legitimately empty from the dashboard, or in a
      -- buffer with no LSP attached / no changes: an empty picker you can
      -- retype in is quieter than a warning that throws away the prompt.
      -- Scoped per-source on purpose; setting this globally would make `files`
      -- and `grep` sit open on a blank list instead of telling you nothing
      -- matched.
      opts.picker = opts.picker or {}
      opts.picker.sources = opts.picker.sources or {}
      opts.picker.sources.files = vim.tbl_deep_extend("force", opts.picker.sources.files or {}, {
        hidden = true,
      })
      opts.picker.sources.grep = vim.tbl_deep_extend("force", opts.picker.sources.grep or {}, {
        hidden = true,
      })

      for _, source in ipairs {
        "diagnostics",
        "diagnostics_buffer",
        "git_status",
        "lsp_symbols",
        "lsp_workspace_symbols",
        "lsp_references",
        "lsp_definitions",
        "lsp_declarations",
        "lsp_implementations",
        "lsp_type_definitions",
      } do
        opts.picker.sources[source] = vim.tbl_deep_extend("force", opts.picker.sources[source] or {}, {
          show_empty = true,
        })
      end

      -- Strip the redundant title from Snacks' own toasts: the icon and colour
      -- already carry the level, so every message rendering as "Snacks Picker"
      -- is noise. `filter` is the supported hook here and receives the live
      -- notification, so blanking the title takes effect before it renders.
      -- Returning true keeps the notification itself. Titles from other
      -- sources (e.g. AstroNvim) are left alone.
      opts.notifier = opts.notifier or {}
      opts.notifier.filter = function(notif)
        if notif.title == "Snacks" or notif.title == "Snacks Picker" then notif.title = "" end
        return true
      end
    end,
  },
}
