local c = {
  none = "NONE",
  syntax = {},
  ui = {},
  term = {},
  icon = {},
}

-- Kaile keeps the VS Code, Neovim, Ghostty, and iTerm palettes aligned.
-- The UI uses neutral charcoal while syntax uses saturated ANSI colors.

--------------------------------
--- Syntax
--------------------------------
c.syntax.red = "#ff0000"
c.syntax.orange = "#ff5faf"
c.syntax.yellow = "#ffff00"
c.syntax.green = "#00ff00"
c.syntax.cyan = "#00ffcc"
c.syntax.blue = "#33b5ff"
c.syntax.purple = "#ff5faf"
c.syntax.text = "#d0d0d0"
c.syntax.comment = "#858585"
c.syntax.mute = "#858585"

--------------------------------
--- UI
--------------------------------
c.ui.red = "#ff0000"
c.ui.orange = "#ff5faf"
c.ui.yellow = "#ffff00"
c.ui.green = "#00ff00"
c.ui.cyan = "#00ffcc"
c.ui.blue = "#33b5ff"
c.ui.purple = "#ff5faf"

c.ui.accent = c.ui.green

c.ui.tabline = "#202020"
c.ui.winbar = "#d0d0d0"
c.ui.tool = "#181818"
c.ui.base = "#121212"
c.ui.inactive_base = "#181818"
c.ui.statusline = "#202020"
c.ui.split = "#393939"
c.ui.float = "#181818"
c.ui.title = c.ui.accent
c.ui.border = c.ui.blue
c.ui.current_line = "#202020"
c.ui.scrollbar = c.ui.accent
c.ui.selection = "#2a2a2a"
c.ui.menu_selection = c.ui.selection
c.ui.highlight = "#242424"
c.ui.none_text = "#393939"
c.ui.text = "#d0d0d0"
c.ui.text_active = "#f2f2f2"
c.ui.text_inactive = "#858585"
c.ui.text_match = c.ui.accent

c.ui.prompt = "#202020"

--------------------------------
--- Terminal
--------------------------------
c.term.black = "#2a2a2a"
c.term.bright_black = "#858585"

c.term.red = "#ff0000"
c.term.bright_red = "#ff0000"

c.term.green = "#00ff00"
c.term.bright_green = "#00ff00"

c.term.yellow = "#ffff00"
c.term.bright_yellow = "#ffff00"

c.term.blue = "#008ed6"
c.term.bright_blue = "#33b5ff"

c.term.purple = "#ff5faf"
c.term.bright_purple = "#ff5faf"

c.term.cyan = "#00ffcc"
c.term.bright_cyan = "#00ffcc"

c.term.white = "#d0d0d0"
c.term.bright_white = "#f2f2f2"

c.term.background = c.ui.base
c.term.foreground = c.ui.text

--------------------------------
--- Icons
--------------------------------
c.icon.c = c.ui.blue
c.icon.css = c.ui.blue
c.icon.deb = c.ui.purple
c.icon.docker = c.ui.cyan
c.icon.html = c.ui.red
c.icon.jpeg = c.ui.purple
c.icon.jpg = c.ui.purple
c.icon.js = c.ui.yellow
c.icon.jsx = c.ui.cyan
c.icon.kt = c.ui.purple
c.icon.lock = c.ui.yellow
c.icon.lua = c.ui.blue
c.icon.mp3 = c.ui.purple
c.icon.mp4 = c.ui.purple
c.icon.out = c.ui.text
c.icon.png = c.ui.purple
c.icon.py = c.ui.yellow
c.icon.rb = c.ui.red
c.icon.robots = c.ui.text
c.icon.rpm = c.ui.red
c.icon.rs = c.ui.orange
c.icon.toml = c.ui.green
c.icon.ts = c.ui.blue
c.icon.ttf = c.ui.text
c.icon.vue = c.ui.green
c.icon.woff = c.ui.text
c.icon.woff2 = c.ui.text
c.icon.zip = c.ui.yellow

return c
