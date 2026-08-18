return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      -- LazyVim configures these servers and Mason installs any that are
      -- missing. Reapplying this file is therefore idempotent.
      servers = {
        -- Application languages
        vtsls = {},
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
