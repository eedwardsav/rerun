#!/bin/bash
#
# NAME
#
#   add-option
#
# DESCRIPTION
#
#   add a command option
#

# Source common function library
source $RERUN_MODULES/stubbs/lib/functions.sh || { echo "failed laoding function library" ; exit 1 ; }

# Upper case the string
caps() { echo "$1" | tr '[:lower:]' '[:upper:]' ; }

# Used to generate an entry inside options.sh
add_optionparser() {
    oU=$(echo $1 | tr "[:lower:]" "[:upper:]")
    printf " -%s) rerun_syntax_check \$# ; %s=\$2 ; shift ;;\n" "$1" "$oU"
}

# Init the handler
rerun_init 

# Get the options
while [ "$#" -gt 0 ]; do
    OPT="$1"
    case "$OPT" in
        # options without arguments
	# options with arguments
	-name)
	    rerun_syntax_check "$#"
	    NAME="$2"
	    shift
	    ;;
	-description)
	    rerun_syntax_check "$#"
	    DESC="$2"
	    shift
	    ;;
	-command)
	    rerun_syntax_check "$#"
	    COMMAND="$2"
	    shift
	    ;;
	-module)
	    rerun_syntax_check "$#"
	    MODULE="$2"
	    shift
	    ;;
	-req)
	    rerun_syntax_check "$#"
	    REQ="$2"
	    shift
	    ;;
	-args)
	    rerun_syntax_check "$#"
	    ARGS="$2"
	    shift
	    ;;
	-default)
	    rerun_syntax_check "$#"
	    DEFAULT="$2"
	    shift
	    ;;
        # unknown option
	-?)
	    rerun_syntax_error
	    ;;
	  # end of options, just arguments left
	*)
	    break
    esac
    shift
done

# Post process the options
[ -z "$NAME" ] && {
    echo "Name: "
    read NAME
}

[ -z "$DESC" ] && {
    echo "Description: "
    read DESC
}

[ -z "$MODULE" ] && {
    echo "Module: "
    select MODULE in $(rerun_modules $RERUN_MODULES);
    do
	echo "You picked module $MODULE ($REPLY)"
	break
    done
}

[ -z "$COMMAND" ] && {
    echo "Command: "
    select COMMAND in $(rerun_commands $RERUN_MODULES $MODULE);
    do
	echo "You picked command $COMMAND ($REPLY)"
	break
    done
}


# Generate metadata for new option

(
    cat <<EOF
# generated by add-option
# $(date)
NAME=$NAME
DESCRIPTION="$DESC"
ARGUMENTS=${ARGS:-true}
REQUIRED=${REQ:-true}
DEFAULT=$DEFAULT

EOF
) > $RERUN_MODULES/$MODULE/commands/$COMMAND/$NAME.option || rerun_die


# list the options that set a default
optionsWithDefaults=
for opt in $(rerun_options $RERUN_MODULES $MODULE $COMMAND); do
    default=$(rerun_optionDefault $RERUN_MODULES $MODULE $COMMAND $opt)
    [ -n "$default" ] && optionsWithDefaults="$optionsWithDefaults $opt"
done

# Generate option parser script.

(
cat <<EOF
# generated by add-option
# $(date)

# options: [$(rerun_options $RERUN_MODULES $MODULE $COMMAND)]
while [ "\$#" -gt 0 ]; do
    OPT="\$1"
    case "\$OPT" in
        $(for o in $(rerun_options $RERUN_MODULES $MODULE $COMMAND); do printf "%8s\n" "$(add_optionparser $o)"; done)
        # unknown option
        -?)
            rerun_syntax_error
            ;;
        # end of options, just arguments left
        *)
          break
    esac
    shift
done

# If defaultable options variables are unset, set them to their DEFAULT
$(for opt in $(echo $optionsWithDefaults|sort); do
printf "[ -z \"$%s\" ] && %s=%s\n" $(caps $opt) $(caps $opt) $(rerun_optionDefault $RERUN_MODULES $MODULE $COMMAND $opt)
done)
EOF
) > $RERUN_MODULES/$MODULE/commands/$COMMAND/options.sh || rerun_die

# Done
echo "Wrote options script: $RERUN_MODULES/$MODULE/commands/$COMMAND/options.sh"
echo "Wrote option metadata: $RERUN_MODULES/$MODULE/commands/$COMMAND/$NAME.option"


