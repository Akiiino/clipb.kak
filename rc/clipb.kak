#    _________       ____
#   / ____/ (_)___  / __ )
#  / /   / / / __ \/ __  |
# / /___/ / / /_/ / /_/ /
# \____/_/_/ .___/_____/
#         /_/

# File:             clipb.kak
# Description:      Clipboard managers warper for Kakoune
# Original author:  Zach Peltzer
#                   └─ https://github.com/lePerdu
# Fork maintainer:  NNB
#                   └─ https://github.com/NNBnh
# URL:              https://github.com/NNBnh/clipb.kak
# License:          GPLv3

#    Permission is hereby granted, free of charge, to any person obtaining a copy
#    of this software and associated documentation files (the "Software"), to deal
#    in the Software without restriction, including without limitation the rights
#    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#    copies of the Software, and to permit persons to whom the Software is
#    furnished to do so, subject to the following conditions:
#
#    The above copyright notice and this permission notice shall be included in all
#    copies or substantial portions of the Software.
#
#    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#    SOFTWARE.

# Functions
define-command clipb-detect -docstring 'detect clipboard command' %{
	evaluate-commands %sh{
		case $(uname -s | tr '[:upper:]' '[:lower:]') in
			'cygwin')
				 copy_command='tee /dev/clipboard 2>&-'
				paste_command='cat /dev/clipboard'
			;;
			'darwin'*)
				 copy_command='pbcopy'
				paste_command='pbpaste'
			;;
			*)
				if [ -n "$WAYLAND_DISPLAY" ]; then
					if [ -x "$(command -v wl-copy)" ] && [ -x "$(command -v wl-paste)" ]; then
						 copy_command='wl-copy'
						paste_command='wl-paste --no-newline'
					else
						printf '%s\n%s' "echo -debug \"clipb.kak: can't interact with Wayland's clipboard\"" \
						                "echo -debug \"please install 'wl-clipboard'\""

						exit 1
					fi
				elif [ -n "$DISPLAY" ]; then
					if [ -x "$(command -v xclip)" ]; then
						 copy_command='xclip -in  -selection clipboard'
						paste_command='xclip -out -selection clipboard'
					elif [ -x "$(command -v xsel)" ]; then
						 copy_command='xsel --input  --clipboard'
						paste_command='xsel --output --clipboard'
					else
						printf '%s\n%s' "echo -debug \"clipb.kak: can't interact with Xorg's clipboard\"" \
						                "echo -debug \"please install 'xclip' or 'xsel'\""

						exit 1
					fi
				else
					if [ -x "$(command -v termux-clipboard-set)" ]; then
						 copy_command='termux-clipboard-set'
						paste_command='termux-clipboard-get'
					else
						printf '%s' "echo -debug \"clipb.kak: this system is not supported\""

						exit 1
					fi
				fi
			;;
		esac

		printf '%s\n%s' "set-option global clipb_set_command '$copy_command'" \
		                "set-option global clipb_get_command '$paste_command'"
	}
}

define-command clipb-set -docstring 'set system clipboard from the " register' %{
	clipb-disable
	echo -debug "disabled in set"
	try %{
		nop %sh{
			if [ "$kak_opt_clipb_multiple_selections" = 'true' ]; then
				clipboard="$kak_reg_dquote"
			else
				clipboard="$kak_main_reg_dquote"
			fi

			printf '%s' "$clipboard" | eval "$kak_opt_clipb_set_command" >/dev/null 2>&1 &
		}
		echo -debug "set"
	}
	clipb-enable
	echo -debug "undisabled in set"
}

define-command clipb-get -docstring 'get system clipboard into the " register' %{
	clipb-disable
	echo -debug "disabled in get"
	try %{
		set-register dquote %sh{ eval "$kak_opt_clipb_get_command" }
		echo -debug "got"
	}
	clipb-enable
	echo -debug "undisabled in get"

}

define-command clipb-enable -docstring 'enable clipb' %{
	echo -debug "enabled"
	hook -group 'clipb' global WinCreate        .* %{ echo -debug "WinCreate firing"
	clipb-get }
	hook -group 'clipb' global FocusIn          .* %{ echo -debug "FocusIn firing"
	clipb-get }
	hook -group 'clipb' global RegisterModified \" %{ echo -debug "RegisterModified firing"
	clipb-set }
}

define-command clipb-disable -docstring 'disable clipb' %{
	echo -debug "disabled"
	remove-hooks global 'clipb'
}

define-command clipb-pause -hidden -docstring 'temporarily disable clipb' %{
	echo -debug "paused"
	declare-option -hidden str clipb_saved_disabled_hooks %opt{disabled_hooks}
	evaluate-commands %sh{
	    if [ -z "$kak_opt_disabled_hooks" ]; then
	        echo "set-option global disabled_hooks 'clipb'"
	    else
	        echo "set-option global disabled_hooks '($kak_opt_disabled_hooks|clipb)'"
	    fi
	}
}

define-command clipb-resume -hidden -docstring 'reenable temporarily disabled clipb' %{
	echo -debug "unpaused"
	set-option global disabled_hooks %opt{clipb_saved_disabled_hooks}
}


# Values
declare-option -docstring 'command to copy to clipboard'    str clipb_set_command 'clipb copy'
declare-option -docstring 'command to paste from clipboard' str clipb_get_command 'clipb paste'

declare-option -docstring 'multiple selections copy to clipboard feature' bool clipb_multiple_selections 'false'

clipb-detect
