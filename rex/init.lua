rex.bind("ctrl+b>ctrl+b", "pane.send_key", { key = "ctrl+b" })

rex.bind("ctrl+b>h", "pane.focus", { direction = "left" })
rex.bind("ctrl+b>j", "pane.focus", { direction = "down" })
rex.bind("ctrl+b>k", "pane.focus", { direction = "up" })
rex.bind("ctrl+b>l", "pane.focus", { direction = "right" })

rex.mode("repeat", { exclusive = true })
rex.bind("ctrl+b>ctrl+r", "client.mode.enter", { name = "repeat" })
rex.bind("repeat/enter", "client.mode.exit")
rex.bind("repeat/escape", "client.mode.exit")

rex.bind("ctrl+b>shift+h", "pane.resize", { amount = 5, direction = "left" })
rex.bind("repeat/shift+h", "pane.resize", { amount = 5, direction = "left" })
rex.bind("ctrl+b>shift+j", "pane.resize", { amount = 5, direction = "down" })
rex.bind("repeat/shift+j", "pane.resize", { amount = 5, direction = "down" })
rex.bind("ctrl+b>shift+k", "pane.resize", { amount = 5, direction = "up" })
rex.bind("repeat/shift+k", "pane.resize", { amount = 5, direction = "up" })
rex.bind("ctrl+b>shift+l", "pane.resize", { amount = 5, direction = "right" })
rex.bind("repeat/shift+l", "pane.resize", { amount = 5, direction = "right" })

rex.bind("ctrl+b>shift+\\", "pane.split", { direction = "right" })
rex.bind("ctrl+b>-", "pane.split", { direction = "down" })
rex.bind("ctrl+b>c", "client.tab.new")
rex.bind("ctrl+b>r", "client.config.reload")

-- Worktree sessions (see ~/dotfiles/rex/wt). Each opens a floating pane in the focused
-- pane's directory, so it acts on whichever repo you're looking at (wt falls back to
-- ~/Development/dirt):
--   ctrl+b w        asks for a host (this Mac or an ssh host) and a name, then offers an
--                   editor pane for a first message; creates worktree + session there
--   ctrl+b o        pick a worktree and reopen its session, resuming Claude
--   ctrl+b x        confirm, then remove the worktree, branch and session you're in
--   ctrl+b p        list unused worktrees (no session, nothing unpushed), confirm, remove
-- From the CLI, `rex do wt_new name=fix-login [host=LABEL] [base=REF] [prompt=TEXT]
-- [agent=false]` skips the questions (host defaults to this Mac).
local wt = os.getenv("HOME") .. "/.local/bin/wt"
local terminal = "com.superlogical.terminal"

local function focused_cwd(ctx)
  if ctx.block_id == nil then return nil end
  local r = rex.block.call(terminal, "process", { block_id = ctx.block_id })
  if r == nil or r.foreground == nil then return nil end
  return r.foreground.cwd
end

local function float(ctx, command, bounds)
  local _, err = rex.session.new_layer{
    bounds = bounds,
    focus = true,
    layout = rex.layout.block{
      flavor = terminal .. ".shell",
      options = { command = command, cwd = focused_cwd(ctx) },
    },
  }
  if err ~= nil then error(err, 0) end
end

local function wt_float(ctx, args, bounds)
  local command = { wt }
  for _, a in ipairs(args) do table.insert(command, a) end
  float(ctx, command, bounds)
end

-- Remote hosts run this wt as ~/.local/bin/wt-rex (personalize links it; there,
-- ~/.local/bin/wt is the herdr one), reached over ssh, making worktrees of remote_repo.
local LOCAL_HOST = "local"
local this_mac = { label = "This Mac" }
local remote_wt = "~/.local/bin/wt-rex"
local remote_repo = "~/dirt"

-- Actions run with a bare PATH (/usr/bin:/bin:...), without rex, jq, or the coder
-- binary that ssh's ProxyCommand runs for Coder workspaces.
local home = os.getenv("HOME")
local exec_env = { PATH = table.concat({
  home .. "/.local/bin", "/opt/homebrew/bin", "/usr/local/bin",
  home .. "/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS",
  "/usr/bin", "/bin", "/usr/sbin", "/sbin",
}, ":") }

