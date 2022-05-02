#!/bin/bash
# Inpored from https://pwnagotchi.ai/

[[ $1 == 'sleep' ]] && face='(⇀‿‿↼)'
[[ $1 == 'awake' ]] && face='(≖‿‿≖)'
[[ $1 == 'normal' ]] && face='(◕‿‿◕)'
[[ $1 == 'surprise' ]] && face='(☉_☉ )'
[[ $1 == 'observe' ]] && face='(◕‿◕ )'
[[ $1 == 'intense' ]] && face='(°▃▃°)'
[[ $1 == 'cool' ]] && face='(⌐■_■)'
[[ $1 == 'happy' ]] && face='(•‿‿•)'
[[ $1 == 'grateful' ]] && face='(^‿‿^)'
[[ $1 == 'excited' ]] && face='(ᵔ◡◡ᵔ)'
[[ $1 == 'smart' ]] && face='(✜‿‿✜)'
[[ $1 == 'friendly' ]] && face='(♥‿‿♥)'
[[ $1 == 'motivated' ]] && face='(☼‿‿☼)'
[[ $1 == 'demotivated' ]] && face='(≖__≖)'
[[ $1 == 'bored' ]] && face='(-__-)'
[[ $1 == 'sad' ]] && face='(╥☁╥ )'
[[ $1 == 'lonely' ]] && face='(ب__ب)'
[[ $1 == 'broken' ]] && face='(☓‿‿☓)'
[[ $1 == 'bug' ]] && face='(#__#)'

[[ $face == '' ]] && face='(☉_☉ )'

echo $face
exit 0
