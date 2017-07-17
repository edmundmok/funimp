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
temp_dir=$(mktemp -d)
BUILD_SETTINGS=`xcodebuild $FILE_TYPE $FILENAME_WITH_EXT -scheme $FILENAME -showBuildSettings -configuration Debug > $temp_file`

find . -name "*.swift" -not -path "*/Pods/*" -print0 | while read -d $'\0' file; do filename=${file##*/}; cp "$file" "$temp_dir/$file_name"; done
SWIFT_FILES=$(find $temp_dir -type f -name \*.swift -not -path "*/Pods/*" | while read line; do echo -n "$line "; done)

IPHONE_DEPLOYMENT_TARGET=$(grep 'IPHONEOS_DEPLOYMENT_TARGET = ' $temp_file | awk '{print $3}')
SDKROOT=$(grep 'SDKROOT = ' $temp_file | awk '{print $3}')
PLATFORM_DIR=$(grep 'PLATFORM_DIR = ' $temp_file | awk '{print $3}' | sort -r | head -n 1)
BUILD_DIR=$(grep 'BUILD_DIR = ' $temp_file | awk '{print $3}' | head -n 1)
FRAMEWORKS=""

for framework in `grep 'FRAMEWORK_SEARCH_PATHS' $temp_file | awk '{for(i=3;i<=NF;++i)print $i}'`; do
	FRAMEWORKS="$FRAMEWORKS -F $framework"
	# FRAMEWORKS="$FRAMEWORKS -F $BUILD_DIR/Debug-iphoneos/$framework"
done

FRAMEWORKS="$FRAMEWORKS -F $PLATFORM_DIR/Developer/Library/Frameworks"
FRAMEWORKS="$FRAMEWORKS -I $BUILD_DIR/Debug-iphoneos/ -F $BUILD_DIR/Debug-iphoneos"

HEADERS=""

for header in `grep 'HEADER_SEARCH_PATHS' $temp_file | sort -r | head -n 1 | awk '{for(i=3;i<=NF;++i)print $i}'`; do
	HEADERS="$HEADERS -Xcc -I${header}"
done

# echo "SWIFT_FILES: $SWIFT_FILES"
# echo "IPHONE_DEPLOYMENT_TARGET: $IPHONE_DEPLOYMENT_TARGET"
# echo "SDKROOT: $SDKROOT"
# echo "BUILD_DIR: $BUILD_DIR"
# echo "FRAMEWORKS: $FRAMEWORKS"
# echo "HEADERS: $HEADERS"

/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift -frontend -c -suppress-warnings -num-threads 4 -primary-file $SWIFT_FILES -target armv7-apple-ios${IPHONE_DEPLOYMENT_TARGET} -enable-objc-interop -sdk $SDKROOT $FRAMEWORKS $HEADERS
RET_VAL=$?

rm ${temp_file}
rm -rf ${temp_dir}

get_return() {
	return $1
}

get_return $RET_VAL