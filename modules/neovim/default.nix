{ pkgs, ... }:
{

  imports = [
    ./java.nix
    ./kotlin.nix
    ./python.nix
    ./rust.nix
  ];

  config = {
    home.packages = with pkgs; [
      ripgrep
      go
      gopls
      ocamlPackages.ocaml-lsp
      ocamlPackages.ocamlformat
      nil
      nixpkgs-fmt
      nodePackages.typescript-language-server
      vscode-langservers-extracted
      yaml-language-server
      rumdl
    ];
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      extraConfig = ''
        set shiftwidth=4 smarttab
        set expandtab
        set tabstop=4 softtabstop=0
        set number relativenumber
      '';
      plugins = with pkgs.vimPlugins; [
        {
          plugin = gitsigns-nvim;
          type = "lua";
          config = ''
            require('gitsigns').setup()
          '';
        }
        {
          plugin = neogit;
          type = "lua";
          config = ''
            local neogit = require('neogit')
            neogit.setup {}
          '';
        }
        {
          plugin = onedark-nvim;
          type = "lua";
          config = ''
            require('onedark').setup {
              style = 'deep'
            }
            require('onedark').load()
          '';
        }
        {
          plugin = nvim-treesitter;
          type = "lua";
          config = ''
            require'nvim-treesitter.configs'.setup {
              highlight = {
                enable = true,
              },
              additional_vim_regex_highlighting = false,
            }
          '';
        }
        {
          plugin = telescope-nvim;
          type = "lua";
          config = ''
            local builtin = require('telescope.builtin')
            vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
            vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
          '';
        }
        {
          plugin = nvim-lspconfig;
          type = "lua";
          config = ''
            vim.lsp.enable('gopls')
            vim.lsp.enable('ocamllsp')
            vim.lsp.enable('html')
            vim.lsp.enable('ts_ls')
            vim.lsp.enable('yamlls')
            vim.lsp.enable('rumdl')
            vim.lsp.config('nil_ls', {
              settings = {
                ['nil'] = {
                  formatting = {
                    command = { "nixpkgs-fmt" },
                  },
                },
              },
            })
            vim.lsp.enable('nil_ls')

            vim.keymap.set('n', '<space>e', vim.diagnostic.open_float)
            vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
            vim.keymap.set('n', ']d', vim.diagnostic.goto_next)
            vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist)

            vim.api.nvim_create_autocmd('LspAttach', {
              group = vim.api.nvim_create_augroup('UserLspConfig', {}),
              callback = function(ev)
                vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

                local opts = { buffer = ev.buf }
                vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
                vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
                vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
                vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
                vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
                vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
                vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
                vim.keymap.set('n', '<space>wl', function()
                  print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
                end, opts)
                vim.keymap.set('n', '<leader>D', vim.lsp.buf.type_definition, opts)
                vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
                vim.keymap.set({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, opts)
                vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
                vim.keymap.set('n', '<leader>fmt', function()
                  vim.lsp.buf.format { async = true }
                end, opts)
              end,
            })
          '';
        }
        nvim-treesitter-parsers.c
        nvim-treesitter-parsers.go
        nvim-treesitter-parsers.gitcommit
        nvim-treesitter-parsers.gitignore
        nvim-treesitter-parsers.git_rebase
        nvim-treesitter-parsers.html
        nvim-treesitter-parsers.lua
        nvim-treesitter-parsers.nix
        nvim-treesitter-parsers.ocaml
        nvim-treesitter-parsers.query
        nvim-treesitter-parsers.typescript
        nvim-treesitter-parsers.vim
        nvim-treesitter-parsers.vimdoc
        nvim-treesitter-context
        cmp-nvim-lsp
        vim-vsnip
        cmp-vsnip
        {
          plugin = nvim-cmp;
          type = "lua";
          config = ''
            local cmp = require'cmp'
            cmp.setup({
              snippet = {
                expand = function(args)
                  vim.fn["vsnip#anonymous"](args.body)
                end,
              },
              mapping = cmp.mapping.preset.insert({
                ['<C-b>'] = cmp.mapping.scroll_docs(-4),
                ['<C-f>'] = cmp.mapping.scroll_docs(4),
                ['<C-Space>'] = cmp.mapping.complete(),
                ['<C-e>'] = cmp.mapping.abort(),
                ['<CR>'] = cmp.mapping.confirm({ select = true }),
              }),
              sources = cmp.config.sources({
                { name = 'nvim_lsp' },
                { name = 'vsnip' },
              }, {
                { name = 'buffer' },
              }),
            })
          '';
        }
      ];
    };
  };
}
