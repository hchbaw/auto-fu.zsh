# zsh automatic complete-word and list-choices

# Originally incr-0.2.zsh
# Incremental completion for zsh
# by y.fujii <y-fujii at mimosa-pudica.net>

# Thank you very much y.fujii!

# Adapted by Takeshi Banse <takebi@laafc.net>
# I want to use it with menu selection.

# To use this,
# 1) establish `zle-line-init' containing `auto-fu-init' something like below
# % source auto-fu.zsh; zle-line-init () {auto-fu-init;}; zle -N zle-line-init
# 2) use the _oldlist completer something like below
# % zstyle ':completion:*' completer _oldlist _complete
# (If you have a lot of completer, please insert _oldlist before _complete.)

# XXX: use with the error correction or _match completer.
# If you got the correction errors during auto completing the word, then
# plese do _not_ do `magic-space` or `accept-line`. Insted please do the
# following, `undo` and then hit <tab> or throw away the buffer altogether.
# This applies _match completer with complex patterns, too.
# I'm very sorry for this annonying behaviour.
# (For example, 'ls --bbb' and 'ls --*~^*al*' etc.)

# TODO: handle RBUFFER.
# TODO: region_highlight, POSTDISPLAY and such should be zstyleable.
# TODO: signal handling during the recursive edit.
# TODO: add afu-viins/afu-vicmd keymaps.
# TODO: handle empty or space characters.

afu_zles=( \
  # Zles should be rebinded in the afu keymap. `auto-fu-maybe' to be called
  # after it's invocation, see `afu-initialize-zle-afu'.
  self-insert backward-delete-char backward-kill-word kill-line \
  kill-whole-line \
)

autoload +X keymap+widget

(( $+functions[keymap+widget-fu] )) || {
  local code=${functions[keymap+widget]/for w in *
	do
/for w in $afu_zles
  do
  }
  eval "function keymap+widget-fu () { $code }"
}

(( $+functions[afu-boot] )) ||
afu-boot () {
  {
    bindkey -M isearch "^M" afu+accept-line

    bindkey -N afu emacs
    keymap+widget-fu
    bindkey -M afu "^I" afu+complete-word
    bindkey -M afu "^M" afu+accept-line
    bindkey -M afu "^J" afu+accept-line
    bindkey -M afu "^O" afu+accept-line-and-down-history
    bindkey -M afu "^[a" afu+accept-and-hold
    bindkey -M afu "^X^[" afu+vi-cmd-mode

    bindkey -N afu-vicmd vicmd
    bindkey -M afu-vicmd  "i" afu+vi-ins-mode
  } always { "$@" }
}
(( $+functions[afu+vi-ins-mode] )) ||
(( $+functions[afu+vi-cmd-mode] )) || {
afu+vi-cmd-mode () { zle -K afu-vicmd; }; zle -N afu+vi-cmd-mode
afu+vi-ins-mode () { zle -K afu      ; }; zle -N afu+vi-ins-mode
}

{ #(( ${#${(@M)keymaps:#afu}} )) || afu-boot bindkey -e
  #afu-boot bindkey -e
  afu-boot
} >/dev/null 2>&1

local -a afu_accept_lines

