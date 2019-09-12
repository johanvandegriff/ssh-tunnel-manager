#!/bin/bash

#UTILITIES
#function for terminal colors that supports color names and nested colors
color() {
    color="$1"
    shift
    text="$@"
    case "$color" in
        # text attributes
#        end) num=0;;
        bold) num=1;;
        special) num=2;;
        italic) num=3;;
        underline|uline) num=4;;
        reverse|rev|reversed) num=7;;
        concealed) num=8;;
        strike|strikethrough) num=9;;
        # foreground colors
        black) num=30;;
        D_red) num=31;;
        D_green) num=32;;
        D_yellow) num=33;;
        D_orange) num=33;;
        D_blue) num=34;;
        D_magenta) num=35;;
        D_cyan) num=36;;
        gray) num=37;;
        D_gray) num=30;;
        red) num=31;;
        green) num=32;;
        yellow) num=33;;
        orange) num=33;;
        blue) num=34;;
        magenta) num=35;;
        cyan) num=36;;
        # background colors
        B_black) num=40;;
        BD_red) num=41;;
        BD_green) num=42;;
        BD_yellow) num=43;;
        BD_orange) num=43;;
        BD_blue) num=44;;
        BD_magenta) num=45;;
        BD_cyan) num=46;;
        BL_gray) num=47;;
        B_gray) num=5;;
        B_red) num=41;;
        B_green) num=42;;
        B_yellow) num=43;;
        B_orange) num=43;;
        B_blue) num=44;;
        B_magenta) num=45;;
        B_cyan) num=46;;
        B_white) num=47;;
#        +([0-9])) num="$color";;
#        [0-9]+) num="$color";;
        *) num="$color";;
#        *) echo "$text"
#             return;;
    esac


    mycode='\033['"$num"'m'
    text=$(echo "$text" | sed -e 's,\[0m,\[0m\\033\['"$num"'m,g')
    echo -e "$mycode$text\033[0m"
}

#display a message to stderr in bold red and exit with error status
error(){
    #bold red
    color bold `color red "$@"` 1>&2
    exit 1
}

#display a message to stderr in bold yellow
warning(){
    #bold yellow
    color bold `color yellow "$@"` 1>&2
}

#a yes or no prompt
yes_or_no(){
    prompt="$@ [y/n]"
    answer=
    while [[ -z "$answer" ]]; do #repeat until a valid answer is given
        read -p "$prompt" -n 1 response #read 1 char
        case "$response" in
            y|Y)answer=y;;
            n|N)answer=n;;
            *)color yellow "
Enter y or n.";;
        esac
    done
    echo
}
