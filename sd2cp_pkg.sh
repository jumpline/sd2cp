#!/bin/bash

#############################################
## @Author: Jumpline <schaffins>
## @Date:   2021-02-08T18:58:20-05:00
## @Email:  admins@jumpline.som
## @Filename: sd2cp_pkg.sh
## @Last modified by:   schaffins
## @Last modified time: 2021-07-20T00:16:56-04:00
#############################################


# -----------------------------------------------------------------------------
# Using this line to set some basic vairables.
# -----------------------------------------------------------------------------
VDSUSER=`id|awk '{print $1}'|cut -d "(" -f 2|cut -d ")" -f 1`
TODAY=`date +"%m-%d-%y"`
WDIR=/root/"$TODAY"_"$VDSUSER"
MDOM=`cat /bin/hostname | sed -n 2p | cut -d " " -f 2`
IP=`cat /etc/hosts |awk '{print $1}'|tail -1` #look into vds_ip command, much simpler.
IFS=$'\n'

# -----------------------------------------------------------------------------
# Announce that the process has begun.
# -----------------------------------------------------------------------------
echo
echo -e "\e[33m\e[1m Setting VDS user variable... \e[0m";sleep 1;
echo

# -----------------------------------------------------------------------------
# Check if the /root directory exists.
# -----------------------------------------------------------------------------
if [ ! -d /root ]
then
  mkdir /root
fi

# -----------------------------------------------------------------------------
# Making some of the text needed directories.
# -----------------------------------------------------------------------------
echo -e "\e[33m\e[1m Creating some directories to be used in the process... \e[0m"
mkdir -p /root/"$TODAY"_"$VDSUSER"/{text_files,database_dumps};
echo

# -----------------------------------------------------------------------------
# Get a list of email accounts
# -----------------------------------------------------------------------------
echo -e "\e[33m\e[1m Getting Email Account list... \e[0m"
cat /etc/mail/virtusertable |awk '{print $1}'|grep -vE '\#|MAILER-DAEMON|postmaster|^$|root\@|ftp\@'| sed '/^@/ d'|sed 's/www\.//' |uniq > "$WDIR"/text_files/"$VDSUSER"_mailusers;sleep 1;echo

echo -e "\e[33m\e[1m Copying mailbox data... \e[0m";

##ticking
while :; do
  for s in / - \\ \|; do echo -ne "\r $s";sleep 1;done
done &
bgid=$!
##end ticking

#cp -a /var/spool/mail "$WDIR"/mailboxes


mkdir -p "$WDIR"
cat /etc/mail/virtusertable |awk '{print $1}'|grep -vE '\#|MAILER-DAEMON|postmaster|^$|root\@|ftp\@'| sed '/^@/ d'|sed 's/www\.//' |uniq|sed 's/@.*//'|awk '!seen[$0]++' > "$WDIR"/mailusers.txt
cp -a /var/spool/mail "$WDIR"/mailboxes


while read MBNAME
do
  ls -1 "$WDIR"/mailboxes/ |grep "$MBNAME"\.*\.gz > "$WDIR"/$MBNAME.box.txt
  mv "$WDIR"/mailboxes/$MBNAME{,.original}

  cat "$WDIR"/$MBNAME.box.txt
  if [[ $? != 0 ]]
    then
      while read MBBOX
      do
        zcat "$WDIR"/mailboxes/"$MBBOX" >> "$WDIR"/mailboxes/"$MBNAME"

      done < "$WDIR"/$MBNAME.box.txt
  #else
  # echo "File is empty. Nothing captured, or nothing to restore"
  # exit 1
  fi

  cat "$WDIR"/mailboxes/$MBNAME.original >> "$WDIR"/mailboxes/"$MBNAME"

done < "$WDIR"/mailusers.txt;

kill "$bgid"; echo
# -----------------------------------------------------------------------------
# Get the main domain
# -----------------------------------------------------------------------------
echo -e "\e[33m\e[1m Making main domain file... \e[0m"; echo
#grep -E 'ServerName|DocumentRoot' /etc/httpd/conf/httpd.conf | head -2|sed -e 's/.*Name\ //g' |sed -e 's/.*DocumentRoot\ //g'| xargs -n2 |awk ' { t = $1; $1 = $2; $2 = t; print; } ' > "$WDIR"/text_files/"$VDSUSER"_main_domain;
echo $MDOM > "$WDIR"/text_files/"$VDSUSER"_main_domain;


