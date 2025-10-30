#!/usr/bin/env bash

# This script copies yazi plugins from a mac host to a Linux guest using SCP.
plugins=(
	Make.yazi
	audio.yazi
	bat.yazi
	chmod.yazi
	command.yazi
	httpview.yazi
	ipynb.yazi
	md.yazi
	nu.yazi
	okular.yazi
	seek.yazi
)

for plugin in "${plugins[@]}"; do
	echo "Copying $plugin to Linux guest..."
	scp -r "$HOME/.config/yazi/plugins/$plugin" dino@linux:~/.config/yazi/plugins/$plugin
done
