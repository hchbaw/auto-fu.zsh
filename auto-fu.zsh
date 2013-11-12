# zsh automatic complete-word and list-choices

# Originally incr-0.2.zsh
# Incremental completion for zsh
# by y.fujii <y-fujii at mimosa-pudica.net>

# Thank you very much y.fujii!

# Adapted by Takeshi Banse <takebi@laafc.net>, public domain
# I want to use it with menu selection.

# To use this,
# 1) source this file.
# % source auto-fu.zsh
# 2) establish `zle-line-init' containing `auto-fu-init' something like below.
# % zle-line-init () {auto-fu-init;}; zle -N zle-line-init
# 3) use the _oldlist completer something like below.
# % zstyle ':completion:*' completer _oldlist _complete
# (If you have a lot of completer, please insert _oldlist before _complete.)
# 4) establish `zle-keymap-select' containing `auto-fu-zle-keymap-select'.
# % zle -N zle-keymap-select auto-fu-zle-keymap-select
# (This enables the afu-vicmd keymap switching coordinates a bit.)
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
# Here is the auto-fu-zcompile manual.
# --- >8 ---
# NAME
#        auto-fu-zcompile - zcompile auto-fu
#
# SYNOPSIS
#        auto-fu-zcompile <auto-fu.zsh file> <directory to output>
#               [<restoffiles>...]
#
# DESCRIPTION
#        This command dumps out the auto-fu's functions, zle and stuff to
#        <directory to output>/auto-fu. This is inspired from `compinit' which
#        dumps out the completion system's internal stuff to ~/.zcompdump.
#        Then `zrecompile' the <directory to output>/auto-fu.
#        As you can see, auto-fu.zsh has some `eval' calls, so it may result
#        poor loading performance. I want to avoid that as far as possible, so
#        the resulting file (~/.zsh/auto-fu) has fewer `eval's and stripped
#        unnecessary things at runtime.
#        afu+* and auto-fu* widgets and afu+* functions will *NOT* be
#        stripped by auto-fu-zcompile.
#
# OPTIONS
#        <auto-fu.zsh file>
#            This file.
#
#        <directory to output>
#            Directory to dumped and zcompiled files reside.
#
#        [<restoffile>...]
#            Files to be `source'ed right before the dumped file creation.
#            auto-fu-zcompile will strip unnecessary stuff, so some utility
#            shell functions will not be available at runtime. If you want
#            to customize auto-fu stuff using auto-fu.zsh's internal
#            functions, you can code it at this point (example below).
#
# EXAMPLES
#        .   zcompile auto-fu in ~/.zsh.d:
#
#                % A=/path/to/auto-fu.zsh
#                % (zsh -c "source $A ; auto-fu-zcompile $A ~/.zsh.d")
#
#        .   Customize some not-easily-customizable things:
#
#                % A=/path/to/auto-fu.zsh
#                % (zsh -c "source $A ; \
#                  auto-fu-zcompile $A ~/.zsh.d ~/.zsh/auto-fu-customize.zsh")
#
#            '~/.zsh/auto-fu-customize.zsh' is something like this:
#>
#              afu+my-kill-line-maybe () {
#                if (($#BUFFER > CURSOR));
#                then zle kill-line
#                else zle kill-whole-line
#                fi
#              }
#              zle -N afu+my-kill-line-maybe
#
#              afu-register-zle-eof \
#                afu+orf-ignoreeof-deletechar-list \
#                afu-ignore-eof afu+my-kill-line-maybe
#              afu-register-zle-eof \
#                afu+orf-exit-deletechar-list exit afu+my-kill-line-maybe
#<
#            Using `afu-register-zle-eof' to customize the <C-d> behaviors.
# --- 8< ---

# Configuration
# The auto-fu features can be configured via zstyle.

# :auto-fu:highlight
#   input
#     A highlight specification used for user input string.
#   completion
#     A highlight specification used for completion string.
#   completion/one
#     A highlight specification used for completion string if it is the
#     only one candidate.
# :auto-fu:var
#   postdisplay
#     An initial indication string for POSTDISPLAY in auto-fu-init.
#   postdisplay/clearp
#     If set, POSTDISPLAY will be cleared after the accept-lines.
#     'yes' by default.
#   enable
#     A list of zle widget names the automatic complete-word and
#     list-choices to be triggered after its invocation.
#     Only with ALL in 'enable', the 'disable' style has any effect.
#     ALL by default.
#   disable
#     A list of zle widget names you do *NOT* want the complete-word to be
#     triggered. Only used if 'enable' contains ALL. For example,
#       zstyle ':auto-fu:var' enable all
#       zstyle ':auto-fu:var' disable magic-space
#     yields; complete-word will not be triggered after pressing the
#     space-bar, otherwise automatic thing will be taken into account.
#   track-keymap-skip
#     A list of keymap names to *NOT* be treated as a keymap change.
#     In other words, these keymaps cannot be used with the standalone main
#     keymap. For example "opp". If you use my opp.zsh, please add an 'opp'
#     to this zstyle.
#   autoable-function/skipwords
#   autoable-function/skiplbuffers
#   autoable-function/skiplines
#     A list of patterns to *NOT* be treated as auto-stuff appropriate.
#     These patterns will be tested against the part of the command line
#     buffer as shown on the below figure:
#     (*) is used to denote the cursor position.
#
#       # nocorrect aptitude --assume-*yes -d install zsh && echo ready
#                            <-------->skipwords
#                   <----------------->skiplbuffers
#                   <----------------------------------->skplines
#
#     Examples:
#     - To disable auto-stuff inside single and also double quotes.
#       And less than 3 chars before the cursor.
#       zstyle ':auto-fu:var' autoable-function/skipwords \
#         "('|$'|\")*" "^((???)##)"
#
#     - To disable the rm's first option, and also after the '(cvs|svn) co'.
#       zstyle ':auto-fu:var' autoable-function/skiplbuffers \
#         'rm -[![:blank:]]#' '(cvs|svn) co *'
#
#     - To disable after the 'aptitude word '.
#       zstyle ':auto-fu:var' autoable-function/skiplines \
#         '([[:print:]]##[[:space:]]##|(#s)[[:space:]]#)aptitude [[:print:]]# *'
#   autoable-function/preds
#     A list of functions to be called whether auto-stuff appropriate or not.
#     These functions will be called with the arguments (above figure)
#       - $1 '--assume-'
#       - $2 'aptitude'
#       - $3 'aptitude --assume-'
#       - $4 'aptitude --assume-yes -d install zsh'
#     For example,
#     to disable some 'perl -M' thing, we can do by the following zsh codes.
#>
#       afu-autoable-pm-p () { [[ ! ("$2" == 'perl' && "$1" == -(#i)m*) ]] }
#
#       # retrieve default value into 'preds' to push the above function into.
#       local -a preds; afu-autoable-default-functions preds
#       preds+=afu-autoable-pm-p
#
#       zstyle ':auto-fu:var' autoable-function/preds $preds
#<
#     The afu-autoable-dots-p is actually an example of this ability to skip
#     uninteresting dots.
#   autoablep-function
#     A predicate function to determine whether auto-stuff could be
#     appropriate. (Default `auto-fu-default-autoable-pred' implements the
#     above autoablep-function/* functionality.)
#
# Configuration example