# -----------------------------------------------------------------------------
# Get the addon domains, and the subdomains.
# -----------------------------------------------------------------------------
echo -e "\e[33m\e[1m Getting Addon and Subdomain lists... \e[0m"; echo
grep -E 'ServerName|DocumentRoot' /etc/httpd/conf/httpd.conf | grep -vE ':80|/var/www/html' |sed -e 's/.*Name\ //g' |sed -e 's/.*DocumentRoot\ //g'| xargs -n2 |awk '$1 !~ (/.*\..*\./)'| sed 's/www\.//' > "$WDIR"/text_files/"$VDSUSER"_addonsub_list;
grep -E 'ServerName|DocumentRoot' /etc/httpd/conf/httpd.conf | grep -vE ':80|/var/www/html' |sed -e 's/.*Name\ //g' |sed -e 's/.*DocumentRoot\ //g'| xargs -n2 |awk '$1 ~ (/.*\..*\./)'|grep -v "$MDOM"| sed 's/www\.//' > "$WDIR"/text_files/"$VDSUSER"_subdomain_list;

# -----------------------------------------------------------------------------
# List aliased/parked domains that have the web directory set to /var/www/html
# -----------------------------------------------------------------------------
echo -e "\e[33m\e[1m Getting Parked/Aliased domains list... \e[0m"; echo
#cat "$WDIR"/text_files/"$VDSUSER"_addonsub_list | awk '$2 == "/var/www/html"'|awk '{print $1}' >> "$WDIR"/text_files/"$VDSUSER"_parked_domains

# -----------------------------------------------------------------------------
# Singling out the parked domains.
# -----------------------------------------------------------------------------
excadon=`cat "$WDIR"/text_files/"$VDSUSER"_addonsub_list | awk -F '\' '{print $1}'`
cat /etc/mail/virtusertable |awk '{print $1}'|grep -vE '\#|^$'| sed '/^@/ d'|sed 's/.*@//'| grep -v 'www.'| sort -u >  "$WDIR"/text_files/"$VDSUSER"_all_domains

if [ -z "$excadon" ]; then
  cat "$WDIR"/text_files/"$VDSUSER"_all_domains |grep -v "$MDOM" | sed 's/www\.//' > "$WDIR"/text_files/"$VDSUSER"_parked_domains
else
  cat "$WDIR"/text_files/"$VDSUSER"_all_domains |grep -v "$MDOM" |grep -v "$excadon" | sed 's/www\.//' > "$WDIR"/text_files/"$VDSUSER"_parked_domains
fi

#cat "$WDIR"/text_files/"$VDSUSER"_all_domains |grep -v "$MDOM" |grep -v "$excadon" | sed 's/www\.//' > "$WDIR"/text_files/"$VDSUSER"_parked_domains

# -----------------------------------------------------------------------------
# Gathering addon domains whos paths are not specifically /var/www/html.
# -----------------------------------------------------------------------------
echo -e "\e[33m\e[1m Cleaning up domain lists... \e[0m"
cat "$WDIR"/text_files/"$VDSUSER"_addonsub_list |awk '$2 != "/var/www/html"' |sed 's/www\.//' > "$WDIR"/text_files/"$VDSUSER"_addon_subdomains;
echo

# -----------------------------------------------------------------------------
# This is going to start copying data for the addon domains.
# -----------------------------------------------------------------------------
echo -e "\e[33m\e[1m Copying addon domain and subdomain file data now... \e[0m"

##ticking
while :; do
  for s in / - \\ \|; do echo -ne "\r $s";sleep 1;done
done &
bgid=$!
##end ticking

  TMPemptychk=`cat "$WDIR"/text_files/"$VDSUSER"_addon_subdomains`

while read line
do
  d=`echo "$line" | awk '{print $1}'`
  s=`echo "$line" | awk '{print $2}'`
  mkdir -p /root/"$TODAY"_"$VDSUSER"/domain_files/$d/
  #cp -R "$s"/. /root/"$TODAY"_"$VDSUSER"/domain_files/$d/
  if [ ! -z "$TMPemptychk" ]; then
    rsync -vaP "$s"/. /root/"$TODAY"_"$VDSUSER"/domain_files/$d/
  else
    echo;echo "no addon domain files to rsync"
  fi
done < "$WDIR"/text_files/"$VDSUSER"_addon_subdomains;

