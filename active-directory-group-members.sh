#!/bin/bash
#List Active directory Group members
#@author Fatih USTA
#@date 2013/11/10


adUsername="administrator"
adPassword="Password"

echo -n "
Checking AD integration..."
check_ad_wb=`wbinfo -t 2>&1`
check_stats_wb=`echo $?`
cehck_ad_net=`net ads testjoin 2>&1`
check_stats_net=`echo $?`

if [[ $check_stats_wb != "0" ]] || [[ $check_stats_net != "0" ]]; then
	echo "Failed"
	echo "Ad_Group_Members: ERROR: Active directory integration Failed" | logger
	exit 1
else
	echo "OK

"
fi

_rpcclient=`which rpcclient`

test -f $_rpcclient

if [ "$?" -ne 0 ]; then
	echo "Ad_Group_Members: ERROR: rpcclient is not installed"  | logger
        exit 2
fi


workgroup=`net ads workgroup | awk -F ": " '{print $2}'`
domain_sid=`wbinfo -n "domain users" | cut -d "-" -f 1-7`
domain_controller=`net ads info | grep "LDAP server name:" | awk -F ": " '{print $2}'`

listgroup=`wbinfo -g > /tmp/ad_group_list.tmp`

function ad_group_members()
{
        groupname=`echo $1 | cut -d"/" -f 2`
        group_sid=`wbinfo -n "$1"`

        if [ "$?" -ne 0 ]; then
                echo "Ad_Group_Members: ERROR: $group_sid" | logger
                exit 3
        fi

        #grpid=`echo $group_sid | sed "s/${domain_sid}-//" | sed 's/ Domain..*//'`
        grpid=`echo $group_sid | sed "s/${domain_sid}-//" | cut -d" " -f 1 `

        ridlist=`$_rpcclient -W $workgroup -U $adUsername%$adPassword -c "querygroupmem $grpid" $domain_controller | grep -w rid| tr -s '\t' ' ' |awk '{print $1}' | awk -F "0x" '{print $2}'| cut -d "]" -f 1`

        for rid in $ridlist; do
                data=`wbinfo -s ${domain_sid}-\`printf %d 0x${rid}\``
                eval `echo $data | awk '{print "member='"'"'"$1"'"'"'; type="$2}'`

                if [ "$type" == "2" ]; then
                        # List subgroup
			subgroup=`echo "$member" | awk -F "/" '{print $2}'`
                        echo "SubGroup: $subgroup		Group: $group"
                else
			#list group users
                        user=`echo "$member" | awk -F "/" '{print $2}'`
			echo "User: $user		Group: $group"
                fi
        done
}

# List the main group

while read group;
do
    ad_group_members "$group"
done < /tmp/ad_group_list.tmp
