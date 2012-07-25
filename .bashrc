# If not running interactively, don't do anything
[[ $- != *i* ]] && return

PS1='\[\e[0;31m\]\A\[\e[0;31m\][ \W ]\[\e[0;37m\]: \[\e[0m\]'

PATH=$PATH:/home/jd/.bin:
export PATH

if [ -x /usr/bin/dircolors ]; then
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Use up and down arrow to search the history
bind '"\e[A"':history-search-backward
bind '"\e[B"':history-search-forward

alias cc="clear"
alias rr="reset"
alias lsl="ls -l"
alias lsa="ls -la"
alias nano="nano -wxz"
alias pacs="pacsearch.sh"
alias pacg="sudo pacman -S"
alias paci="sudo pacman -Si"
alias pacup="sudo pacman -Syu"
alias wi="wicd-curses"

function sslcrypt {
  item=$(echo $1 | sed -e 's/\/$//') # get rid of trailing / on directories

  if [ ! -r $item ]; then
    exit 1;
  fi

  if [ -d $item ]; then
    tar zcf "${item}.tar.gz" "${item}"
    openssl enc -aes-256-cbc -a -salt -in "${item}.tar.gz" -out "${item}.tar.gz.ssl"
    rm -f "${item}.tar.gz"
  else
    openssl enc -aes-256-cbc -a -salt -in "${item}" -out "${item}.ssl"
  fi
}

function ssldecrypt {
  item=$1

  if [ ! -r $item ]; then
    exit 1;
  fi

  openssl enc -d -a -aes-256-cbc -in "${item}" > "${item}.decrypted"
}
