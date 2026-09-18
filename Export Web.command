#!/bin/zsh
set -u
project_dir="${0:A:h}"
if ! command -v python3 >/dev/null 2>&1; then
  print 'Python 3 is required to build the browser version.'
  read -r '?Press Return to close.'
  exit 1
fi
cd "$project_dir" || exit 1
python3 "$project_dir/tools/export_web.py"
export_status=$?
if (( export_status == 0 )); then
  print '\nBuild ready in dist/web. Share dist/Taterland-Web.zip.'
  print 'Starting the local browser preview. Press Ctrl+C here to stop it.'
  python3 "$project_dir/tools/serve_web.py" --open
else
  print '\nThe previous working Web build has been kept.'
  read -r '?Press Return to close.'
fi
exit "$export_status"
