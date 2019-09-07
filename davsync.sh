#!/usr/bin/env bash

davwizard_dir="$HOME/.config/davwizard"
vdirsyncer_dir="$HOME/.vdirsyncer"

find "$vdirsyncer_dir" -type f -name "*.items*" -mmin +59 -exec rm {} \;

for account in $(ls -p $davwizard_dir/accounts/ | grep -v /); do
  echo "Syncing account $account"
  vdirsyncer -c "$davwizard_dir/accounts/$account.d/vdirsyncer.conf" sync
done
