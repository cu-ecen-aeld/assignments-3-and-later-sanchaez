#!/bin/sh

# writer.sh
# Create a WRITEFILE by full path with WRITESTR content

## Validate args
if [ $# -ne 2 ]
then
    echo "Invalid number of arguments: expected 2 but $# provided"
    exit 1
fi

writefile=$1
writestr=$2
writefile_dir=$(dirname "$writefile")

exit_with_error() {
    echo "$1" >&2
    exit $2
}

## Act
mkdir -p "$writefile_dir" || exit_with_error "Failed to create a directory at $writefile_dir" 1
touch "$writefile" || exit_with_error "Failed to create a file at $writefile" 1
echo "$writestr" > $writefile || exit_with_error "Failed to write to $writefile" 1
