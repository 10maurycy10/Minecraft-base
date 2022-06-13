#!/bin/bash
# NOTE: We use zsh for better readability and error handling here
# but it's not hard to make it work with regular shell
set -euo pipefail
# SETTINGS
readonly mail_address="someone@0.0.0.0"
# Path for logfiles that get mailed
readonly logpath=logs/latest.log
# How long (in seconds) to wait before restarting
readonly restart_delay=15
# Whether to restart on crash or not
# The `settings.restart-on-crash` setting in spigot.yml doesn't always work
# but also sometimes server might not return proper exit code,
# so it's best to keep both options enabled
# Accepted values: y/yes/true/n/no/false
readonly restart_on_crash='true'
# The name of your server jar
readonly server_jar='server.jar'
# What will be passed to `-Xms` and `-Xmx`
readonly heap_size='8G' # aka "RAM"
# JVM startup flags, one per line for better readability
# These are mostly "Aikar flags"
# taken from: https://mcflags.emc.gs/
readonly jvm_flags=(
	"-Xms${heap_size}"
	"-Xmx${heap_size}"
	-XX:+UseG1GC
	-XX:+ParallelRefProcEnabled
	-XX:MaxGCPauseMillis=200
	-XX:+UnlockExperimentalVMOptions
	-XX:+DisableExplicitGC
	-XX:+AlwaysPreTouch
	-XX:G1NewSizePercent=30
	-XX:G1MaxNewSizePercent=40
	-XX:G1HeapRegionSize=8M
	-XX:G1ReservePercent=20
	-XX:G1HeapWastePercent=5
	-XX:G1MixedGCCountTarget=4
	-XX:InitiatingHeapOccupancyPercent=15
	-XX:G1MixedGCLiveThresholdPercent=90
	-XX:G1RSetUpdatingPauseTimePercent=5
	-XX:SurvivorRatio=32
	-XX:+PerfDisableSharedMem
	-XX:MaxTenuringThreshold=1
	-Daikars.new.flags=true
	-Dusing.aikars.flags=https://mcflags.emc.gs
	--add-modules=jdk.incubator.vector # SIMD operations
)
# Minecraft arguments you might want to start your server with
# Usually there isn't much to configure here:
readonly mc_args=(
	--nogui # Start the server without GUI
)
# Java executable
readonly java_executable="java"
# END SETTINGS

should_restart_on_crash() {
	case "${restart_on_crash,,}" in
		y|yes|true) return 0;;
		n|no|false) return 1;;
		*)
			echo "ERROR: Invalid value for 'restart_on_crash' variable: ${restart_on_crash}"
			exit 1
			;;
	esac
}

# The arguments that will be passed to Java:
readonly java_args=(
	"${jvm_flags[@]}" # Use JVM flags specified above
	-jar "${server_jar}" # Run the server
	"${mc_args[@]}" # And pass it these settings
)

# Check if `restart_on_crash` has valid value
should_restart_on_crash || true

restart=""

while :; do # Loop infinitely
	# Run server
	${java_executable} "${java_args[@]}" || {
		# Oops, server didn't exit gracefully
		echo "Detected server crash (exit code: ${?})"
		echo "There is likey more info above or in the log files"
		if hash mutt ; then
			date | mutt "${mail_address}" -a "${logpath}" -s "server crash!"
		else
			echo "mutt is not found, log will not be sent"
		fi
		# Check if we should restart on crash or not
		if should_restart_on_crash; then
			restart="yes"
		fi
	}
	# check if a restart is required. if not, exit
	if [ -z "${restart}" ]; then
		break
	else
		restart=""
	fi
	echo "Restarting server in ${restart_delay} seconds, press Ctrl+C to abort."
	sleep "${restart_delay}" || break # Exit if sleep is interrupted (for example Ctrl+C)
done

echo 'Server stopped'
