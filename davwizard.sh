#!/usr/bin/env bash

set -e

davwizard_dir="$HOME/.config/davwizard"
default_title="davwizard"
temporary_folder="/tmp/davwizard/"

function exitWizard() {
  clear
  exit 0
}

function formatMenu() {
  list=("$@")
  list_truncated=()
  for item in "${list[@]}"; do
    list_truncated+=($item $item)
  done
  echo "${list_truncated[@]}"
}

function formatChecklist() {
  list=("$@")
  list_truncated=()
  for item in "${list[@]}"; do
    list_truncated+=($item $item off)
  done
  echo "${list_truncated[@]}"
}

function listAccounts() {
  echo $(ls -p $davwizard_dir/accounts | grep -v /)
}

function listAccountsMenu() {
  account_list=($(listAccounts))
  echo $(formatMenu $account_list)
}

function listAccountsChecklist() {
  account_list=($(listAccounts))
  echo $(formatChecklist $account_list)
}

function listAccountsDialog() {
  account_list="$(listAccounts)"
  dialog \
    --title "$default_title - Accounts detected" \
    --msgbox "The following accounts have been detected:
$account_list" \
    6 60 \
    3>&1 1>&2 2>&3 3>&-
}

function getAccountFile() {
  echo "$davwizard_dir"/accounts/"$1"
}

function setValueInFile() {
  key="$1"
  value="$2"
  file="$3"
  [ ! -f "$file" ] && touch "$file"
  sed -i "/\(^$key=\).*/d" "$file"
  echo "$key=\"$value\"" >> "$file"
}

function getValueInFile() {
  key="$1"
  file="$2"
  value="$(grep -w $key $file | awk -F'=' '{print $2}' | sed 's/"//g')"
  [ -z "$value" ] && value="null"
  echo $value
}

function createAccountConfig() {
  setValueInFile "name" "$1" "$davwizard_dir"/accounts/"$1"
  setValueInFile "encryption_key" "$2" "$davwizard_dir"/accounts/"$1"
  setValueInFile "url" "$3" "$davwizard_dir"/accounts/"$1"
  setValueInFile "username" "$4" "$davwizard_dir"/accounts/"$1"
  mkdir -p "$davwizard_dir/accounts/$1.d"
}

function getCerficate() {
  id="$1"
  url="$2"
  openssl s_client -showcerts -connect "$url" < /dev/null > /tmp/"$id".pem 2> /dev/null
}

function getCertificateFingerprint() {
  id="$1"
  echo $(openssl x509 -in /tmp/"$id".pem -noout -sha256 -fingerprint | awk -F "=" '{print $2}')
}

function vdirsyncerDiscovery() {
  account_name="$1"
  locations=( ".calendars" ".contacts" ".vdirsyncer" )
  for location in "${locations[@]}"; do
    [ -d "$HOME/$location" ] || \
      mkdir -p "$HOME/$location"
    [ -d "$HOME/$location/$account_name" ] && \
      mv "$HOME/$location/$account_name" "$HOME/$location/$account_name.bkp"
  done
  yes | vdirsyncer -c "$davwizard_dir/accounts/$account_name.d/vdirsyncer.conf" discover
}

function createAccountVdirsyncerConfig() {
  account_name="$1"
  vdirsyncer_config="$davwizard_dir/accounts/$account_name.d/vdirsyncer.conf"
  replacement="
    s|\$account|$(getValueInFile "name" "$davwizard_dir/accounts/$account_name")|g;
    s|\$url|$(getValueInFile "url" "$davwizard_dir/accounts/$account_name")|g;
    s|\$username|$(getValueInFile "username" "$davwizard_dir/accounts/$account_name")|g"
  touch "$vdirsyncer_config"
  cat $davwizard_dir/autoconf/vdirsyncer/config | sed -e "$replacement" >> "$vdirsyncer_config"
}

function addAccountDialog() {
  title="$default_title -- Account creation"
  account_name="$(dialog \
    --title "$title" \
    --inputbox "Enter a generic name to identify this account:" \
    10 60 \
    3>&1 1>&2 2>&3 3>&-)"
  account_encryption_key="$(dialog \
    --title "$title" \
    --inputbox "Enter the PGP key you wish to use to encrypt this account's password:" \
    10 60 \
    3>&1 1>&2 2>&3 3>&-)"
  account_url="$(dialog \
    --title "$title" \
    --inputbox "Enter the URL:" \
    10 60 \
    3>&1 1>&2 2>&3 3>&-)"
  account_username="$(dialog \
    --title "$title" \
    --inputbox "Enter the username:" \
    10 60 \
    3>&1 1>&2 2>&3 3>&-)"
  account_password="$(dialog \
    --title "$title" \
    --passwordbox "Enter the password:" \
    10 60 \
    3>&1 1>&2 2>&3 3>&-)"
  encryptPassword "$account_name" "$account_encryption_key" "$account_password"
  createAccountConfig "$account_name" "$account_encryption_key" "$account_url" "$account_username"
  createAccountVdirsyncerConfig "$account_name"
  vdirsyncerDiscovery "$account_name"
  dialog \
    --title "$title" \
    --msgbox "Account \"$account_name\" created." \
    10 60
}

function removeAccountDialog() {
  account_list=($(listAccountsChecklist))
  chosen=($(dialog \
    --separate-output \
    --no-tags \
    --checklist "Select all desired accounts with <SPACE>." \
    15 40 16 \
    "${account_list[@]}" \
    2>&1 >/dev/tty \
  ))
  for account in "${chosen[@]}"; do
    removeAccount "$account"
    dialog \
      --title "$default_title -- Account removal" \
      --msgbox "Account $account removed" \
      6 60 \
      3>&1 1>&2 2>&3 3>&-
  done
}

