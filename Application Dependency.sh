#!/bin/zsh

:<<HEADER

██████╗  ██████╗  ██████╗██╗  ██╗███████╗████████╗███╗   ███╗ █████╗ ███╗   ██╗
██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝╚══██╔══╝████╗ ████║██╔══██╗████╗  ██║
██████╔╝██║   ██║██║     █████╔╝ █████╗     ██║   ██╔████╔██║███████║██╔██╗ ██║
██╔══██╗██║   ██║██║     ██╔═██╗ ██╔══╝     ██║   ██║╚██╔╝██║██╔══██║██║╚██╗██║
██║  ██║╚██████╔╝╚██████╗██║  ██╗███████╗   ██║   ██║ ╚═╝ ██║██║  ██║██║ ╚████║
╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝

        Name: Application Dependency
 Description: Waits for Core Applications to Install. Typically used for Dock Items with App Installers or Mac App Store Apps. 
  Created By: Christopher Schasse
     License: Copyright (c) 2023, Rocketman Management LLC. All rights reserved.  
   More Info: For Documentation, Instructions and Latest Version, visit https://www.rocketman.tech/jamf-toolkit 

      Parameter Options
        A number of options can be set with policy parameters.
        The order does not matter, but they must be written in this format:
           --options=value
           --trueoption
        See the section immediately below starting with CONFIG for the list.

       Future Improvements: 
        - Allow to define a file or a directory (right now it's just a directory... probable just have a [filedependency] parameter that you can set
        - Ability to add dependencies as a policy parameter (right now it can only be set by a local or managed plist)

HEADER
        
declare -A CONFIG
CONFIG=(
	[policytrigger]='' ## Policy to run after condition above has been met. EG: openChromeWebpages
	[timeout]='300' ## Timeout in seconds. EG: 1800
	[waitforuser]='' ## 'true' if you want to wait for the user to login before running. EG: true
	[multiple]='' ## 'true' if you want multiple dependencies defined through a plist. 
	[appdependency]='' ## Full path to application to wait for before proceeding. EG: /Applications/Google Chrome.app/
	[domain]='tech.rocketman.appdependency' ## Plist that the preferences will be stored. 
)

###
### Rocketman Functions
###

### Input Handlers ###

function loadArgs() { #f26de#
	## loadArgs "CONFIG" $argv

	## Input
	local hashName=$1  ## The name of the array as a string and NOT the array itself
	shift              ## Now we just deal with the rest

	## Now we make sure the rest is treated as an array regardless whether
	## the OS sent as string or list
    local argString="${argv}"
	local argList=(${(s:|:)argString//\ -/|-})

	## Output: NULL

	## Get a list of keys from the array
	keys=${(Pk)hashName}

	for arg in ${argList}; do

		## If it matches "--*" or "--*=*", parse into key/value or key/true
		case "${arg}" in
			--*=* ) # Key/Value pairs
				key=$(echo "$arg" | sed -E 's|^\-\-([^=]+)\=.*$|\1|g')
				val=$(echo "$arg" | sed -E 's|^\-\-[^=]+\=(.*)$|\1|g')
			;;

			--* ) # Simple flags
				key=$(echo "$arg" | sed -E 's|\-+(.*)|\1|g')
				val="True"
			;;

			*) # Invalid or no match in keys
				key=''
				val=''
		esac

		## If the current key is in the list of valid keys, update the array
		if [[ ${key} && $keys[(Ie)$key] -gt 0 ]]; then
			eval "${hashName}[${key}]='${val}'"
		fi

	done

	return 0 ## All is well
}

function loadPlist() { #21fa4#
	## loadPlist "CONFIG" "/Library/Preferences/tech.rocketman.workflow.plist"

	## Input
	local hashName=$1    ## The name of the array as a string and NOT the array itself
	local configFile=$2  ## Full path to plist file 

	## Output: NULL

	if [[ -f "${configFile}" ]]; then
		for key in ${(Pk)hashName}; do
			val=$(defaults read "${configFile}" "${key}" 2>/dev/null)
			if [[ $? -eq 0 ]]; then
				eval "${hashName}[$key]='$val'"
			fi
		done
	fi
}

function savePlist() { #799ce#
	## savePlist 'CONFIG' "${LOCALPLIST}" 

	## Input
	local hashName=$1    ## The name of the array as a string and NOT the array itself
	local configFile=$2  ## Full path to plist file 

	## Output: NULL

	for key in ${(Pk)hashName}; do
		defaults write "${configFile}" "${key}" "${${(P)hashName}[${key}]}" 2>/dev/null
	done
}

### Workflow Management ###

function getCurrentUser() { #faaf1#
	## CONFIG[currentuser]=$(getCurrentUser)

	## Input: NULL
	## Output
	local currentUser='' ## The string of the current user

	## Does the existing config know or do we need to check?
	if [[ $1 == '/' ]]; then 
		## We are in a Jamf environment
		currentUser=$3
	else
		## Make sure there's an active user
		dockRunning=$(pgrep -x Dock)
		if [[ ${dockRunning} ]]; then
			currentUser=$(defaults read /Library/Preferences/com.apple.loginwindow.plist lastUserName)
		fi
	fi

	## Send it back
	echo "${currentUser}"
	return 0
}

