#!/bin/bash

# Global variables
version=$(git describe --abbrev=4 --always --tags)
homedir=$(pwd)
scriptpath=$(cd shell; pwd)
shfile=$scriptpath/forsyde-shell.sh
shconf=$scriptpath/shell.conf
libdir=$homedir/libs
tooldir=$homedir/tools
projdir=$homedir/workspace

# Sources and repositories for tools
pkg_systemc='systemc-2.3.1a.tar.gz'
url_systemc='http://accellera.org/images/downloads/standards/systemc/systemc-2.3.1a.tar.gz'
repo_fsysc='https://github.com/ugeorge/ForSyDe-SystemC.git -b type-introspecion --single-branch'
repo_f2dot='https://github.com/forsyde/f2dot.git'
repo_fm2m='https://github.com/ugeorge/forsyde-m2m.git'
repo_fsysc_apps='https://github.com/forsyde/forsyde-systemc-demonstrators.git'

# Load initial configuration
source setup.conf

# Load utilities for the supported OSs
source shell/debian_setup_utils.sh

# The reset method only removes the generated script and
# configurations.
function reset-shell () {
    rm $shfile
    rm $shconf
    rm forsyde-shell
    touch $shconf;
}

# The uninstall method resets (removes) the contents of the root
# folder to its initial form.
function uninstall-shell () {
    read -p "Are you sure you want to completely remove the shell along with the install tools and libraries? [N]" yn
    case $yn in
	[Yy]* ) rm -rf $shfile $shconf $libdir $tooldir $projdir forsyde-shell ;;
	* ) ;;
    esac
    exit 0
}

# Interactive GUI installer. All it does is just to set/reset the
# configuration flags.
function install-dialog () {
    install-application $dep_dialog

    source $shconf #load previous config
    cmd=(dialog --keep-tite --menu "Welcome to ForSyDe-Shell installer. What would you like to do?" 22 76 16)
    options=( 1 "Install/Update : installs libs & tools. Updates shell environment."
	      2 "Reset shell    : installs libs & tools. Resets shell environment." 
	      3 "Uninstall      : uninstalls libs, tools & the current shell.")
    choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
    for choice in $choices; do
	case $choice in
            1) __install__general=on ;;
            2) __install__general=on; reset-shell ;;
	    3) uninstall-shell ;;
	esac
    done

    cmd=(dialog --separate-output --checklist 	"Which ForSyDe library would you like to install? (<SPC> to select)" 22 76 16)
    options=(1 "ForSyDe-Haskell (not available yet)" $__install__fhask  
             2 "ForSyDe-SystemC (prerquisite: SystemC)" $__install__fsysc)
    choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
    clear
    for choice in $choices; do
    	case $choice in
            1) __install__fhask=on ;;
            2) __install__fsysc=on ;;
    	esac
    done

    if [ "$__install__fsysc" = on ]; then
	source shell/systemc-setup.sh
	cmd=(dialog --keep-tite --menu "Is SystemC installed on this computer?" 22 76 16)
	options=( 1 "Yes, attempt to find it and include its path in the shell."
		  2 "Yes, provide its path manually in the next dialog." 
		  3 "No, attempt to install it locally from Acclelera website."
		  4 "No, abort setup and retry after manual installation.")
	choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
	for choice in $choices; do
	    case $choice in
		1) search-systemc-path ;;
		2) ;;
		3) install-systemc-locally ;;
		4) exit 1 ;;
	    esac
	done

	exec 3>&1
	VALUES=$(dialog --backtitle "ForSyDe-SystemC" \
			--title "System Information" \
			--form "Fill in the information if not correct:"  \
			15 86 0 \
			"SystemC path: "                 1 1 "$syscpath"    1 15 70 0 \
			"SystemC libs (name): lib-"      2 1 "$arch_string" 2 26 60 0 \
			2>&1 1>&3)
	exec 3>&-
	syscpath=$(echo "$VALUES" |sed -n -e '1{p;q}')
	arch_string=$(echo "$VALUES" |sed -n -e '2{p;q}')
	
	cmd=(dialog --separate-output --checklist "What other features would you like to install?" 22 76 16)
	options=(1 "demo        : a collection of ForSyDe-SystemC demonstrators"  $__install__fsysc_demo  
	         2 "f2dot       : plotting XML-based IR"                          $__install__f2dot  
                 3 "forsyde-m2m : convert between ForSyDe and oher IRs"           $__install__fm2m
                 4 "valgrind    : extract run-time executions of SystemC models." $__install__valgrind)
	choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
	clear
	for choice in $choices
	do
    	    case $choice in
		1) __install__fsysc_demo=on ;;
		2) __install__f2dot=on ;;
		3) __install__fm2m=on ;;
		4) __install__valgrind=on ;;
    	    esac
	done
    fi
}

