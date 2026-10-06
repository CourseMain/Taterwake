#!/bin/zsh
set -u
web_folder="${0:A:h}"
cd "$web_folder" || exit 1
if ! command -v python3 >/dev/null 2>&1; then
  print 'Python 3 is required to preview this game locally.'
  read -r '?Press Return to close.'
  exit 1
fi
python3 "$web_folder/serve.py" --open
preview_status=$?
if (( preview_status != 0 )); then
  read -r '?Press Return to close.'
fi
exit "$preview_status"
