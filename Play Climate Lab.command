#!/bin/zsh
cd -- "${0:A:h}" || exit 1
python3 tools/preview_climate.py