local function shquote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- One entry per ssh destination: the same machine can be listed under several labels.
local function ssh_hosts()
  local r = rex.exec({ "rex", "hosts", "--json" }, { env = exec_env, timeout = 10 })
  if r == nil or not r.ok then return {} end
  local hosts, seen = {}, {}
  for _, h in ipairs(rex.json.decode(r.stdout).hosts or {}) do
    for _, ep in ipairs(h.host.endpoints or {}) do
      local dest = ep:match("^ssh://([^/]+)")
      if dest ~= nil then
        if seen[dest] == nil then
          seen[dest] = { label = h.host.label, dest = dest, labels = {} }
          table.insert(hosts, seen[dest])
        end
        seen[dest].labels[h.host.label] = true
      end
    end
  end
  return hosts
end

local function find_host(name)
  if name == LOCAL_HOST then return this_mac end
  for _, h in ipairs(ssh_hosts()) do
    if h.labels[name] or h.dest == name then return h end
  end
  error("no ssh host named " .. name, 0)
end

local function ask_host()
  local items = { { id = LOCAL_HOST, title = this_mac.label, subtitle = "repo of the focused pane", icon = "terminal" } }
  local by_id = { [LOCAL_HOST] = this_mac }
  for _, h in ipairs(ssh_hosts()) do
    by_id[h.dest] = h
    table.insert(items, { id = h.dest, title = h.label, subtitle = remote_repo .. " on " .. h.dest, icon = "server" })
  end
  local id = rex.ui.pick{ title = "New worktree session on…", placeholder = "Filter hosts", items = items }
  if id == nil then return nil end
  return by_id[id]
end

-- A non-interactive ssh shell has no XDG_RUNTIME_DIR, which rex needs to find the host's
-- own server.
local function remote_cmd()
  return "XDG_RUNTIME_DIR=/run/user/$(id -u) WT_DEFAULT_REPO=" .. remote_repo .. " " .. remote_wt
end

local function coder_workspace(dest)
  return dest:match("^(.-)%.coder$") or dest:match("^coder%.(.+)$")
end

-- nil when it can't tell (not a Coder host, or coder isn't logged in): then just try ssh.
local function coder_status(ws)
  local r = rex.exec({ "coder", "list", "-o", "json" }, { env = exec_env, timeout = 15 })
  if r == nil or not r.ok then return nil end
  for _, w in ipairs(rex.json.decode(r.stdout) or {}) do
    if w.name == ws then return w.latest_build.status end
  end
  return nil
end

-- ssh to a stopped workspace hangs, so ask to start it. Returns false to give up.
local function wake_host(host)
  local ws = host.dest and coder_workspace(host.dest)
  if ws == nil then return true end
  local st = coder_status(ws)
  if st == nil or st == "running" then return true end
  local choice = rex.ui.pick{
    title = ws .. " is " .. st,
    items = {
      { id = "start", title = "Start " .. ws .. " and continue", icon = "server",
        subtitle = "Takes a few minutes; the session is created once it's up" },
      { id = "cancel", title = "Cancel" },
    },
  }
  if choice ~= "start" then return false end
  -- Detached, so the workspace boots while the remaining questions are answered.
  rex.exec.start({ "/bin/sh", "-c", 'exec "$0" _coder_up "$1" "$2" >/dev/null 2>&1', wt, ws, host.dest },
    { env = exec_env, detach = true })
  host.waking = ws
  return true
end

local function run_wt(ctx, host, words)
  if host.waking ~= nil then
    -- An action gets 30 seconds, so a background job waits for the workspace.
    local argv = { "/bin/sh", "-c", 'exec "$0" _remote_create_bg "$@" >/dev/null 2>&1', wt, host.dest, remote_cmd() }
    for _, w in ipairs(words) do table.insert(argv, w) end
    local h, err = rex.exec.start(argv, { env = exec_env, detach = true })
    if h == nil then error(err, 0) end
    return { output = "wt: creating " .. words[1] .. " once " .. host.waking .. " is up; you'll get a notification." }
  end
  local r, err
  if host.dest == nil then
    local argv = { wt }
    for _, w in ipairs(words) do table.insert(argv, w) end
    r, err = rex.exec(argv, { cwd = focused_cwd(ctx), env = exec_env, timeout = 25 })
  else
    local cmd = { remote_cmd() }
    for _, w in ipairs(words) do table.insert(cmd, shquote(w)) end
    r, err = rex.exec({ "ssh", host.dest, table.concat(cmd, " ") }, { env = exec_env, timeout = 25 })
  end
  if r == nil then error(err, 0) end
  if not r.ok then
    local msg = r.stderr ~= "" and r.stderr or r.stdout
    error((msg:gsub("^wt: ", "")), 0)
  end
  local out = r.stdout
  if host.dest ~= nil then
    out = out .. "It's on " .. host.label .. "; switch to that host to see it."
  end
  return { output = out }
