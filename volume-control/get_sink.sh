#!/usr/bin/env bash

# We only wish to query the default
if [[ -z $1 ]]; then
	default_sink=$(pactl info | sed -En 's/Default Sink: (.*)/\1/p')

	if [[ ${default_sink} == *"hw_sofhdadsp__sink"* ]]; then
		echo "c"
	elif [[ ${default_sink} == *"_Plantronics_Blackwire"* ]]; then
		echo "h"
	else
		echo "u"
	fi

	exit 0
fi

sink=$1
if [[ ${sink} == "c" ]]; then
	sink_id=$(pactl list short sinks | awk '/hw_sofhdadsp__sink/ {print $1}')
elif [[ ${sink} == "h" ]]; then
	sink_id=$(pactl list short sinks | awk '/_Plantronics_Blackwire/ {print $1}')
fi

if [[ -z ${sink} ]]; then
	echo "Chosen sink is invalid or not connected"
	exit 1
fi

echo "Setting chosen sink ${sink} with id ${sink_id}"
pacmd set-default-sink ${sink_id}
echo "Response to querying defualt sink is: $(pactl info | sed -En 's/Default Sink: (.*)/\1/p')"
