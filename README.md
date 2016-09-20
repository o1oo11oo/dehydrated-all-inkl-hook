# [dehydrated](https://github.com/lukas2511/dehydrated) ALL-INKL hook script
A Hook script to use the ALL-INKL KAS API with dehydrated for dns-01 challenges.

## Download
Using git: `git clone --recursive https://github.com/o1oo11oo/dehydrated-all-inkl-hook.git`  
Updating the git repository: `git pull && git submodule update --init --recursive`  
Without using git: [get the latest release](https://github.com/o1oo11oo/dehydrated-all-inkl-hook/releases/latest)

## Usage
Set your hook in your dehydrated config to `dehydrated-all-inkl-hook/hook.sh`, for example:
```Bash
HOOK="${BASEDIR}/dehydrated-all-inkl-hook/hook.sh"
```
