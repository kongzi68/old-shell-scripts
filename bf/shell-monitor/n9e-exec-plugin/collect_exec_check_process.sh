#!/bin/bash

PROCESS_NUM=$(ps -ef | grep fileSync3 | grep -v grep | wc -l)
echo "processes,type=check,region=shanghai,name=wind_tools_fileSync3 process_num=${PROCESS_NUM}"
