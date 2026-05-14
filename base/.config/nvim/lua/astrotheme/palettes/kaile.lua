local c = {
  none = "NONE",
  syntax = {},
  ui = {},
  term = {},
  icon = {},
}

-- Kaile mirrors the high-contrast terminal palette in
-- darwin/iterm2-themes/kaile.itermcolors and the dark-terminal agent theme.
-- The UI stays near-black while syntax uses saturated ANSI colors.

--------------------------------
--- Syntax
--------------------------------
c.syntax.red = "#ff0000"
c.syntax.orange = "#ff5faf"
c.syntax.yellow = "#ffff00"
c.syntax.green = "#00ff00"
c.syntax.cyan = "#00ffcc"
c.syntax.blue = "#00aaff"
c.syntax.purple = "#ff5faf"
c.syntax.text = "#cccccc"
c.syntax.comment = "#cccccc"
c.syntax.mute = "#666666"

--------------------------------
--- UI
--------------------------------
c.ui.red = "#ff0000"
c.ui.orange = "#ff5faf"
c.ui.yellow = "#ffff00"
c.ui.green = "#00ff00"
c.ui.cyan = "#00ffcc"
c.ui.blue = "#00aaff"
c.ui.purple = "#ff5faf"

c.ui.accent = c.ui.green

c.ui.tabline = "#111111"
c.ui.winbar = "#cccccc"
c.ui.tool = "#0a0a0a"
c.ui.base = "#050505"
c.ui.inactive_base = "#080808"
c.ui.statusline = "#111111"
c.ui.split = "#333333"
c.ui.float = "#0a0a0a"
c.ui.title = c.ui.accent
c.ui.border = c.ui.blue
c.ui.current_line = "#111111"
c.ui.scrollbar = c.ui.accent
c.ui.selection = "#333333"
c.ui.menu_selection = c.ui.selection
c.ui.highlight = "#001100"
c.ui.none_text = "#333333"
c.ui.text = "#cccccc"
c.ui.text_active = "#ffffff"
c.ui.text_inactive = "#666666"
c.ui.text_match = c.ui.accent

c.ui.prompt = "#111111"

--------------------------------
--- Terminal
--------------------------------
c.term.black = "#111111"
c.term.bright_black = "#666666"

c.term.red = "#ff0000"
c.term.bright_red = "#ff0000"

c.term.green = "#00ff00"
c.term.bright_green = "#00ff00"

c.term.yellow = "#ffff00"
c.term.bright_yellow = "#ffff00"

c.term.blue = "#00aaff"
c.term.bright_blue = "#00aaff"

c.term.purple = "#ff5faf"
c.term.bright_purple = "#ff5faf"

c.term.cyan = "#00ffcc"
c.term.bright_cyan = "#00ffcc"

c.term.white = "#cccccc"
c.term.bright_white = "#ffffff"

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
