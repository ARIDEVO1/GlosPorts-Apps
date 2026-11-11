# GlosPorts-Apps

Two small apps for the goodluckOS handheld (GA36-MB), built with LÖVE 11.5:

- **Calculator** — engineering calculator. Expressions with SI suffixes (`4.7k`, `10u`), `||` for parallel resistors, variables (`R1 = 10k`, saved between runs), and built-in circuit formulas (divider, LED resistor, RC/LC).
- **Notebook** — plain-text notes with a gamepad-driven on-screen keyboard.

Both use a shared on-screen keyboard (`shared/osk.lua`) and are controlled with the gamepad.

## Controls

| | Calculator | Notebook |
|---|---|---|
| D-pad | move on the active keypad | move over the keyboard / pick a note |
| L / R | switch BASIC and ENGINEERING keypads | — |
| A | press key / insert formula | press key / open note |
| B | delete | delete |
| X | clear | shift / new note |
| Y | formula list | new line / delete note (twice) |
| Start | evaluate | save and go back / quit from list |

A physical keyboard works too.

## Layout

```
.local/share/applications/*.puppy   launcher entries (Ports category)
.local/share/icons/*.png            launcher icons
apps/calc, apps/notes               app sources (main.lua, conf.lua, eval.lua)
shared/osk.lua                      on-screen keyboard
ports/<app>/run.sh                  launcher script
ports/<app>/<app>.love              built game (created by build.py)
ports/<app>/love, lib/              LÖVE runtime for armhf, copied from the goodluckOS openSEEK port
```

## Build

```sh
python3 make_icons.py   # optional: regenerate launcher icons
python3 build.py        # writes ports/<app>/<app>.love
```

The `love` runtime and `lib/` folders are not built here. Copy them from a LÖVE 11.5 armhf install (or from the openSEEK port) into each `ports/<app>/`.

## Tests

The expression parser was checked against a set of cases with plain LuaJIT. The apps were run under LÖVE 11.5 with scripted input.
Tested on GOODLUCKOS V0.1.0 run without problem.

## Licence

App code: MIT (see `LICENSE`). The bundled LÖVE runtime is zlib-licensed, and the libraries in `lib/` carry their own licences in `lib/licenses/`.
