# zsh automatic complete-word and list-choices

# Originally incr-0.2.zsh
# Incremental completion for zsh
# by y.fujii <y-fujii at mimosa-pudica.net>

# Thank you very much y.fujii!

# Adapted by Takeshi Banse <takebi@laafc.net>
# I want to use it with menu selection.

# To use this,
# 1) source this file.
# % source auto-fu.zsh
# 2) establish `zle-line-init' containing `auto-fu-init' something like below.
# % zle-line-init () {auto-fu-init;}; zle -N zle-line-init
# 3) use the _oldlist completer something like below.
# % zstyle ':completion:*' completer _oldlist _complete
# (If you have a lot of completer, please insert _oldlist before _complete.)
#
# *Optionally* you can use the zcompiled file for a little faster loading on
# every shell startup, if you zcompile the necessary functions.
# *1) zcompile the defined functions. (generates ~/.zsh/auto-fu.zwc)
# % A=/path/to/auto-fu.zsh; (zsh -c "source $A ; auto-fu-zcompile $A ~/.zsh")
# *2) source the zcompiled file instead of this file and some tweaks.
# % source ~/.zsh/auto-fu; auto-fu-install
# *3) establish `zle-line-init' and such (same as a few lines above).
# Note:
# It is approximately *(6~10) faster if zcompiled, according to this result :)
# TIMEFMT="%*E %J"
# 0.041 ( source ./auto-fu.zsh; )
# 0.004 ( source ~/.zsh/auto-fu; auto-fu-install; )

# Configuration
# The auto-fu features can be configured via zstyle.
# :auto-fu:highlight
#   input
#     A highlight specification used for user input string.
#   completion
#     A highlight specification used for completion string.
# :auto-fu:var
#   postdisplay
#     An initial indication string for POSTDISPLAY in auto-fu-init.
# Configuration example
# -- >8 --
# zstyle ':auto-fu:highlight' input bold
# zstyle ':auto-fu:highlight' completion fg=black,bold
# zstyle ':auto-fu:var' postdisplay $'\n-azfu-'
# -- 8< --

# XXX: use with the error correction or _match completer.
# If you got the correction errors during auto completing the word, then
# plese do _not_ do `magic-space` or `accept-line`. Insted please do the
# following, `undo` and then hit <tab> or throw away the buffer altogether.
# This applies _match completer with complex patterns, too.
# I'm very sorry for this annonying behaviour.
# (For example, 'ls --bbb' and 'ls --*~^*al*' etc.)

# TODO: http://d.hatena.ne.jp/tarao/20100531/1275322620
# TODO: handle RBUFFER.
# TODO: signal handling during the recursive edit.
# TODO: add afu-viins/afu-vicmd keymaps.
# TODO: handle empty or space characters.
# TODO: cp x /usr/
# TODO: region_highlight vs afu-able-p → nil

# History

# v0.0.1.1
# Documentation typo fix.

# v0.0.1
# Initial version.

afu_zles=( \
  # Zle widgets should be rebinded in the afu keymap. `auto-fu-maybe' to be
  # called after it's invocation, see `afu-initialize-zle-afu'.
  self-insert backward-delete-char backward-kill-word kill-line \
  kill-whole-line \
)

autoload +X keymap+widget

{
  local code=${functions[keymap+widget]/for w in *
	do
/for w in $afu_zles
  do
  }
  eval "function afu-keymap+widget () { $code }"
}

afu-install () {
  bindkey -M isearch "^M" afu+accept-line

  bindkey -N afu emacs
  { "$@" }
  bindkey -M afu "^I" afu+complete-word
  bindkey -M afu "^M" afu+accept-line
  bindkey -M afu "^J" afu+accept-line
  bindkey -M afu "^O" afu+accept-line-and-down-history
  bindkey -M afu "^[a" afu+accept-and-hold
  bindkey -M afu "^X^[" afu+vi-cmd-mode

  bindkey -N afu-vicmd vicmd
  bindkey -M afu-vicmd  "i" afu+vi-ins-mode
}

afu+vi-ins-mode () { zle -K afu      ; }; zle -N afu+vi-ins-mode
afu+vi-cmd-mode () { zle -K afu-vicmd; }; zle -N afu+vi-cmd-mode

afu-install afu-keymap+widget
function () {
  [[ -z $AUTO_FU_NOCP ]] || return
  # For backward compatibility
  zstyle ':auto-fu:highlight' input bold
  zstyle ':auto-fu:highlight' completion fg=black,bold
  zstyle ':auto-fu:var' postdisplay $'\n-azfu-'
}

declare -a afu_accept_lines

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
    zle $rawzle && {
      local hi
      zstyle -s ':auto-fu:highlight' input hi
      [[ -z ${hi} ]] || region_highlight=("0 ${#BUFFER} ${hi}")
    }
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

