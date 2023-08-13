#!/bin/bash
# Define the above for bash binary location
# maui[at]mybsd.org.my, azmawee[at]azmawee.com azmawee[at]yahoo.com
# Copyright (c) 2016 - https://azmawee.com
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# Changelog:
# Version 1.0 - 26 Jul 2016 - Script lived.
# Version 1.1 - 27 Jul 2016 - Added email notification using mutt (support wide customization through ~/.muttrc).
# Version 1.2 - 03 Aug 2016 - Fix reporting bug. 
# Version 1.3 - 07 Sep 2016 - Changes report has better visibility of modified records (using rfcdiff).
# Version 1.4 - 14 Sep 2016 - Email body only content the changes found on record. Fixed some bugs.
# Version 1.5 - 19 Sep 2016 - Bug fixed.
# Version 1.6 - 27 Sep 2016 - Added archive feature.
# Version 1.7 - 01 Dec 2016 - Bug fix on reporting email.
# Version 1.8 - 14 Dec 2016 - Bug fix.
# Version 1.9 - 13 Aug 2023 - Bug fix.

# Script requirement:
# 1. Bash shell.
# 2. dig utility from Bind DNS server.
# 3. domain.txt file for targeted domains, one domain per line, all text will be auto convert into lowercase.
# (You can change the filename in "Targeted domain list file" variable).
# 4. Mutt email client (Optional if you enable email notification).
# 5. rfcdiff tool.

# This is an alternative workaround if the script run or didn't generate the report properply (Optional).
# 1. Create an ssh key within your own user - run ssh-keygen command
# 2. Copy the content of your ~/.ssh/id_rsa.pub to ~/.ssh/authorized_keys
# 3. Try to ssh to your own current user and see if you can ssh without password - ssh <user>@127.0.0.1
# 4. The crontab syntax for the script should be : ssh <user>@127.0.0.1 "~/<dir>/spfcheck.sh -q"

# Working path, default is in current directory (pwd)
#wpath="`pwd`"
wpath="`echo $HOME`/spfcheck"

# Location of dig utility and @<dns server ip to be use>
_dig="/usr/bin/dig @8.8.8.8"

# Targeted domain list file
filelist="$wpath/domain.txt"

# Log file
log_file=output.log
log="$wpath/$log_file"

# Change log file
output_change="changes.html"
change_log="$wpath/$output_change"

# Full CSV report file
output_file="output.csv"
report_file="$wpath/$output_file"

# Last report file
output_file_last="output_last.csv"
report_file_last="$wpath/$output_file_last"

# Email notification, 1 to enable, 0 to disable
email_notification="1"

# Location to mutt
_mail="/usr/bin/mutt"

# Location to rfcdiff
_rfcdiff="`echo $HOME`/rfcdiff/rfcdiff"

# List of emails
# Multiple recipients example : email_list="azmawee@domain1.com,azmawee@domain2.com,maui@domain3.com"
email_list="azmawee.mustafa@domain1.com"

# Enable Archive, 1 to enable, 0 to disable
archive="1"

# Archive location
arc_dir="archived"
arc_file="output-`date +"%Y-%m-%d"`.csv"
arc_log="$wpath/$arc_dir/$arc_file"

# Changes archive location
arcc_dir="archived-changes"
arcc_file="changes-`date +"%Y-%m-%d"`.html"
arcc_log="$wpath/$arcc_dir/$arcc_file"

_help(){
	echo "This script will check and compare the DMARC/SPF record recursively including all IP's of the 'include' record for all domains listed in the $filelist file."
	echo "Please create the $filelist and put one domain per line, all content in the file will be auto convert to lowercase."
	echo " "
	echo "Outout from this script : "
	echo "Log - $log "
	echo "Full CSV report - $report_file "
	echo "Last report - $report_file_last (Created on second time onward)"
	echo "Change log - $report_change (If the script detect ANY changes from Last report) "
	echo " "
	echo "Usage :"
	echo "$0 -q : Quite mode, silent on-screen output."
	echo " "
	exit 0
}

if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
        _help
fi

if [ ! -s $filelist ]; then
	echo "`date` - $filelist missing, please create the file (one domain per line)."
	exit 0
fi

if [ -r "$report_file" ]; then
        mv $report_file $report_file_last
fi

if [ "$1" != "-q" ]; then
	echo "`date` - Please use $0 -h or $0 --help to see more options."
fi

if [ "$1" != "-q" ]; then
	echo "`date` - Converting $filelist contents to lowercase..."
fi

# Convert domain name to lowercase
dd if=$filelist of=$filelist.tmp conv=lcase status=none
mv $filelist.tmp $filelist
if [ "$1" != "-q" ]; then
	echo "`date` - Converting done."
fi

_getspf(){
	$_dig +short txt "$1" | tr ' ' '\n' |
	while read entry; do
		case "$entry" in
			ip4:*)
				echo "ipv4:${entry#*:}"
				;;
			include:*)
				echo "$entry(`_getspf ${entry#*:}`)"
				;;
		esac
	done
}

echo "`date` - Script started." > $log
echo "Domain Name,Public SPF Record,Recursive SPF Record (with IP's listed)" > $report_file

for domain in `cat $filelist`
	do
		ips=(`_getspf $domain`)
		echo "$domain,`($_dig +short txt $domain | grep -i spf | tr -d '"')`,${ips[*]}" >> $report_file
	done

echo "`date` - Script ended. Full CSV report in $output_file" >> $log

cd $wpath

if [ -r "$report_file_last" ]; then
	_diff=(`diff $report_file $report_file_last`)
	if [ "$_diff" != "" ]; then
		$_rfcdiff --hwdiff $output_file_last $output_file $change_log 2>&1
		echo "Addition of new record will be highlighted in <strong><font color='green'>green</font></strong> and subtraction from the record will be highlighted with <strike><font color='red'>red strikethrough.</font></strike><p>" > $log
		egrep -i "strike>|strong>" $change_log >> $log 2>&1
		if [ "$email_notification" == "1" ]; then
			$_mail -e "set content_type=text/html" -s "DMARC Check : Alert! Policy has been changed from last check." -a $change_log -a $report_file -a $report_file_last -- $email_list < $log
		fi
	else
		echo "`date` - No record change from last report" >> $log
		if [ "$email_notification" == "1" ]; then
			$_mail -s "DMARC Check : No policy change." -a $report_file -- $email_list < $log
		fi
	fi
else
	cp $report_file $report_file_last
fi

if [ "$archive" == "1" ]; then
	[ -d "$arc_dir" ] && cp $report_file $arc_log || (mkdir $wpath/$arc_dir && cp $report_file $arc_log)
	if [ -f "$change_log" ] ; then
		[ -d "$arcc_dir" ] && mv $change_log $arcc_log || (mkdir $wpath/$arcc_dir && mv $change_log $arcc_log)
	fi
fi

if [ "$1" != "-q" ]; then
	cat $log
fi