#!/bin/bash
set +eu

iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT

iptables -F
iptables -X
iptables -Z
