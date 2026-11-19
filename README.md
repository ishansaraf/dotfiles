# dotfiles

Devbox config. `personalize` installs packages and links everything into place; the devbox
runs `~/personalize` (a symlink to it) on every launch.

Fresh box: `git clone <this repo> ~/dotfiles && ~/dotfiles/personalize`

Theme is Gruvbox Material Dark throughout (helix, tmux, fzf, delta, starship; bat/eza use the
terminal palette). The font is set on the laptop, not here: link `ghostty/config` to
`~/.config/ghostty/config` and install Monaspace (`brew install --cask font-monaspace`).

`zsh/completions/_bazel` is vendored from bazelbuild/bazel at 9.3.0 (`scripts/zsh_completion/_bazel`, Apache-2.0), plus a trailing `_bazel "$@"` call so the first Tab works.

## Claude Code: `/hunk`

`claude/skills/hunk` adds a `/hunk` command to Claude Code. Run inside a [Rex](https://www.superlogical.com/rex)
pane, it splits the pane, opens [Hunk](https://github.com/modem-dev/hunk) on the right, and attaches the
calling Claude session to that review: it can move through it, leave notes beside the code (press `a`
in Hunk to show them), and read and address the notes you leave.

- `/hunk` reviews uncommitted changes, live (`hunk diff --watch`).
- `/hunk main...HEAD` reviews a range; `/hunk show HEAD`, `/hunk log` and `/hunk gh pr` pass through.

Needs `hunk`, `rex` and `jq` on `PATH`. `bin/hunk-pane` does the split and finds the Hunk session by the
pane's process ID, so the skill never attaches to another Hunk window in the same repo.
`claude/skills/hunk-review` is Hunk's own pointer skill (MIT), which loads its instructions from the
installed `hunk` CLI. `personalize` links all three into place; elsewhere, link `bin/hunk-pane` onto
`PATH` and both skill directories into `~/.claude/skills/`.