# Creates executable script and takes care of general dependencies.
function init-shell () {
    echo "[SETUP] : Installing shell dependencies"
    install-dependencies $dep_general

    touch forsyde-shell
    echo '#!/bin/bash' > forsyde-shell
    echo 'gnome-terminal -e "bash --rcfile shell/forsyde-shell.sh"' >> forsyde-shell
    chmod +x forsyde-shell

    force-add-var "__install__general" "on"
    add-export-var "SHELL_ROOT" "$(pwd)"
}

function install-forsyde-haskell {
    echo "[SETUP] : Currently ForSyDe-Haskell is not supported"
    force-add-var "__install__fhask" "off"
}


function install-forsyde-systemc {
    # syscpath=$(bash $scriptpath/setup-forsyde-systemc.sh $shfile | tail -n 1)
    # echo "$syscpath"
    # read -p "What is your machine architecture [linux64]" arch
    # if [ $arch ]; then arch_string=$arch; fi

    echo "[SETUP] : Installing ForSyDe-SystemC dependencies"
    echo "[SETUP] : SystemC path '$syscpath'"
    install-dependencies $dep_sysc

    echo "[SETUP] : Acquiring ForSyDe-SystemC libraries"
    clone-repo $repo_fsysc $libdir/ForSyDe-SystemC
    fsspath=$(cd $libdir/ForSyDe-SystemC; pwd)

    echo "[SETUP] : Creating  shell environment variables for SystemC-ForSyDe"
    force-add-var "__install__fsysc" "on"
    add-export-var "SYSC_ARCH"        $arch_string
    force-export-var "SYSTEMC_HOME"     "$syscpath"
    add-export-var "LD_LIBRARY_PATH"  "$syscpath/lib-$arch_string"
    add-export-var "SC_FORSYDE"       "$fsspath/src"
    add-export-var "FORSYDE_MAKEDEFS" "$scriptpath/Makefile.defs"
}

function install-apps () {
    echo "[SETUP] : Installing applications from $1 "
    mkdir -p $projdir
    appdir=$projdir/$2
    clone-repo $1 $appdir

    echo "[SETUP] : Creating  shell environment variables for applications"
    force-add-var "__install__fsysc_demo" "on"
    force-export-var "WORKSPACE" "${projdir}"
}

function install-f2dot {
    echo "[SETUP] : Installing f2dot dependencies"
    install-dependencies $dep_f2dot
    f2dotpath=$tooldir/f2dot
    clone-repo $repo_f2dot $f2dotpath

    echo "[SETUP] : Creating  shell environment variables for f2dot"
    force-add-var "__install__f2dot" "on"
    add-export-var "F2DOT" "$(cd $f2dotpath; pwd)/f2dot"
}

function install-forsyde-m2m {
    echo "[SETUP] : Installing dependencies for forsyde-m2m"
    install-dependencies $dep_fm2m
    fm2mpath=$tooldir/forsyde-m2m
    clone-repo $repo_fm2m $fm2mpath

    echo "[SETUP] : Creating  shell environment variables for forsyde-m2m "
    force-add-var "__install__fm2m" "on"
    add-export-var "FM2M_HOME" "$(cd $fm2mpath; pwd)"
    add-export-var "F2SDF3"    "$(cd $fm2mpath; pwd)/f2sdf3.xsl"
}

function install-f2et {
    echo "[SETUP] : Installing valgrind"
    install-dependencies $dep_valgrind
    force-add-var "__install__valgrind" "on"
}

