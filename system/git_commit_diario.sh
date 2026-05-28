#!/bin/bash

HOY=`date "+%F %H:%M:%S"`

cd /etc/mon &&
(git status
echo
git diff
echo
git commit -a -m "Commit diario ${HOY} en $(hostname -s)"
echo)
