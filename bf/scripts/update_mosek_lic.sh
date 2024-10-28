#!/bin/bash
## 更新/mnt/bf-nvme-pool1/k8s-pv1/nfs-nsep下的所有mosek lic
#+ 下次到期时间：09-may-2025

for MOSEK_DIR in $(find /mnt/bf-nvme-pool1/k8s-pv1/nfs-nsep -maxdepth 1 -type d -name "*mosek*");do
    echo $MOSEK_DIR
    cp -a mosek.lic ${MOSEK_DIR}
    ls -lh ${MOSEK_DIR}/mosek.lic
done
