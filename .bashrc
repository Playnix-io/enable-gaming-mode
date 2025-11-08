#
# ~/.bashrc
#

sudo -S pacman -Syu --noconfirm

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ll='ls -la --color=auto'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
