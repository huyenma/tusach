#!/bin/sh
random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}
install_3proxy() {
    version=0.8.9
    apt-get update && apt-get -y upgrade
    apt-get install gcc make git -y
    wget --no-check-certificate -O 3proxy-${version}.tar.gz https://raw.githubusercontent.com/Thanhan0901/install-proxy-v6/main/3proxy-${version}.tar.gz
    tar xzf 3proxy-${version}.tar.gz
    cd 3proxy-${version}
    make -f Makefile.Linux
    cd src
    mkdir /etc/3proxy/
    mv 3proxy /etc/3proxy/
    cd /etc/3proxy/
    wget --no-check-certificate https://github.com/SnoyIatk/3proxy/raw/master/3proxy.cfg
    chmod 600 /etc/3proxy/3proxy.cfg
    mkdir /var/log/3proxy/
    cd /etc/init.d/
    wget --no-check-certificate  https://raw.github.com/SnoyIatk/3proxy/master/3proxy
    chmod  +x /etc/init.d/3proxy
    update-rc.d 3proxy defaults
    cd $WORKDIR
}

gen_3proxy() {
    cat <<EOF
daemon
maxconn 1000
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
flush
auth strong

users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 " "}' ${WORKDATA})

$(awk -F "/" '{print "auth strong\n" \
"allow " $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}

upload_proxy() {
    local PASS=$(random)
    zip --password $PASS proxy.zip proxy.txt
    URL=$(curl -s --upload-file proxy.zip https://transfer.sh/proxy.zip)
    
    echo "Proxy is ready! Format IP:PORT:LOGIN:PASS"
    echo "Download zip archive from: ${URL}"
    echo "Password: ${PASS}"
    
}
install_jq() {
  wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
  chmod +x ./jq
  cp jq /usr/bin
}

upload_2file() {
  local PASS=$(random)
  zip --password $PASS proxy.zip proxy.txt
  JSON=$(curl -F "file=@proxy.zip" https://file.io)
  URL=$(echo "$JSON" | jq --raw-output '.link')

  echo "Proxy is ready! Format IP:PORT:LOGIN:PASS"
  echo "Download zip archive from: ${URL}"
  echo "Password: ${PASS}"
}
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "usr$(random)/pass$(random)/$IP4/$port/$(gen64 $IP6)"
    done
}

gen_iptables() {
    cat <<EOF
    $(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA})
EOF
}

gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "/sbin/ip -6 addr add dev enp1s0 " $5 }' ${WORKDATA})
EOF
}



echo "installing apps"

install_3proxy

echo "working folder = /home/proxy-installer"
WORKDIR="/home/proxy-installer"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal ip = ${IP4}. Exteranl sub for ip6 = ${IP6}"

echo "How many proxy do you want to create? Example 500"
read COUNT

FIRST_PORT=10000
LAST_PORT=$(($FIRST_PORT + $COUNT))

gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x ./home/proxy-installer/boot_iptables.sh
chmod +x ./home/proxy-installer/boot_ifconfig.sh
gen_3proxy >/etc/3proxy/3proxy.cfg
ulimit -S -n 4096
/etc/init.d/3proxy start

gen_proxy_file_for_user

#upload_proxy
install_jq && upload_2file
