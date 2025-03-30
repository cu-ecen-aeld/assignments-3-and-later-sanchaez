#!/bin/sh

# finder.sh
# Find a SEARCHSTR in the FILESDIR
# NOTE: this script does not use /bin/bash as the finder-test uses /bin/sh shell to run the tests
# This means Bash specific extentions won't work here

## Validate args
if [ $# -ne 2 ]
then
    echo "Invalid number of arguments: expected 2 but $# provided" >&2
    exit 1
fi

filesdir=$1
searchstr=$2

if ! [ -d "$filesdir" ]
then
    echo "$filesdir is not a directory" >&2
    exit 1
fi

## Act
filecnt=0
matchcnt=0
for file in "$filesdir"/*
do
    if [ -f "$file" ]
    then
        filecnt=$((filecnt + 1))
        matchcnt=$((matchcnt + $(grep -c "$searchstr" "$file")))
    fi
done

echo "The number of files are $filecnt and the number of matching lines are $matchcnt"
