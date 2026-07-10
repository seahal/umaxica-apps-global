#
# This file is intentionally lightweight; it simply serves as the bind-mount
# target for devcontainers so that /home/global/.bashrc is always a file.
# Add personal shell customizations here if needed.

export PATH="$HOME/.local/bin:$PATH"
export HISTFILE="$HOME/workspace/docker/core/preferences/.bash_history"
export HISTSIZE=50000
export HISTFILESIZE=100000
export HISTCONTROL=ignoreboth:erasedups
export HISTIGNORE='ls:ll:cd:pwd:exit'
export HISTTIMEFORMAT='%F %T '
shopt -s histappend
shopt -s checkwinsize
shopt -s cmdhist

PROMPT_COMMAND='history -a; history -n'
