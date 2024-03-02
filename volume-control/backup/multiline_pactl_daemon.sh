#!/usr/bin/env bash

pactl --format=json subscribe | while true; do
	read -t 0.5 holder

	if [[ -z ${holder} ]]; then
		continue
	fi

	echo $holder
done
