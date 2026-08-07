-- AstroLSP customizes language server setup. Tool binaries are provided by mise
-- in ~/.config/mise/conf.d fragments rather than installed through Mason.

--- Locate a `tsserver.js` for typescript-language-server to fall back on.
---
--- typescript-language-server needs a real TypeScript install and does *not*
--- search $PATH for one, so projects with no local `typescript` dependency get
--- no ts_ls at all unless we point at a global copy.
---
--- This resolves mise's `npm:typescript` install directly instead of using
--- `exepath "tsserver"`: several packages ship a `tsserver` shim, and $PATH
--- order used to resolve to vscode-langservers-extracted's bundled TypeScript
--- 4.9.5, silently pinning every project to it.
---@return string? path absolute path to tsserver.js, or nil when unavailable
local function tsserver_fallback()
  -- NOTE: only `~` is expanded here. Passing the whole pattern through
  -- `vim.fn.expand` would expand the `*` too and return a newline-joined
  -- string, which `vim.fn.glob` then fails to match.
  local candidates = vim.fn.glob(
    vim.fn.expand "~" .. "/.local/share/mise/installs/npm-typescript/*/node_modules/typescript/lib/tsserver.js",
    false,
    true
  )
  -- Prefer the highest version so a pinned 5.x wins over any stale install.
  table.sort(candidates)
  for i = #candidates, 1, -1 do
    if vim.uv.fs_stat(candidates[i]) then return candidates[i] end
  end
end

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

    -- `fallbackPath`, not `path`: `path` overrides the workspace's own
    -- TypeScript, while `fallbackPath` is only consulted when the project has
    -- none. Omitted entirely when no global TypeScript exists (the Linux
    -- servers), since a bogus path makes ts_ls exit on startup.
    local fallback = tsserver_fallback()
    if fallback then
      opts.config = opts.config or {}
      opts.config.ts_ls = vim.tbl_deep_extend(
        "force",
        opts.config.ts_ls or {},
        { init_options = { tsserver = { fallbackPath = fallback } } }
      )
    end
  end,
}
