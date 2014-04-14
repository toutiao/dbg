#!/bin/bash
cd `dirname $0`
mkdir -p newpic

while true
do
    date
    cat .std.out | grep '^http' | sort -r | uniq > .urls; aria2c --http-proxy 42.120.23.151:13128 -i .urls -c -d newpic
    sleep 90
done
