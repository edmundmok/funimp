#!/bin/bash
# Use chmod +x funimp.sh if permission denied

# Get proj/workspace
FILENAME_WITH_PATH=`find . -maxdepth 1 -name \*.xcworkspace -o -name \*.xcodeproj | sort -r | head -n 1`
FILENAME_WITH_EXT=${FILENAME_WITH_PATH##*/}
FILE_EXT=${FILENAME_WITH_EXT##*.}
FILENAME=${FILENAME_WITH_EXT%.*}

if [[ "$FILE_EXT" == "xcodeproj" ]]; then
    FILE_TYPE="-project"
else
    FILE_TYPE="-workspace"
fi

BUILD_CMD='xcodebuild $FILE_TYPE $FILENAME_WITH_EXT -scheme $FILENAME -quiet > /dev/null 2>&1'
echo "Targeting $FILENAME_WITH_EXT"

# Sanity check
eval $BUILD_CMD
if [[ $? -ne 0 ]]; then
	echo "$(tput setaf 1) Failed the initial build! Please check if your code compiles! $(tput sgr0)"
	exit -1
else
	echo "Commencing unused imports check~"
fi

for file in `find . -type f -name \*.swift`; do
	echo "Checking $file"

	LINE_NUM=0

	while IFS='' read -r line || [[ -n "$line" ]]; do
        LINE_NUM=$((LINE_NUM + 1))
        COMMENTED_LINE="//${line}"
        echo $line | grep -q -m 1 -F "import "
        if [[ $? -eq 0 ]]; then
        	# Check this import (comment it out and try compile)
        	sed -i "" "${LINE_NUM}s|${line}|${COMMENTED_LINE}|" ${file}

        	# Check result
        	eval $BUILD_CMD
        	if [[ $? -eq 0 ]]; then
    			echo "$(tput setaf 1) Found unused import at line $LINE_NUM: $line $(tput sgr0)"
    		fi

        	# Uncomment import
        	sed -i "" "${LINE_NUM}s|${COMMENTED_LINE}|${line}|" ${file}

        fi
	done < $file

done
