-- Expression evaluator for the calculator. MIT licensed.
-- Recursive-descent parser: no load(), so input can never run Lua code.
--
-- Supports: numbers with SI suffixes (10k, 4.7u, 2M), scientific notation (1e-3),
-- + - * / % ^, parentheses, implicit multiplication (2pi, 3(R+1)),
-- the parallel operator a || b = ab/(a+b), constants pi and e,
-- the variable `ans` (last result), user variables (R1 = 10k), and functions
-- sqrt abs sin cos tan asin acos atan ln log exp db (radians, log is base 10).
--
-- Precedence, loosest first: + -   then ||   then * / %   then unary -   then ^

local M = {}

local SI = { p = 1e-12, n = 1e-9, u = 1e-6, m = 1e-3, k = 1e3, M = 1e6, G = 1e9, T = 1e12 }
local CONST = { pi = math.pi, e = math.exp(1) }
local LN10 = math.log(10)

local FUNCS = {
    sqrt = math.sqrt,
    abs = math.abs,
    sin = math.sin,
    cos = math.cos,
    tan = math.tan,
    asin = math.asin,
    acos = math.acos,
    atan = math.atan,
    ln = math.log,
    exp = math.exp,
    log = function(x) return math.log(x) / LN10 end,
    db = function(x) return 20 * math.log(x) / LN10 end,
}

local function fail(msg)
    error(msg, 0)
end

local function lex(s)
    local toks, i, n = {}, 1, #s
    while i <= n do
        local c = s:sub(i, i)
        if c:match("%s") then
            i = i + 1
        elseif c:match("%d") or (c == "." and s:sub(i + 1, i + 1):match("%d")) then
            local num = s:match("^%d*%.?%d*", i)
            i = i + #num
            local ex = s:match("^[eE][%+%-]?%d+", i)
            if ex then
                num = num .. ex
                i = i + #ex
            end
            local value = tonumber(num)
            local suffix = s:sub(i, i)
            if SI[suffix] and not s:sub(i + 1, i + 1):match("[%w_]") then
                value = value * SI[suffix]
                i = i + 1
            end
            toks[#toks + 1] = { t = "num", v = value }
        elseif c:match("[%a_]") then
            local id = s:match("^[%a_][%w_]*", i)
            i = i + #id
            toks[#toks + 1] = { t = "id", v = id }
        elseif s:sub(i, i + 1) == "||" then
            toks[#toks + 1] = { t = "op", v = "||" }
            i = i + 2
        elseif ("+-*/^%(),="):find(c, 1, true) then
            toks[#toks + 1] = { t = "op", v = c }
            i = i + 1
        else
            fail("unexpected character '" .. c .. "'")
        end
    end
    return toks
end

-- Evaluates tokens from index `start`. Returns the value.
local function evaluate_tokens(toks, start, vars)
    local pos = start

    local function is_op(v)
        local t = toks[pos]
        return t ~= nil and t.t == "op" and t.v == v
    end

    local function take_op(v)
        if is_op(v) then
            pos = pos + 1
            return true
        end
        return false
    end

    local function starts_operand()
        local t = toks[pos]
        return t ~= nil and (t.t == "num" or t.t == "id" or (t.t == "op" and t.v == "("))
    end

    local expr

    local function primary()
        local t = toks[pos]
        if not t then fail("unexpected end of input") end

        if t.t == "num" then
            pos = pos + 1
            return t.v
        end

        if t.t == "op" and t.v == "(" then
            pos = pos + 1
            local v = expr()
            if not take_op(")") then fail("missing ')'") end
            return v
        end

        if t.t == "id" then
            pos = pos + 1
            local name = t.v
            if is_op("(") then
                pos = pos + 1
                local args = {}
                if not is_op(")") then
                    repeat
                        args[#args + 1] = expr()
                    until not take_op(",")
                end
                if not take_op(")") then fail("missing ')' after " .. name) end
                local f = FUNCS[name]
                if not f then fail("unknown function '" .. name .. "'") end
                if #args ~= 1 then fail(name .. " takes 1 argument") end
                return f(args[1])
            end
            if CONST[name] then return CONST[name] end
            if vars[name] ~= nil then return vars[name] end
            fail("unknown name '" .. name .. "'")
        end

        fail("unexpected '" .. tostring(t.v) .. "'")
    end

    local unary

    local function power()
        local base = primary()
        if take_op("^") then
            return base ^ unary()
        end
        return base
    end

    unary = function()
        if take_op("-") then return -unary() end
        if take_op("+") then return unary() end
        return power()
    end

    local function product()
        local v = unary()
        while true do
            if take_op("*") then
                v = v * unary()
            elseif take_op("/") then
                local d = unary()
                if d == 0 then fail("division by zero") end
                v = v / d
            elseif take_op("%") then
                local d = unary()
                if d == 0 then fail("modulo by zero") end
                v = math.fmod(v, d)
            elseif starts_operand() then
                v = v * unary()
            else
                break
            end
        end
        return v
    end

    local function parallel()
        local v = product()
        while take_op("||") do
            local r = product()
            local sum = v + r
            if sum == 0 then fail("parallel of two zero values") end
            v = v * r / sum
        end
        return v
    end

    expr = function()
        local v = parallel()
        while true do
            if take_op("+") then
                v = v + parallel()
            elseif take_op("-") then
                v = v - parallel()
            else
                break
            end
        end
        return v
    end

    local value = expr()
    if pos <= #toks then
        fail("unexpected '" .. tostring(toks[pos].v) .. "'")
    end
    return value
end

-- Runs one line. Returns value, name, where name is set for "name = expr" lines.
-- Returns nil for an empty line. Raises an error string on bad input.
-- The caller decides whether to store the result.
function M.run(line, vars)
    local toks = lex(line)
    if #toks == 0 then return nil end

    local name, start = nil, 1
    if #toks >= 3 and toks[1].t == "id" and toks[2].t == "op" and toks[2].v == "=" then
        name = toks[1].v
        if CONST[name] then fail("'" .. name .. "' is a constant") end
        start = 3
    end

    local value = evaluate_tokens(toks, start, vars)
    if value ~= value or value == math.huge or value == -math.huge then
        fail("result is undefined")
    end
    return value, name
end

local PREFIX = { [-12] = "p", [-9] = "n", [-6] = "u", [-3] = "m", [0] = "",
                 [3] = "k", [6] = "M", [9] = "G", [12] = "T" }

-- Engineering notation: 4700 -> "4.7k", 0.0022 -> "2.2m", 1e-7 -> "100n".
function M.eng(v)
    if v == 0 then return "0" end
    local sign = v < 0 and "-" or ""
    local a = math.abs(v)
    local e = math.floor(math.log(a) / LN10 / 3) * 3
    if e < -12 then e = -12 elseif e > 12 then e = 12 end
    local mant = a / 10 ^ e
    local text = string.format("%.4g", mant)
    if tonumber(text) >= 1000 and e < 12 then
        -- rounding reached 1000: show it one prefix up instead
        e = e + 3
        mant = a / 10 ^ e
        text = string.format("%.4g", mant)
    end
    return sign .. text .. PREFIX[e]
end

return M