# zstyle ':auto-fu:highlight' input bold
# zstyle ':auto-fu:highlight' completion fg=black,bold
# zstyle ':auto-fu:highlight' completion/one fg=white,bold,underline
# zstyle ':auto-fu:var' postdisplay $'\n-azfu-'
# zstyle ':auto-fu:var' track-keymap-skip opp
# #zstyle ':auto-fu:var' disable magic-space

# XXX: use with the error correction or _match completer.
# If you got the correction errors during auto completing the word, then
# plese do _not_ do `magic-space` or `accept-line`. Insted please do the
# following, `undo` and then hit <tab> or throw away the buffer altogether.
# This applies _match completer with complex patterns, too.
# I'm very sorry for this annonying behaviour.
# (For example, 'ls --bbb' and 'ls --*~^*al*' etc.)

# XXX: ignoreeof semantics changes for overriding ^D.
# You cannot change the ignoreeof option interactively. I'm verry sorry.
# To customize the ^D behavior further, it will be done for example above
# auto-fu-zcomple manual's EXAMPLE section's code. Please take a look.

# XXX: zsh-syntax-highlighting
# I'm a very fond of this fancy zsh script `zsh-syntax-highlighting'.
# https://github.com/nicoulaj/zsh-syntax-highlighting
# If you want to integrate auto-fu.zsh with zsh-syntax-highlighting,
# please source zsh-syntax-highlighting before this file.

# XXX: use with the url-quote-magic, select-word-style and more.
# Please set up url-quote-magic and select-word-style before sourcing
# auto-fu.zsh.
#
# If you zcompile auto-fu.zsh with auto-fu-zcompile, it will likely not be
# known the presence of these contrib's widgets at the zcompile-time. In
# this case for example to use with url-quote-magic, please set the variable
# AUTO_FU_ZCOMPILE_URLQUOTEMAGIC=t at the zcompile-time.
# AUTO_FU_ZCOMPILE_* variables will be checked to see if the corresponding
# widget should be set up to use with at the zcompile-time. For example, to
# use with 'kill-word-match' widget, AUTO_FU_ZCQMPILE_KILLWORDMATCH=t shoud
# be specified at that time.
# Note: AUTO_FU_ZCOMPILE_* variable naming scheme is "${(U)widgetname//-/}".
# Also AUTO_FU_ZCOMPILE_ZLECONTRIB=t will be checked to see if all those
# well-known contrib widgets should be used with.
# For now,
# url-quote-magic, kill-word-match and backword-kill-word-match
# are supported. In other words, I use them :)
# For example to zcompile all those contrib's widgets to be used with,
# please do the following:
#>
#    % A=/path/to/auto-fu.zsh; (zsh -c "source $A && AUTO_FU_ZCOMPILE_ZLECONTRIB=t && auto-fu-zcompile $A ~/.zsh")
#<
# If you replace 'AUTO_FU_ZCOMPILE_ZLECONTRIB=t' to
# 'AUTO_FU_ZCOMPILE_URLQUOTEMAGIC=t', only url-quote-magic will to be used.
# If you want to use some more customized widgets which are not in the
# above, you could define some functions to cooperate with those widgets and
# push them to AUTO_FU_INITIALIZE.

# XXX: use with both zsh-syntax-highlighting and url-quote-magic,
# select-word-style and more.
# To detect url-quote-magic and select-word-style (and some other), please
# source zsh-syntax-highlighting after all those contrib widgets but before
# auto-fu.zsh;
# (1) source and setup url-quote-magic and select-word-style,
# (2) source zsh-syntax-highlighting and
# (3) source auto-fu.zsh at the end, please.
# Please keep the order intact.

# TODO: http://d.hatena.ne.jp/tarao/20100531/1275322620
# TODO: pause auto stuff until something happens. ("next magic-space" etc)
# TODO: handle RBUFFER.
# TODO: signal handling during the recursive edit.
# TODO: handle empty or space characters.
# TODO: cp x /usr/loc
# TODO: region_highlight vs afu-able-p → nil
# Do *NOT* clear the region_highlight if it should.
# TODO: ^C-n could be used as the menu-select-key outside of the menuselect.
# TODO: *-directories|all-files may not be enough.
# TODO: recommend zcompiling.
# TODO: undo should reset the auto stuff's state.
# TODO: when `_match`ing,
# sometimes extra <TAB> key is needed to enter the menu select,
# sometimes is *not* needed. (already be entered menu select state.)

# History

# v0.0.1.12
# fix some options potentially will be reset during the auto-stuff.
# fix afu-keymap+widget to $afu_zles work in custom widgets.
# Thank you very much for the reports, Christian271!

# v0.0.1.11
# play nice with banghist.
# Thank you very much for the report, yoshikaw!
# add autoablep-function machinery.
# Thank you very much for the suggestion, tyru and kei_q!

# v0.0.1.10
# Fix not work auto-thing without extended_glob.
# Thank you very much for the report, myuhe!

# v0.0.1.9
# add auto-fu-activate, auto-fu-deactivate and auto-fu-toggle.

# v0.0.1.8.3
# in afu+complete-word PAGER=<TAB> ⇒ PAGER=PAGER= bug fix.
# Thank you very much for the report, tyru!

# v0.0.1.8.2
# afu+complete-word bug fixes.

# v0.0.1.8.1
# README.md

# v0.0.1.8
# add completion/one and postdisplay/clearp configurations.
# add kill-word and yank to afu_zles.

# v0.0.1.7
# Fix "no such keymap `isearch'" error.
# Thank you very much for the report, mooz and Shougo!

# v0.0.1.6
# Fix `parameter not set`. Thank you very much for the report, Shougo!
# Bug fix.

# v0.0.1.5
# afu+complete-word bug (directory vs others) fix.

# v0.0.1.4
# afu+complete-word bug fixes.

