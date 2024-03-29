#!/bin/bash

#############################################
## @Author: Jumpline <schaffins>
## @Date:   2021-02-08T18:50:53-05:00
## @Email:  admins@jumpline.som
## @Filename: sd2cp.sh
## @Last modified by:   schaffins
## @Last modified time: 2021-07-19T21:41:01-04:00
#############################################

# -----------------------------------------------------------------------------
# Setting basic variables and functions to get started. This includes a list
# of users that will be used. A single user name can be used. This is ran with
# something like /sd2cp.sh USERNAME USERNAME2.
# -----------------------------------------------------------------------------

IFS=$'\n'
masteruserlist=( "$@" )

# function to kill the script if theres a Catastrophic Failure.
function dye()
{
  echo -e "\e[1m\e[41m Try Again! \e[0m"
  kill -s TERM $TOP_PID
}


# -----------------------------------------------------------------------------
# Some basic checks to create directories and files necessary to
# ensure things can get started. This will check for and grab the included
# scripts we will need.
# -----------------------------------------------------------------------------

# Creating directories
mkdir -p /root/
mkdir -p /var/log/sd2cp_logs/

# Logging
exec 2> /var/log/sd2cp_logs/stderr.log 1> >(tee -i /var/log/sd2cp_logs/stdout.log)

# -----------------------------------------------------------------------------
# Checking which server type is running, cPanel or VDS. Once determined this
# will download the appropriate pkg or restore script. If downloading the pkg
# script, it will also ask if you want to have it migrate to a destination
# server once packaged.
# -----------------------------------------------------------------------------
if [[ ! -f /usr/local/cpanel/cpanel ]]; then
  chmod 755 $(dirname "$0")/sd2cp_pkg.sh
  while :; do
    echo
    echo -e "\e[93m -------------------------------------------------------------------------------- \e[0m"
    echo -e "\e[93m ######################### \e[91m\e[1m Configuration / Setup  \e[0m\e[93m############################## \e[0m"
    echo -e "\e[93m -------------------------------------------------------------------------------- \e[0m"        #
    echo
    echo -e "\e[91m\e[1mWould you like this script to auto-copy the packaged account file to the destination server?\e[0m\e[1m [Y]es/[n]o \e[0m"
    read shouldrsync
    echo
    if [ "$shouldrsync" = "Y" ] || [ "$shouldrsync" = "Yes" ] || [ "$shouldrsync" = "y" ] || [ "$shouldrsync" = "yes" ]; then
      echo -e "\e[91m\e[1mType the full hostname of the destination/cPanel server, followed by [ENTER]:\e[0m";
      read fulldesthost
      echo

      echo -e "\e[91m\e[1mType the full path of the SSH key you wish to use, followed by [ENTER]:\e[0m"
      read fullkeythost
      shouldrsync="10"
      echo
      break
    elif [ "$shouldrsync" = "N" ] || [ "$shouldrsync" = "No" ] || [ "$shouldrsync" = "n" ] || [ "$shouldrsync" = "No" ]; then
      echo "No problemo, no rsyncing at the end."; echo;
      shouldrsync="11"
      break
    else
      echo -e "\e[33m\e[1m Unrecognizable Response, Please enter [Y]es or [N]o. \e[0m";echo;echo;
    fi
  done
elif [[ -f /usr/local/cpanel/cpanel ]]; then
  chmod 755 $(dirname "$0")/sd2cp_rest.sh
else
  echo "Cant Decide if this is a Package or Restore. STOP!"
  echo $(dye)
fi


# -----------------------------------------------------------------------------
# Again checking which server this is (probably could store that as a variable)
# in the previous check). Then, this makes some directories, copies the script
# and runs it. If VDS was chosen, this is the part that scp's to the
# destination server. The cPanel version generates a unique password for each
# account, restores then displays it after it restores the accounts.
# Then this cleans up everything except the original pkg file.
# -----------------------------------------------------------------------------

echo -e "\e[93m -------------------------------------------------------------------------------- \e[0m"
echo -e "\e[93m ###################### \e[91m\e[1mStaring Migration Process Now \e[0m\e[93m########################### \e[0m"
echo -e "\e[93m -------------------------------------------------------------------------------- \e[0m"

