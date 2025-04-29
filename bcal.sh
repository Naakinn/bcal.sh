#!/bin/bash
function HELP() {
    exec 1>&2 
    printf 'bcal - generate calendar in html\n'
    printf 'usage: bcal [FILE] [-h] [-y YEAR] [-x8, -x16]\n'
    printf 'generates html file FILE with table calendar of current year or YEAR, if specified.\n'
    printf 'if FILE is not specified, outputs to <CURRENT_YEAR>.html\n'
    printf 'use -h to print this page, -x8 and -x16 enable secret display mode :)\n'
}

# Initialization and argument parsing
declare FILE=''
declare NUM_FIELD='%d'
declare YEAR_FIELD='%d'
declare -i YEAR_NUM
declare -i CURRENT_YEAR=$(printf '%(%Y)T')
declare -i CURRENT_MONTH=$(printf '%(%_m)T')
declare -i CURRENT_DAY=$(printf '%(%_d)T')
declare -i ENABLE_BIN=0
while [[ -n $1 ]]; do
    case "$1" in
        "-y" )
            if [[ -n $2 ]]; then
                YEAR_NUM=$2; shift 
            else
                printf 'argument for -y is missing, run bcal -h to get help\n' >&2
            fi
            ;;
        "-x8" )
            NUM_FIELD='0%o'
            YEAR_FIELD='0%o'
            ENABLE_BIN=1
            ;;
        "-x16" )
            NUM_FIELD='%x'
            YEAR_FIELD='0x%X'
            ENABLE_BIN=1
            ;;
        "-h" )
            HELP
            exit 0
            ;;
        * )
            FILE=$1
            ;;
    esac
    shift 
done
[[ -z $YEAR_NUM ]] && YEAR_NUM=$CURRENT_YEAR
[[ -z $FILE ]] && FILE="$YEAR_NUM.html"

# Count shift from 01/01/1970 - thursday
function IS_LEAP() {
    if [[ $(($1 % 400)) -eq 0 ]]; then
        return 0
    elif [[ $(($1 % 100)) -eq 0 ]]; then
        return 1
    elif [[ $(($1 % 4)) -eq 0 ]]; then
        return 0
    fi
    return 1
}

declare -i START_YEAR=1970
declare -i LEAP_COUNT=0

for ((Y=1970; Y < $YEAR_NUM; ++Y)); do
    IS_LEAP $Y && ((LEAP_COUNT++))
done
# monday - 0, ..., thursday - 3
declare -i WEEKDAY_JAN1=$(((3 + $YEAR_NUM - $START_YEAR + $LEAP_COUNT) % 7 + 1))
# now monday - 1, tuesday - 2, ...

# HTML file generation
:> $FILE
exec 1>$FILE
printf '<!DOCTYPE html>\n'
# numbers of days in months(indexing from 1)
declare -a MONTH_DAYNR=( 'NONE' '31' '28' '31' '30' '31' '30' '31' '31' '30' '31' '30' '31' )
declare -a MONTH_NAMES=( 'NONE' 'Jan' 'Feb' 'Mar' 'Apr' 'May' 'Jun' 'Jul' 'Aug' 'Sep' 'Oct' 'Nov' 'Dec' )
declare BIN_RESULT=''

if IS_LEAP $YEAR_NUM; then
    # feb
    MONTH_DAYNR[2]='29'
fi

function DEC2BIN() {
    declare -i NUM=$1 
    declare -i MASK=4 # 100
    BIN_RESULT=''
    for I in {1..3}; do
        if ((NUM & MASK)); then
            BIN_RESULT+='1'
        else
            BIN_RESULT+='0'
        fi
        ((MASK /= 2))
    done
}

function TAG_HANDLE() {
    printf "$1\n"
    $2 # callback function
    printf "${1/</</}\n" # from <...> to </...> 
}

function HEAD() {
    printf '<head>'
    printf '
<meta charset="UTF-8">
<title>%d</title>
<style>
body {font-family: Arial, Helvetica, sans-serif;}
h1,h2,td{text-align:center;}
table{margin:1rem 1rem 1rem 1rem;}
.container {display:grid;grid-template-columns:repeat(4,1fr);}
</style>' $YEAR_NUM
    printf '</head>\n'
    BODY
}

function BODY() {
    printf '<body>\n'
    YEAR    
    CONTAINER
    printf '</body>\n'
}

function YEAR() {
    printf "<h1>$YEAR_FIELD</h1>\n" $YEAR_NUM
}

function CONTAINER() {
    printf '<div class="container">\n'
    declare -i SHIFT=$WEEKDAY_JAN1
    for M in {1..12}; do
        TABLE $M $SHIFT
        SHIFT=$(( ($SHIFT + ${MONTH_DAYNR[$M]}) % 7 ))
        [[ $SHIFT -eq 0 ]] && SHIFT=7
    done
    printf '</div>\n'
}

function TABLE() {
    declare MONTH=$1
    declare START_WEEKDAY=$2
    declare -i DAY_NUM=1
    
    printf '<table>\n'
    if [[ $ENABLE_BIN -eq 1 ]]; then
        printf "<caption><h2>$NUM_FIELD</h2></caption>" $MONTH
    else
        printf "<caption><h2>%s</h2></caption>" ${MONTH_NAMES[$MONTH]}
    fi
    printf '<tr>\n'
    for I in {1..7}; do
        if [[ $ENABLE_BIN -eq 1 ]]; then
            DEC2BIN $I    
            printf "<th>$BIN_RESULT</th>\n"
        else
            printf "<th>$I</th>\n"
        fi
    done
    printf '</tr>\n'
    
    for W in {1..6}; do
        printf '<tr>\n'
        for D in {1..7}; do
            [[ $DAY_NUM -gt ${MONTH_DAYNR[$MONTH]} ]] && break
            if [[ $DAY_NUM -eq 1 && $D -lt $START_WEEKDAY ]]; then
                printf '<td></td>\n'
            else
                # Mark current day
                if [[ $YEAR_NUM -eq $CURRENT_YEAR && $MONTH -eq $CURRENT_MONTH && $DAY_NUM -eq $CURRENT_DAY ]]; then
                    printf "<td><u><b>$NUM_FIELD</b></u></td>\n" $DAY_NUM
                else
                    printf "<td>$NUM_FIELD</td>\n" $DAY_NUM
                fi
                ((++DAY_NUM))
            fi
        done
        printf '</tr>\n'
    done
    printf '</table>\n'
}
TAG_HANDLE '<html>' 'HEAD'
