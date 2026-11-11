#!/bin/sh
# Launches notes with the LÖVE runtime bundled next to this script.
here=$(dirname "$(readlink -f "$0")")
export LD_LIBRARY_PATH="$here/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
# goodluckOS has no window manager, so draw straight to the panel. Override
# SDL_VIDEODRIVER in the environment to test on a desktop (e.g. x11).
export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-kmsdrm}"
export LOVE_GRAPHICS_USE_OPENGLES=1
exec "$here/love" "$here/notes.love" "$@" > "$here/run.log" 2>&1