function wrap-up () {
    echo "[SETUP] : Wrapping it all up..."
    echo "[SETUP] : Setting up the shell environment"

    source $shconf
    touch $shfile
    echo '#!/bin/bash'										>  $shfile
    echo											>> $shfile
    echo 'PS1="\[\e[32;2m\]\w\[\e[0m\]\n[ForSyDe-Demos]$ "'					>> $shfile
    echo											>> $shfile
    echo 'if [ "$FORSYDE_BASH_RUN" != "" ]; then'						>> $shfile
    echo '   return 0 # is already runníng'							>> $shfile
    echo 'fi'											>> $shfile
    echo 'FORSYDE_BASH_RUN=1'									>> $shfile
    echo											>> $shfile
    echo "source $shconf"									>> $shfile
    echo											>> $shfile
    if [ "$__install__general" = on ]; then
	echo "source $scriptpath/general.sh"							>> $shfile
    fi
    if [ "$__install__fsysc" = on ]; then
	echo "source $scriptpath/sysc_script.sh"						>> $shfile
    fi
    if [ "$__install__valgrind" = on ]; then    
	echo "source $scriptpath/valgrind_script.sh"						>> $shfile
    fi
    if [ "$__install__f2dot" = on ]; then
	echo "source $scriptpath/f2dot_script.sh"						>> $shfile
    fi
    if [ "$__install__fm2m" = on ]; then
	echo "source $scriptpath/fm2m_script.sh"						>> $shfile
    fi
    echo											>> $shfile
    echo 'echo "########################################################################'	>> $shfile 
    echo											>> $shfile
    echo "                  =  ForSyDe Shell v$version ="					>> $shfile 
    echo											>> $shfile
    echo " Libraries included:"       								>> $shfile 
    if [ "$__install__fhask" = on ]; then
	echo " * ForSyDe-Haskell"       					       		>> $shfile
    fi
    if [ "$__install__fsysc" = on ]; then
	echo " * ForSyDe-SystemC"              							>> $shfile
    fi
    echo											>> $shfile
    echo " Tools included:"       								>> $shfile
    if [ "$__install__f2dot" = on ]; then
	echo ' * f2dot           script path : $F2DOT'					        >> $shfile
    fi
    if [ "$__install__fm2m" = on ]; then
	echo ' * f2sdf3          script path : $F2SDF3'					        >> $shfile
    fi
    echo											>> $shfile
    if [ "$__install__fsysc_demo" = on ]; then
	echo " ForSyDe-SystemC applications:"							>> $shfile
	for app in $(find $projdir -type f -name '.project' -printf '%P\n'); do
	    appname=$(dirname $app)
	    echo " * $appname"       								>> $shfile	
	done
    fi
    echo											>> $shfile
    echo " To list all commands provided by the shell type 'list-commands'."			>> $shfile
    echo											>> $shfile
    echo "########################################################################"		>> $shfile
    echo '"'											>> $shfile
    echo											>> $shfile
    echo "cd \$WORKSPACE"									>> $shfile
    echo "export LS_OPTIONS='--color=auto'"							>> $shfile
    echo 'eval "`dircolors`"'									>> $shfile
    echo "alias ls='ls \$LS_OPTIONS'"								>> $shfile
    echo											>> $shfile
    echo "function list-commands () {"								>> $shfile
    echo '    echo " Commands provided by this shell (type help-<command> for manual):'		>> $shfile
    if [ "$__install__general" = on ]; then
	echo "$(source $scriptpath/general.sh; _print-general);"				>> $shfile
    fi
    if [ "$__install__fsysc" = on ]; then
	echo "$(source $scriptpath/sysc_script.sh; _print-general);"				>> $shfile
    fi
    if [ "$__install__valgrind" = on ]; then    
	echo " * $(source $scriptpath/valgrind_script.sh; info-execute-model)"			>> $shfile
    fi
    if [ "$__install__f2dot" = on ]; then
	echo " * $(source $scriptpath/f2dot_script.sh; info-plot)"				>> $shfile
    fi
    if [ "$__install__fm2m" = on ]; then
	echo " * $(source $scriptpath/fm2m_script.sh; info-f2sdf3)"				>> $shfile
    fi
    echo '"'											>> $shfile
    echo '}'											>> $shfile

}


function help-menu () {
    echo "ForSyDe-Shell v$version -- instalation script"
    echo "(c) 2016-2017 George Ungureanu KTH/ICT/ESY <ugeorge@kth.se>"
    echo
    echo "Usage: ./setup.sh <options>"
    echo
    echo "For customizing the installation check/modify 'setup.conf'."
    echo
    echo "Options:"
    echo "  -no-dialog : no interactive GUI. Only 'setup.conf' is considered."
    echo "               Useful in case you do *NOT* want to install the "
    echo "               'dialog' tool."
    echo "  -reset     : resets previous installation. May be called only"
    echo "               with the '-no-dialog' option."
    echo "  -uninstall : removes a previous installation. May be called only"
    echo "               with the '-no-dialog' option. "
}


####### MAIN ##########

if [[ $@ == *"-h"* ]]; then
    help-menu
    exit 1
fi

if [[ $@ == *"-no-dialog"* ]]; then
    if [[ $@ == *"-reset"* ]]; then reset-shell; fi
    if [[ $@ == *"-uninstall"* ]]; then uninstall-shell; fi
    __install__general=on
else
    install-dialog;
fi

source $shconf #load previous config
if [ "$__install__general" = on ];    then init-shell; fi
if [ "$__install__fhask" = on ];      then install-forsyde-haskell; fi
if [ "$__install__fsysc" = on ];      then install-forsyde-systemc; fi
if [ "$__install__fsysc_demo" = on ]; then install-apps $repo_fsysc_apps demo; fi
if [ "$__install__f2dot" = on ];      then install-f2dot; fi
if [ "$__install__fm2m" = on ];       then install-forsyde-m2m; fi
if [ "$__install__valgrind" = on ];   then install-f2et; fi

wrap-up

#read -p "Would you like to install the SDF3 tool chain? [y]" yn
#case $yn in
#    [Nn]* ) ;;
#    * ) source shell/__obsolete.sh; install-sdf3;;
#esac
