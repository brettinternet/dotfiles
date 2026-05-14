-- AstroLSP customizes language server setup. Tool binaries are provided by mise
-- in darwin/.config/mise/config.toml rather than installed through Mason.

---@type LazySpec
return {
  "AstroNvim/astrolsp",
  ---@type AstroLSPOpts
  opts = function(_, opts)
    opts.servers = opts.servers or {}
    vim.list_extend(opts.servers, {
      "elixirls",
      "gopls",
      "ts_ls",
      "cssls",
      "html",
      "pyright",
      "ruff",
      "marksman",
      "lua_ls",
    })

    opts.config = opts.config or {}
    opts.config.ts_ls = vim.tbl_deep_extend("force", opts.config.ts_ls or {}, {
      init_options = {
        tsserver = {
          path = vim.fn.fnamemodify(vim.fn.resolve(vim.fn.exepath "tsserver"), ":h:h") .. "/lib/tsserver.js",
        },
      },
    })
  end,
}
