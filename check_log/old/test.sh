#!/bin/bash

test_dir=(
	mysql
	test1
	test2
)

test1111=`echo ${test_dir[@]} |sed "s/ /|/g"`
echo ${test1111}
