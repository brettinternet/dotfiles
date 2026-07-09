local config = require "astrotheme.lib.config"
local util = require "astrotheme.lib.util"

local opts = config.user_config {
  palette = "kaile",
  background = {
    dark = "kaile",
    light = "kaile",
  },
  style = {
    transparent = false,
    inactive = true,
    float = true,
    neotree = true,
    border = true,
    title_invert = false,
    italic_comments = false,
    simple_syntax_colors = true,
  },
  palettes = {
    kaile = {},
  },
  highlights = {
    kaile = {
      modify_hl_groups = function(hl, c)
        hl.Comment = { fg = c.syntax.comment, bg = c.none }
        hl.Keyword = { fg = c.syntax.blue, bg = c.none }
        hl.Function = { fg = c.syntax.yellow, bg = c.none }
        hl.Identifier = { fg = c.syntax.cyan, bg = c.none }
        hl.String = { fg = c.syntax.green, bg = c.none }
        hl.Number = { fg = c.syntax.green, bg = c.none }
        hl.Boolean = { fg = c.syntax.green, bg = c.none }
        hl.Type = { fg = c.syntax.green, bg = c.none }
        hl.Operator = { fg = c.syntax.mute, bg = c.none }
        hl.Delimiter = { fg = c.syntax.mute, bg = c.none }

        hl.Normal = { fg = c.ui.text, bg = c.ui.base }
        hl.NormalNC = { fg = c.ui.text_inactive, bg = c.ui.base }
        hl.CursorLine = { bg = c.ui.current_line }
        hl.Visual = { fg = c.ui.text_active, bg = c.ui.selection }
        hl.Search = { fg = c.ui.yellow, bg = c.ui.selection }
        hl.IncSearch = { fg = c.ui.green, bg = c.ui.selection }
        hl.LineNr = { fg = c.ui.text_inactive, bg = c.none }
        hl.CursorLineNr = { fg = c.ui.green, bg = c.none }
        hl.ColorColumn = { bg = c.ui.current_line }
        hl.SignColumn = { bg = c.none }
        hl.VertSplit = { fg = c.ui.border, bg = c.none }
        hl.WinSeparator = { fg = c.ui.border, bg = c.none }
        hl.FloatBorder = { fg = c.ui.border, bg = c.ui.float }
        hl.FloatTitle = { fg = c.ui.green, bg = c.ui.float, bold = true }
        hl.NormalFloat = { fg = c.ui.text, bg = c.ui.float }
        hl.Pmenu = { fg = c.ui.text, bg = c.ui.tool }
        hl.PmenuSel = { fg = c.ui.blue, bg = c.ui.selection }
        hl.StatusLine = { fg = c.ui.text, bg = c.ui.statusline }
        hl.StatusLineNC = { fg = c.ui.text_inactive, bg = c.ui.statusline }

        hl.DiagnosticError = { fg = c.ui.red, bg = c.none }
        hl.DiagnosticWarn = { fg = c.ui.yellow, bg = c.none }
        hl.DiagnosticInfo = { fg = c.ui.blue, bg = c.none }
        hl.DiagnosticHint = { fg = c.ui.cyan, bg = c.none }
        hl.DiagnosticOk = { fg = c.ui.green, bg = c.none }

        hl.DiffAdd = { fg = c.ui.green, bg = c.ui.selection }
        hl.DiffChange = { fg = c.ui.yellow, bg = c.ui.selection }
        hl.DiffDelete = { fg = c.ui.red, bg = c.ui.selection }
        hl.DiffText = { fg = c.ui.yellow, bg = c.ui.current_line, bold = true }

        hl.NeoTreeNormal = { fg = c.ui.text, bg = c.ui.base }
        hl.NeoTreeNormalNC = { fg = c.ui.text, bg = c.ui.base }
        hl.NeoTreeDirectoryName = { fg = c.ui.blue, bg = c.none }
        hl.NeoTreeDirectoryIcon = { fg = c.ui.blue, bg = c.none }
        hl.NeoTreeFileNameOpened = { fg = c.ui.green, bg = c.none }
        hl.NeoTreeGitAdded = { fg = c.ui.green, bg = c.none }
        hl.NeoTreeGitModified = { fg = c.ui.yellow, bg = c.none }
        hl.NeoTreeGitDeleted = { fg = c.ui.red, bg = c.none }

        hl.TelescopeBorder = { fg = c.ui.border, bg = c.ui.float }
        hl.TelescopeNormal = { fg = c.ui.text, bg = c.ui.float }
        hl.TelescopeSelection = { fg = c.ui.text_active, bg = c.ui.selection }
        hl.TelescopeMatching = { fg = c.ui.green, bg = c.none }
      end,
    },
  },
}

vim.o.background = "dark"
util.reload(opts)
local colors = util.set_palettes(opts)
local highlights = util.get_highlights(colors, opts)
util.set_highlights(highlights)
if opts.terminal_colors then util.set_terminal_colors(colors) end
