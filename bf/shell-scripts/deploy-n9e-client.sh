#!/bin/sh

version=1.22.1
tarball=telegraf-${version}_linux_amd64.tar.gz
wget https://dl.influxdata.com/telegraf/releases/$tarball
tar xzvf $tarball

mkdir -p /opt/telegraf
cp -far telegraf-${version}/usr/bin/telegraf /opt/telegraf

# 修改hostname
NEWHOSTNAME="$(hostname)-$(ip addr list eth0 | grep -w inet | awk -F'[[:space:]]+|/' '{print $3}' | sed 's/\./-/g')"
# hostnamectl set-hostname $NEWHOSTNAME

cat <<EOF > /opt/telegraf/telegraf.conf
[global_tags]

[agent]
  interval = "10s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "0s"
  flush_interval = "10s"
  flush_jitter = "0s"
  precision = ""
  hostname = "$NEWHOSTNAME"
  omit_hostname = false

# [[outputs.opentsdb]]
#   host = "http://iamIPaddress"
#   port = 19000
#   http_batch_size = 50
#   http_path = "/opentsdb/put"
#   debug = false
#   separator = "_"

[[outputs.datadog]]
  timeout = "5s"
  url = "http://iamIPaddress:19000/datadog/api/v1/series"
  apikey = "iamsecrets11111111"

[[inputs.cpu]]
  percpu = true
  totalcpu = true
  collect_cpu_time = false
  report_active = true

[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]

[[inputs.diskio]]

[[inputs.kernel]]

[[inputs.mem]]

[[inputs.processes]]

[[inputs.system]]
  fielddrop = ["uptime_format"]

[[inputs.net]]
  ignore_protocol_stats = true

EOF

cat <<EOF > /etc/systemd/system/telegraf.service
[Unit]
Description="telegraf"
After=network.target

[Service]
Type=simple

ExecStart=/opt/telegraf/telegraf --config telegraf.conf
WorkingDirectory=/opt/telegraf

SuccessExitStatus=0
LimitNOFILE=65536
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=telegraf
KillMode=process
KillSignal=SIGQUIT
TimeoutStopSec=5
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable telegraf
systemctl restart telegraf
systemctl status telegraf

cd /opt && {
    [ -d telegraf-${version} ] && rm -rf telegraf-${version}
    [ -f ${tarball} ] && rm -f ${tarball}
    [ -f $(basename $0) ] && rm -f $(basename $0)
}
