#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin:/opt/homebrew/bin
export PATH

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
PLAIN='\033[0m'
BOLD='\033[1m'
SUCCESS='[\033[32mOK\033[0m]'
COMPLETE='[\033[32mDONE\033[0m]'
WARN='[\033[33mWARN\033[0m]'
ERROR='[\033[31mERROR\033[0m]'
WORKING='[\033[34m*\033[0m]'

# LANG=en_US.UTF-8
is64bit=`getconf LONG_BIT`

startTime=`date +%s`

if [ -f /www/server/mdserver-web/tools.py ];then
	echo -e "存在旧版代码,不能安装!,已知风险的情况下" 
	echo -e "rm -rf /www/server/mdserver-web"
	echo -e "可安装!" 
	exit 0
fi

_os=`uname`
echo "use system: ${_os}"

if [ "$EUID" -ne 0 ]
	then echo "Please run as root!"
	exit
fi

if [ ${_os} != "Darwin" ] && [ ! -d /www/server/mdserver-web/logs ]; then
	mkdir -p /www/server/mdserver-web/logs
fi

LOG_FILE=/var/log/mw-update.log

{

HTTP_PREFIX="https://"
LOCAL_ADDR=common
cn=$(curl -fsSL -m 10 -s http://ipinfo.io/json | grep "\"country\": \"CN\"")
if [ ! -z "$cn" ] || [ "$?" == "0" ] ;then
	LOCAL_ADDR=cn
fi

if [ "$LOCAL_ADDR" != "common" ];then
	declare -A PROXY_URL
    PROXY_URL["github_do"]="https://github.do/"
    PROXY_URL["gh_llkk_cc"]="https://gh.llkk.cc/https://"
    PROXY_URL["gh_felicity_ac_cn"]="https://gh.felicity.ac.cn/https://"
    PROXY_URL["ghfast_top"]="https://ghfast.top/"
    PROXY_URL["ghproxy_net"]="https://ghproxy.net/"
    PROXY_URL["gh_927223_xyz"]="https://gh.927223.xyz/https://"
    PROXY_URL["gh_proxy_net"]="https://gh-proxy.net/"
    
    PROXY_URL["source"]="https://"


	SOURCE_LIST_KEY_SORT_TMP=$(echo ${!PROXY_URL[@]} | tr ' ' '\n' | sort -n)
	SOURCE_LIST_KEY=(${SOURCE_LIST_KEY_SORT_TMP//'\n'/})
	SOURCE_LIST_LEN=${#PROXY_URL[*]}
fi


function AutoSizeStr(){
	NAME_STR=$1
	NAME_NUM=$2

	NAME_STR_LEN=`echo "$NAME_STR" | wc -L`
	NAME_NUM_LEN=`echo "$NAME_NUM" | wc -L`

	fix_len=35
	remaining_len=`expr $fix_len - $NAME_STR_LEN - $NAME_NUM_LEN`
	FIX_SPACE=' '
	for ((ass_i=1;ass_i<=$remaining_len;ass_i++))
	do 
		FIX_SPACE="$FIX_SPACE "
	done
	echo -e " ❖   ${1}${FIX_SPACE}${2})"
}

function ChooseProxyURL(){
	clear
    echo -e '+---------------------------------------------------+'
    echo -e '|                                                   |'
    echo -e '|   =============================================   |'
    echo -e '|                                                   |'
    echo -e '|     欢迎使用 Linux 一键安装mdserver-web面板源码   |'
    echo -e '|                                                   |'
    echo -e '|   =============================================   |'
    echo -e '|                                                   |'
    echo -e '+---------------------------------------------------+'
    echo -e ''
    echo -e '#####################################################'
    echo -e ''
    echo -e '            提供以下国内代理地址可供选择:                  '
    echo -e ''
    echo -e '#####################################################'
    echo -e ''
    cm_i=0
    for V in ${SOURCE_LIST_KEY[@]}; do
    num=`expr $cm_i + 1`
	AutoSizeStr "${V}" "$num"
	cm_i=`expr $cm_i + 1`
	done
    echo -e ''
    echo -e '#####################################################'
    echo -e ''
    echo -e "        系统时间  ${BLUE}$(date "+%Y-%m-%d %H:%M:%S")${PLAIN}"
    echo -e ''
    echo -e '#####################################################'
    CHOICE_A=$(echo -e "\n${BOLD}└─ 请选择并输入你想使用的代理地址 [ 1-${SOURCE_LIST_LEN} ]：${PLAIN}")

    read -p "${CHOICE_A}" INPUT
    # echo $INPUT
    if [ "$INPUT" == "" ];then
        INPUT=1
        TMP_INPUT=`expr $INPUT - 1`
        INPUT_KEY=${SOURCE_LIST_KEY[$TMP_INPUT]}
        echo -e "\n默认选择[${BLUE}${INPUT_KEY}${PLAIN}]安装！"
    fi

    if [ "$INPUT" -lt "0" ];then
		INPUT=1
		TMP_INPUT=`expr $INPUT - 1`
		INPUT_KEY=${SOURCE_LIST_KEY[$TMP_INPUT]}
		echo -e "\n低于边界错误!选择[${BLUE}${INPUT_KEY}${PLAIN}]安装！"
		sleep 2s
	fi

	if [ "$INPUT" -gt "${SOURCE_LIST_LEN}" ];then
		INPUT=${SOURCE_LIST_LEN}
		TMP_INPUT=`expr $INPUT - 1`
		INPUT_KEY=${SOURCE_LIST_KEY[$TMP_INPUT]}
		echo -e "\n超出边界错误!选择[${BLUE}${INPUT_KEY}${PLAIN}]安装！"
		sleep 2s
	fi

    INPUT=`expr $INPUT - 1`
    INPUT_KEY=${SOURCE_LIST_KEY[$INPUT]}
    HTTP_PREFIX=${PROXY_URL[$INPUT_KEY]}
}


if [ "$LOCAL_ADDR" != "common" ];then
	ChooseProxyURL

	if [ "$HTTP_PREFIX" != "https://" ];then
		DOMAIN=`echo $HTTP_PREFIX | sed 's|https://||g'`
		DOMAIN=`echo $DOMAIN | sed 's|/||g'`
		ping -c 3 $DOMAIN > /dev/null 2>&1
		if [ "$?" != "0" ];then
			echo "无效代理地址:${DOMAIN}"
			exit
		fi
	fi
fi

if [ ${_os} == "Darwin" ]; then
	OSNAME='macos'
elif grep -Eqi "openSUSE" /etc/*-release; then
	OSNAME='opensuse'
	zypper refresh
elif grep -Eqi "EulerOS" /etc/*-release || grep -Eqi "openEuler" /etc/*-release; then
	OSNAME='euler'
elif grep -Eqi "FreeBSD" /etc/*-release; then
	OSNAME='freebsd'
elif grep -Eqi "CentOS" /etc/issue || grep -Eqi "CentOS" /etc/*-release; then
	OSNAME='centos'
	yum install -y wget zip unzip
elif grep -Eqi "Fedora" /etc/issue || grep -Eqi "Fedora" /etc/*-release; then
	OSNAME='rhel'
	yum install -y wget zip unzip
elif grep -Eqi "Rocky" /etc/issue || grep -Eqi "Rocky" /etc/*-release; then
	OSNAME='rhel'
	yum install -y wget zip unzip
elif grep -Eqi "AlmaLinux" /etc/issue || grep -Eqi "AlmaLinux" /etc/*-release; then
	OSNAME='rhel'
	yum install -y wget zip unzip
elif grep -Eqi "Anolis" /etc/issue || grep -Eqi "Anolis" /etc/*-release; then
	OSNAME='rhel'
	yum install -y wget curl zip unzip tar crontabs
elif grep -Eqi "Amazon Linux" /etc/issue || grep -Eqi "Amazon Linux" /etc/*-release; then
	OSNAME='amazon'
	yum install -y wget zip unzip
elif grep -Eqi "Debian" /etc/issue || grep -Eqi "Debian" /etc/*-release; then
	OSNAME='debian'
	apt install -y wget zip unzip
elif grep -Eqi "Ubuntu" /etc/issue || grep -Eqi "Ubuntu" /etc/*-release; then
	OSNAME='ubuntu'
	apt install -y wget zip unzip
elif grep -Eqi "Raspbian" /etc/issue || grep -Eqi "Raspbian" /etc/*-release; then
	OSNAME='raspbian'
elif grep -Eqi "Alpine" /etc/issue || grep -Eqi "Alpine" /etc/*-release; then
	OSNAME='alpine'
else
	OSNAME='unknow'
fi

echo "local:${LOCAL_ADDR}"

CP_CMD=/usr/bin/cp
if [ -f /bin/cp ];then
	CP_CMD=/bin/cp
fi

if [ -f /tmp/dev.tar.gz ];then
	rm -rf /tmp/dev.tar.gz
fi

if [ -d /tmp/mdserver-web-dev ];then
	rm -rf /tmp/mdserver-web-dev
fi

echo "update mdserver-web dev code start"

curl --insecure -sSLo /tmp/dev.tar.gz ${HTTP_PREFIX}github.com/ramondelee/mdserver-web/archive/refs/heads/dev.tar.gz
cd /tmp && tar -zxvf /tmp/dev.tar.gz
$CP_CMD -rf /tmp/mdserver-web-dev/* /www/server/mdserver-web
rm -rf /tmp/dev.tar.gz
rm -rf /tmp/mdserver-web-dev

echo "update mdserver-web dev code end"


#pip uninstall public
echo "use system version: ${OSNAME}"
cd /www/server/mdserver-web && bash scripts/update/${OSNAME}.sh

bash /etc/rc.d/init.d/mw restart
bash /etc/rc.d/init.d/mw default

if [ -f /usr/bin/mw ];then
	rm -rf /usr/bin/mw
fi

if [ ! -e /usr/bin/mw ]; then
	if [ ! -f /usr/bin/mw ];then
		ln -s /etc/rc.d/init.d/mw /usr/bin/mw
	fi
fi

endTime=`date +%s`
((outTime=($endTime-$startTime)/60))
echo -e "Time consumed:\033[32m $outTime \033[0mMinute!"

} 1> >(tee $LOG_FILE) 2>&1
