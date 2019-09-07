#!/bin/bash
pass=$(gpg2 --decrypt --quiet ~/.config/davwizard/accounts/$1.d/secret.gpg)
pass=$(printf '%q' $pass)
echo $pass
