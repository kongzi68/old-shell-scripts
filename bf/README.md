# scripts

> run gitlab pipeline
> 
> 若要触发pipeline管道，需要修改这个 README.md 文件的内容.......

存放运维相关shell、python等零散脚本。

## 忽略 CI

要在不触发管道的情况下推送提交，请将`[ci skip]`或`[skip ci]`使用任何大写形式添加到您的提交消息中。
或者，如果您使用的是 Git 2.10 或更高版本，请使用ci.skip Git 推送选项。ci.skippush 选项不会跳过合并请求管道。


## jenkins 脚本自动更新的 gitlab-runner

```bash
iamUserName@ecs-d3aipaddr-171:~$ docker ps | grep runner
076ad97a4699   gitlab/gitlab-runner:alpine-v14.2.0    "/usr/bin/dumb-init …"   11 months ago   Up 7 months    gitlab-runner
```

## ansible ssh 密钥

证书文件放 rke-k8s-rancher-tools 上，id_rsa_jenkins id_rsa_jenkins.pub

```bash
iamUserName@rke-k8s-rancher-tools:~/temp$ #ssh -i /home/iamUserName/.ssh/id_rsa_jenkins iamUserName@iamIPaddress
iamUserName@rke-k8s-rancher-tools:~/temp$ ssh-copy-id -i /home/iamUserName/.ssh/id_rsa_jenkins.pub iamUserName@iamIPaddress
/usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/home/iamUserName/.ssh/id_rsa_jenkins.pub"
The authenticity of host 'iamIPaddress (iamIPaddress)' can't be established.
ECDSA key fingerprint is SHA256:c3FlBc+pFQ4J1H6q+JrkYz4CoEo/1+s6jRpO8dESFJA.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
iamUserName@iamIPaddress's password:

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'iamUserName@iamIPaddress'"
and check to make sure that only the key(s) you wanted were added.

iamUserName@rke-k8s-rancher-tools:~/temp$ ssh -i /home/iamUserName/.ssh/id_rsa_jenkins iamUserName@iamIPaddress
......
  System load:  0.0                Processes:              389
  Usage of /:   46.2% of 98.18GB   Users logged in:        1
  Memory usage: 45%                IP address for eth0:    iamIPaddress
  Swap usage:   0%                 IP address for docker0: iamIPaddress
......
Last login: Thu May 18 20:42:30 2023 from iamIPaddress
iamUserName@apiipaddr-106:~$ exit
Connection to iamIPaddress closed.
```