function countdown() { #366b6#
	## timeRemaining=$(countdown "${startTime}" "${CONFIG[timeout]}")

	## Input
	local startTime=$1 ## The UNIX time (in seconds) the clock started
	                   ## Ex. startTime=$(date +%s)
	local timeout=$2   ## How many seconds are we waiting

	## Output
	local remaining=0  ## Number of seconds left in the countdown

	remaining=$((${startTime}+${timeout}-$(date +%s)))
	echo ${remaining}
}
				
function waitForUser() { 
	## waitForUser [NOTE: No input or output]

	## Input:  NULL
	## Output: NULL
	## NOTE - This function is blocking until user logs in

	## Check to see if we're in a user context or not. Wait if not.
	local startTime=$(date +%s)
	dockStatus=$( pgrep -x Dock )
	while [[ "$dockStatus" == "" ]]; do
		sleep 1
		dockStatus=$( pgrep -x Dock )
		timeRemaining=$(countdown "${startTime}" "${CONFIG[timeout]}")
		echo "Waiting $timeRemaining seconds for user to login"
		if [[ $timeRemaining -le 0 ]];then
			echo "TIMEOUT: User did not install in ${CONFIG[timeout]} seconds. Exiting..."
			exit 1
		fi
	done
}

###
### Setup
###

## Path to local and managed plist files based on script domain
LOCALPLIST="/Library/Preferences/${CONFIG[domain]}.plist"
PROFILE="/Library/Managed Preferences/${CONFIG[domain]}.plist"

## Update input from policy parameters and profiles
loadArgs  "CONFIG" ${argv} ## Start here to get changes in $CONFIG[domain] for plists
loadPlist "CONFIG" "${LOCALPLIST}"
loadPlist "CONFIG" "${PROFILE}"
loadArgs  "CONFIG" ${argv} ## Now take these as written in stone

## Load common use parameters into CONFIG
CONFIG[currentuser]=$(getCurrentUser) ## Works for Jamf policy or command line

###
### Main
###

## Exit the script if the proper items are not set. 
if [[ ! ${CONFIG[timeout]} ]];then
	echo "The timeout parameter is not set. This is required to run. Exiting..."
	exit 1
fi

## Waits for the user to login if this setting is set
if [[ "${CONFIG[waitforuser]}" == "true" ]];then
  waitForUser
  echo "User is logged in. Checking if Core Applications are installed."
fi


if [[ "${CONFIG[multiple]}" == "true" ]];then
	# Check if either file exists
	if [[ ! -f "$LOCALPLIST" ]] && [[ ! -f "$PROFILE" ]]; then
		echo "Error: Neither $LOCALPLIST nor $PROFILE exist. These files are required for this script. Exiting..."
		exit 1
	fi
	
	count=$(( $(/usr/libexec/PlistBuddy -c "Print :Application" "$PROFILE" | wc -l | xargs) - 2 ))
	
	# Initialize an empty array to hold the application paths
	applications=()
	
	# Loop through each index in the array
	for ((i=0; i<count; i++)); do
		# Get the value at the current index and add it to the applications array
		app=$(/usr/libexec/PlistBuddy -c "Print :Application:$i" "$PROFILE")
		applications+=("$app")
	done
									
	# Start the timer
	startTime=$(date +%s)
	
	# Loop until all applications are found or timeout is reached
	while true; do
		allInstalled=true
		for app in "${applications[@]}"; do
			if [[ ! -d "$app" ]]; then
				allInstalled=false
				echo "Waiting for $app to be installed"
					timeRemaining=$(countdown "${startTime}" "${CONFIG[timeout]}")
					echo $timeRemaining
					if [[ $timeRemaining -le 0 ]];then
							echo "TIMEOUT: Core Applications did not install in ${CONFIG[timeout]} seconds. Exiting..."
							exit 1
					fi
				break
			fi
		done
	
		if $allInstalled; then
			break
		fi
	
		sleep 1
	done
	
	echo "Core Applications are installed: ${applications[@]}"
else
	if [[ ${CONFIG[appdependency]} ]];then
	startTime=$(date +%s)
	while [[ ! -d "${CONFIG[appdependency]}" ]];do
		timeRemaining=$(countdown "${startTime}" "${CONFIG[timeout]}")
		echo $timeRemaining
		if [[ $timeRemaining -le 0 ]];then
		echo "TIMEOUT: ${CONFIG[appdependency]} did not install in ${CONFIG[timeout]} seconds. Exiting..."
		exit 1
		fi
		sleep 1
	done
	echo "${CONFIG[appdependency]} is installed."
	fi
fi


if [ ${CONFIG[policytrigger]} ];then
		echo "Installing custom trigger ${CONFIG[policytrigger]}"
		jamf policy -event ${CONFIG[policytrigger]}
fi