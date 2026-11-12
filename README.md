# GlosPorts-Apps

Two small apps for the goodluckOS handheld (GA36-MB), built with LÖVE 11.5:

- **Calculator** — engineering calculator. Expressions with SI suffixes (`4.7k`, `10u`), `||` for parallel resistors, variables (`R1 = 10k`, saved between runs), and built-in circuit formulas (divider, LED resistor, RC/LC).
- **Notebook** — plain-text notes with a gamepad-driven on-screen keyboard.

Both use a shared on-screen keyboard (`shared/osk.lua`) and are controlled with the gamepad.

> #V1.1
> New
> - Resistor tool: 4-band and 5-band color-code reader, plus an E12/E24 picker for the last result.
> - Units tool: the last result in every readable SI prefix, plus dB helpers.
> - Select (or F2) cycles through the calculator, resistor, and units pages.
> - README rewritten for this version.
> - Logic tests moved into `tests/test_logic.lua.`
> Fixed
> - The calculator crashed on its function-key row (bare strings in a keypad row). Fixed before the release.
> - `ans` was saved one step late. Now it’s saved with the result.
> - Values like 999.9999 are shown as `1000` instead of `1k`.
> - The resistor tool’s 5-band header lost its “(Y to change)” hint due to an operator-precedence bug.
> - The units tool printed `4.6e+15` and `inf` for values that don’t read cleanly. Those rows are now hidden.
> Removed
> - The single mixed keypad. It’s now two keypads, BASIC and ENGINEERING, switched with L and R. This was in the released version.
> - Nothing else has been removed. Y still opens the formula list, and Tab still does too.

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