# v0.0.1.3
# Teach ^D and magic-space.

# v0.0.1.2
# Add configuration option and auto-fu-zcompile for a little faster loading.

# v0.0.1.1
# Documentation typo fix.

# v0.0.1
# Initial version.

# Code

afu_zles=( \
  # Zle widgets should be rebinded in the afu keymap. `auto-fu-maybe' to be
  # called after it's invocation, see `afu-initialize-zle-afu'.
  self-insert backward-delete-char backward-kill-word kill-line \
  kill-whole-line kill-word magic-space yank \
)

afu-install () {
  zstyle -t ':auto-fu:var' misc-installed-p || {
    zmodload zsh/parameter 2>/dev/null || {
      echo 'auto-fu:zmodload error. exiting.' >&2; exit -1
    }
    afu-install-isearchmap
    afu-install-eof
    afu-install-preexec
  } always {
    zstyle ':auto-fu:var' misc-installed-p yes
  }

  bindkey -N afu emacs
  { "$@" }
  bindkey -M afu "^I" afu+complete-word
  bindkey -M afu "^M" afu+accept-line
  bindkey -M afu "^J" afu+accept-line
  bindkey -M afu "^O" afu+accept-line-and-down-history
  bindkey -M afu "^[a" afu+accept-and-hold
  bindkey -M afu "^X^[" afu+vi-cmd-mode

  bindkey -N afu-vicmd vicmd
}