# Entry point.
auto-fu-init () {
  local auto_fu_init_p=1
  local ps
  {
    local -a region_highlight
    local afu_in_p=0

    zstyle -s ':auto-fu:var' postdisplay ps
    [[ -z ${ps} ]] || POSTDISPLAY="$ps"

    afu-recursive-edit-and-accept
    zle -I
  } always {
    [[ -z ${ps} ]] || POSTDISPLAY=''
  }
}
zle -N auto-fu-init

# Entry point.
auto-fu-on  () { with-afu-gvars zle -K afu   }; zle -N auto-fu-on
auto-fu-off () { with-afu-gvars zle -K emacs }; zle -N auto-fu-off # emacs...?
with-afu-gvars () {
  (( auto_fu_init_p == 1 )) && {
    zle -M "Sorry, can't turn on or off if auto-fu-init is in effect."; return
  }
  typeset -g afu_in_p=0
  region_highlight=()
  "$@"
}

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
  [[ $c == ''  ]] && return 1;
  [[ $c == ' ' ]] && return 1;
  [[ $c == '.' ]] && return 1;
  [[ $c == '^' ]] && return 1;
  [[ $c == '~' ]] && return 1;
  [[ $c == ')' ]] && return 1;
  return 0
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
    {
      local hi
      zstyle -s ':auto-fu:highlight' completion hi
      [[ -z ${hi} ]] || region_highlight=("$CURSOR $cursor_new ${hi}")
    }

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

[[ -z $afu_zcompiling_p ]] && unset afu_zles

# NOTE: This is iffy. It dumps the necessary functions into ~/.zsh/auto-fu,
# then zrecompiles it into ~/.zsh/auto-fu.zwc.

afu-clean () {
  local d=${1:-~/.zsh}
  rm -f ${d}/{auto-fu,auto-fu.zwc*(N)}
}

afu-install-installer () {
  local match mbegin mend

  eval ${${${"$(<=(cat <<"EOT"
    auto-fu-install () {
      { $body }
      afu-install
      typeset -ga afu_accept_lines
      afu_accept_lines=($afu_accept_lines)
    }
EOT
  ))"}/\$body/
    $(print -l \
      "# afu's all zle widgets expect own keymap+widgets stuff" \
      ${${${(M)${(@f)"$(zle -l)"}:#(afu+*|auto-fu*)}:#(\
        ${(j.|.)afu_zles/(#b)(*)/afu+$match})}/(#b)(*)/zle -N $match} \
      "# keymap+widget machinaries" \
      ${afu_zles/(#b)(*)/zle -N $match ${match}-by-keymap} \
      ${afu_zles/(#b)(*)/zle -N afu+$match})}/
      \$afu_accept_lines/$afu_accept_lines}
}

auto-fu-zcompile () {
  local afu_zcompiling_p=t

  local s=${1:?Please specify the source file itself.}
  local d=${2:?Please specify the directory for the zcompiled file.}
  local g=${d}/auto-fu
  emulate -L zsh
  setopt extended_glob no_shwordsplit

  echo "** zcompiling auto-fu in ${d} for a little faster startups..."
  { source ${s} >/dev/null 2>&1 } # Paranoid.
  echo "mkdir -p ${d}" | sh -x
  afu-clean ${d}
  afu-install-installer
  echo "* writing code ${g}"
  {
    local -a fs
    : ${(A)fs::=${(Mk)functions:#(*afu*|*auto-fu*|*-by-keymap)}}
    echo "#!zsh"
    echo "# NOTE: Generated from auto-fu.zsh ($0). Please DO NOT EDIT."; echo
    echo "$(functions \
      ${fs:#(afu-register-*|afu-initialize-*|afu-keymap+widget|\
        afu-clean|afu-install-installer|auto-fu-zcompile)})"
  }>! ${d}/auto-fu
  echo -n '* '; autoload -U zrecompile && zrecompile -p -R ${g} && {
    zmodload zsh/datetime
    touch --date="$(strftime "%F %T" $((EPOCHSECONDS - 120)))" ${g}
    [[ -z $AUTO_FU_ZCOMPILE_NOKEEP ]] || { echo "rm -f ${g}" | sh -x }
    echo "** All done."
    echo "** Please update your .zshrc to load the zcompiled file like this,"
    cat <<EOT
-- >8 --
## auto-fu.zsh stuff.
# source ${s/$HOME/~}
{ . ${g/$HOME/~}; auto-fu-install; }
zstyle ':auto-fu:highlight' input bold
zstyle ':auto-fu:highlight' completion fg=black,bold
zstyle ':auto-fu:var' postdisplay $'\n-azfu-'
zle-line-init () {auto-fu-init;}; zle -N zle-line-init
-- 8< --
EOT
  }
}
