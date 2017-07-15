#!/bin/bash
# Use chmod +x funimp.sh if permission denied

# Configuration
TIMEOUT_MULT=2

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
echo "Running initial build..."
eval $BUILD_CMD
if [[ $? -ne 0 ]]; then
   echo "$(tput setaf 1) Failed the initial build! Please check if your code compiles! $(tput sgr0)"
   exit -1
else
   echo "Commencing unused imports check~"
fi

# Trigger an build failure
FAIL_FILE=`find . -maxdepth 2 -type f -name \*.swift | head -n 1`
FAIL_LINE_NUM=`grep -c '' $FAIL_FILE`
FAIL_LINE=`sed "${FAIL_LINE_NUM}q;d" ${FAIL_FILE}`
sed -i "" "${FAIL_LINE_NUM}s|.*|a|" ${FAIL_FILE}

TIMEFORMAT=%R;
# Get build fail time
FAIL_TIME=$(time (eval $BUILD_CMD >/dev/null 2>&1) 2>&1)
FAIL_TIME=`printf "%.0f" $FAIL_TIME`
# Determine timeout
TIMEOUT=$((FAIL_TIME * TIMEOUT_MULT))

# Undo trigger for build failure
sed -i "" "${FAIL_LINE_NUM}s|.*|$FAIL_LINE|" ${FAIL_FILE}

# Go through all files
for file in `find . -type f -name \*.swift`; do
    echo "Checking $file"

    LINE_NUM=0

    while IFS='' read -r line || [[ -n "$line" ]]; do
        LINE_NUM=$((LINE_NUM + 1))
        COMMENTED_LINE="//${line}"
        echo $line | grep -q -m 1 -F "import "
        if [[ $? -eq 0 ]]; then
            # Check this import (comment it out and try compile)
            sed -i "" "${LINE_NUM}s|.*|${COMMENTED_LINE}|" ${file}

            # Build and time
            SECONDS=0
            ( eval $BUILD_CMD >/dev/null 2>&1 ) & pid=$!
            ( sleep $TIMEOUT && kill -HUP $pid ) 2>/dev/null & watcher=$!

            # Wait for build to end (success/fail) or timeout
            wait $pid 2>/dev/null
        
            # Record time taken
            EXIT=$?
            TIME_TAKEN=$SECONDS

            # Check if watcher still exists
            if kill -s 0 $watcher 2>/dev/null; then
                # Watcher exists: Build ended (success/fail)
                # Kill the watcher
                pkill -HUP -P $watcher
                wait $watcher

                # Check if success / fail
                if [[ $EXIT -ne 0 ]]; then
                    # Failure before timeout
                    # Update TIMEOUT if needed
                    if [[ $TIME_TAKEN -gt $FAIL_TIME ]]; then
                        FAIL_TIME=$TIME_TAKEN
                        TIMEOUT=$((FAIL_TIME * TIMEOUT_MULT))
                    fi
                else
                    # Success before timeout
                    echo "$(tput setaf 1) Found unused import at line $LINE_NUM: $line $(tput sgr0)"
                fi
            else
                # Build finished due to timeout
                # Do nothing (assume success)
                echo "$(tput setaf 1) Found unused import at line $LINE_NUM: $line $(tput sgr0)"
            fi

            # Uncomment import
            sed -i "" "${LINE_NUM}s|.*|${line}|" ${file}
        fi
    done < $file
done
