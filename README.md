<img src="https://github.com/hchbaw/auto-fu.zsh/raw/readme/auto-fu.gif" />

<pre>
zsh automatic complete-word and list-choices

Originally incr-0.2.zsh
Incremental completion for zsh
by y.fujii &lt;y-fujii at mimosa-pudica.net&gt;

Thank you very much y.fujii!

Adapted by Takeshi Banse &lt;takebi@laafc.net&gt;
I want to use it with menu selection.

To use this,
1) source this file.
% source auto-fu.zsh
2) establish `zle-line-init' containing `auto-fu-init' something like below.
% zle-line-init () {auto-fu-init;}; zle -N zle-line-init
3) use the _oldlist completer something like below.
% zstyle ':completion:*' completer _oldlist _complete
(If you have a lot of completer, please insert _oldlist before _complete.)
4) establish `zle-keymap-select' containing `auto-fu-zle-keymap-select'.
% zle -N zle-keymap-select auto-fu-zle-keymap-select
(This enables the afu-vicmd keymap switching coordinates a bit.)
*Optionally* you can use the zcompiled file for a little faster loading on
every shell startup, if you zcompile the necessary functions.
*1) zcompile the defined functions. (generates ~/.zsh/auto-fu.zwc)
% A=/path/to/auto-fu.zsh; (zsh -c "source $A ; auto-fu-zcompile $A ~/.zsh")
*2) source the zcompiled file instead of this file and some tweaks.
% source ~/.zsh/auto-fu; auto-fu-install
*3) establish `zle-line-init' and such (same as a few lines above).
Note:
It is approximately *(6~10) faster if zcompiled, according to this result :)
TIMEFMT="%*E %J"
0.041 ( source ./auto-fu.zsh; )
0.004 ( source ~/.zsh/auto-fu; auto-fu-install; )

Configuration
The auto-fu features can be configured via zstyle.

:auto-fu:highlight
  input
    A highlight specification used for user input string.
  completion
    A highlight specification used for completion string.
  completion/one
    A highlight specification used for completion string if it is the
    only one candidate.
:auto-fu:var
  postdisplay
    An initial indication string for POSTDISPLAY in auto-fu-init.
  postdisplay/clearp
    If set, POSTDISPLAY will be cleared after the accept-lines.
    'yes' by default.
  enable
    A list of zle widget names the automatic complete-word and
    list-choices to be triggered after its invocation.
    Only with ALL in 'enable', the 'disable' style has any effect.
    ALL by default.
  disable
    A list of zle widget names you do *NOT* want the complete-word to be
    triggered. Only used if 'enable' contains ALL. For example,
      zstyle ':auto-fu:var' enable all
      zstyle ':auto-fu:var' disable magic-space
    yields; complete-word will not be triggered after pressing the
    space-bar, otherwise automatic thing will be taken into account.
  track-keymap-skip
    A list of keymap names to *NOT* be treated as a keymap change.
    In other words, these keymaps cannot be used with the standalone main
    keymap. For example "opp". If you use my opp.zsh, please add an 'opp'
    to this zstyle.
  autoable-function/skipwords
  autoable-function/skiplbuffers
  autoable-function/skiplines
    A list of patterns to *NOT* be treated as auto-stuff appropriate.
    These patterns will be tested against the part of the command line
    buffer as shown on the below figure:
    (*) is used to denote the cursor position.
      # nocorrect aptitude --assume-*yes -d install zsh && echo ready
                           &lt;--------&gt;skipwords
                  &lt;-----------------&gt;skiplbuffers
                  &lt;-----------------------------------&gt;skplines
    Examples:
    - To disable auto-stuff inside single and also double quotes.
      And less than 3 chars before the cursor.
      zstyle ':auto-fu:var' autoable-function/skipwords \
        "('|$'|")*" "^((???)##)"
    - To disable the rm's first option, and also after the '(cvs|svn) co'.
      zstyle ':auto-fu:var' autoable-function/skiplbuffers \
        'rm -[![:blank:]]#' '(cvs|svn) co *'
    - To disable after the 'aptitude word '.
      zstyle ':auto-fu:var' autoable-function/skiplines \
        '([[:print:]]##[[:space:]]##|(#s)[[:space:]]#)aptitude [[:print:]]# *'
  autoable-function/preds
    A list of functions to be called whether auto-stuff appropriate or not.
    These functions will be called with the arguments (above figure)
      - $1 '--assume-'
      - $2 'aptitude'
      - $3 'aptitude --assume-'
      - $4 'aptitude --assume-yes -d install zsh'
    For example,
    to disable some 'perl -M' thing, we can do by the following zsh codes.
&gt;
      afu-autoable-pm-p () { [[ ! ("$2" == 'perl' && "$1" == -(#i)m*) ]] }
      # retrieve default value into 'preds' to push the above function into.
      local -a preds; afu-autoable-default-functions preds
      preds+=afu-autoable-pm-p
      zstyle ':auto-fu:var' autoable-function/preds $preds
&lt;
    The afu-autoable-dots-p is actually an example of this ability to skip
    uninteresting dots.
  autoablep-function
    A predicate function to determine whether auto-stuff could be
    appropriate. (Default `auto-fu-default-autoable-pred' implements the
    above autoablep-function/* functionality.)
Configuration example

zstyle ':auto-fu:highlight' input bold
zstyle ':auto-fu:highlight' completion fg=black,bold
zstyle ':auto-fu:highlight' completion/one fg=white,bold,underline
zstyle ':auto-fu:var' postdisplay $'
-azfu-'
zstyle ':auto-fu:var' track-keymap-skip opp
#zstyle ':auto-fu:var' disable magic-space

XXX: use with the error correction or _match completer.
If you got the correction errors during auto completing the word, then
plese do _not_ do `magic-space` or `accept-line`. Insted please do the
following, `undo` and then hit &lt;tab&gt; or throw away the buffer altogether.
This applies _match completer with complex patterns, too.
I'm very sorry for this annonying behaviour.
(For example, 'ls --bbb' and 'ls --*~^*al*' etc.)

XXX: ignoreeof semantics changes for overriding ^D.
You cannot change the ignoreeof option interactively. I'm verry sorry.

TODO: play nice with zsh-syntax-highlighting.
TODO: http://d.hatena.ne.jp/tarao/20100531/1275322620
TODO: pause auto stuff until something happens. ("next magic-space" etc)
TODO: handle RBUFFER.
TODO: signal handling during the recursive edit.
TODO: handle empty or space characters.
TODO: cp x /usr/loc
TODO: region_highlight vs afu-able-p → nil
Do *NOT* clear the region_highlight if it should.
TODO: ^C-n could be used as the menu-select-key outside of the menuselect.
TODO: *-directories|all-files may not be enough.
TODO: recommend zcompiling.
TODO: undo should reset the auto stuff's state.
TODO: when `_match`ing,
sometimes extra &lt;TAB&gt; key is needed to enter the menu select,
sometimes is *not* needed. (already be entered menu select state.)

History

v0.0.1.12
fix some options potentially will be reset during the auto-stuff.
fix afu-keymap+widget to $afu_zles work in custom widgets.
Thank you very much for the reports, Christian271!

v0.0.1.11
play nice with banghist.
Thank you very much for the report, yoshikaw!
add autoablep-function machinery.
Thank you very much for the suggestion, tyru and kei_q!

v0.0.1.10
Fix not work auto-thing without extended_glob.
Thank you very much for the report, myuhe!

v0.0.1.9
add auto-fu-activate, auto-fu-deactivate and auto-fu-toggle.

v0.0.1.8.3
in afu+complete-word PAGER=&lt;TAB&gt; ⇒ PAGER=PAGER= bug fix.
Thank you very much for the report, tyru!

v0.0.1.8.2
afu+complete-word bug fixes.

v0.0.1.8.1
README.md

v0.0.1.8
add completion/one and postdisplay/clearp configurations.
add kill-word and yank to afu_zles.

v0.0.1.7
Fix "no such keymap `isearch'" error.
Thank you very much for the report, mooz and Shougo!

v0.0.1.6
Fix `parameter not set`. Thank you very much for the report, Shougo!
Bug fix.

v0.0.1.5
afu+complete-word bug (directory vs others) fix.

v0.0.1.4
afu+complete-word bug fixes.

v0.0.1.3
Teach ^D and magic-space.

v0.0.1.2
Add configuration option and auto-fu-zcompile for a little faster loading.

v0.0.1.1
Documentation typo fix.

v0.0.1
Initial version.
</pre>
