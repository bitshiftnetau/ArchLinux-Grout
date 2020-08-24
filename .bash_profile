#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

# If user ID is greater than or equal to 1000 & if ~/bin exists and is a directory & if ~/bin is not already in your $PATH
# then export ~/bin to your $PATH.
if [[ $UID -ge 1000 && -d $HOME/.config && -z $(echo $XDG_CONFIG_HOME | grep -o $HOME/.config) ]]
then
    export XDG_CONFIG_HOME="$HOME/.config"
fi

# if something about Display and XDG??? then startx and keeptty, also send the output somewhere else to make it quiet.
if [[ ! $DISPLAY && $XDG_VTNR -eq 1 ]]; then 
	exec startx -- -keeptty > ~/.xorg.log 2>&1 
fi

export PATH=$PATH:/home/access/.gem/ruby/2.6.0/bin
transmission-daemon
