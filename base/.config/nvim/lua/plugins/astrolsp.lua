-- AstroLSP customizes language server setup. Tool binaries are provided by mise
-- in darwin/.config/mise/config.toml rather than installed through Mason.

---@type LazySpec
return {
  "AstroNvim/astrolsp",
  ---@type AstroLSPOpts
  opts = {
    servers = {
      "elixirls",
      "gopls",
      "ts_ls",
      "cssls",
      "html",
      "pyright",
      "ruff",
      "marksman",
      "lua_ls",
    },
  },
}
