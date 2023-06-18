+++
title = "PXE Boot - Getting Started (draft)"
tags = ["pxe", "hackathon"]
date = "2023-03-26"
+++

Preboot eXecution Environment (PXE) is a client-server [specification](http://www.pix.net/software/pxeboot/archive/pxespec.pdf) that enables computers to boot from the network.

### DHCP Server

`isc-dhcp-server` with the following config files `/etc/dhcp/dhcpd.conf`:

{{< highlight config >}}
option domain-name "example.org";
option domain-name-servers 8.8.8.8, 8.8.4.4;

default-lease-time 600;
max-lease-time 7200;

# The ddns-updates-style parameter controls whether or not the server will
# attempt to do a DNS update when a lease is confirmed. We default to the
# behavior of the version 2 packages ('none', since DHCP v2 didn't
# have support for DDNS.)
ddns-update-style none;

subnet 192.168.200.0 netmask 255.255.255.0 {
  range 192.168.200.10 192.168.200.20;
  option routers 192.168.200.1;
  next-server 192.168.200.1;
  option bootfile-name "/test/pxelinux.0";
}
{{< / highlight >}}

`/etc/default/isc-dhcp-server`:

{{< highlight config >}}
INTERFACESv4="enp0s31f6"
{{< / highlight >}}

### TFTP Server

`tftpd-hpa` server with the following config file `/etc/default/tftpd-hpa`:

{{< highlight config >}}
# /etc/default/tftpd-hpa

TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/srv/tftp"
TFTP_ADDRESS="0.0.0.0:69"
TFTP_OPTIONS="--secure"
{{< / highlight >}}

### Network images

### Other commands

`7z e debian-live-11.6.0-amd64-standard.iso <the file inside>` to extract a particular file inside the iso
