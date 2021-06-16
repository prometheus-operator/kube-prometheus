#!/bin/bash

set -euo pipefail

img_url="https://cloud-images.ubuntu.com/hirsute/current/hirsute-server-cloudimg-amd64.tar.gz"

script_dirname="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
outdir="${script_dirname}/_output/rootfs"

rm -Rf $outdir
mkdir -p $outdir

curl -L -o "${outdir}/rootfs.tar.gz" $img_url

cd $outdir

tar -xvf rootfs.tar.gz

qemu-img resize hirsute-server-cloudimg-amd64.img +20G

sudo virt-customize -a hirsute-server-cloudimg-amd64.img --run-command 'resize2fs /dev/sda'

sudo virt-customize -a hirsute-server-cloudimg-amd64.img --root-password password:root

netconf="
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:
      dhcp4: yes
"

# networking setup
sudo virt-customize -a hirsute-server-cloudimg-amd64.img --run-command "echo '${netconf}' > /etc/netplan/01-net.yaml"

# copy kernel modules
sudo virt-customize -a hirsute-server-cloudimg-amd64.img --copy-in /lib/modules/$(uname -r):/lib/modules

# ssh
sudo virt-customize -a hirsute-server-cloudimg-amd64.img --run-command 'apt remove openssh-server -y && apt install openssh-server -y'
sudo virt-customize -a hirsute-server-cloudimg-amd64.img --run-command "sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
sudo virt-customize -a hirsute-server-cloudimg-amd64.img --run-command "sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config"

# mark as ready
touch rootfs-ready.lock

echo "k3s development environment is ready"
