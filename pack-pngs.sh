#!/bin/bash

# Requires crunch (https://github.com/WebFreak001/crunch), installed as "crunch-pack"

RED='\033[0;31m'
NC='\033[0m' # No Color

crunch-pack res/spritesheet res/sprites -p2 -c -t -u -ba64 -v || printf "${RED}crunch-pack failed! Did you install it from https://github.com/WebFreak001/crunch or is it crashing?${NC} Textures will not be updated!"
