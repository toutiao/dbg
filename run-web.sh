#!/bin/bash
cd `dirname $0`

screen -r web || screen -S web rackup -p 4000 -o 127.0.0.1 -E production