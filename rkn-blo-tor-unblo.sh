#RKN blocks https://reestr.rublacklist.net/article/api

#dependencies:
pkgs='tor ipset wget md5sum ntpdate ca-certificates'

#path to store temporary files, if you installing on openwrt, set this path to USB or elsewhere not on the router drive
tordir='/tmp/'

#creating tordir if not exists
if [ ! -d $tordir ]
	then mkdir -p $tordir
fi

#getting urls of jsons with blocks and setting where to save downloaded jsons
currectstatsurl='https://reestr.rublacklist.net/api/v2/json'
domainsjsonurl='https://reestr.rublacklist.net/api/v2/domains/json'
ipsjsonurl='https://reestr.rublacklist.net/api/v2/ips/json'

currectstats=$tordir'rknblockedstats'
domainsjsonpath=$tordir'rknblockeddomains'
ipsjsonpath=$tordir'rknblockedips'

#detect internal ip address:
lanip=`ip a | grep -o -E "inet (192\.168(\.[0-9]{1,3}){2}|172\.16(\.[0-9]{1,3}){2}|10(\.[0-9]{1,3}){3})" | grep -o -E "([0-9]{1,3}\.){3}[0-9]{1,3}"`

#proxy port:
port='9050'

#how much percent of total memory to set for MaxMemInQueues (set if the system have RAM less than 256Mb)
percentofram='50'

#checking requirements
if grep -q -i 'openwrt' /proc/version
	then OS='openwrt'
elif grep -q -i 'Red Hat' /proc/version
	then OS='redhat'
fi

if [ $OS = 'openwrt' ]
	then
		installpkg(){
			if opkg install $1
				then continue
				else
					opkg update
					if opkg install $1
						then continue
						else
							echo "can't install package $1, breaking"
							exit
					fi
			fi
		}
		opkg list-installed > $tordir'installedpkgslist'
		for pkg in $pkgs
			do
				if cat $tordir'installedpkgslist' | grep -q "^$pkg"
					then continue
				elif which $pkg >> /dev/null
					then continue
				else
					installpkg $pkg
				fi
			done
		rm -f $tordir'installedpkgslist'
	else for pkg in $pkgs
		do
			if [ $pkg = 'ca-certificates' ]
				then
					if ls -1 /etc/ssl/certs/ | grep -q "^COMODO_"
						then echo "$pkg already installed"
					elif [ $OS = 'redhat' ]
						then continue
					else
							echo "$pkg not found"
					fi
			elif which $pkg >> /dev/null
				then echo "$pkg detected"
			else
				echo "$pkg not found, breaking"
				exit
			fi
		done
fi

#configuring tor
torconfpath='/etc/tor/'
if [ ! -f $torconfpath"torrc.old" ]
	then
		if [ -f $torconfpath"torrc" ]
			then mv $torconfpath"torrc" $torconfpath"torrc.old"
		fi
		#calculating optimal MaxMemInQueues parameter for tor
		ram=$(( `cat /proc/meminfo | grep MemTotal: | grep -o -E [0-9]+` / 1024 ))
		if [ $ram -lt 256 ]
			then
				maxmeminqueues=$(( ram * percentofram / 100 ))
			else
				maxmeminqueues='0'
		fi
		echo "
RunAsDaemon 1
ORPort 9001
ExitPolicy reject *:*
ExitPolicy reject6 *:*
SocksPort 127.0.0.1:$port
+SocksPort $lanip:$port
#MaxMemInQueues $maxmeminqueues #uncomment if the system have less than 256mb RAM
#DataDirectory $tordir #uncomment if the system don't have enough free space on the drive
ExcludeExitNodes {RU}" > $torconfpath"torrc"
		ntpdate -s time.nist.gov
		if [ OS = 'redhat' ]
			then systemctl restart tor
			else /etc/init.d/tor restart
		fi
fi

#echo "Log notice file /data/tor.log" >> $torconfpath"torrc"
#ntpdate -s time.nist.gov

if [ -f $torconfpath"torsocks.conf" ]
	then
		mv $torconfpath"torsocks.conf" $torconfpath"torsocks.conf.old"
		ntpdate -s time.nist.gov
		if [ OS = 'redhat' ]
			then systemctl restart tor
			else /etc/init.d/tor restart
		fi
fi

#parsing json with blocked domains list
parsedomainsjson() {
	IFS=", "
	for domain in $1
		do
			domain=${domain:1}
			domain=${domain%?}
			echo $domain
			break
		done
}

#parsing json with blocked IPs list
parseipsjson() {
	IFS=", "
	for ip in $1
		do
			ip=${ip:2}
			ip=${ip%??}
			echo $ip
			break
		done
}

if [ -f $currectstats ]
	then
		mv $currectstats "$currectstats.old"
		wget $currectstatsurl -O $currectstats
		if [ `md5sum $currectstats | awk '{ echo $1 }'` = `md5sum "$currectstats.old" | awk '{ echo $1 }'` ]
			then
				exit
		fi
	else
		wget $currectstatsurl -O $currectstats
fi

wget $domainsjsonurl -O $domainsjsonpath #downloading json with blocked domains
wget $ipsjsonurl -O $ipsjsonpath #downloading json with blocked ips

domains="`cat $domainsjsonpath`"
#cropping square brackets
domains=${domains:1}
domains=${domains%?}
ips="`cat $ipsjsonpath`"
#cropping double quotes and square brackets
ips=${ips:2}
ips=${ips%??}

parsedomainsjson "$domains"
rm -f $domainsjsonpath

parseipsjson "$ips"
rm -f $ipsjsonpath
