#!/bin/bash

# veth for gNB/PDN
VETH="0 5"

if [ ${EUID:-${UID}} != 0 ]; then 
	echo "ERROR : should execute as the root user."
	exit 1
fi

function create () {
	
	for i in $VETH
	do
		if [ $i == 0 ]; then
			host="gNB"
			addr="10.10.1.0/24"
		elif [ $i == 5 ]; then
			host="PDN"
			addr="10.10.2.5/24"
		fi
		veth="veth"$i

		if [ -z "`ip netns show | grep $host`" ]; then
			ip netns add $host
			ip link set $veth netns $host up
			ip netns exec $host ip a add $addr dev $veth
			ip netns exec $host ip link set dev $veth up
			echo "INFO: $host is setup with $veth."
		else
			echo "INFO: host$i is already exist."
		fi
	done
}

function destroy () {

	# remove the interface / delete the host
	for i in $VETH
	do
		if [ $i == 0 ]; then
			host="gNB"
		elif [ $i == 5 ]; then
			host="PDN"
		fi
		veth="veth"$i

		if [ -n "`ip netns show | grep $host`" ]; then
			ip netns exec $host ip link set $veth netns 1
			ip link set dev $veth up
			ip netns delete $host
			echo "INFO: $host is deleted."
		else
			echo "INFO $host does not exist."
		fi
	done
}

while getopts "cd" OPT;
do
	case $OPT in
		c ) create
			exit 1;;
		d ) destroy
			exit 1;;
	esac
done

echo "Usage: $0 [-c|-d] (create or destroy)"