end

rex.action{
  name = "wt_new",
  title = "New Worktree Session…",
  description = "Create a git worktree and a Rex session for it, with Claude running in it, on this Mac or a remote host.",
  keywords = "worktree branch agent claude host remote coder desk",
  args = { name = "string?", base = "string?", prompt = "string?", agent = "boolean?", host = "string?" },
  run = function(ctx, args)
    local host
    if args.host ~= nil then
      host = find_host(args.host)
      local ws = host.dest and coder_workspace(host.dest)
      local st = ws and coder_status(ws)
      if st ~= nil and st ~= "running" then
        error(ws .. " is " .. st .. "; start it with: coder start " .. ws, 0)
      end
    elseif args.name ~= nil then
      host = this_mac
    else
      host = ask_host()
      if host == nil or not wake_host(host) then return end
    end

    if args.name ~= nil then
      local words = { args.name }
      if args.base ~= nil then table.insert(words, "--base"); table.insert(words, args.base) end
      if args.prompt ~= nil then table.insert(words, "--prompt"); table.insert(words, args.prompt) end
      if args.agent == false then table.insert(words, "--no-agent") end
      return run_wt(ctx, host, words)
    end

    -- The name takes the same trailing flags as the CLI: "fix-login --base HEAD --no-agent".
    local name = rex.ui.input{
      title = "Worktree name on " .. host.label,
      placeholder = "fix-login   (may end in --base REF or --no-agent)",
      confirm = "Next",
    }
    if name == nil then return end
    local words = {}
    for w in name:gmatch("%S+") do table.insert(words, w) end
    if #words == 0 then error("a worktree name is required", 0) end

    -- The palette's text field is one short line, so a long first message is written in
    -- an editor pane, which creates the session itself once the editor exits.
    local first = rex.ui.pick{
      title = "First message for Claude",
      items = {
        { id = "write", title = "Write one…", subtitle = "Opens your editor: starts in insert mode; :wq creates the session, :cq! cancels", icon = "document" },
        { id = "none", title = "No message", subtitle = "Start Claude without one", icon = "terminal" },
      },
    }
    if first == nil then return end
    if first == "write" then
      local command = { wt, "_compose", host.dest or "", host.dest and remote_cmd() or "" }
      for _, w in ipairs(words) do table.insert(command, w) end
      return float(ctx, command, { 0.1, 0.1, 0.8, 0.75 })
    end
    return run_wt(ctx, host, words)
  end,
}

rex.action{
  name = "wt_open",
  title = "Open Worktree Session…",
  description = "Pick an existing worktree and reopen its Rex session, resuming Claude.",
  keywords = "worktree branch resume reopen claude",
  run = function(ctx, args)
    wt_float(ctx, { "pick" }, { 0.2, 0.15, 0.6, 0.6 })
  end,
}

rex.action{
  name = "wt_remove",
  title = "Remove This Worktree…",
  description = "Show the focused worktree's unsaved work, then remove it, its branch and its session.",
  keywords = "worktree branch delete close cleanup",
  run = function(ctx, args)
    wt_float(ctx, { "rm-here" }, { 0.15, 0.15, 0.7, 0.6 })
  end,
}

rex.action{
  name = "wt_prune",
  title = "Clean Up Worktrees…",
  description = "Remove worktrees with no open session, no uncommitted changes and nothing unpushed.",
  keywords = "worktree prune cleanup unused stale branch delete",
  run = function(ctx, args)
    wt_float(ctx, { "prune", "--pause" }, { 0.15, 0.15, 0.7, 0.6 })
  end,
}

rex.bind("ctrl+b>w", "wt_new")
rex.bind("ctrl+b>o", "wt_open")
rex.bind("ctrl+b>x", "wt_remove")
rex.bind("ctrl+b>p", "wt_prune")
