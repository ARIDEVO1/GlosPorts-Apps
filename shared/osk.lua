-- On-screen keyboard driven by a gamepad d-pad. Shared by goodluck-apps. MIT licensed.
--
-- A keyboard is a list of rows. A row is a list of keys:
--   { label = "A", value = "a", w = 1 }
-- `w` is the relative width (default 1). `value` starts with "@" for actions
-- the app handles itself (e.g. "@del"); anything else is text to type.

local Osk = {}
Osk.__index = Osk

local function key(label, value, w)
    return { label = label, value = value or label, w = w or 1 }
end
Osk.key = key

function Osk.new(rows)
    local self = setmetatable({ rows = rows, r = 1, c = 1, shift = false }, Osk)
    for _, row in ipairs(rows) do
        local total = 0
        for _, k in ipairs(row) do total = total + (k.w or 1) end
        row.total = total
    end
    return self
end

-- Horizontal centre of key c in a row, as a fraction of the row width.
local function centre(row, c)
    local before = 0
    for i = 1, c - 1 do before = before + (row[i].w or 1) end
    return (before + (row[c].w or 1) / 2) / row.total
end

function Osk:move(dr, dc)
    if dc ~= 0 then
        local row = self.rows[self.r]
        self.c = math.max(1, math.min(#row, self.c + dc))
    end
    if dr ~= 0 then
        local target = math.max(1, math.min(#self.rows, self.r + dr))
        if target ~= self.r then
            -- Land on the key in the new row that sits closest horizontally.
            local x = centre(self.rows[self.r], self.c)
            local row = self.rows[target]
            local best, best_d = 1, math.huge
            for i = 1, #row do
                local d = math.abs(centre(row, i) - x)
                if d < best_d then best, best_d = i, d end
            end
            self.r, self.c = target, best
        end
    end
end

function Osk:current()
    return self.rows[self.r][self.c]
end

-- Draws the keyboard into the rectangle (x, y, w, h).
function Osk:draw(x, y, w, h, font)
    local row_h = h / #self.rows
    local old_font = love.graphics.getFont()
    love.graphics.setFont(font)
    for ri, row in ipairs(self.rows) do
        local cx = x
        local ry = y + (ri - 1) * row_h
        for ci, k in ipairs(row) do
            local kw = w * (k.w or 1) / row.total
            local selected = (ri == self.r and ci == self.c)
            local is_action = k.value:sub(1, 1) == "@"
            local pad = 3

            if selected then
                love.graphics.setColor(0.95, 0.8, 0.3)
            elseif is_action then
                love.graphics.setColor(0.28, 0.22, 0.34)
            else
                love.graphics.setColor(0.22, 0.25, 0.32)
            end
            love.graphics.rectangle("fill", cx + pad, ry + pad, kw - pad * 2, row_h - pad * 2, 5, 5)

            local label = k.label
            if self.shift and label:match("^%l$") then label = label:upper() end
            if selected then
                love.graphics.setColor(0.08, 0.08, 0.1)
            else
                love.graphics.setColor(0.93, 0.93, 0.95)
            end
            love.graphics.print(label,
                cx + kw / 2 - font:getWidth(label) / 2,
                ry + row_h / 2 - font:getHeight() / 2)
            cx = cx + kw
        end
    end
    love.graphics.setFont(old_font)
end

return Osk
