#!/bin/bash

IPTABLES="echo iptables"## remove echo to use
IN_INT="enp3s0" ## internet side interface
CONTAINER_NAME="web1" ## lxc container name
LOCAL_NET="x.y.z.s/27"## fill your public network
ACCPEPT_ROOT_LOCAL_NET_PORTS="22 1080" ## ports to open the root server from local network
ACCPEPT_ROOT_FROM_WORLDPORTS="" ## ports to open the root server from world wide network
ACCPEPT_CONTAINER_PORTS="80 110" ## port to open and DNAT to lxc container
WORLD_NET="0.0.0.0/0"

PUBIP=$(ip a show dev $IN_INT | grep inet\ | awk '{print $2}' | cut -f 1 -d\/)
CONTAINERIP=$(lxc-info $CONTAINER_NAME -iH)

acceptRulesFrom() {
    DPORT=$1
    MOD=$2
    SOURCE=$3
    $IPTABLES $MOD INPUT -i $IN_INT -p tcp --dport $DPORT -m state -s $SOURCE --state NEW,ESTABLISHED -j ACCEPT
    $IPTABLES $MOD OUTPUT -o $IN_INT -p tcp --sport $DPORT -m state -s $SOURCE --state ESTABLISHED -j ACCEPT
}

natContainer(){
    DPORT=$1
    MOD=$2
    $IPTABLES -t nat $MOD PREROUTING -d $PUBIP -p tcp -m tcp --dport $DPORT -j DNAT --to-destination $CONTAINERIP
    $IPTABLES $MOD FORWARD -p tcp -m tcp --dport $DPORT -d $CONTAINERIP  -j ACCEPT
}

updateIptables(){
POLICY=$1
MOD=$2
$IPTABLES -P INPUT $POLICY
$IPTABLES -P FORWARD $POLICY
$IPTABLES -P OUTPUT ACCEPT
$IPTABLES $MOD INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

$IPTABLES $MOD INPUT -p icmp --icmp-type echo-request -j ACCEPT
$IPTABLES $MOD OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT
$IPTABLES $MOD INPUT -i lo -j ACCEPT
$IPTABLES $MOD OUTPUT -o lo -j ACCEPT

for PORT in $ACCPEPT_ROOT_LOCAL_NET_PORTS; do
    acceptRulesFrom $PORT $MOD $LOCAL_NET
done
for PORT in $ACCPEPT_ROOT_FROM_WORLDPORTS; do
    acceptRulesFrom $PORT $MOD $WORLD_NET
done

for PORT in $ACCPEPT_CONTAINER_PORTS; do
    natContainer $PORT $MOD
done

}

case "$1" in
    start)
	updateIptables DROP "-A"
    ;;
    stop)
	updateIptables ACCEPT "-D"
    ;;
esac