function removeAccount() {
  account_name="$1"
  rm -rf "$davwizard_dir/accounts/$account_name" | true
  rm -rf "$davwizard_dir/accounts/$account_name.d" | true
  rm -rf "$davwizard_dir/credentials/$account_name.gpg" | true
  locations=( ".calendars" ".contacts" ".vdirsyncer" )
  for location in "${locations[@]}"; do
    [ -d "$HOME/$location/$account_name" ] && \
      rm -rf "$HOME/$location/$account_name" | true
  done
}

function configureAutosyncDialog() {
  testSync() {
    (crontab -l | grep davsync.sh && removeSync) || \
      addSync
  }
  addSync() {
    min=$(dialog \
      --inputbox "How many minutes should be between mail syncs?" \
      8 60 \
      3>&1 1>&2 2>&3 3>&-)
    (crontab -l; echo "*/$min * * * * eval \"export $(egrep -z DBUS_SESSION_BUS_ADDRESS /proc/$(pgrep -u $LOGNAME -x i3)/environ)\"; "$davwizard_dir"/davsync.sh") | crontab -
    dialog \
      --msgbox "Cronjob successfully added. Remember you may need to restart or tell systemd/etc. to start your cron manager for this to take effect." \
      7 60
  }
  removeSync() {
    ((crontab -l | sed -e '/davsync.sh/d') | crontab - >/dev/null) && \
    dialog \
      --msgbox "Cronjob successfully removed. To reactivate, select this option again." \
      6 60
  }
  (cat /var/run/crond.pid && testSync) || dialog --msgbox "No cronjob manager detected. Please install one and return to enable automatic davsyncing" 10 60 ;
}

function getAccountEncryptionKey() {
  account_name="$1"
  getValueInFile "encryption_key" "$davwizard_dir/accounts/$account_name"
}

function encryptPassword() {
  account_name="$1"
  account_encryption_key="$2"
  account_password="$3"
  echo "$account_password" > "/tmp/davwizard_$account_name"
  gpg2 -r "$account_encryption_key" --encrypt "/tmp/davwizard_$account_name"
  shred -u "/tmp/davwizard_$account_name"
  mv "/tmp/davwizard_$account_name.gpg" "$davwizard_dir/credentials/$account_name.gpg"
}

function changeAccountPasswordDialog() {
  account_list=$(listAccountsMenu)
  account_name=$(dialog \
    --no-tags \
    --title "$default_title -- Password manager" \
    --menu "Select account:" \
    15 45 7 \
    ${account_list[@]} \
    3>&1 1>&2 2>&3 3>&1 \
  )
  account_password=$(dialog \
    --title "$default_title - Password manager" \
    --passwordbox "Enter the password for the \"$account_name\" account." \
    10 60 \
    3>&1 1>&2 2>&3 3>&-)
  encryptPassword "$account_name" "$(getAccountEncryptionKey $account_name)" "$account_password"
}

function listCalendars() {
  account_name="$1"
  calendar_location="$HOME/.calendars/$account_name"
  echo "$(ls $calendar_location | grep -v /)"
}

function listCalendarsMenu() {
  account_name="$1"
  collection_list=($(listCalendars $account_name))
  echo $(formatMenu $collection_list)
}

function setCalendarColor() {
  account_name="$1"
  calendar="$2"
  color="$3"
  calendar_location="$HOME/.calendars/$account_name/$calendar"
  echo "$color" > "$calendar_location/color"
}

function setCalendarColorDialog() {
  account_list=$(listAccountsMenu)
  account_name=$(dialog \
    --no-tags \
    --title "$default_title -- Collection manager" \
    --menu "Select account:" \
    15 45 7 \
    ${account_list[@]} \
    3>&1 1>&2 2>&3 3>&1 \
  )
  echo $(listCalendars "$account_name")
  calendar_list=$(formatMenu $(listCalendars "$account_name"))
  calendar_name=$(dialog \
    --no-tags \
    --title "$default_title -- Collection manager" \
    --menu "Select calendar:" \
    15 45 7 \
    ${calendar_list[@]} \
    3>&1 1>&2 2>&3 3>&1 \
  )
  echo ${color_list_menu[@]}
  color_name=$(dialog \
    --no-tags \
    --title "$default_title -- Collection manager" \
    --inputbox "Select color:" \
    10 60 \
    3>&1 1>&2 2>&3 3>&1 \
  )
  setCalendarColor "$account_name" "$calendar_name" "$color_name"
}

function advancedOptions() {
  choice=$(dialog \
    --title "$default_title - Advanced options" --nocancel \
    --menu "What would you like to do?" 15 45 7 \
      0 "Change calendar color" \
    3>&1 1>&2 2>&3 3>&1 )
  case $choice in
    0) setCalendarColorDialog ;;
    9) exitWizard ;;
  esac
}

trap "exitWizard" 0 1 2 3 15
while true; do
  choice=$(dialog \
    --title "$default_title" --nocancel \
    --menu "What would you like to do?" 15 45 7 \
      0 "List all accounts configured." \
      1 "Add an account." \
      2 "Enable/disable autosync." \
      3 "Change an account's password." \
      4 "Remove an account." \
      5 "Advanced options." \
      9 "Exit this wizard." \
    3>&1 1>&2 2>&3 3>&1 )
  case $choice in
    0) listAccountsDialog ;;
    1) addAccountDialog ;;
    2) configureAutosyncDialog ;;
    3) changeAccountPasswordDialog ;;
    4) removeAccountDialog ;;
    5) advancedOptions ;;
    9) exitWizard ;;
    *) echo "Unable to read response from dialog. Exiting." >&2; exit 2
  esac
done

