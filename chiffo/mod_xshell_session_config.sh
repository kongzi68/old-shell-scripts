#!/bin/bash

DIR='/d/Documents/NetSarang/Xshell/Sessions'

cd ${DIR} && {
    for i in $(find . -name "*.xsh")
    do
        sed -i '/ColorScheme=/s/=.*/=ANSI Colors on Black/' $i
        sed -i '/FontSize=/s/=.*/=11/' $i
        sed -i '/BoldMethod=/s/=.*/=0/' $i
        sed -i '/FontFace=/s/=.*/=Source Code Pro/' $i
        grep -E "ColorScheme|FontSize|BoldMethod|FontFace" $i
        echo "====================================="
    done
}