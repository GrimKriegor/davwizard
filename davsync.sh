#!/usr/bin/env bash

davwizard_dir="$HOME/.config/davwizard"

for account in $(ls -p $davwizard_dir/accounts/ | grep -v /); do
  echo "Syncing account $account"
  vdirsyncer -c $davwizard_dir/accounts/$account.d/vdirsyncer.conf sync
done
