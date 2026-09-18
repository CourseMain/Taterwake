#!/bin/zsh
set -eu
project_dir="${0:A:h}"

if [[ -n "${GODOT_BIN:-}" ]]; then
  if [[ -x "$GODOT_BIN" ]]; then
    exec "$GODOT_BIN" --path "$project_dir"
  elif game_engine="$(command -v -- "$GODOT_BIN" 2>/dev/null)"; then
    exec "$game_engine" --path "$project_dir"
  else
    print 'GODOT_BIN does not point to an executable Godot engine.'
    read -r '?Press Return to close.'
    exit 1
  fi
fi

for game_engine in "$project_dir/.tools/Godot.app/Contents/MacOS/Godot" "$project_dir/.tools/godot-web-engine/Godot.app/Contents/MacOS/Godot"; do
  if [[ -x "$game_engine" ]]; then
    exec "$game_engine" --path "$project_dir"
  fi
done
for engine_command in godot godot4; do
  if game_engine="$(command -v -- "$engine_command" 2>/dev/null)"; then
    exec "$game_engine" --path "$project_dir"
  fi
done

# Standard macOS install, followed by locations used by older local checkouts.
for game_engine in /Applications/Godot.app/Contents/MacOS/Godot "$project_dir/../.tools/Godot.app/Contents/MacOS/Godot" "$project_dir/../maths/.tools/Godot.app/Contents/MacOS/Godot"; do
  if [[ -x "$game_engine" ]]; then
    exec "$game_engine" --path "$project_dir"
  fi
done

print 'Install Godot 4.7.2 from https://godotengine.org/download/, then open project.godot and press F5.'
print 'You can also set GODOT_BIN to the Godot executable and run this launcher again.'
read -r '?Press Return to close.'
exit 1
