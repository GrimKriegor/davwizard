#!/bin/bash
pass=$(gpg2 --decrypt --quiet ~/.config/davwizard/credentials/$1.gpg)
pass=$(printf '%q' $pass)
echo $pass
