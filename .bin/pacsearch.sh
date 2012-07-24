#!/bin/bash --norc
##
##  Title:	pacman search2list
##  Name:	srch2list.sh
##  Usage:	srch2list srchfile (see options below or run with -h for summary)
##  Version:	0.0.8
##  Date:	08/07/2010, 09:50:49 PM
##  Author:	David C. Rankin, J.D.,P.E
##  Summary:	srch2list.sh performs a search using pacman -Ss 'srchTerm' or will
##              reads a file containing the output from 'pacman -Ss term >srchfName'
##              and formats the output in two columns 'pkgname' and 'description'. The
##              pkgname colume width is adjusted to the longest filename and the
##              description column (in multiple lines, if necessary) spans the remainder
##              of the xterm width leaving a one-char margin on the right. This makes
##              reading the search results *much* easier and may prevent blindness.
##
##              To use as a graphical app, create a launcher on your desktop to:
##              'srch2list -z -n'  (you will be prompted for a filename or searchTerm)
##
##  Run as:	user - root (or sudo) required to install packages
##  Requires:	Arch Linux, pacman, (zenity for graphical display, selection and install
##              of search results)
##
#

### Initial Functions

## Basic colors
blk='\e[0;30m'       # ${blk}
blu='\e[0;34m'       # ${blu}
grn='\e[0;32m'       # ${grn}
cyn='\e[0;36m'       # ${cyn}
red='\e[0;31m'       # ${red}
prp='\e[0;35m'       # ${prp}
brn='\e[0;33m'       # ${brn}
ltgry='\e[0;37m'     # ${ltgry}
dkgry='\e[1;30m'     # ${dkgry}
ltblu='\e[1;34m'     # ${ltblu}
ltgrn='\e[1;32m'     # ${ltgrn}
ltcyn='\e[1;36m'     # ${ltcyn}
ltred='\e[1;31m'     # ${ltred}
ltprp='\e[1;35m'     # ${ltprp}
ylw='\e[1;33m'       # ${ylw}
wht='\e[1;37m'       # ${wht}

nc='\e[0m'           # ${nc} (no color - disables previous color selection)


## basic usage function displaying any information provided as an error, then
## displays the propper scripts usage and finally exiting."
usage() {
    [[ -n $1 ]] && echo -e "\n  $1" >&2
    echo -e "\n  Usage:  ${ltblu}${0##*/} srchTerm [srchfName] [-d|--double] [-h|--help] [-z|--zenity]"
    echo -e "                                [-w|--write filename]${nc}\n"
    echo -e "    ${0##*/} provides formatted output for 'pacman -Ss srchTerm'. The output is provided"
    echo -e "    in two columns (package name)(description). The columns are dynamically sized so"
    echo -e "    the package name column is wide enough for the longest package name returned, and the"
    echo -e "    description fills the remaining space provided by the terminal while leaving a one"
    echo -e "    character margin at the right-hand side. You can now read the search results without"
    echo -e "    going blind.\n"
    echo -e "    The script will also parse a previous pacman search saved with 'pacman -Ss >srchfName.'"
    echo -e "    If you provide both a srchTerm and srchfName, the search will be performed and the"
    echo -e "    srchfName ignored. The remaining options are as follows:\n"
    echo -e "  ${ltblu}Options:${nc}\n"
    echo -e "    NOTE: options can be given in any order, flags must be separate: '-d -z' NOT '-dz'\n"
    echo -e "    ${ltblu}-c | --color${nc}           disable the use of an accent color for pkgnames."
    echo -e "    ${ltblu}-d | --double${nc}          option controls single/double spaced output."
    echo -e "    ${ltblu}-h | --help${nc}            display this help message."
    echo -e "    ${ltblu}-i | --installed${nc}       show only installed packages."
    echo -e "    ${ltblu}-n | --notext${nc}          don't output list to console (use with -z)."
    echo -e "    ${ltblu}-u | --uninstalled${nc}     show only uninstalled packages."
    echo -e "    ${ltblu}-w | --write filename${nc}  write search results to 'filename'."
    echo -e "    ${ltblu}-z | --zenity${nc}          provide graphical output using 'zenity --list' (requires zenity)\n"
    echo -e "  Two additional testing options (no effect on script):\n"
    echo -e "    -v | --verbose         dump select variables to the screen."
    echo -e "    -a | --array           dump the array contents to the screen (requires -v option)\n"
    echo -e "  NOTE: To use as a graphical application, create a launcher to '${0##*/} -z -n'.\n"
    exit 1
}