afu-install-isearchmap () {
  zstyle -t ':auto-fu:var' isearchmap-installed-p || {
    [[ -n ${(M)keymaps:#isearch} ]] && bindkey -M isearch "^M" afu+accept-line
  } always {
    zstyle ':auto-fu:var' isearchmap-installed-p yes
  }
}

afu-install-eof () {
  zstyle -t ':auto-fu:var' eof-installed-p || {
    # fiddle the main(emacs) keymap. The assumption is it propagates down to
    # the afu keymap afterwards.
    if [[ "$options[ignoreeof]" == "on" ]]; then
      bindkey "^D" afu+orf-ignoreeof-deletechar-list
    else
      setopt ignoreeof
      bindkey "^D" afu+orf-exit-deletechar-list
    fi
  } always {
    zstyle ':auto-fu:var' eof-installed-p yes
  }
}

afu-eof-maybe () {
  local eof="$1"; shift
  [[ -z $BUFFER ]] && { $eof; return }
  "$@"
}

afu-ignore-eof () { zle -M "zsh: use 'exit' to exit." }

afu-register-zle-eof () {
  local fun="$1"
  local then="$2"
  local else="${3:-delete-char-or-list}"
  eval "$fun () { afu-eof-maybe $then zle $else }; zle -N $fun"
}
afu-register-zle-eof afu+orf-ignoreeof-deletechar-list afu-ignore-eof
afu-register-zle-eof      afu+orf-exit-deletechar-list exit

afu-install-preexec () {
  zstyle -t ':auto-fu:var' preexec-installed-p || {
    autoload -Uz add-zsh-hook
    add-zsh-hook preexec auto-fu-preexec
  } always {
    zstyle ':auto-fu:var' preexec-installed-p yes
  }
}

auto-fu-preexec () { echo -en '\e[0m' }

afu+vi-ins-mode () { zle -K afu      ; }; zle -N afu+vi-ins-mode
afu+vi-cmd-mode () { zle -K afu-vicmd; }; zle -N afu+vi-cmd-mode

auto-fu-zle-keymap-select () { afu-track-keymap "$@" afu-adjust-main-keymap }

afu-adjust-main-keymap () { [[ "$KEYMAP" == 'main' ]] && { zle -K "$1" } }

afu-track-keymap () {
  typeset -gA afu_keymap_state # XXX: global state variable.
  local new="${KEYMAP}"
  # XXX: widget name will not be passed (zsh < 8856dc8)
  local old="${@[-2]}"
  local fun="${@[-1]}"
  { afu-track-keymap-skip-p "$old" "$new" } && return
  local cur="${afu_keymap_state[cur]-}"
  afu_keymap_state+=(old "${afu_keymap_state[cur]-}")
  afu_keymap_state+=(cur "$old $new")
  [[ "$new" == 'main' ]] && [[ -n "$cur" ]] && {
    local -a tmp; tmp=("${(Q)=cur}")
    afu_keymap_state+=(cur "$old $tmp[1]")
    "$fun" "$tmp[1]"
  }
}

afu-track-keymap-skip-p () {
  local old="$1"
  local new="$2"
  { [[ -z "$old" ]] || [[ -z "$new" ]] } && return 0
  local -a ms; ms=(); zstyle -a ':auto-fu:var' track-keymap-skip ms
  (( ${#ms} )) || return -1
  local m; for m in $ms; do
    [[ "$old" == "$m" ]] && return 0
    [[ "$new" == "$m" ]] && return 0
  done
  return -1
}

declare -a afu_accept_lines

afu-recursive-edit-and-accept () {
  local -a __accepted
  zle recursive-edit -K afu || { afu-reset; zle -R ''; zle send-break; return }
  [[ -n ${__accepted} ]] &&
  (( ${#${(M)afu_accept_lines:#${__accepted[1]}}} > 1 )) &&
  { zle "${__accepted[@]}"} || { zle accept-line }
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
      [[ -z ${hi} ]] || {
        # XXX: subject to change.
        (($+functions[${hi}])) && "${hi}" || afu-rh-finish "0 ${#BUFFER} ${hi}"
      }
    }
    zstyle -T ':auto-fu:var' postdisplay/clearp && POSTDISPLAY=''
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
afu-line-init () {
  local auto_fu_init_p=1
  local ps
  {
    local -A afu_rh_state
    local afu_in_p=0
    local afu_paused_p=0

    zstyle -s ':auto-fu:var' postdisplay ps
    [[ -z ${ps} ]] || POSTDISPLAY="$ps"

    afu-recursive-edit-and-accept
  } always {
    [[ -z ${ps} ]] || POSTDISPLAY=''
  }
}

auto-fu-init () { with-afu-zle-rebinding afu-line-init }; zle -N auto-fu-init

# Entry point.
with-afu-gvars () {
  (( auto_fu_init_p == 1 )) && {
    zle -M "Sorry, can't turn on or off if auto-fu-init is in effect."; return
  }
  typeset -g afu_in_p=0
  typeset -g afu_paused_p=0
  typeset -gA afu_rh_state
  "$@"
}
auto-fu-on  () { with-afu-gvars zle -K afu   }
auto-fu-off () { with-afu-gvars zle -K emacs }
auto-fu-on~ () { afu-zle-force-install; auto-fu-on  }
auto-fu-off~() { afu-zle-force-install; auto-fu-off }
zle -N auto-fu-on  auto-fu-on~
zle -N auto-fu-off auto-fu-off~

afu-register-zle-toggle () {
  local var="$1"
  local toggle="$2"
  local activate="$3"
  local deactivate="$4"
  eval "$(cat <<EOT
    $toggle () {
      (( $var == 1 )) && { $var=0; return }
      (( $var != 1 )) && { $var=1; return }
    }
    $activate () { $var=0 }
    $deactivate () { $var=1 }
    zle -N $toggle; zle -N $activate; zle -N $deactivate
EOT
  )"
}
afu-register-zle-toggle afu_paused_p \
  auto-fu-toggle auto-fu-activate auto-fu-deactivate

afu-rh-highlight-state () {
  local oplace="$1" cplace="$2"; shift 2
  : ${(P)oplace::=afu-rh-highlight-state-sync-old}
  : ${(P)cplace::=afu-rh-highlight-state-sync-cur}
  { "$@" }
}

afu-rh-highlight-state-update () {
  afu_rh_state+=(old "${afu_rh_state[cur]-}")
  afu_rh_state+=(cur "$1")
}

afu-rh-highlight-state-sync-old () {
  local -a old; : ${(A)old::=${=afu_rh_state[old]-}}
  [[ -n ${old} ]] && [[ -n ${region_highlight} ]] && {
    : ${(A)region_highlight::=${region_highlight:#"$old[2,-1]"}}
  }
}

afu-rh-highlight-state-sync-cur () {
  local -a cur; : ${(A)cur::=${=afu_rh_state[cur]-}}
  if [[ -n ${cur} ]] &&
     { [[ -n ${region_highlight} ]] &&
       [[ -z ${(M)region_highlight:#"$cur[2,-1]"} ]] } ||
     [[ -z ${region_highlight} ]]; then
    region_highlight+="$cur[2,-1]"
  fi
}

afu-rh-highlight-maybe () {
  local hi="$1"
  local beg="$2"
  local end="$3"
  local hiv="$4"
  local ok ck
  afu-rh-highlight-state ok ck \
    afu-rh-highlight-state-update "$hi $beg $end $hiv"; "$ok"; "$ck";
}

afu-rh-clear-maybe () {
  local ok _ck
  afu-rh-highlight-state ok _ck \
    afu-rh-highlight-state-update ""; "$ok"
}

afu-rh-finish () {
  local -a cur; : ${(A)cur::=${=afu_rh_state[cur]-}}
  [[ -n "$cur" ]] && [[ "$cur[1]" == completion/* ]] && { afu-rh-clear-maybe }
  region_highlight+="$1"
}

afu-clearing-maybe () {
  local clearregionp="$1"
  [[ $clearregionp == t ]] && region_highlight=()
  afu-rh-clear-maybe
  if ((afu_in_p == 1)); then
    [[ "$BUFFER" != "$buffer_new" ]] || ((CURSOR != cursor_cur)) &&
    { afu_in_p=0 }
  fi
}

afu-reset () {
  region_highlight=()
  afu_in_p=0
  local ps; zstyle -s ':auto-fu:var' postdisplay ps
  [[ -z ${ps} ]] || POSTDISPLAY=''
}

# XXX: see also with-afu-region-highlight-saving
# XXX: see also afu-register-zle-afu-override
# XXX: see also afu-initialize-zle-misc
typeset -ga afu_rhs_no_kills; afu_rhs_no_kills=()

with-afu-region-highlight-saving () {
  local -a rh; : ${(A)rh::=$region_highlight}
  region_highlight=()
  {
    local h; local -a tmp rhtmp; : ${(A)rhtmp::=$rh}
    for h in $rhtmp; do
      : ${(A)tmp::=${=h}}
      if ((PENDING==0)); then
        if (($#afu_rhs_no_kills != 0)) && \
           [[ -z ${(M)afu_rhs_no_kills:#$WIDGET} ]]; then
          afu-rhs-protect rh  afu-rhs-save afu-rhs-kill afu-rhs-kill "$tmp[@]"
        else
          afu-rhs-protect rh  afu-rhs-save : : "$tmp[@]"
        fi
      else
        afu-rhs-protect rh  : afu-rhs-kill afu-rhs-kill "$tmp[@]"
      fi
    done
    "$@"
  } always {
    : ${(A)region_highlight::=$rh}
  }
}

afu-rhs-save () { region_highlight+="$@"    }
afu-rhs-kill () { : ${(PA)1::=${(PA)1:#$2}} }

afu-rhs-protect () {
  # TODO: handle "P" region_highlight
  local   place="$1"
  local savefun="$2"
  local killfun="$3"
  local rillfun="$4"
  shift 4
  local -a a; : ${(A)a::=$@}
  if [[ -n "$RBUFFER" ]]; then
    if ((CURSOR > $tmp[2])) || [[ $WIDGET == *complete* ]]; then
      "$savefun" "$a[*]"
    else
      [[ -n "${(P)place-}" ]] && "$rillfun" $place "$a[*]"
    fi
  else
    if (($a[2] > $#BUFFER + 1)); then
      "$killfun" $place "$a[*]"
      "$savefun" "$a[1] $#BUFFER $a[3]"
    elif (($a[2] > $#BUFFER)); then
      "$savefun" "$a[1] $#BUFFER $a[3]"
    else
      (($a[1] > $#BUFFER + 1)) || "$savefun" "$a[*]"
    fi
  fi
}

with-afu () {
  local clearp="$1"; shift
  local zlefun="$1"; shift
  local -a zs
  : ${(A)zs::=$@}
  afu-clearing-maybe "$clearp"
  ((afu_in_p == 1)) && { afu_in_p=0; BUFFER="$buffer_cur" }
  with-afu-region-highlight-saving zle $zlefun && {
    setopt localoptions extendedglob no_banghist
    local es ds
    zstyle -a ':auto-fu:var' enable es; (( ${#es} == 0 )) && es=(all)
    if [[ -n ${(M)es:#(#i)all} ]]; then
      zstyle -a ':auto-fu:var' disable ds
      : ${(A)es::=${zs:#(${~${(j.|.)ds}})}}
    fi
    [[ -n ${(M)es:#${zlefun#.}} ]]
  } && { auto-fu-maybe }
}

# XXX: see also afu+complete-word~

auto-fu-extend () { "$@" }; zle -N auto-fu-extend

with-afu~ () { zle auto-fu-extend -- with-afu "$@" }

with-afu-zsh-syntax-highlighting () {
  local -a rh_old; : ${(A)rh_old::=$region_highlight}
  local b_old; b_old="${buffer_cur-}"
  local -i ret=0
  local -i hip=0; ((hip=$+functions[_zsh_highlight]))
  ((hip==0)) && { "$1" t   "$@[2,-1]"; ret=$? }
  ((hip!=0)) && { "$1" nil "$@[2,-1]"; ret=$? }
  if ((PENDING==0)); then
    ((hip==1)) && {
      if ((afu_in_p==1)); then
        # XXX: Badness
        [[ "$BUFFER" != "$buffer_cur" ]] && { _ZSH_HIGHLIGHT_PRIOR_BUFFER="" }
        ((CURSOR != cursor_cur))         && { _ZSH_HIGHLIGHT_PRIOR_CORSUR=-1 }
      fi
      _zsh_highlight
    }
    ((ret==-1)) || {
      local _ok ck
      afu-rh-highlight-state _ok ck; "$ck"
    }
  else
    [[ ${#${buffer_cur-}} > $#b_old ]] && : ${(A)region_highlight::=$rh_old}
  fi
}

# XXX: redefined!
zle -N auto-fu-extend with-afu-zsh-syntax-highlighting

afu-able-p () {
  # XXX: This could be done sanely in the _main_complete or $_comps[x].
  local pred=; zstyle -s ':auto-fu:var' autoablep-function pred
  "${pred:-auto-fu-default-autoable-pred}"; return $?
}

auto-fu-default-autoable-pred () {
  local -a ps; zstyle -a ':auto-fu:var' autoable-function/preds ps
  (( $#ps )) || { afu-autoable-default-functions ps }

  local -a reply; local -i REPLY REPLY2; local -a areply
  afu-split-shell-arguments

  local word="${reply[REPLY]-}"
  local commandish="${areply[1]-}"
  local p; for p in $ps; do
    local ret=0; "$p" \
      "$word" "$commandish" \
        "${(j..)areply[1,((REPLY-1))]}" \
        "${(j..)areply[1,-1]}"
    ret=$?
    ((ret == 1)) && return 1
    ((ret ==-1)) && return 0 # XXX: Badness.
  done
  return 0
}

afu-error-symif () {
  local fname="$1"; shift
  local place="$1"; shift
  [[ "$place" == (${~${(j.|.)@}}) ]] && {
    echo \
      "*** error in $fname; ${(qq)@} cannot be used in this context. sorry."
    return -1
  }
  return 0
}

afu-autoable-default-functions () {
  local place="$1"
  afu-error-symif "$0" "$place" defaults || return $?
  local -a defaults; defaults=(\
    afu-autoable-paused-p \
    afu-autoable-space-p \
    afu-autoable-skipword-p \
    afu-autoable-dots-p \
    afu-autoable-skiplbuffer-p \
    afu-autoable-skipline-p)
  : ${(PA)place::=$defaults}
}

afu-autoable-paused-p () { (( afu_paused_p == 0 )) }

afu-split-shell-arguments () {
  autoload -U split-shell-arguments; split-shell-arguments
  ((REPLY & 1)) && ((REPLY--))
  ((REPLY2 = ${#reply[REPLY]-} + 1))

  # set up the 'areply'. (Cursor positoin (*))
  # % echo bar && command ls -a* -l | grep foo
  #                       <-------> areply holds
  local -i p; local -a tmp
  : ${(A)tmp::=$reply[1,REPLY]}
  p=${tmp[(I)(\||\|\||;|&|&&)]}; ((p)) && ((p+=2)) || ((p=1))
  while [[ ${tmp[p]-} == (noglob|nocorrect|builtin|command) ]] do ((p+=2)) done;
  ((p!=1)) && ((p++))
  : ${(A)tmp::=$reply[p,-1]}
  p=${tmp[(I)(\||\|\||;|&|&&)]}; ((p)) && ((p-=2)) || ((p=-1))
  : ${(A)areply::=${tmp[1,p]}}
}

afu-autoable-space-p () {
  local c=$LBUFFER[-1]
  [[ $c == ''  ]] && return 1;
  [[ $c == ' ' ]] && { afu-able-space-p || return 1 }
  return 0
}

afu-able-space-p () {
  [[ -z ${AUTO_FU_NOCP-} ]] &&
    # For backward compatibility.
    { [[ "$WIDGET" == "magic-space" ]] || return 1 }

  # TODO: This is quite iffy guesswork, broken.
  local -a x
  : ${(A)x::=${(z)LBUFFER}}
  #[[ $x[1] != (man|perldoc|ri) ]]
  [[ $x[1] != man ]]
}

afu-autoable-dots-p () { [[ "${1##*/}" != ("."|"..")  ]] }

afu-autoable-skip-pred () {
  local place="$1"
  local style="$2"
  local deffn="${3-}"
  local value="${(P)place}"
  local -a skips; skips=(); zstyle -a ':auto-fu:var' "$style" skips
  (($#skips==0)) && [[ -n "$deffn" ]] && { "$deffn" skips }
  local skip; for skip in $skips; do
    [[ "${value}" == ${~skip} ]] && {
      [[ -n "${AUTO_FU_DEBUG-}" ]] && {
        echo "***BREAK*** ${skip}" >> ${AUTO_FU_DEBUG-}
      }
      return 1
    }
  done
  return 0
}

afu-autoable-skipword-p () {
  local word="$1"
  afu-autoable-skip-pred word autoable-function/skipwords \
    afu-autoable-skipword-p-default
}

afu-autoable-skipword-p-default () {
  afu-error-symif "$0" "$1" a tmp || return $?
  local -a a; a=("'" "$'" "$histchars[1]");local -a tmp; tmp=("(${(j.|.)a})*")
  : ${(PA)1::=$tmp}
}

afu-autoable-skiplbuffer-p () {
  local lbuffer="$3"
  afu-autoable-skip-pred lbuffer autoable-function/skiplbuffers
}

afu-autoable-skipline-p () {
  local line="$4"
  afu-autoable-skip-pred line autoable-function/skiplines
}

auto-fu-maybe () {
  local ret=-1
  (($PENDING== 0)) && { afu-able-p } && [[ $LBUFFER != *$'\012'*  ]] &&
  { auto-fu; ret=0 }
  return ret
}

with-afu-compfuncs () {
  compprefuncs=(afu-comppre)
  comppostfuncs=(afu-comppost)
  "$@"
}

with-afu-completer-vars () {
  setopt localoptions no_recexact
  local LISTMAX=999999
  with-afu-compfuncs "$@"
}

auto-fu () {
  cursor_cur="$CURSOR"
  buffer_cur="$BUFFER"
  with-afu-region-highlight-saving with-afu-completer-vars zle complete-word
  cursor_new="$CURSOR"
  buffer_new="$BUFFER"

  if [[ "$buffer_cur[1,cursor_cur]" == "$buffer_new[1,cursor_cur]" ]];
  then
    CURSOR="$cursor_cur"
    {
      local hi hiv
      [[ $afu_one_match_p == t ]] && hi=completion/one || hi=completion
      zstyle -s ':auto-fu:highlight' "$hi" hiv
      [[ -z ${hiv} ]] || {
        local -i end=$cursor_new
        [[ $BUFFER[$cursor_new] == ' ' ]] && (( end-- ))
        afu-rh-highlight-maybe $hi $CURSOR $end $hiv
      }
    }

    if [[ "$buffer_cur" != "$buffer_new" ]] || ((cursor_cur != cursor_new))
    then afu_in_p=1; {
      local -a region_highlight; region_highlight=()
      local BUFFER="$buffer_cur"
      local CURSOR="$cursor_cur"
      with-afu-completer-vars zle list-choices
    }
    fi
  else
    BUFFER="$buffer_cur"
    CURSOR="$cursor_cur"
    with-afu-completer-vars zle list-choices
  fi
}
zle -N auto-fu

afu-comppre () {
  [[ $LASTWIDGET == afu+*~afu+complete-word ]] && {
    # XXX: on backward-kill-word-match, ls /usr/share ⇒ ^W^W forces to be in
    # the menu selecting state (and selecting the first match) without
    # fiddling these variables as shown below.
    compstate[old_list]=
    compstate[insert]=automenu-unambiguous
  }
}

afu-comppost () {
  ((compstate[list_lines] + BUFFERLINES + 2 > LINES)) && {
    compstate[list]=''
    [[ $WIDGET == afu+complete-word ]] || compstate[insert]=''
    zle -M "$compstate[list_lines]($compstate[nmatches]) too many matches..."
  }

  typeset -g afu_one_match_p=
  (( $compstate[nmatches] == 1 )) && afu_one_match_p=t
}

afu+complete-word () {
  afu-clearing-maybe "${1-}"
  { afu-able-p } || { zle complete-word; return; }

  with-afu-completer-vars;
  if ((afu_in_p == 1)); then
    afu_in_p=0; CURSOR="$cursor_new"
    case $LBUFFER[-1] in
      (=) # --prefix= ⇒ complete-word again for `magic-space'ing the suffix
        { # TODO: this may not be accurate.
          local x="${${(@z)LBUFFER}[-1]}"
          [[ "$x" == -* ]] && zle complete-word && return
        };;
      (/) # path-ish  ⇒ propagate auto-fu if it could be
        { # TODO: this may not be enough.
          local y="((*-)#directories|all-files|(command|executable)s)"
          y=${AUTO_FU_PATHITH:-${y}}
          local -a x; x=${(M)${(@z)"${_lastcomp[tags]}"}:#${~y}}
          zle complete-word
          [[ -n $x ]] && zle -U "$LBUFFER[-1]"
          return
        };;
      (,) # glob-ish  ⇒ activate the `complete-word''s suffix
        BUFFER="$buffer_cur"; zle complete-word;
        return
        ;;
    esac
    (( $_lastcomp[nmatches]  > 1 )) &&
      # many matches ⇒ complete-word again to enter the menuselect
      zle complete-word
    (( $_lastcomp[nmatches] == 1 )) &&
      # exact match  ⇒ flag not using _oldlist for the next complete-word
      _lastcomp[nmatches]=0
  else
    [[ $LASTWIDGET == afu+*~afu+complete-word ]] && {
      afu_in_p=0; BUFFER="$buffer_cur"
    }
    zle complete-word
  fi
}

afu+complete-word~ () {with-afu-region-highlight-saving afu+complete-word "$@"}

afu+complete-word~~ () { zle auto-fu-extend -- afu+complete-word~ }

zle -N afu+complete-word afu+complete-word~~

autoload +X keymap+widget

() {
  setopt localoptions extendedglob no_shwordsplit
  local code=${(S)${functions[keymap+widget]/for w in *
	do
/for w in $afu_zles
  do
  }/(#b)(\$w-by-keymap \(\) \{*\})/
  eval \${\${\${\"\$(echo \'$match\')\"}/\\\$w/\$w}//\\\$WIDGET/\$w}
  }
  eval "function afu-keymap+widget () { $code }"
}

afu-register-zle-afu-raw () {
  local afufun="$1"
  local rawzle="$2"
  shift 2
  eval "function $afufun () { with-afu~ $rawzle $@; }; zle -N $afufun"
}

afu-register-zle-afu () {
  local afufun="$1"
  local rawzle=".${afufun#*+}"
  afu-register-zle-afu-raw $afufun $rawzle $afu_zles
}

afu-initialize-zle-afu () {
  local z
  for z in $afu_zles ;do
    afu-register-zle-afu afu+$z
  done
}

afu-install-forall () {
  local a; for a in "$@"; do
    "$a"
  done
}

typeset -gA afu_rebinds_pre; afu_rebinds_pre=()
typeset -gA afu_rebinds_post; afu_rebinds_post=()

typeset -ga afu_zle_contrib_installs; afu_zle_contrib_installs=()

(($+AUTO_FU_CONTRIBKEYMAPS)) || AUTO_FU_CONTRIBKEYMAPS=(main emacs zex zed)

typeset -ga afu_zle_contrib_mapped_commands; afu_zle_contrib_mapped_commands=()

typeset -gA afu_zle_contribs; afu_zle_contribs=()

afu-initialize-zle-contrib () { afu-install-forall $afu_zle_contrib_installs }

afu-initialize-register-zle-contrib () {
  local fname="$1"
  local zcomp="$2"
  local builtinname="$3"
  local    afunname="$4"
  local usebuiltinp="$5"
  local    nfunname="$6"
  shift 6
  local -a keymaps; : ${(A)keymaps::=$@}
  afu_zle_contrib_installs+="$fname"
  eval "
    ${fname}-p () {
      [[ -n \${afu_zcompiling_p-} ]] &&
        ([[ -n \${AUTO_FU_ZCOMPILE_ZLECONTRIB-} ]] ||
         [[ -n \${${zcomp}-} ]]) || {
        [[ -z \${afu_zcompiling_p-} ]]
      }
    }
    ${fname}  () { ${fname}-p && ${fname}~ }
    ${fname}~ () {
      zle -N ${builtinname} ${builtinname}-by-keymap # Iffy. see keymap+widgets
      afu_zle_contribs+=(${builtinname} $afunname)
      local k; for k in ${keymaps}; do
        afu_zle_contrib_mapped_commands+=\${k}+${builtinname}
        ((\$+widgets[\${k}+${builtinname}])) ||\
          zle -N \${k}+${builtinname} ${nfunname}
      done

      if [[ "${usebuiltinp}" == t ]]; then
        afu-builtin-${builtinname} () { zle .${builtinname} }
        zle -N afu+${afunname} afu-builtin-${builtinname}
      else
        zle -N afu+${afunname} ${afunname}
      fi

      afu-register-zle-afu-raw \
        afu+${builtinname} afu+${afunname} afu+${afunname} \$afu_zles
    }
  "
}

afu-initialize-register-zle-contrib~ () {
  [[ -z "${4-}" ]] && 4="$2"
  afu-initialize-register-zle-contrib \
    afu-initialize-zle-contrib-"${2}" \
    AUTO_FU_ZCOMPILE_"${(U)2//-/}" \
    "$1" "$2" "$3" "$4" \
    $AUTO_FU_CONTRIBKEYMAPS
}

afu-initialize-register-zle-contrib~~ () {
  # XXX: assume _zsh_highlight
  afu-initialize-register-zle-contrib~ "$1" "$2" nil "_zsh_highlight_widget_$1"
}

afu-initialize-register-zle-contrib-all () {
  setopt localoptions extendedglob
  local match mbegin mend
  local bname uname; for bname uname in "$@"; do
    if [[ $uname == _zsh_highlight_widget* ]]; then
      case ${${functions[$uname]}#$'\tbuiltin zle '} in
        (.*)
          # _zsh_highlight only
          afu-initialize-register-zle-contrib~ $bname $uname t
          ;;
        ((#b)(*) '-- "$@" && _zsh_highlight')
          # _zsh_highlight plus custom widget
          afu-initialize-register-zle-contrib~ $bname \
            ${${widgets[${match}]}#user:} nil $uname
          ;;
        (*)
          echo "auto-fu:zsh-syntax-highlighting code detection failure."
          ;;
      esac
    else
      afu-initialize-register-zle-contrib~ $bname $uname nil
    fi
  done
}

afu-initialize-register-zle-contrib-all~ () {
  local -a cell;
  afu-initialize-register-zle-contrib-all-collect-contribs cell &&
    afu-initialize-register-zle-contrib-all "$cell[@]"
}

afu-initialize-register-zle-contrib-all-collect-contribs () {
  local place="$1"
  zmodload zsh/zleparameter || {
    echo 'auto-fu:zmodload error.' >&2; return -1
  }
  setopt localoptions extendedglob
  local -a match mbegin mend
  local -a a
  local z; for z in $afu_zles; do
    [[ ${widgets[$z]} == user:(#b)(*) ]] && { a+=$z; a+=$match }
  done
  : ${(PA)place::=$a}
}

afu-initialize-rebinds () {
  setopt localoptions extendedglob
  local -a match mbegin mend
  # auto-fu uses complete-word and list-choices as they are not "rebinded".
  local -a rs; rs=($afu_zles complete-word list-choices ${(k)afu_rebinds_post})
  eval "
    function with-afu-zle-rebinding () {
      local -a restores
      {
        eval \"\$("${rs/(#b)(*)/afu-rebind-expand restores $match;}")\"
        function afu-zle-force-install () {
          "$(echo ${afu_zles/(#b)(*)/ \
              zle -N ${match} ${match}-by-keymap;})"
          zle -C complete-word .complete-word _main_complete
          zle -C list-choices .list-choices _main_complete
          "$(echo ${(v)afu_rebinds_pre/(#b)(*)/$match;})"
        }
        afu-zle-force-install
        { \"\$@\" }
      } always {
        eval \"function afu-zle-rebind-restore () { \${(j.;.)restores} }\"
        afu-zle-rebind-restore

        # XXX: redefined!
        function "\$0" () {
          {
            afu-zle-force-install
            { \"\$@\" }
          } always {
            afu-zle-rebind-restore
          }
        }
      }
    }
  "
}

afu-rebind-expand () {
  local place="$1"
  local w="$2"
  local x="$widgets[$w]"
  [[ -n ${afu_zle_contribs} && -n ${(Mk)afu_zle_contribs:#$w} ]] && return
  [[ -z ${afu_rebinds_post[$w]-} ]] || {
    echo " $place+=\"${afu_rebinds_post[$w]}\""; return
  }
  [[ $x == user:*-by-keymap    ]] && return
  [[ $x == (user|completion):* ]] || return
  local f="${x#*:}"
  [[ $x == completion:* ]] && echo " $place+=\"zle -C $w ${f/:/ }\" "
  [[ $x != completion:* ]] && echo " $place+=\"zle -N $w $f\" "
}

afu-rebind-add () {
  local name="$1"
  local  pre="$2"
  local post="$3"
  afu_rebinds_pre+=("$name" "$2")
  afu_rebinds_post+=("$name" "$3")
}

afu-install~ () {
  afu-install afu-install-forall \
    afu-initialize-zle-afu \
    "$@" \
    afu-initialize-zle-contrib \
    afu-keymap+widget \
    afu-initialize-rebinds
  function () {
    [[ -z ${AUTO_FU_NOCP-} ]] || return
    # For backward compatibility
    zstyle ':auto-fu:highlight' input bold
    zstyle ':auto-fu:highlight' completion fg=black,bold
    zstyle ':auto-fu:highlight' completion/one fg=whilte,bold,underline
    zstyle ':auto-fu:var' postdisplay $'\n-azfu-'
  }
}

afu-initialize-zcompile-register-zle-contrib-common () {
  afu-initialize-register-zle-contrib~~ self-insert url-quote-magic
  afu-initialize-register-zle-contrib~~ backward-kill-word{,-match}
  afu-initialize-register-zle-contrib~~ kill-word{,-match}
}

afu-register-zle-afu-override () {
  local name="$1"
  local zlefun="$2"
  local rhskill="$3"
  local precode="${4-}"
  local postcode="${5-}"
  afu-register-zle-afu-raw ${name} ${zlefun} ${zlefun} $afu_zles
  [[ $rhskill == t ]] && afu_rhs_no_kills+=${name}
  [[ -n "${precode}" ]] && [[ -n "${postcode}" ]] && {
    afu-rebind-add ${name} "${precode}" "${postcode}"
  }
}

afu-initialize-zle-misc () {
  local b=; v=; for v b in vi-add-eol A vi-add-next a; do
    afu-register-zle-afu-override afu+${v} ${v} t \
      "bindkey -M vicmd '${b}' afu+${v}" "bindkey -M vicmd '${b}' ${v}"
  done
}

() {
  (($+AUTO_FU_INITIALIZE)) || {
    local -a AUTO_FU_INITIALIZE; AUTO_FU_INITIALIZE=()
    local -a is; is=()
    if [[ -z ${afu_zcompiling_p-} ]]; then
      is+=afu-initialize-register-zle-contrib-all~
    else
      is+=afu-initialize-zcompile-register-zle-contrib-common
    fi
    [[ -z ${AUTO_FU_NOCP-} ]] || is+=afu-initialize-zle-misc
    : ${(A)AUTO_FU_INITIALIZE::=$is}
  }
  afu-install~ "$AUTO_FU_INITIALIZE[@]"
}

[[ -z ${afu_zcompiling_p-} ]] &&
  unset afu_zles afu_zle_contrib_installs afu_zle_contrib_mapped_commands

# NOTE: This is iffy. It dumps the necessary functions into ~/.zsh/auto-fu,
# then zrecompiles it into ~/.zsh/auto-fu.zwc.

afu-clean () {
  local d=${1:-~/.zsh}
  rm -f ${d}/{auto-fu,auto-fu.zwc*(N)}
}

afu-install-installer () {
  local match mbegin mend

  eval ${${${${${${${"$(<=(cat <<"EOT"
    auto-fu-install () {
      typeset -ga afu_accept_lines
      afu_accept_lines=($afu_accept_lines)
      typeset -gA afu_zle_contribs
      afu_zle_contribs=($afu_zle_contribs)
      typeset -ga afu_rhs_no_kills
      afu_rhs_no_kills=($afu_rhs_no_kills)
      typeset -gA afu_rebinds_pre
      afu_rebinds_pre=($afu_rebinds_pre)
      typeset -gA afu_rebinds_post
      afu_rebinds_post=($afu_rebinds_post)
      { $body }
      afu-install
    }
EOT
  ))"}/\$body/
    $(print -l \
      "# afu's all zle widgets expect own keymap+widgets stuff" \
      ${${${(M)${(@f)"$(zle -l -L)"}:#zle -N (afu+*|auto-fu*)}:#(\
        ${(j.|.)afu_zles/(#b)(*)/afu+$match})}/(#b)(*)/$match} \
      "## keymap+widget machinaries" \
      "# ${afu_zles/(#b)(*)/zle -N $match ${match}-by-keymap}" \
      ${afu_zles/(#b)(*)/zle -N afu+$match} \
      "## mapped keymap+widget " \
      "$(afu-install-installer-expand-mapped-cammonds \
        $afu_zle_contrib_mapped_commands)"
      )
    }/\$afu_accept_lines/$afu_accept_lines
    }/\$afu_rhs_no_kills/$afu_rhs_no_kills
    }/\$afu_rebinds_pre/$(afu-install-installer-expand-assoc afu_rebinds_pre)
    }/\$afu_rebinds_post/$(afu-install-installer-expand-assoc afu_rebinds_post)
    }/\$afu_zle_contribs/${(kv)afu_zle_contribs}}
}

afu-install-installer-expand-mapped-cammonds () {
  (( $# )) || return
  local -a zles
  : ${(A)zles::=${(M)${(@f)"$(zle -l -L)"}:#zle -N (${(~j.|.)@})*}}
  local match mbegin mend
  print -l \
    "# zle calls" $zles \
    "# autoload/zle -N calls" \
    ${${(u)zles/zle -N (#b)*+(*) */
      autoload -Uz $afu_zle_contribs[$match]
      zle -N $afu_zle_contribs[$match]}} \
}

afu-install-installer-expand-assoc () {
  local k=; v=; for k v in ${(@kvPAA)1}; do
    echo ${(q)k} ${(q)v}
  done
}

auto-fu-zcompile () {
  local afu_zcompiling_p=t

  local s=${1:?Please specify the source file itself.}
  local d=${2:?Please specify the directory for the zcompiled file.}
  shift 2 # "$@" is now point to rest of files for further customizations
  local g=${d}/auto-fu
  setopt localoptions extendedglob no_shwordsplit

  echo "** zcompiling auto-fu in ${d} for a little faster startups..."
  { source ${s} >/dev/null 2>&1 } # Paranoid.
  echo "mkdir -p ${d}" | sh -x
  afu-clean ${d}
  (($#@ > 0)) && {
    eval "$({
      autoload -Uz zargs
      zargs -I{} -- "$@" -- echo source {}
    })"
  }
  afu-install-installer
  echo "* writing code ${g}"
  {
    local -a fs
    : ${(A)fs::=${(Mk)functions:#(*afu*|*auto-fu*|*-by-keymap)}}
    echo "#!zsh"
    echo "# NOTE: Generated from auto-fu.zsh ($0). Please DO NOT EDIT."; echo
    echo "$(functions \
      ${fs:#(afu-register-*|afu-initialize-*|afu-keymap+widget|\
        afu-clean|afu-install-installer*|auto-fu-zcompile)})"
  }>! ${d}/auto-fu
  echo -n '* '; autoload -U zrecompile && zrecompile -p -R ${g} && {
    zmodload zsh/datetime
    touch --date="$(strftime "%F %T" $((EPOCHSECONDS - 120)))" ${g}
    [[ -z ${AUTO_FU_ZCOMPILE_NOKEEP-} ]] || { echo "rm -f ${g}" | sh -x }
    echo "** All done."
    echo "** Please update your .zshrc to load the zcompiled file like this,"
    cat <<EOT
-- >8 --
## auto-fu.zsh stuff.
# source ${s/$HOME/~}
{ . ${g/$HOME/~}; auto-fu-install; }
zstyle ':auto-fu:highlight' input bold
zstyle ':auto-fu:highlight' completion fg=black,bold
zstyle ':auto-fu:highlight' completion/one fg=white,bold,underline
zstyle ':auto-fu:var' postdisplay $'\n-azfu-'
zstyle ':auto-fu:var' track-keymap-skip opp
zle-line-init () {auto-fu-init;}; zle -N zle-line-init
zle -N zle-keymap-select auto-fu-zle-keymap-select
-- 8< --
EOT
  }
}
