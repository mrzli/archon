local native_tsc_by_root = {}

local function typescript_root(bufnr)
  local root_markers = { "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock" }
  root_markers = vim.fn.has("nvim-0.11.3") == 1 and { root_markers, { ".git" } }
    or vim.list_extend(root_markers, { ".git" })

  local deno_root = vim.fs.root(bufnr, { "deno.json", "deno.jsonc" })
  local deno_lock_root = vim.fs.root(bufnr, { "deno.lock" })
  local project_root = vim.fs.root(bufnr, root_markers)
  if deno_lock_root and (not project_root or #deno_lock_root > #project_root) then
    return
  end
  if deno_root and (not project_root or #deno_root >= #project_root) then
    return
  end

  return project_root or vim.fn.getcwd()
end

local function native_tsc(root)
  if native_tsc_by_root[root] ~= nil then
    return native_tsc_by_root[root] or nil
  end

  local bin = vim.fs.joinpath(root, "node_modules", ".bin", "tsc")
  local result = vim.fn.executable(bin) == 1 and vim.system({ bin, "--version" }, { text = true }):wait() or nil
  local version = result and result.code == 0 and vim.version.parse(result.stdout or "") or nil
  native_tsc_by_root[root] = version and version.major >= 7 and bin or false

  return native_tsc_by_root[root] or nil
end

return {
  { import = "lazyvim.plugins.extras.util.rest" },
  {
    "nvim-mini/mini.pairs",
    enabled = false,
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        javascript = { "oxfmt" },
        javascriptreact = { "oxfmt" },
        typescript = { "oxfmt" },
        typescriptreact = { "oxfmt" },
      },
    },
  },
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          select = {
            kinds = {
              codeaction = {
                matcher = { sort_empty = true },
                transform = function(item)
                  local selection = item.item
                  local action = selection and selection.action
                  local title = action and action.title or ""
                  local specifier = title:match('from "([^"]+)"') or title:match("from '([^']+)'")
                  local is_index_import = false

                  if specifier then
                    local basename = specifier:match("([^/]+)$") or specifier
                    is_index_import = basename == "index" or basename:match("^index%.") ~= nil

                    local is_relative = specifier == "."
                      or specifier == ".."
                      or specifier:match("^%./") ~= nil
                      or specifier:match("^%.%./") ~= nil
                    local bufnr = selection and selection.ctx and selection.ctx.bufnr
                    local filename = bufnr and vim.api.nvim_buf_get_name(bufnr) or ""

                    if is_relative and filename ~= "" then
                      local module_path = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(filename), specifier))
                      is_index_import = is_index_import or vim.fn.isdirectory(module_path) == 1
                    end
                  end

                  if specifier and specifier:match("^%./[^/]+$") and not is_index_import then
                    item.import_priority = 0
                  elseif is_index_import then
                    item.import_priority = 1
                  else
                    item.import_priority = 2
                  end

                  return item
                end,
                sort = {
                  fields = { "import_priority", "score:desc", "#text", "idx" },
                },
              },
            },
          },
        },
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      -- LazyVim configures these servers and Mason installs any that are
      -- missing. Reapplying this file is therefore idempotent.
      servers = {
        -- Application languages
        vtsls = {
          root_dir = function(bufnr, on_dir)
            local root = typescript_root(bufnr)
            if root and not native_tsc(root) then
              on_dir(root)
            end
          end,
          settings = {
            vtsls = {
              autoUseWorkspaceTsdk = true,
            },
          },
        },
        -- TypeScript 7+ provides its own project-local native language server.
        tsc = {
          mason = false,
          root_dir = function(bufnr, on_dir)
            local root = typescript_root(bufnr)
            if root and native_tsc(root) then
              on_dir(root)
            end
          end,
          cmd = function(dispatchers, config)
            return vim.lsp.rpc.start({ native_tsc(config.root_dir), "--lsp", "--stdio" }, dispatchers)
          end,
        },
        -- Projects provide their own Oxlint executable and configuration.
        oxlint = { mason = false },
        basedpyright = {},
        lua_ls = {},
        ruby_lsp = {},
        bashls = {},

        -- Web and configuration files
        html = {},
        cssls = {},
        jsonls = {},
        yamlls = {},
        tailwindcss = {},

        -- Infrastructure, documentation, and data
        dockerls = {},
        docker_compose_language_service = {},
        marksman = {},
        sqls = {},
      },
    },
  },
}
