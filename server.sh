#!/bin/sh
git pull
cp server.properties.default server.properties
screen -US mc ./start.sh
