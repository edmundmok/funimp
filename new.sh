#!/bin/bash
# Use chmod +x funimp.sh if permission denied

FILENAME_WITH_PATH=`find . -maxdepth 1 -name \*.xcworkspace -o -name \*.xcodeproj | sort -r | head -n 1`
FILENAME_WITH_EXT=${FILENAME_WITH_PATH##*/}
FILE_EXT=${FILENAME_WITH_EXT##*.}
FILENAME=${FILENAME_WITH_EXT%.*}

if [[ "$FILE_EXT" == "xcodeproj" ]]; then
    FILE_TYPE="-project"
else
    FILE_TYPE="-workspace"
fi

temp_file=$(mktemp)
BUILD_SETTINGS=`xcodebuild $FILE_TYPE $FILENAME_WITH_EXT -scheme $FILENAME -showBuildSettings > $temp_file`
# cat $temp_file

SWIFT_FILES=$(find . -type f -name \*.swift | while read line; do echo -n "$line "; done)
IPHONE_DEPLOYMENT_TARGET=$(grep 'IPHONEOS_DEPLOYMENT_TARGET = ' $temp_file | awk '{print $3}')
SDKROOT=$(grep 'SDKROOT = ' $temp_file | awk '{print $3}')
PLATFORM_DIR=$(grep 'PLATFORM_DIR = ' $temp_file | awk '{print $3}' | sort -r | head -n 1)
BUILD_DIR=$(grep 'BUILD_DIR = ' $temp_file | awk '{print $3}' | head -n 1)
FRAMEWORKS=""

for framework in `grep 'OTHER_LDFLAGS' $temp_file | grep -o -- '-framework.*' | tr ' ' '\n' | grep -o '"[^"]\+"' | tr -d '"'`; do
	FRAMEWORKS="$FRAMEWORKS -F $BUILD_DIR/Debug-iphoneos/$framework"
done

FRAMEWORKS="$FRAMEWORKS -F $PLATFORM_DIR/Developer/Library/Frameworks"
FRAMEWORKS="$FRAMEWORKS -I $BUILD_DIR/Debug-iphoneos/"

# echo "SWIFT_FILES: $SWIFT_FILES"
# echo "IPHONE_DEPLOYMENT_TARGET: $IPHONE_DEPLOYMENT_TARGET"
# echo "SDKROOT: $SDKROOT"
# echo "BUILD_DIR: $BUILD_DIR"
# echo "FRAMEWORKS: $FRAMEWORKS"

rm ${temp_file}
$(/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift -frontend -c -primary-file $SWIFT_FILES -target armv7-apple-ios${IPHONE_DEPLOYMENT_TARGET} -enable-objc-interop -sdk $SDKROOT $FRAMEWORKS)