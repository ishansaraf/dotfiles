# dotfiles

Devbox config. `personalize` installs packages and links everything into place; the devbox
runs `~/personalize` (a symlink to it) on every launch.

Fresh box: `git clone <this repo> ~/dotfiles && ~/dotfiles/personalize`

Theme is Gruvbox Material Dark throughout (helix, tmux, fzf, delta, starship; bat/eza use the
terminal palette). The font is set on the laptop, not here: link `ghostty/config` to
`~/.config/ghostty/config` and install Monaspace (`brew install --cask font-monaspace`).

`zsh/completions/_bazel` is vendored from bazelbuild/bazel at 9.3.0 (`scripts/zsh_completion/_bazel`, Apache-2.0), plus a trailing `_bazel "$@"` call so the first Tab works.
