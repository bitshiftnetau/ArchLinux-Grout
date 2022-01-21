#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias tlmgr='/usr/bin/tllocalmgr'
alias clear='/usr/bin/clear && /usr/bin/neofetch'
PS1='[\W]\$ '
