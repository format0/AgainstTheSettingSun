#!/bin/sh
# Opens levels in the real Godot editor and checks that their elements work there (see
# tools/editor_check/editor_check.gd), with screenshots of the 2D view to look at.
#
#   tools/editor_check.sh [scenes, comma-separated] [screenshot prefix]
#
# Needs a display (DISPLAY, e.g. an Xvfb) and OpenGL. Set GODOT to the editor binary if it
# is not `godot`.
# Exits with 1 when a check failed. Script errors raised meanwhile appear in the output.
cd "$(dirname "$0")/.." || exit 1
SCENES=${1:-res://levels/gallery/gallery.tscn,res://levels/level_01/level_01.tscn,res://levels/level_02/level_02.tscn,res://levels/level_03/level_03.tscn}
OUT=${2:-/tmp/editor_check}
# a plugin that does not parse would stop the editor at a dialog: find out first
if ${GODOT:-godot} --headless --check-only -s tools/editor_check/editor_check.gd 2>&1 | grep -A1 "SCRIPT ERROR"; then
	exit 1
fi
# the check plugin is switched on for this run only; project.godot is put back afterwards
# (the editor also likes to rewrite it, dropping settings that equal their defaults)
SAVED=$(mktemp)
cp project.godot "$SAVED"
trap 'cp "$SAVED" project.godot; rm -f "$SAVED"' EXIT INT TERM
sed -i 's|^enabled=PackedStringArray("res://addons/level_tools/plugin.cfg")|enabled=PackedStringArray("res://addons/level_tools/plugin.cfg", "res://tools/editor_check/plugin.cfg")|' project.godot
grep -q "tools/editor_check/plugin.cfg" project.godot || { echo "could not enable the check plugin in project.godot"; exit 1; }
LOG=$(mktemp)
EDITOR_CHECK_SCENES=$SCENES EDITOR_CHECK_OUT=$OUT timeout 600 ${GODOT:-godot} --editor --path . \
	--audio-driver Dummy --resolution 1600x900 >"$LOG" 2>&1
grep -E "^CHECK|SCRIPT ERROR|^ERROR|at: .*res://" "$LOG" | grep -vE "Vulkan|err != OK"
STATUS=0
grep -q "^CHECK all passed" "$LOG" || STATUS=1
grep -q "SCRIPT ERROR" "$LOG" && STATUS=1
rm -f "$LOG"
exit $STATUS
