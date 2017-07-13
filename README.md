# funimp - Find unused Swift import statements

A simple script that discovers any unused import statements in your Swift files. The script looks at all import statements and attempts to build without it. If the build succeeds, the import statement is marked as unused (and unneeded).

## Install
Add `funimp.sh` into your Xcode directory where your `.xcworkspace` or `.xcodeproj` is located.

## Usage
```
./funimp.sh
```

> Run `chmod +x funimp.sh` if permissions are denied.