afu-recursive-edit-and-accept () {
  local -a __accepted
  zle recursive-edit -K afu || { zle send-break; return }
  #if [[ ${__accepted[0]} != afu+accept* ]]
  if (( ${#${(M)afu_accept_lines:#${__accepted[0]}}} ))
  then zle "${__accepted[@]}"; return
  else return 0
  fi
}

afu-register-zle-accept-line () {
  local afufun="$1"
  local rawzle=".${afufun#*+}"
  local code=${"$(<=(cat <<"EOT"
  $afufun () {
    __accepted=($WIDGET ${=NUMERIC:+-n $NUMERIC} "$@")
    zle $rawzle && region_highlight=("0 ${#BUFFER} bold")
    return 0
  }
  zle -N $afufun
EOT
  ))"}
  eval "${${code//\$afufun/$afufun}//\$rawzle/$rawzle}"
  afu_accept_lines+=$afufun
}
afu-register-zle-accept-line afu+accept-line
afu-register-zle-accept-line afu+accept-line-and-down-history
afu-register-zle-accept-line afu+accept-and-hold
afu-register-zle-accept-line afu+run-help

# Entry point.
auto-fu-init () {
  {
    local -a region_highlight
    local afu_in_p=0
    POSTDISPLAY=$'\n-azfu-'
    afu-recursive-edit-and-accept
    zle -I
  } always {
    POSTDISPLAY=''
  }
}
zle -N afu

afu-clearing-maybe () {
  region_highlight=()
  if ((afu_in_p == 1)); then
    [[ "$BUFFER" != "$buffer_new" ]] || ((CURSOR != cursor_cur)) &&
    { afu_in_p=0 }
  fi
}

with-afu () {
  local zlefun="$1"
  afu-clearing-maybe
  ((afu_in_p == 1)) && { afu_in_p=0; BUFFER="$buffer_cur" }
  zle $zlefun && auto-fu-maybe
}

afu-register-zle-afu () {
  local afufun="$1"
  local rawzle=".${afufun#*+}"
  eval "function $afufun () { with-afu $rawzle; }; zle -N $afufun"
}

(( $+functions[afu-initialize-zle-afu] )) ||
afu-initialize-zle-afu () {
  local z
  for z in $afu_zles ;do
    afu-register-zle-afu afu+$z
  done
}
afu-initialize-zle-afu

afu+magic-space () {
  afu-clearing-maybe
  if [[ "$LASTWIDGET" == magic-space ]]; then
    LBUFFER+=' '
  else zle .magic-space && {
    # zle list-choices
  }
  fi
}
zle -N afu+magic-space

afu-able-p () {
  local c=$LBUFFER[-1]
  local ret=0
  case $c in
    (| |.|~|\^|\)) ret=1 ;;
  esac
  return $ret
}

auto-fu-maybe () {
  (($PENDING== 0)) && { afu-able-p } && [[ $LBUFFER != *$'\012'*  ]] &&
  { auto-fu }
}

auto-fu () {
  emulate -L zsh
  unsetopt rec_exact
  local LISTMAX=999999

  cursor_cur="$CURSOR"
  buffer_cur="$BUFFER"
  comppostfuncs=(afu-k)
  zle complete-word
  cursor_new="$CURSOR"
  buffer_new="$BUFFER"
  if [[ "$buffer_cur[1,cursor_cur]" == "$buffer_new[1,cursor_cur]" ]];
  then
    CURSOR="$cursor_cur"
    region_highlight=("$CURSOR $cursor_new fg=black,bold")

    if [[ "$buffer_cur" != "$buffer_new" ]] || ((cursor_cur != cursor_new))
    then afu_in_p=1; {
      local BUFFER="$buffer_cur"
      local CURSOR="$cursor_cur"
      zle list-choices
    }
    fi
  else
    BUFFER="$buffer_cur"
    CURSOR="$cursor_cur"
    zle list-choices
  fi
}
zle -N auto-fu

function afu-k () {
  ((compstate[list_lines] + BUFFERLINES + 2 > LINES)) && { 
    compstate[list]=''
    zle -M "$compstate[list_lines]($compstate[nmatches]) too many matches..."
  }
}

afu+complete-word () {
  afu-clearing-maybe
  { afu-able-p } || { zle complete-word; return; }

  comppostfuncs=(afu-k)
  if ((afu_in_p == 1)); then
    afu_in_p=0; CURSOR="$cursor_new"
    case $LBUFFER[-1] in
      (=) # --prefix= ⇒ complete-word again for `magic-space'ing the suffix
        zle complete-word ;;
      (/) # path-ish  ⇒ propagate auto-fu
        zle complete-word; zle -U "$LBUFFER[-1]" ;;
      (,) # glob-ish  ⇒ activate the `complete-word''s suffix
        BUFFER="$buffer_cur"; zle complete-word ;;
      (*) ;;
    esac
  else
    [[ $LASTWIDGET == afu+* ]] && {
      afu_in_p=0; BUFFER="$buffer_cur"
    }
    zle complete-word
  fi
}
zle -N afu+complete-word

unset afu_zles
