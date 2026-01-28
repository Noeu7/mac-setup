# vim: set ft=zsh :

#=============================
# 基本環境変数（locale）
#=============================
export LANG=ja_JP.UTF-8
export LC_CTYPE=ja_JP.UTF-8
# LC_ALL は強制しない（ツールの挙動が変わってハマることがあるため）
# 必要な時だけ: LC_ALL=C <command>

#=============================
# 履歴設定（統合）
#=============================
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt EXTENDED_HISTORY        # タイムスタンプ付き
setopt INC_APPEND_HISTORY      # 実行ごと即時追記
setopt SHARE_HISTORY           # 複数端末で共有
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS

#=============================
# カラー＆キーバインド
#=============================
autoload -Uz colors && colors
bindkey -e
bindkey '^R' history-incremental-pattern-search-backward

#=============================
# 補完とオプション
#=============================
autoload -Uz compinit
compinit -C

setopt NO_BEEP NO_FLOW_CONTROL IGNORE_EOF INTERACTIVE_COMMENTS
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS EXTENDED_GLOB
setopt MAGIC_EQUAL_SUBST

#=============================
# 改行を出力する関数（初回以外）
#=============================
function add_line {
  if [[ -z "${PS1_NEWLINE_LOGIN:-}" ]]; then
    PS1_NEWLINE_LOGIN=true
  else
    printf '\n'
  fi
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd add_line

#=============================
# PATH / Homebrew / arch / pyenv 整理
#=============================
# 既存で brew が alias 済みの場合に備えて解除（source時に死ぬのを防ぐ）
unalias brew 2>/dev/null

typeset -U path PATH
path=(
  /opt/homebrew/bin(N-/)   # Apple Silicon brew
  /usr/local/bin(N-/)      # Intel brew
  $path
)

# Load Homebrew env if available (sets PATH, MANPATH, etc.)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# pyenv (only if installed)
if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi

# brew wrapper: avoid pyenv shims interfering with brew
brew() {
  if command -v pyenv >/dev/null 2>&1; then
    env PATH="${PATH//$(pyenv root)\/shims:/}" command brew "$@"
  else
    command brew "$@"
  fi
}

# Intel Homebrew via Rosetta (Apple Silicon only, and only when needed)
ibrew() {
  if [[ "$(uname -s)" == "Darwin" && "$(uname -m)" == "arm64" ]] \
     && command -v arch >/dev/null 2>&1 \
     && [[ -x /usr/local/bin/brew ]]; then
    env PATH="${PATH//$(pyenv root)\/shims:/}" arch -arch x86_64 /usr/local/bin/brew "$@"
  else
    echo "ibrew is for Apple Silicon + Intel Homebrew (/usr/local/bin/brew)." >&2
    return 1
  fi
}

# Handy arch switchers (portable)
x64() { [[ "$(uname -m)" == "arm64" ]] && exec arch -arch x86_64 "$SHELL" || exec "$SHELL"; }
a64() { exec "$SHELL"; }

#=============================
# Android / JtR / gam
#=============================
# gam
gam() { "$HOME/bin/gam/gam" "$@"; }

# Android platform-tools
if [[ -d "$HOME/Library/Android/sdk/platform-tools" ]]; then
  export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"
fi

# John the Ripper (Homebrew cellar path is versioned; keep it best-effort)
if [[ -d "/opt/homebrew/Cellar/john-jumbo" ]]; then
  # latest version directory under john-jumbo
  jtr_dir="$(ls -1d /opt/homebrew/Cellar/john-jumbo/* 2>/dev/null | tail -n 1)"
  if [[ -n "${jtr_dir:-}" && -d "$jtr_dir/share/john" ]]; then
    export PATH="$jtr_dir/share/john:$PATH"
  fi
fi

#=============================
# エイリアス
#=============================
alias la='ls -a'
alias ll='ls -l'
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -p'

alias -g L='| less'
alias -g G='| grep'

if command -v pbcopy >/dev/null 2>&1; then
  alias -g C='| pbcopy'
elif command -v xsel >/dev/null 2>&1; then
  alias -g C='| xsel --input --clipboard'
elif command -v putclip >/dev/null 2>&1; then
  alias -g C='| putclip'
fi

#=============================
# OSごとのlsの色設定
#=============================
case "$OSTYPE" in
  darwin*) alias ls='ls -G -F' ;;
  linux*)  alias ls='ls -F --color=auto' ;;
esac

#=============================
# Zinit 初期化
#=============================
if [[ ! -f "$HOME/.local/share/zinit/zinit.git/zinit.zsh" ]]; then
  echo "Installing zinit..."
  mkdir -p "$HOME/.local/share/zinit"
  git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git"
fi
source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"

# Plugin: 補完機能強化
zinit light zsh-users/zsh-completions

# Plugin: 入力履歴からの補完候補（グレー文字）
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
zinit light zsh-users/zsh-autosuggestions

# Plugin: 入力時に構文の色付け
zinit light zsh-users/zsh-syntax-highlighting

#=============================
# プロンプト設定：日付・時刻付きシンプル表示
#=============================
PROMPT='%F{green}[%D{%Y-%m-%d %H:%M:%S}]%f %F{blue}%n@%m%f:%F{yellow}%~%f %# '
