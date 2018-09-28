# Title: parsOpts
# Description: parsOpts is a bash function that can be used to parse the positional parameters of a shell script into options and their corresponding arguments
# Version: 1.00
# Author: Andrew T. Withers

# Set OPTIND global variable to zero
OPTIND=0

parsOpts ()
{

# Unset OPT and OPTARG global variables
unset OPT
unset OPTARG

# Add all arguments (shell arguments + function argument) to the $args array
local args=("$@")
# Set OPTSTRING (Possible options and arguments) to the last argument in $args
local optstring="${args[(($#-1))]}"
# Remove the last argument in args (optstring)
unset "args[${#args[@]}-1]"

## Parse OPTSTRING
# Convert comma-separation to space-separation
optstring="$(echo $optstring  | sed -e 's/,/ /g')"
# Send options and there argument symbols to an array
local stringopts=($optstring)
# Create an associative array where the option is the key and the number of arguments for that option is the value. '-1' represents unknown number of options
declare -A opt_args
for i in "${stringopts[@]}"; do
	if [[ $(printf "%s" "$i" | grep -o ':' | grep -c ':') -eq 2 ]]; then		# Number of args is 0 > infinity (double ':' = Unknown)
		opt_args[$(printf "%s" "$i" | cut -d':' -f1)]=-1
	elif [[ $(printf "%s" "$i" | grep -c ':') -eq 0 ]]; then		# Number of args is 0 (no ':')
		opt_args["$i"]=0
	elif [[ $(printf "%s" "$i" | grep -o ':' | grep -c ':') -eq 1 ]] && [[ $(printf "%s" "$i" | cut -d':' -f2) =~ ^[0-9]+$ ]]; then
		opt_args[$(printf "%s" "$i" | cut -d':' -f1)]=$(printf "%s" "$i" | cut -d':' -f2)     # Number of args is equal to the number following ':'
	elif [[  $(printf "%s" "$i" | grep -o ':' | grep -c ':') -eq 1 ]] && [[ $(printf "%s" "$i" | cut -c 3) == '' ]]; then
		opt_args[$(printf "%s" "$i" | cut -d':' -f1)]=1	# Number of args is 1 (single ':')
	else
		OPTARG="$i"
		OPT='!'
		printf "parsOpts: Error while parsing OPTSTRING. Undefined number of args for option: %s." "$OPTARG"
		printf  "Ensure that the OPTSTRING is properly formatted."
		break 2
	fi
done

# Validate the integrity of the optstring. Ensure that each key has a positive or negative integer value
for i in "${!opt_args[@]}"; do
	if ! [[ ${opt_args["$i"]} =~ ^[+-]?[0-9]+$ ]] || [[ ${opt_args["$i"]} -lt -1 ]]; then
		OPTARG="$i"
		OPT='!'
		printf "parsOpts: Error while parsing OPTSTRING. Undefined number of args for option: %s." "$OPTARG"
		printf  "Ensure that the OPTSTRING is properly formatted."
		break 2
	fi
done

## Parse option
if [[ $(printf "%s" "${args[$OPTIND]}" | head -c1) != '-' ]]; then
	break
else
	# Check if more stringed short options require processing
	if [[ -n $____Stringed_Short_Option ]]; then
		# Get the next opt and remove it from the global string
		OPT=$(printf "%s" "$____Stringed_Short_Option" | head -c1)
		____Stringed_Short_Option=$(printf "%s" "$____Stringed_Short_Option" | cut -c 2-)
		# Check that the OPT is a key in opt_args
		if echo "${!opt_args[@]}" | grep -qw "$OPT"; then
			# Find the number of arguments that should be assosciated with this option
			local numargs="${opt_args[$OPT]}"
			if [[ $numargs  =~ ^[1-9]+$ ]]; then  # numargs is a positive integer. The option requires a specific number of args
				# Add the numargs number of arguments to the OPTARG string. If to few arguments exist, return OPT as OPTARG, OPT as ':', and NUMARGS
				local arg_count=0
				for (( i=$((OPTIND+1)); i<=$((OPTIND+numargs)); i++ )); do
					if [[ $(printf "%s" "${args["$i"]}" | head -c1) != '-' ]] && [[ -n ${args["$i"]} ]]; then
						OPTARG+="${args[$i]} "
						((arg_count++))
					else
						OPTARG="$OPT"
						OPT=':'
						NUMARGS="$numargs"
						# Change numargs to the actual number of arguments that were detected
						numargs=$arg_count
						break
					fi
				done
				if [[ $OPT != ':' ]] && [[ $(printf "%s" "$OPTARG" | rev | head -c1) == ' ' ]]; then      # The appropriate number of arguments were present
					OPTARG=$(printf "%s" "$OPTARG" | rev | cut -c 2- | rev)		# Remove the trailing space at the end of the OPTARG string
				fi
			elif [[ $numargs -eq -1 ]]; then	# An unknown number of arguments are attached to this option
				numargs=0
				i=$((OPTIND+1))
				while [[ $(printf "%s" "${args["$i"]}" | head -c1) != '-' ]] && [[ -n ${args[$i]} ]]; do
					OPTARG+="${args[$i]} "
					((i++))
					((numargs++))
				done
				if [[ $(printf "%s" "$OPTARG" | rev | head -c1) == ' ' ]]; then
					OPTARG=$(printf "%s" "$OPTARG" | rev | cut -c 2- | rev)	  # Remove the trailing space at the end of the OPTARG string
				fi
			fi
			# Check if numargs is > $____Stringed_Short_Option_Highest_Arg_Count
			if [[ $numargs -gt $____Stringed_Short_Option_Highest_Arg_Count ]]; then
				____Stringed_Short_Option_Highest_Arg_Count=$numargs
			fi
		else
			# OPT is not an allowable option as defined by the optstring
			OPTARG="$OPT"
			OPT='?'
		fi
		# If all of the options in the stringed short option have been processed, shift the number
		# of arguments of the option with the highest argument count
		if [[ -z $____Stringed_Short_Option ]]; then
			if [[ -z $____Stringed_Short_Option_Highest_Arg_Count ]]; then
				____Stringed_Short_Option_Highest_Arg_Count=0
			fi
			OPTIND=$(($OPTIND+$____Stringed_Short_Option_Highest_Arg_Count+1)) # shift arguments + option
			unset ____Stringed_Short_Option_Highest_Arg_Count
		fi
	elif [[ $(printf "%s" "${args[$OPTIND]}" | head -c2) == '--' ]]; then	# Long option
		OPT=$(printf "%s" "${args[$OPTIND]}" | cut -c 3-)	# Remove the leading double dash and set OPT as the option name
		# Check that OPT is a key in opt_args
		if echo "${!opt_args[@]}" | grep -qw "$OPT"; then
			# Find the number of arguments that should be assosciated with this option
			local numargs="${opt_args[$OPT]}"
			if [[ $numargs  =~ ^[1-9]+$ ]]; then  # numargs is a positive integer. The option requires a specific number of args
				# Add the numargs number of arguments to the OPTARG string. If to few arguments exist, return OPT as OPTARG, OPT as ':', and NUMARGS
				for (( i=$((OPTIND+1)); i<=$((OPTIND+numargs)); i++ )); do
					if [[ $(printf "%s" "${args["$i"]}" | head -c1) != '-' ]] && [[ -n ${args["$i"]} ]]; then
						OPTARG+="${args[$i]} "
					else
						OPTARG="$OPT"
						OPT=':'
						NUMARGS="$numargs"
						break
					fi
				done
				if [[ $OPT != ':' ]]; then	# The appropriate number of arguments were present
					if [[ $(printf "%s" "$OPTARG" | rev | head -c1) == ' ' ]]; then
						OPTARG=$(printf "%s" "$OPTARG" | rev | cut -c 2- | rev)		# Remove the trailing space at the end of the OPTARG string
					fi
					OPTIND=$(($OPTIND+numargs+1))	# Shift the appropriate number of arguments (arguments + option)
				else
					((OPTIND++))	# Shift the option
					while [[ $(printf "%s" "${args[$OPTIND]}" | head -c1) != '-' ]] &&  [[ $OPTIND -lt $# ]]; do	# Shift until an option is found or end of arguments
						((OPTIND++))
					done
				fi
			elif [[ $numargs -eq -1 ]]; then 	# An unknown number of arguments are attached to this option
				((OPTIND++))	# Shift the option
				while [[ $(printf "%s" "${args[$OPTIND]}" | head -c1) != '-' ]] && [[ $OPTIND -lt $# ]]; do	# While the argument is not an option and not end of arguments
					OPTARG+="${args[$OPTIND]} "	# Add the argument to the arguments string
					((OPTIND++))	# Shift the argument
				done
				if [[ $(printf "%s" "$OPTARG" | rev | head -c1) == ' ' ]]; then
					OPTARG=$(printf "%s" "$OPTARG" | rev | cut -c 2- | rev)	  # Remove the trailing space at the end of the OPTARG string
				fi
			else	# No args are required
				((OPTIND++))
			fi
		else
			# OPT is not an allowable option as defined by the optstring
			OPTARG="$OPT"
			OPT='?'
			((OPTIND++))
		fi
	elif [[ $(printf "%s" "${args[$OPTIND]}" | head -c1) == '-' ]] && [[ $(printf "%s" "${args[$OPTIND]}" | cut -c 3) != '' ]]; then		# Stringed short option
		OPT=$(printf "%s" "${args[$OPTIND]}" | cut -c 2)	# The second character in the string is the first option to be processed
		# Remove the first option from the string and add the rest to the stringed options global (____Stringed_Short_Option)
		____Stringed_Short_Option=$(printf "%s" "${args[$OPTIND]}" | cut -c 3-)
		# Check that OPT is a key in opt_args
		if echo "${!opt_args[@]}" | grep -qw "$OPT"; then
			# Find the number of arguments that should be associated with this option
			local numargs="${opt_args[$OPT]}"
			if [[ $numargs  =~ ^[1-9]+$ ]]; then  # numargs is a positive integer. The option requires a specific number of args
			       	# Add the numargs number of arguments to the OPTARG string. If to few arguments exist, return OPT as OPTARG, OPT as ':', and NUMARGS
			       	for (( i=$((OPTIND+1)); i<=$((OPTIND+numargs)); i++ )); do
				       	if [[ $(printf "%s" "${args["$i"]}" | head -c1) != '-' ]] && [[ -n ${args["$i"]} ]]; then
					       	OPTARG+="${args[$i]} "
				       	else
					       	OPTARG="$OPT"
					       	OPT=':'
					       	NUMARGS="$numargs"
					       	break
				       	fi
			       	done
				if [[ $OPT != ':' ]] && [[ $(printf "%s" "$OPTARG" | rev | head -c1) == ' ' ]]; then      # The appropriate number of arguments were present
				       	OPTARG=$(printf "%s" "$OPTARG" | rev | cut -c 2- | rev)		# Remove the trailing space at the end of the OPTARG string
			    fi
			elif [[ $numargs -eq -1 ]]; then	# An unknown number of arguments are attached to this option
				numargs=0
				i=$((OPTIND+1))
				while [[ $(printf "%s" "${args["$i"]}" | head -c1) != '-' ]] && [[ -n ${args["$i"]} ]]; do
					OPTARG+="${args[$i]} "
					((i++))
					((numargs++))
				done
				if [[ $(printf "%s" "$OPTARG" | rev | head -c1) == ' ' ]]; then
					OPTARG=$(printf "%s" "$OPTARG" | rev | cut -c 2- | rev)	  # Remove the trailing space at the end of the OPTARG string
				fi
			fi
			# Assign the number of arguments for the first option to the highest number of arguments variable (____Stringed_Short_Option_Highest_Arg_Count)
			____Stringed_Short_Option_Highest_Arg_Count=$numargs
		else
			# OPT is not an allowable option as defined by the optstring
			OPTARG="$OPT"
			OPT='?'
		fi
	else		# Short option
		OPT=$(printf "%s" "${args[$OPTIND]}" | cut -c 2)
		# Check that OPT is a key in opt_args
		if echo "${!opt_args[@]}" | grep -qw "$OPT"; then
			local numargs="${opt_args[$OPT]}"
			if [[ $numargs  =~ ^[1-9]+$ ]]; then  # numargs is a positive integer. The option requires a specific number of args
				# Add the numargs number of arguments to the OPTARG string. If to few arguments exist, return OPT as OPTARG, OPT as ':', and NUMARGS
				for (( i=$((OPTIND+1)); i<=$((OPTIND+numargs)); i++ )); do
					if [[ $(printf "%s" "${args["$i"]}" | head -c1) != '-' ]] && [[ -n ${args["$i"]} ]]; then
						OPTARG+="${args[$i]} "
					else
						OPTARG="$OPT"
						OPT=':'
						NUMARGS="$numargs"
						break
					fi
				done
				if [[ $OPT != ':' ]]; then      # The appropriate number of arguments were present
					if [[ $(printf "%s" "$OPTARG" | rev | head -c1) == ' ' ]]; then
						OPTARG=$(printf "%s" "$OPTARG" | rev | cut -c 2- | rev)		# Remove the trailing space at the end of the OPTARG string
					fi
					OPTIND=$(($OPTIND+numargs+1))    # Shift the appropriate number of arguments (arguments + option)
				else
					((OPTIND++))   # Shift the option
					while [[ $(printf "%s" "${args[$OPTIND]}" | head -c1) != '-' ]] && [[ $OPTIND -lt $# ]]; do  # Shift until an option is found or end of arguments
						((OPTIND++))
					done
				fi
			elif [[ $numargs -eq -1 ]]; then	# An unknown number of arguments are attached to this option
				((OPTIND++))   # Shift the option
				while [[ $(printf "%s" "${args[$OPTIND]}" | head -c1) != '-' ]] && [[ $OPTIND -lt $# ]]; do  # While the argument is not an option and not end of arguments
					OPTARG+=$(printf "%s" "${args[$OPTIND]} ")    # Add the argument to the arguments string
					((OPTIND++))   # Shift the argument
				done
				if [[ $(printf "%s" "$OPTARG" | rev | head -c1) == ' ' ]]; then
					OPTARG=$(printf "%s" "$OPTARG" | rev | cut -c 2- | rev)	  # Remove the trailing space at the end of the OPTARG string
				fi
			else	# No args are required
				((OPTIND++))
			fi
		else
			# OPT is not an allowable option as defined by the optstring
			OPTARG="$OPT"
			OPT='?'
			((OPTIND++))
		fi
	fi
fi
}
