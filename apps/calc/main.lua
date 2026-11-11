-- Engineering Calculator for goodluckOS. MIT licensed.
--
-- Type an expression on the on-screen keypad or a physical keyboard.
--   Left keypad  (BASIC):       digits, + - * / ^ %, brackets, clear, delete, EVAL
--   Right keypad (ENGINEERING): SI prefixes, pi, e, ans, ||, functions
--   L / R shoulder buttons switch keypads. A presses, B deletes, X clears.
--   Start / EVAL evaluates.  Y opens the formula list; A inserts a formula.
--   R1 = 10k stores a variable; variables are saved between runs.

local Osk = require "osk"
local Eval = require "eval"

local VW, VH = 640, 480
local SAVE_FILE = "vars.txt"
local MAX_HISTORY = 50

local K = Osk.key
local font, small
local basic_pad, eng_pad
local panel = "basic"            -- which keypad has the d-pad: "basic" or "eng"
local S = {
    input = "",
    error = "",
    history = {},
    vars = {},
    mode = "keys",               -- "keys" or "formulas"
    tpl = 1,
}

-- Formulas: the expression is inserted; define the named inputs first.
local FORMULAS = {
    { name = "Power",           expr = "V*I",                hint = "P = V * I" },
    { name = "Voltage divider", expr = "Vin*R2/(R1+R2)",     hint = "Vout, with R1 on top and R2 to ground" },
    { name = "LED resistor",    expr = "(Vs-Vf)/If",         hint = "R = (Vs - Vf) / If" },
    { name = "RC cutoff",       expr = "1/(2*pi*R*C)",       hint = "fc in Hz" },
    { name = "LC resonance",    expr = "1/(2*pi*sqrt(L*C))", hint = "f0 in Hz" },
}

local function build_pads()
    local basic = Osk.new({
        { K"7", K"8", K"9", K"+", K"-" },
        { K"4", K"5", K"6", K"*", K"/" },
        { K"1", K"2", K"3", K"^", K"%" },
        { K"0", K".", K"(", K")", K"," },
        { K("CLR", "@clr", 1.5), K("DEL", "@del", 1.5), K("EVAL", "@eval", 2) },
    })
    local eng = Osk.new({
        { K"p", K"n", K"u", K"m", K"k", K"M", K"G" },
        { K"pi", K"e", K"ans", K"||" },
        { K("sqrt", "sqrt("), K("sin", "sin("), K("cos", "cos("), K("tan", "tan(") },
        { K("asin", "asin("), K("acos", "acos("), K("atan", "atan("), K("ln", "ln(") },
        { K("log", "log("), K("exp", "exp("), K("abs", "abs("), K("db", "db(") },
    })
    return basic, eng
end

local function active_pad()
    return panel == "basic" and basic_pad or eng_pad
end