kill "$bgid";
# -----------------------------------------------------------------------------
# Copying subdomains data
# -----------------------------------------------------------------------------

##ticking
while :; do
  for s in / - \\ \|; do echo -ne "\r $s";sleep 1;done
done &
bgid=$!
##end ticking
TMPemptychk2=$(cat "$WDIR"/text_files/"$VDSUSER"_subdomain_list)

while read sdcopy
do
  dcop=`echo "$sdcopy" | awk '{print $1}'`
  scop=`echo "$sdcopy" | awk '{print $2}'`
  mkdir -p /root/"$TODAY"_"$VDSUSER"/domain_files/$dcop/
  if [ ! -z "$TMPemptychk2"]; then
    rsync -vaP "$scop"/. /root/"$TODAY"_"$VDSUSER"/domain_files/$dcop/
  else
    echo;echo "no subdomain files to rsync"
  fi
  #cp -R "$scop"/. /root/"$TODAY"_"$VDSUSER"/domain_files/$dcop/
done < "$WDIR"/text_files/"$VDSUSER"_subdomain_list;

kill "$bgid"; echo

# -----------------------------------------------------------------------------
# Copying the main domain data. This is messy and ugly, but there's no rsync.
# -----------------------------------------------------------------------------
echo -e "\e[33m\e[1m Copying main domain... \e[0m"
grep -E 'ServerName|DocumentRoot' /etc/httpd/conf/httpd.conf | grep -vE ':80|/var/www/html' |sed -e 's/.*Name\ //g' |sed -e 's/.*DocumentRoot\ //g'| xargs -n2 |awk '{print $2}'|awk -F "/" '{print $NF}' |grep -v '^html$'|grep -v -e '^[[:space:]]*$' > "$WDIR"/text_files/tmp_excludes
mkdir -p /root/"$TODAY"_"$VDSUSER"/domain_files/$MDOM
ls /var/www/html/|grep -v '^manager.html$' |grep -v '^plugins$' |grep -v '^fm$' |grep -v '^users$' |grep -v '^manager$' |grep -v '^vdsbackup$'  |grep -vf "$WDIR"/text_files/tmp_excludes > "$WDIR"/text_files/mdom_exlist

#ticking
while :; do
  for s in / - \\ \|; do echo -ne "\r $s";sleep 1;done

done &
bgid=$!
##end ticking

while read fline
do
  cp -R /var/www/html/$fline $WDIR/domain_files/$MDOM/
done < "$WDIR"/text_files/mdom_exlist

kill "$bgid"; echo

# -----------------------------------------------------------------------------
# Find all existing MySQL databases. MySQL must be running.
# -----------------------------------------------------------------------------
echo -e "\e[33m\e[1m Getting list of MySQL databases and dumping them... \e[0m"

##ticking
while :; do
  for s in / - \\ \|; do echo -ne "\r $s";sleep 1;done
done &
bgid=$!
##end ticking

if [ ! -f /usr/bin/mysql ];
then
  echo -e "\e[31m No databases to dump! \e[0m"
else
  ls -A1 /var/lib/mysql/ |grep -Ev "^mysql$|\.err|\.sock" > $WDIR/text_files/"$VDSUSER"_databases
  for i in `cat "$WDIR"/text_files/"$VDSUSER"_databases`; do mysqldump $i > "$WDIR"/database_dumps/$i.sql;done
fi

kill "$bgid"; echo

# -----------------------------------------------------------------------------
# This tars and gzips all thats been gathered (data and text files, and dumps.)
# -----------------------------------------------------------------------------
##ticking
while :; do
  for s in / - \\ \|; do echo -ne "\r $s";sleep 1;done
done &
bgid=$!
##end ticking

echo -e "\e[33m\e[1m Archiving and compressing everything thats been done...\e[0m \e[1m\e[41m BE PATIENT! \e[0m "; sleep 1

tar -C "$WDIR" -cf /root/sd2cp_restore_"$VDSUSER".tar . |grep -v "Removing leading"

kill "$bgid";echo

echo -e "\e[33m\e[1m Archiving of all data now complete..."; echo

# -----------------------------------------------------------------------------
# Remove all the backed up files that we tar'd up. Leaving the tar.gz will.
# -----------------------------------------------------------------------------
echo -e "\e[33m\e[1m Cleaning Up data and packaging files... \e[0m";echo
rm -rf "$WDIR"

exit 0
