-- AstroUI provides the basis for configuring the AstroNvim User Interface
-- Configuration documentation can be found with `:h astroui`
-- NOTE: We highly recommend setting up the Lua Language Server (`:LspInstall lua_ls`)
--       as this provides autocomplete and documentation while editing

---@type LazySpec
return {
  "AstroNvim/astroui",
  ---@type AstroUIOpts
  opts = {
    -- change colorscheme
    colorscheme = "kaile",
    -- AstroUI allows you to easily modify highlight groups easily for any and all colorschemes
    highlights = {
      init = { -- this table overrides highlights in all themes
        Normal = { bg = "none" },
        SignColumn = { bg = "none" },
        FoldColumn = { bg = "none" },
        NormalFloat = { bg = "none" },
        NormalNC = { bg = "none" },
        NormalSB = { bg = "none" },
        FloatBorder = { bg = "none" },
        FloatTitle = { bg = "none" },

        CursorLineNr = { bg = "none" },
        CursorLine = { bg = "none" },
        ColorColumn = { bg = "none" },

        TelescopeBorder = { bg = "none" },
        TelescopePromptTitle = { bg = "none" },
        TelescopePromptBorder = { bg = "none" },
        TelescopeNormal = { bg = "none" },

        TabLine = { bg = "none" },
        TabLineSel = { bg = "none" },
        TabLineFill = { bg = "none" },

        NeoTreeNormal = { bg = "none" },
        NeoTreeNormalNC = { bg = "none" },
        NeoTreeTabInactive = { bg = "none" },
        NeoTreeTabSeperatorActive = { bg = "none" },
        NeoTreeTabSeperatorInactive = { bg = "none" },
        NvimTreeTabSeperatorActive = { bg = "none" },
        NvimTreeTabSeperatorInactive = { bg = "none" },
        MiniTabLineFill = { bg = "none" },
      },
      kaile = { -- a table of overrides/changes when applying the kaile theme
        Normal = { bg = "#121212" },
        SignColumn = { bg = "#121212" },
        FoldColumn = { bg = "#121212" },
        NormalFloat = { bg = "#181818" },
        NormalNC = { bg = "#121212" },
        NormalSB = { bg = "#121212" },
        FloatBorder = { bg = "#181818" },
        FloatTitle = { bg = "#181818" },

        CursorLineNr = { bg = "#202020" },
        CursorLine = { bg = "#202020" },
        ColorColumn = { bg = "#202020" },

        TelescopeBorder = { bg = "#181818" },
        TelescopePromptTitle = { bg = "#181818" },
        TelescopePromptBorder = { bg = "#181818" },
        TelescopeNormal = { bg = "#181818" },

        TabLine = { bg = "#202020" },
        TabLineSel = { bg = "#121212" },
        TabLineFill = { bg = "#202020" },

        NeoTreeNormal = { bg = "#121212" },
        NeoTreeNormalNC = { bg = "#121212" },
        NeoTreeTabInactive = { bg = "#202020" },
        NeoTreeTabSeperatorActive = { bg = "#202020" },
        NeoTreeTabSeperatorInactive = { bg = "#202020" },
        NvimTreeTabSeperatorActive = { bg = "#202020" },
        NvimTreeTabSeperatorInactive = { bg = "#202020" },
        MiniTabLineFill = { bg = "#202020" },
      },
    },
    -- Icons can be configured throughout the interface
    icons = {
      -- configure the loading of the lsp in the status line
      LSPLoading1 = "⠋",
      LSPLoading2 = "⠙",
      LSPLoading3 = "⠹",
      LSPLoading4 = "⠸",
      LSPLoading5 = "⠼",
      LSPLoading6 = "⠴",
      LSPLoading7 = "⠦",
      LSPLoading8 = "⠧",
      LSPLoading9 = "⠇",
      LSPLoading10 = "⠏",
    },
  },
}