local function save_vars()
    local parts = {}
    for name, value in pairs(S.vars) do
        if type(value) == "number" then
            parts[#parts + 1] = string.format("%s=%.17g", name, value)
        end
    end
    love.filesystem.write(SAVE_FILE, table.concat(parts, "\n"))
end

local function load_vars()
    local data = love.filesystem.read(SAVE_FILE)
    if not data then return end
    for name, value in data:gmatch("([%w_]+)=([^\n]+)") do
        local n = tonumber(value)
        if n then S.vars[name] = n end
    end
end

local function evaluate()
    local line = S.input
    local ok, value, name = pcall(Eval.run, line, S.vars)
    if not ok then
        S.error = value
        return
    end
    if value == nil then return end
    S.error = ""
    if name then S.vars[name] = value end
    S.vars.ans = value
    save_vars()
    local out = Eval.eng(value)
    table.insert(S.history, {
        expr = line,
        out = (name and (name .. " = ") or "= ") .. out,
    })
    while #S.history > MAX_HISTORY do table.remove(S.history, 1) end
    S.input = ""
end

-- Live result shown beside the input line while typing.
local function preview()
    if S.input == "" then return "" end
    local ok, value, name = pcall(Eval.run, S.input, S.vars)
    if ok and value ~= nil then
        return (name and (name .. " = ") or "= ") .. Eval.eng(value)
    end
    return ""
end

local function backspace()
    S.input = S.input:sub(1, -2)
    S.error = ""
end

local function press_key()
    local v = active_pad():current().value
    if v == "@del" then
        backspace()
    elseif v == "@clr" then
        S.input = ""
        S.error = ""
    elseif v == "@eval" then
        evaluate()
    else
        S.input = S.input .. v
    end
end

local function insert_formula()
    S.input = S.input .. FORMULAS[S.tpl].expr
    S.mode = "keys"
end

local function sorted_var_names()
    local names = {}
    for name, value in pairs(S.vars) do
        if type(value) == "number" then names[#names + 1] = name end
    end
    table.sort(names)
    return names
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

local function draw_history(x, y, w, h)
    local row_h = 34
    local rows = math.floor(h / row_h)
    if #S.history == 0 then
        love.graphics.setColor(0.45, 0.5, 0.6)
        love.graphics.print("Try: 4.7k || 10k    or    R1 = 10k", x, y)
        return
    end
    local first = math.max(1, #S.history - rows + 1)
    local yy = y
    for i = first, #S.history do
        local e = S.history[i]
        love.graphics.setColor(0.6, 0.65, 0.75)
        love.graphics.print(e.expr, x, yy)
        love.graphics.setColor(0.45, 0.9, 0.6)
        love.graphics.printf(e.out, x, yy + 16, w, "right")
        yy = yy + row_h
    end
end

local function draw_variables(x, y, w, h)
    love.graphics.setColor(0.14, 0.17, 0.23)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    love.graphics.setColor(0.7, 0.75, 0.85)
    love.graphics.print("Variables", x + 8, y + 6)
    local names = sorted_var_names()
    if #names == 0 then
        love.graphics.setColor(0.45, 0.5, 0.6)
        love.graphics.printf("none yet.\nTry: R1 = 10k", x + 8, y + 30, w - 16, "left")
        return
    end
    local row_h = 18
    local rows = math.floor((h - 30) / row_h)
    local first = math.max(1, #names - rows + 1)
    local yy = y + 28
    for i = first, #names do
        local name = names[i]
        love.graphics.setColor(0.93, 0.93, 0.95)
        love.graphics.print(name .. " = " .. Eval.eng(S.vars[name]), x + 8, yy)
        yy = yy + row_h
    end
end

local function draw_formulas(x, y, w, h)
    local row_h = 38
    for i, f in ipairs(FORMULAS) do
        local yy = y + (i - 1) * row_h
        local selected = (i == S.tpl)
        if selected then
            love.graphics.setColor(0.25, 0.27, 0.36)
            love.graphics.rectangle("fill", x, yy, w, row_h - 4, 5, 5)
        end
        love.graphics.setColor(selected and 0.95 or 0.8, selected and 0.8 or 0.85, selected and 0.3 or 0.9)
        love.graphics.print(f.name .. ":  " .. f.expr, x + 8, yy + 2)
        love.graphics.setColor(0.6, 0.65, 0.75)
        love.graphics.print(f.hint, x + 8, yy + 18)
    end
end

-- Two keypads side by side. The active one gets a highlighted frame.
local function draw_pads()
    local top = 288
    local gap = 8
    local pad_w = (VW - 16 - gap) / 2
    local labels = { { basic_pad, 8, "BASIC  (L)" }, { eng_pad, 8 + pad_w + gap, "ENGINEERING  (R)" } }
    for _, p in ipairs(labels) do
        local pad, x, title = p[1], p[2], p[3]
        local is_active = (pad == active_pad())
        love.graphics.setFont(small)
        love.graphics.setColor(is_active and 0.95 or 0.5, is_active and 0.8 or 0.55, is_active and 0.3 or 0.65)
        love.graphics.print(title, x + 4, top)
        if is_active then
            love.graphics.setColor(0.95, 0.8, 0.3, 0.6)
            love.graphics.rectangle("line", x, top + 18, pad_w, 176, 6, 6)
        end
        pad:draw(x + 4, top + 22, pad_w - 8, 168, small)
    end
end

function love.draw()
    love.graphics.clear(0.07, 0.08, 0.11)
    love.graphics.setFont(font)

    -- Header.
    love.graphics.setColor(0.16, 0.19, 0.26)
    love.graphics.rectangle("fill", 0, 0, VW, 26)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Calculator", 10, 4)
    love.graphics.setColor(0.6, 0.65, 0.75)
    love.graphics.printf("Start eval   X clear   Y formulas   L/R keypad", 0, 4, VW - 10, "right")

    -- Display: history or formulas on the left, variables on the right.
    if S.mode == "formulas" then
        draw_formulas(8, 34, 420, 200)
    else
        draw_history(8, 34, 420, 196)
    end
    draw_variables(440, 34, 192, 196)

    -- Error line.
    if S.error ~= "" then
        love.graphics.setColor(1, 0.45, 0.4)
        love.graphics.print(S.error, 8, 232)
    end

    -- Input line.
    love.graphics.setColor(0.14, 0.17, 0.23)
    love.graphics.rectangle("fill", 8, 252, VW - 16, 28, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(S.input .. "_", 16, 258)
    love.graphics.setColor(0.45, 0.9, 0.6)
    love.graphics.printf(preview(), 8, 258, VW - 24, "right")

    draw_pads()
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function love.load()
    font = love.graphics.newFont(16)
    small = love.graphics.newFont(14)
    basic_pad, eng_pad = build_pads()
    load_vars()
end

function love.gamepadpressed(_, button)
    if button == "leftshoulder" then
        panel = "basic"
    elseif button == "rightshoulder" then
        panel = "eng"
    elseif button == "dpup" or button == "dpdown" or button == "dpleft" or button == "dpright" then
        local dr = (button == "dpup" and -1) or (button == "dpdown" and 1) or 0
        local dc = (button == "dpleft" and -1) or (button == "dpright" and 1) or 0
        if S.mode == "formulas" then
            S.tpl = math.max(1, math.min(#FORMULAS, S.tpl + dr))
        else
            active_pad():move(dr, dc)
        end
    elseif button == "a" then
        if S.mode == "formulas" then insert_formula() else press_key() end
    elseif button == "b" then
        if S.mode == "formulas" then S.mode = "keys" else backspace() end
    elseif button == "x" then
        S.input = ""
        S.error = ""
    elseif button == "y" then
        S.mode = (S.mode == "formulas") and "keys" or "formulas"
    elseif button == "start" then
        evaluate()
    end
end

function love.textinput(text)
    if S.mode == "keys" then
        S.input = S.input .. text
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "backspace" then
        backspace()
    elseif key == "return" or key == "kpenter" then
        evaluate()
    elseif key == "tab" then
        S.mode = (S.mode == "formulas") and "keys" or "formulas"
    elseif S.mode == "formulas" and (key == "up" or key == "down") then
        S.tpl = math.max(1, math.min(#FORMULAS, S.tpl + (key == "up" and -1 or 1)))
    end
end
