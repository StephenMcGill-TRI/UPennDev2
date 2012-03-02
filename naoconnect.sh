#!/bin/sh

#######################################
#Accepts nao id (10x) and then connects
#######################################

sudo ifconfig eth0 192.168.0.200
rsync -avr --exclude=".*" ./Player/* nao@192.168.0.$1:Player/ 
ssh nao@192.168.0.$1
