#!/bin/bash

DIR='/data/www/traindata/files/movies/'
for MOVIE_NAME in $(find ${DIR} -maxdepth 1 -type d |awk -F/ '{print $NF}')
do
    cd ${DIR}${MOVIE_NAME} && {
        [ -e ${MOVIE_NAME}_10min.m3u8 ] || {
            cp ${MOVIE_NAME}.m3u8 ${MOVIE_NAME}_10min.m3u8
            sed -i "/${MOVIE_NAME}-60.ts/{n;d}" ${MOVIE_NAME}_10min.m3u8
            sed -i "/${MOVIE_NAME}-61.ts/,$"d ${MOVIE_NAME}_10min.m3u8
            echo "#EXT-X-ENDLIST" >> ${MOVIE_NAME}_10min.m3u8
        }
    }
done 