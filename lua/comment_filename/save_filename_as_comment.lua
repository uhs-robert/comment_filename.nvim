-- lua/comment_filename/save_filename_as_comment.lua
local M = {}

local function realpath(p)
  return vim.uv.fs_realpath(p) or p
end

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function sys_ok(cmd, cwd)
  local ok, proc = pcall(vim.system, cmd, { text = true, cwd = cwd })
  if not ok then return false, "" end
  local r = proc:wait()
  return r.code == 0, (r.stdout or ""):gsub("%s+$", "")
end

local function git_ignored(abs)
  local dir = vim.fs.dirname(abs)
  local ok = sys_ok({ "git", "check-ignore", "--quiet", abs }, dir)
  return ok
end

local function git_root_for(path)
  local dir = realpath(vim.fs.dirname(path) or "")
  if dir == "" then return nil end
  local ok, out = sys_ok({ "git", "-C", dir, "rev-parse", "--show-toplevel" })
  if ok and out ~= "" then return realpath(out) end
  local gitdir = vim.fs.find(".git", { path = dir, upward = true })[1]
  return gitdir and realpath(vim.fs.dirname(gitdir)) or nil
end

local fallback_by_ft = {
  lua = "-- %s",
  vim = '" %s',
  python = "# %s",
  sh = "# %s",
  bash = "# %s",
  zsh = "# %s",
  fish = "# %s",
  ruby = "# %s",
  perl = "# %s",
  r = "# %s",
  php = "// %s",
  javascript = "// %s",
  typescript = "// %s",
  javascriptreact = "// %s",
  typescriptreact = "// %s",
  vue = "<!-- %s -->",
  svelte = "<!-- %s -->",
  astro = "<!-- %s -->",
  html = "<!-- %s -->",
  css = "/* %s */",
  scss = "/* %s */",
  less = "/* %s */",
  c = "/* %s */",
  cpp = "/* %s */",
  objc = "/* %s */",
  objcpp = "/* %s */",
  cuda = "/* %s */",
  rust = "// %s",
  go = "// %s",
  java = "// %s",
  kotlin = "// %s",
  scala = "// %s",
  groovy = "// %s",
  swift = "// %s",
  dart = "// %s",
  sql = "-- %s",
  toml = "# %s",
  conf = "# %s",
  dosini = "; %s",
  gitconfig = "# %s",
  nginx = "# %s",
  dockerfile = "# %s",
  make = "# %s",
  cmake = "# %s",
  nix = "# %s",
  helm = "# %s",
}

local function comment_for_buf(bufnr, text)
  local cs = vim.bo[bufnr].commentstring
  if cs and cs ~= "" and cs:find("%%s") then return (cs:gsub("%%s", text)) end
  local fb = fallback_by_ft[vim.bo[bufnr].filetype]
  if fb then return (fb:gsub("%%s", text)) end
  return "# " .. text
end

local function already_has_comment(bufnr, target)
  local l1 = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ""
  local l2 = vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)[1] or ""
  return trim(l1) == trim(target) or trim(l2) == trim(target)
end

local function insertion_row_for_header(bufnr)
  local l1 = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ""
  if l1:sub(1, 3) == "\239\187\191" then return 1 end -- BOM
  if l1:match("^#!") then return 1 end -- shebang
  return 0
end

-- creates the augroup+autocmd, capturing cfg/state by closure
function M.create_autocmds(cfg, state)
  local group = vim.api.nvim_create_augroup("CommentFilename", { clear = true })

  vim.api.nvim_create_autocmd("BufWritePre", {
    group = group,
    pattern = cfg.patterns,
    desc = "Insert repo-relative filename comment on save",
    callback = function(args)
      if not state.enabled then return end
      if vim.b[args.buf].comment_filename_disabled then return end

      local ft = vim.bo[args.buf].filetype
      if cfg.filetypes[ft] == false then return end

      local abs = realpath(args.file)
      if cfg.skip_gitignored and git_ignored(abs) then return end

      local root = git_root_for(abs)
      local rel
      if root then
        rel = abs:gsub("^" .. vim.pesc(root) .. "/", "")
      else
        -- Fallback: use path relative to cwd or home when not in a git repo
        rel = vim.fn.fnamemodify(abs, ":~:.")
      end
      local header = comment_for_buf(args.buf, rel)
      if already_has_comment(args.buf, header) then return end

      local row = insertion_row_for_header(args.buf)
      vim.api.nvim_buf_set_lines(args.buf, row, row, false, { header })
    end,
  })
end

return M
