#!/bin/bash
cd `dirname $0`

while true
do
	for group_id in $(cat groups.txt | grep -v ^#)
	do
		date
		echo "===group ${group_id}"
		GROUP_ID=${group_id} ruby douban-group.rb >> .std.out
		sleep 55
	done
done