## fn trimWS will trim white space from both ends of a string
## Usage:  newStr=$(trimWS $oldStr) or just Str=$(trimWS $Str)
trimWS() {
    [[ -z $1 ]] && {
# 	echo "WARNING: Nothing passed to trimWS()" >&2
	return 1
    }
    strln="${#1}"    # get string length and return immedtialy if only single char
    [[ strln -lt 2 ]] && {
	echo $1
	return 2
    }
    trimSTR=$1
    trimSTR="${trimSTR#"${trimSTR%%[![:space:]]*}"}"  # remove leading whitespace characters
    trimSTR="${trimSTR%"${trimSTR##*[![:space:]]}"}"  # remove trailing whitespace characters
    echo $trimSTR
    return 0
} # end trimWS

## fn stripSlash - parse input search dir and strip trailing / and set SEARCHDIR
## Usage: VAR=$(stripSlash VAR)
stripSlash() {
    [[ -z $1 ]] && { echo "WARNING: Nothing passed to fn 'stripSlash'" >&2; return 1; }
    testSTR="$1"
    lastCHAR=${1:$((${#testSTR}-1))}
    [[ $lastCHAR == / ]] && echo "${testSTR%/*}" || echo "$testSTR"
} # end stripSlash

## fn getWH fills the Width & Height varibles with the current xterm dimensions.
## Usage:  'getWH $tWidth $tHeight'  (you must use these variables)
getWH() {
    [[ ! $1 ]] || [[ ! $2 ]] && {
        echo -e "\n  ERROR: Insufficient Number of Variable Passed to 'getWH'\n" >&2
        return 1
    }
    tmp=$(stty -a) # fill tmp with stty ouput and then parse for W & H
    tmp=${tmp##*rows\ }
    tHeight=${tmp%%;*}
    tmp=${tmp##*columns\ }
    tWidth=${tmp%%;*}
    return 0
} # end getWH

## fn breakstr breaks a string into lines of strLimit width breaking on spaces only
## Usage:  brkstr strVar strLimit  (the 'rtnArray' must exist in a global context)

brkstr() {
    fullstr=$1
    strLimit=$2
    strLen=${#fullstr}
    arryidx=0
    unset rtnArray
    if [[ $strLen -gt $strLimit ]]; then
	while [[ $strLen -gt $strLimit ]]; do
	    for((i=strLimit;i>0;i--)); do
		[[ ${fullstr:$i:1} == ' ' ]] && {
# 		    rtnArray[$arryidx]=${fullstr:0:$((i-1))}
		    rtnArray[$arryidx]=${fullstr:0:$i}
		    ((arryidx+=1))
		    fullstr=${fullstr:$((i+1))}
		    strLen=${#fullstr}
		    [[ strLen -le strLimit ]] && rtnArray[$arryidx]=$fullstr
		break
		}
	    done
	done
    else
	rtnArray[$arryidx]="$fullstr"
    fi
    return $((arryidx+=1))
} # end brkstr

#-----------------------------------------------------------------------------------------
#  Print routines - just to cut down on the clutter in the actual output code section
#-----------------------------------------------------------------------------------------

## printpkg needs 2 inputs (1) array index; (2) description lines
printpkg() {
    [[ -n $1 ]] && idx=$1 || idx=$j  # ($j is just a hack in case an index isn't passed
    [[ -n $2 ]] && numlines=$2

    # provide an accent color for the package column (-c | --color) disables the color
    [[ $nocolor -eq 1 ]] && \
	printf "%-${pkwidth}s   %s\n" ${PKG[${idx}]} ${rtnArray[0]} || \
	printf "${ltblu}%-${pkwidth}s${nc}   %s\n" ${PKG[${idx}]} ${rtnArray[0]}

    # write remaining description lines
    [[ $numlines -gt 1 ]] && {
	for((k=1;k<$numlines;k++)); do
	    printf "%-${pkwidth}s   %s\n" ' ' "${rtnArray[$k]}"
	done
    }
    [[ $doubleSpace -eq 1 ]] && printf "\n"  # add a space between packages if flag set
} #end printpkg

chkroot() {
    [[ $UID -eq 0 ]] && return 0 || return 1
}

## my test block to dump variables and the srchArray use the (-v|--verbose) to dump the values.
dumpvars() {

    	echo -e "\n  Test Block\n"
	echo "    srchfName  : $srchfName"
	echo "    srchTerm   : $srchTerm"
	echo "    doubleSpace: $doubleSpace"
	echo "    tmpfile    : $tmpfile"
	echo "    verbose    : $verbose"
	echo "    useZenity  : $useZenity"
	echo "    tWidth     : $tWidth"
	echo "    tHeight    : $tHeight"
	echo ""

    #     [[ $dumparray -eq 1 ]] && {
    # 	for ((j=0;j<${#srchArray[@]};j++)); do
    # 	    printf "[%3d]  %s\n" $j "${srchArray[$j]}"
    # 	done
    # 	echo ""
    #     }

	# dump index, installed-status, package-name
    #     [[ $dumparray -eq 1 ]] && {
    # 	for ((j=0;j<${#PKG[@]};j++)); do
    # 	    printf "[%3d]  %d  %s\n" $j ${installed[$j]} ${PKG[${j}]}
    # 	done
    # 	echo ""
    #     }

	# dump uninstalled only
# 	[[ $dumparray -eq 1 ]] && {
# 	    for ((j=0;j<${#PKG[@]};j++)); do
# 		[[ ${installed[$j]} -eq 0 ]] && \
# 		printf "%s\n" ${PKG[${j}]}
# 	    done
# 	    echo ""
# 	}

    #     [[ $dumparray -eq 1 ]] && {
    # 	for ((j=0;j<${#installed[@]};j++)); do
    # 	    printf "[%3d]  %d\n" $j ${installed[$j]}
    # 	done
    # 	echo ""
    #     }
    exit 6
} #end dumpvars

## declare and initialize variables
declare -a srchArray installed REPO PKG DESC rtnArray  # Arrays
CNTR=0		# Array index
finished=0	# multiline description flag
tWidth=0        # initial varibale for terminal Width (updated below)
tHeight=0       # initial varibale for terminal Height (updated below)
pkwidth=25	# initial character width of the pkg name output field (updated below)
maxwidth=80     # initial max line width (will be updated to actual below)
doubleSpace=0   # default is single space
notext=0        # flag to suppress text output to the terminal
reqVars=1       # number of required command line parameters - used with cliArray input process
useZenity=0     # flag determining whether zenity --list output table is shown
verbose=0       # my flag to determing whether test output is shown
srchTerm=""     # search term initialized to empty
srchfName=""    # pacman -SS >searchfName initialized to empty
pkgcolor=${ltblu}  # color for package field
pkgselect=1     # package select flag:
                #  ( 1 - all packages;  2 - uninstalled only; 3  - installed only )
rootprefix=""   # flag to hold sudo if installing packages as user

#------------------------------------------------------------------------------
#  Command line parameter processing with an array, loop and case
#------------------------------------------------------------------------------

## Fill an Array with all CLI input
declare -a cliArray
cliArray=( "$@" )

## check and set options from command line
# [[ ${#cliArray[@]} -lt $reqVars ]] && usage "ERROR: Insufficient input specified"

for ((i=0;i<${#cliArray[@]};i++)); do
    cliOpt=${cliArray[${i}]}
    case $cliOpt in
        -a | --array       ) dumparray=1;;
	-c | --color       ) nocolor=1;;
	-d | --double      ) doubleSpace=1;;
	-h | --help        ) usage;;
	-i | --installed   ) pkgselect=3;;
	-n | --notext      ) notext=1;;
	-u | --uninstalled ) pkgselect=2;;
	-v | --verbose     ) verbose=1;;
	-w | --write       ) tmpfile=${cliArray[$((i+1))]}; ((i+=1));;
	-z | --zeniry      ) useZenity=1;;
	 * )
	    [[ -f $cliOpt ]] && srchfName=$cliOpt || {
		[[ ${cliOpt:0:1} == - ]] && \
		echo -e "${red}\n  WARNING: Invalid option '$cliOpt' -- ignored\n${nc}" || \
		srchTerm=$cliOpt
	    }
	    ;;
    esac
    ## set test for required variables [you will need to customize this]
    [[ $useZenity -eq 1 ]] && {
	if ! which zenity &>/dev/null; then
	    useZenity=0
	    echo -e "${red}\n  WARNING: zenity is not installed\n${ns}"
	fi
    }
done

# [[ $verbose -eq 1 ]] && dumpvars

## test for root and set rootprefix to sudo if not run by root
if [[ $chkroot -eq 1 ]]; then rootprefix=sudo; fi

## test for required search term or filename or prompt user for input
# [[ -z $srchfName ]] && [[ -z $srchTerm ]] && usage "ERROR: No 'srchfile' or 'srchterm' given."
[[ -z $srchfName ]] && [[ -z $srchTerm ]] && {
    [[ $useZenity -eq 0 ]] && {
	echo -e "${red}\n  WARNING: No 'srchfile' or 'srchterm' given.\n${nc}"
	echo -en "  Enter a 'Search Term' or 'Filename':  "
	read ans
	[[ -f $ans ]] && srchfName=$ans || srchTerm=$ans
    }
    [[ $useZenity -eq 1 ]] && {
	ans=$(zenity --entry \
	--width=400 \
	--height=150 \
	--title="WARNING: No Filename or SearchTerm" \
	--text="Enter a search filename or SearchTerm")
	[[ -f $ans ]] && srchfName=$ans || srchTerm=$ans
    }
}

## set internal field separator (IFS) to only break on newlines
OISF=$IFS
IFS=$'\n'

## get terminal width and height and update maxwidth
getWH $tWidth $tHeight
maxwidth=$((tWidth-1))   # leave a 1-char margin on the right side

#-----------------------------------------------------------------------------------------
#  fill the search array with results of search or from file provided on the command line
#-----------------------------------------------------------------------------------------

#  if both a filename and search term provided, do search and notify using search
[[ ! $srchTerm == "" ]] && [[ ! $srchfName == "" ]] && {
    [[ $useZenity -eq 0 ]] && {
	echo -e "\n  WARNING:  Both a search term '$srchTerm' and a filename '$srchfName' specified."
	echo -e "            The search will be performed and the filename ignored.\n"
	echo -e "            Eliminate one to do the other.\n"
    }
    [[ $useZenity -eq 1 ]] && {
	zenity --info \
	--no-wrap \
	--width=600 \
	--height=300 \
	--title="WARNING multiple terms specified" \
	--text="\nWARNING:  Both a search term '$srchTerm' and a filename '$srchfName' specified.\n \
	The search will be performed and the filename ignored.\n\n \
	Eliminate one to do the other."
    }
    srchfName=""
}

#  if a srchTerm is provided call pacman -Ss to fill the array
[[ ! $srchTerm == "" ]] && srchArray=( $(pacman -Ss $srchTerm) )

#  if a srchfName is provided, read the array from the file
[[ ! $srchfName == "" ]] && srchArray=( $(< $srchfName) )

#  test srchArray for content, if none, then exit
[[ ! ${#srchArray[@]} -gt 0 ]] && [[ ${srchArray[0]} == "" ]] && \
usage "ERROR: Search returned nothing or invalid search filename provided"

## step through the array and parse information creating arrays of repo,
## package and package description information
for ((j=0;j<${#srchArray[@]};j++)); do
    didx=$((j+1))	# description index
    i=${srchArray[${j}]}	# tmp line to allow parameter substitution & substring operation
    [[ $i =~ \[installed\] ]] && installed[$CNTR]=1 || installed[$CNTR]=0
    repo=${i%%/*}	# repo info
    pkgnm=${i##*/}	# pkgname
    pkgnm=${pkgnm%%\ *}	# removal of version information
    case $repo in	# case used to simplify package lines
	community | extra | core | community-testing | testing )
	    REPO[$CNTR]=$repo
	    PKG[$CNTR]=$pkgnm
	    [[ $i =~ '[installed]' ]] && installed[$CNTR]=1 || installed[$CNTR]=0  # installed flag
	    desctmp=${srchArray[${didx}]}			# tmp var holding description info
	    nxtline=$(trimWS ${srchArray[$((didx+1))]})	# next line of description
	    while [[ $finished -eq 0 ]]; do		# loop and case to test nxtline
		case ${nxtline%%/*} in
		    community | extra | core | community-testing | testing )
			finished=1;;	# if a repo/package line -> descr is done
		    * )
			desctmp="${desctmp:0:$((${#desctmp}-1))} $nxtline" # strip newline
			((j+=1))	# increment loop counter to next description line
			didx=$((j+1))	# increment description index
			nxtline=$(trimWS ${srchArray[$((didx+1))]})	# read and trim next desc line
			[[ $nxtline == "" ]] && break	# if empty, your done
		    ;;
		esac
	    done
	    DESC[$CNTR]=$(trimWS $desctmp)	# assign completed description
	    finished=0				# reset flag
	    [[ ${#pkgnm} -gt $pkwidth ]] && pkwidth=${#pkgnm} # update output width
	    ((j+=1))				# increment loop counter to next repo/pkg line
	    ((CNTR+=1));;			# increment array index
	* ) echo "skipping: $i" >/dev/null;;	# old test, now just a stub
    esac
done

#-----------------------------------------------------------------------------------------
#  Output Routines
#-----------------------------------------------------------------------------------------

## Provide formatted output
[[ $notext -eq 0 ]] && {
    for ((j=0;j<${#PKG[@]};j++)); do            # loop through the package array

	descr=${DESC[${j}]}                     # assign the package description
	descrlength=${#descr}                   # get the description length
	allowedw=$((maxwidth-pkwidth-3))        # compute the allowable lenght to stay within maxwidth
	brkstr $descr $allowedw                 # call brkstr to split the description into lines
	numlines=$?

	# show package output depending on input flags
	# (1 -all packages;  2 -uninstalled only; 3 -installed only)
	case $pkgselect in
	1 ) printpkg $j $numlines;;
	2 ) [[ ${installed[$j]} -eq 0 ]] && printpkg $j $numlines;;
	3 ) [[ ${installed[$j]} -eq 1 ]] && printpkg $j $numlines;;
	esac

    done
}

## If -w and filename provided, write search results to file
[[ $tmpfile != "" ]] && {

    # test for write permission and clear file (reset to empty) before writing
    [[ ! -f $tmpfile ]] && touch $tmpfile
    if [[ -w $tmpfile ]]; then
	:>$tmpfile
	for ((j=0;j<${#srchArray[@]};j++)); do
	    printf "%s\n" "${srchArray[$j]}" >>$tmpfile
	done
	echo -e "\n  Search results written to file: $tmpfile\n"
    else
	echo -e "\nERROR: Unable to create file to hold search results in '$tmpfile' -- check permissions"
    fi
} # end write output file

## zenity output - only provide if '-z' is given on the cli
[[ $useZenity -eq 1 ]] && {

    declare -a rtn  # array to hold packages selected for install
    confirmed=1     # flag confirming package install (1 - don't install)
    if which zenity &>/dev/null; then

	zout=/tmp/zenout.txt             # assign output filename
	:>$zout                          # reset file to empty if it exists
	instfile=/tmp/zeninst.txt
	:>$instfile

	# set trap to remove $zout and $instfile files on exit or term
	trap 'rm {$zout,$instfile}' EXIT SIGTERM

	# prepare temporary file for zenity list
	# ( 1 - all packages;  2 - uninstalled only; 3  - installed only )
	case $pkgselect in
	1 ) for ((j=0;j<${#PKG[@]};j++)); do
		[[ ${installed[$j]} -eq 1 ]] && pkgstat='TRUE' || pkgstat='FALSE'
		printf "%s\n%s\n%s\n" $pkgstat ${PKG[${j}]} ${DESC[${j}]} >> $zout
	    done;;
	2 ) for ((j=0;j<${#PKG[@]};j++)); do
		[[ ${installed[$j]} -eq 0 ]] && printf "%s\n%s\n%s\n" 'FALSE' ${PKG[${j}]} ${DESC[${j}]} >> $zout
	    done;;
	3 ) for ((j=0;j<${#PKG[@]};j++)); do
		[[ ${installed[$j]} -eq 1 ]] && printf "%s\n%s\n%s\n" 'TRUE' ${PKG[${j}]} ${DESC[${j}]} >> $zout
	    done;;
	esac

	# create & display the list
	zselect=( $(cat $zout | zenity --list \
	--title="Package Search Results" \
	--text="To install, select packages and choose OK" \
	--separator=' ' \
	--checklist \
	--multiple \
	--width=800 \
	--height=600 \
	--column=Sel \
	--column=Package \
	--column=Description) )

	# test for selected packages and install if confirmed by user
	if [[ $zselect != "" ]]; then
	    rtnidx=0
	    tmp=$zselect                     # use a temp to preserve original zselect
	    while :; do                      # parse into separate pkgnames for next list
		rtn[$rtnidx]=${tmp%% *}
		tmp=${tmp#* }
		[[ ${tmp} == ${rtn[$rtnidx]} ]] && break || ((rtnidx++))
	    done

	    # build temporary install file
	    for((i=0;i<${#rtn[@]};i++)); do
		printf "%s\n%s\n" 'TRUE' ${rtn[$i]} >> $instfile
	    done

	    # present user with list of packages to modify and confirm install
	    zselect=( $(cat $instfile | zenity --list \
	    --title="Confirm Package Installation" \
	    --text="Install the following packages with pacman?" \
	    --separator=' ' \
	    --checklist \
	    --multiple \
	    --width=500 \
	    --height=500 \
	    --column=Sel \
	    --column=Package) )

	    ## Restore IFS
	    IFS=$' \t\n'

	    # install selected packages with pacman
	    if [[ $zselect != "" ]]; then
		if ! chkroot; then rootprefix="sudo"; fi
		$rootprefix pacman -Sy --needed $zselect
	    fi
	fi

    fi
} # end zenity routine

exit 0

## Scraps

# 	    ## Restore IFS
# 	    IFS=$' \t\n'
#
# 	    # install selected packages with pacman
# 	    if [[ $zselect != "" ]]; then
# 		if ! chkroot; then rootprefix="sudo"; fi
# 		$rootprefix pacman -Sy --needed $zselect
# 	    fi
            # rebuild array of packages to install
#             unset rtn
#             declare -a rtn
# 	    rtnidx=0
# 	    tmp=$zselect                     # use a temp to preserve original zselect
# 	    while :; do                      # parse into separate pkgnames for next list
# 		rtn[$rtnidx]=${tmp%% *}
# 		tmp=${tmp#* }
# 		[[ ${tmp} == ${rtn[$rtnidx]} ]] && break || ((rtnidx++))
# 	    done
#
# 	    # install selected packages with pacman
# 	    if [[ ${rtn[0]} != "" ]]; then
# 		if ! chkroot; then rootprefix="sudo"; fi
# 		for((i=0;i<${#rtn[@]};i++)); do
# 		    echo "$rootprefix pacman -Sy --needed ${rtn[$i]}"
# 		    $rootprefix pacman -Sy --needed ${rtn[$i]}
# 		done
# 	    fi

# 	        [[ ${zselect:0:1} != [A-Za-z0-9] ]] && zselect=${zselect:1}
# 		echo "zselect: $zselect"
# 		zselect=$(echo $zselect | sed -e "s/[']//g")
# 		echo "zselect: $zselect"

# 	zenity --question \
# 	--width=600 \
# 	--text="Install these ${#rtn[@]} packages:\n$( <$instfile)"
# 	confirmed=$?

#         [[ $confirmed -eq 0 ]] && {
# 	    echo -e "\n Installing: $zselect\n"
# 	    pacman -Sy $zselect
#         }

#     [[ $(($j%2)) -eq 0 ]] && txtcolor=${brn} || txtcolor=${ltgry}
#     printf "${ltblu}%-${pkwidth}s   ${txtcolor}%s\n" ${PKG[${j}]} ${rtnArray[0]}

# for ((j=0;j<${#srchArray[@]};j++)); do
#     printf "[%3d]  %s\n" $j "${srchArray[$j]}"
# done
#
# exit 5

## todo FIX THIS MESS
# Qfile=${2:-$HOME/arch/pkg/pmss-query.sh}  # used to create install script for packages
# [[ -d $Qfile ]] && {
#     Qdir=$Qfile
#     Qfile=pmss-query.sh
#     echo -e "  WARNING: fishish the warning"
# } || {
#     Qdir=${Qfile%/*}                          # get the query file base directory
#     ## below test for trailing '/' to get correct dir not ""
#     # [[ $Qfile =~ / ]] && [[ ! -d ${Qfile%/*} ]] && mkdir -p
# }
# ofile=$HOME/arch/pkg/pmss-read.txt

## test input and readability of filename provided
# [[ -z $1 ]] && usage "ERROR: No filename provided."
# [[ ! -r $1 ]] && usage "ERROR: Filename '$1' not readable."
# [[ $@ =~ -h ]] && usage

## print scraps

#     descr=${DESC[${j}]}                         # assign the package description
#     descrlength=${#descr}                       # get the description length
#     allowedw=$((maxwidth-pkwidth-3))            # compute the allowable lenght to stay within maxwidth
#     descrlines=$((descrlength / allowedw))      # compute the number of description lines required
#     [[ $(( descrlength % allowedw )) -gt 0 ]] && ((descrlines += 1))

#     ## fill in printing the remaining description
#     ## need to test for break on character and increment to break on space, the add and 'adjust' to the
#     ## allowedw to output unbroken text. Subsequent read of descr will be fine because 'adjust' amount
#     ## already removed from descr string
#
#     let adjust=0
#     for((l=2;l<=$descrlines;l++)); do
# 	descr=$(trimWS ${descr:$((allowedw+adjust))})
# 	printf "%-${pkwidth}s   %s\n" " " ${descr:0:$allowedw}
#     done

#     printf "%-${pkwidth}s   (%2d:%2d:%3d:%d) %s\n" ${PKG[${j}]} $pkwidth $allowedw $descrlength $descrlines ${descr:0:$allowedw}
#     printf "%-${pkwidth}s   %s\n" ${PKG[${j}]} "${rtnArray[$i]}"

## misc scraps

#     [[ -z $1 ]] && {
# 	echo "WARNING: Nothing passed to trimWS()" >&2
# 	return 1
#     }
#     strln="${#1}"
#     [[ strln -lt 2 ]] && {
# 	echo "WARNING: '$1' isn't long enought to trim in trimWS()" >&2
# 	return 1
#     }

# 	    ((didx+=1))

# for i in $(< ~/arch/pkg/srch/gnome); do
#     repo=${i%%/*}
#     pkg=${i##*/}
#     pkg=${pkg%%\ *}
#     case $repo in
# 	community )
# 	    echo "comm: $pkg";;
# 	extra )
# 	    echo "extra: $pkg";;
# 	* ) echo "skipping: $i";;
#     esac
# done

# 	* ) echo "skipping: $i";;

# 	    nxtline=${srchArray[$((didx+1))]}
# 			echo "[ $j] didx: $didx  desctmp: $desctmp"

## Provide formatted output
# for ((j=0;j<${#PKG[@]};j++)); do
#     printf "repo: %s\n" ${REPO[${j}]} # repo information (not used)
#     descr=$(trimWS ${DESC[${j}]})
#     printf "%30s  -  %s\n" ${PKG[${j}]} $descr
# done