if [[ ! -f /usr/local/cpanel/cpanel ]] ; then
  for i in "${masteruserlist[@]}"
  do
    echo -e "\e[33m\e[1m Making $i root directory... \e[0m";sleep 1; echo
    eval mkdir -p ~"$i/root/migration_scripts"
    eval chown "$i\:" ~"$i/root/"
    echo -e "\e[33m\e[1m Copying script to $i root directory... \e[0m";sleep 1; echo
    eval cp -av $(dirname "$0")/sd2cp_pkg.sh ~"$i/root/migration_scripts/"
    echo -e "\e[33m\e[1m Chowning root directory to $i ownership... \e[0m";sleep 1; echo
    eval chown $i: -R ~"$i/root/migration_scripts/"
    echo -e "\e[33m\e[1m Running sd2cp_pkg.sh inside of $i VDS... \e[0m";sleep 1;
    su - $i -c 'cd /root/migration_scripts/; /bin/bash sd2cp_pkg.sh'
    if [ "$shouldrsync" -eq "10" ]; then
      echo -e "\e[33m\e[1m Rsyncing $i to $fulldesthost... \e[0m";sleep 1;

      ##ticking
      while :; do
        for s in / - \\ \|; do echo -ne "\r $s";sleep 1;done
      done &
      bgid=$!
      ##end ticking

      eval scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P 1022 -i "$fullkeythost" ~"$i/root/sd2cp_restore_$i.tar" root@"$fulldesthost":/root/
#      eval scp -P 1022 ~"$i/root/sd2cp_restore_$i.tar" "$fulldesthost":/root/

      kill "$bgid"; echo

      if [[ $? -eq 0 ]]; then
        echo
        echo -e "\e[33m\e[1m Rsyncing $i to $fulldesthost was success! \e[0m";
      elif [[ $? -ne 0 ]]; then
        #statements
        echo -e "\e[1m\e[41m Rsync Failure!! \e[0m";echo
      fi
    elif [[ "$shouldrsync" -eq "11" ]]; then

      ##ticking
      while :; do
        for s in / - \\ \|; do echo -ne "\r $s";sleep 1;done
      done &
      bgid=$!
      ##end ticking

      eval rsync -qaP --remove-source-files ~"$i/root/sd2cp_restore_$i.tar" /root/

      kill "$bgid"; echo

      echo -e "\e[1m\e[44m sd2cp_restore_`echo $i`.tar file backed up to /root/sd2cp_restore_`echo $i`.tar \e[0m";sleep 1;
      echo
    fi

    echo
    echo -e "\e[93m -------------------------------------------------------------------------------- \e[0m"
    echo -e "\e[93m ###################### \e[91m\e[1mAccount "$i" Migrated \e[0m\e[93m############################ \e[0m"
    echo -e "\e[93m -------------------------------------------------------------------------------- \e[0m"
    echo;echo
  done
elif [[ -f /usr/local/cpanel/cpanel ]]; then
  for i in "${masteruserlist[@]}"
  do
    rand0pass=$(/bin/date +%N%s | openssl enc -base64 |cut -c -12)
    cpname=$(echo $i | cut -c -8 | sed -E 's/[^[:alnum:]]+//g')
    echo "$cpname" "$rand0pass" >> /var/log/mig_user_pass
    echo -e "\e[33m\e[1m Restoring account $i \e[0m";sleep 1; echo
    #eval cd /root/sd2cp
    eval $(dirname "$0")/sd2cp_rest.sh "$i" "$cpname" "$rand0pass"
    sleep 5;
    echo;
  done
  echo -e "\e[33m\e[1m COPY THESE PASSWORDS NOW!!! THEY EXIST NOWHERE ELSE. \e[0m";
  echo -e "\e[33m\e[1m IF YOU DONT SAVE THESE NOW, YOU WILL HAVE TO REGENERATE FOR ALL CUSTOMERS MIGRATED \e[0m";
  echo -e "\e[33m\e[1m These corresponding password is used with anything that has a password in cPanel. \e[0m";sleep 1; echo
  cat /var/log/mig_user_pass
  echo
  rm -f /var/log/mig_user_pass
  rm -f /root/sd2cp_rest.sh
else
  echo "WHAT IS THIS SERVER?!"
fi

echo -e "\e[1m\e[41m Exiting. Done. \e[0m";echo

#rm -f /root/met_*

echo -e "\e[93m -------------------------------------------------------------------------------- \e[0m"
echo -e "\e[93m ############################## \e[91m\e[1mMigration Complete!\e[0m\e[93m ################################## \e[0m"
echo -e "\e[93m -------------------------------------------------------------------------------- \e[0m"


exit 0
