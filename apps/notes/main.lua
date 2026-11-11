-- Notebook for goodluckOS. MIT licensed.
--
-- List screen:  d-pad select, A open, X new note, Y delete (press Y twice), Start quit.
-- Editor:       d-pad moves over the keyboard, A types the key, B deletes,
--               X shift (capital for the next letter), Y new line, Start save and back.
-- A physical keyboard types directly. Escape goes back, or quits from the list.
-- Notes save as you type.

local Osk = require "osk"

local VW, VH = 640, 480
local DIR = "notes"
local K = Osk.key

local font, small
local keys
local mode = "list"      -- "list" or "edit"
local notes = {}         -- { id = "...", title = "..." }, newest first
local sel = 1
local top = 1            -- first visible row in the list
local armed = false      -- delete pressed once; press again to confirm
local cur = nil          -- { id = "...", text = "..." } while editing
local counter = 0

local LIST_ROW_H = 36
local LIST_VISIBLE = math.floor((VH - 70) / LIST_ROW_H)

local function build_keys()
    local k = Osk.new({
        { K"1", K"2", K"3", K"4", K"5", K"6", K"7", K"8", K"9", K"0" },
        { K"q", K"w", K"e", K"r", K"t", K"y", K"u", K"i", K"o", K"p" },
        { K"a", K"s", K"d", K"f", K"g", K"h", K"j", K"k", K"l" },
        { K("SHIFT", "@shift", 1.5), K"z", K"x", K"c", K"v", K"b", K"n", K"m", K("DEL", "@del", 1.5) },
        { K(","), K("."), K("'"), K("-"), K("?"), K("!"), K("space", " ", 3), K("ENTER", "@enter", 2) },
    })
    return k
end

local function refresh()
    notes = {}
    love.filesystem.createDirectory(DIR)
    for _, name in ipairs(love.filesystem.getDirectoryItems(DIR)) do
        if name:match("%.txt$") then
            local id = name:sub(1, -5)
            local text = love.filesystem.read(DIR .. "/" .. name) or ""
            local title = text:match("[^\n]+") or "(empty note)"
            notes[#notes + 1] = { id = id, title = title:sub(1, 60) }
        end
    end
    table.sort(notes, function(a, b) return a.id > b.id end)
    sel = math.max(1, math.min(sel, #notes))
    top = math.max(1, math.min(top, sel))
end

local function note_path(id)
    return DIR .. "/" .. id .. ".txt"
end

local function save_note()
    if cur then love.filesystem.write(note_path(cur.id), cur.text) end
end

local function open_note(id)
    cur = { id = id, text = love.filesystem.read(note_path(id)) or "" }
    keys.shift = false
    armed = false
    mode = "edit"
end

local function new_note()
    counter = counter + 1
    local id = string.format("%012d%03d", os.time(), counter)
    love.filesystem.write(note_path(id), "")
    open_note(id)
end

local function close_note()
    if cur and cur.text == "" then
        love.filesystem.remove(note_path(cur.id))   -- drop empty notes
    else
        save_note()
    end
    cur = nil
    mode = "list"
    refresh()
end

local function delete_selected()
    if #notes == 0 then return end
    if not armed then
        armed = true
        return
    end
    love.filesystem.remove(note_path(notes[sel].id))
    armed = false
    refresh()
end

local function type_text(t)
    if keys.shift and t:match("^%l$") then
        t = t:upper()
    end
    keys.shift = false
    cur.text = cur.text .. t
    save_note()
end

local function backspace()
    if cur then
        -- Drop one UTF-8 character so accented text deletes cleanly.
        local s = cur.text
        local n = #s
        if n > 0 then
            local i = n
            while i > 1 and (s:byte(i) >= 128 and s:byte(i) < 192) do i = i - 1 end
            cur.text = s:sub(1, i - 1)
            save_note()
        end
    end
end

local function press_key()
    local v = keys:current().value
    if v == "@shift" then
        keys.shift = not keys.shift
    elseif v == "@del" then
        backspace()
    elseif v == "@enter" then
        type_text("\n")
    else
        type_text(v)
    end
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

local function draw_header(title, hint)
    love.graphics.setColor(0.16, 0.19, 0.26)
    love.graphics.rectangle("fill", 0, 0, VW, 26)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(title, 10, 4)
    love.graphics.setColor(0.6, 0.65, 0.75)
    love.graphics.printf(hint, 0, 4, VW - 10, "right")
end

local function draw_list()
    draw_header("Notebook", "A open   X new   Y delete x2   Start quit")
    if #notes == 0 then
        love.graphics.setColor(0.6, 0.65, 0.75)
        love.graphics.printf("No notes yet. Press X to write one.", 0, 200, VW, "center")
        return
    end
    -- Keep the selection on screen.
    if sel < top then top = sel end
    if sel > top + LIST_VISIBLE - 1 then top = sel - LIST_VISIBLE + 1 end

    for row = 0, LIST_VISIBLE - 1 do
        local i = top + row
        local n = notes[i]
        if not n then break end
        local y = 36 + row * LIST_ROW_H
        local selected = (i == sel)
        if selected then
            love.graphics.setColor(0.25, 0.27, 0.36)
            love.graphics.rectangle("fill", 8, y, VW - 16, LIST_ROW_H - 4, 5, 5)
        end
        love.graphics.setColor(selected and 0.95 or 0.9, selected and 0.8 or 0.9, selected and 0.3 or 0.95)
        love.graphics.print(n.title, 18, y + 8)
    end
    if armed then
        love.graphics.setColor(1, 0.5, 0.45)
        love.graphics.printf("Press Y again to delete \"" .. notes[sel].title .. "\"",
            0, VH - 24, VW, "center")
    end
end

local function draw_edit()
    draw_header("Note", "Start save & back   X shift   Y new line")
    local area_x, area_y, area_w, area_h = 10, 34, VW - 20, 236
    love.graphics.setColor(0.1, 0.12, 0.16)
    love.graphics.rectangle("fill", area_x, area_y, area_w, area_h, 6, 6)

    local text = cur.text .. "_"
    local _, lines = font:getWrap(text, area_w - 16)
    local line_h = font:getHeight()
    local max_lines = math.floor((area_h - 8) / line_h)
    local first = math.max(1, #lines - max_lines + 1)
    love.graphics.setColor(0.93, 0.93, 0.95)
    for i = first, #lines do
        love.graphics.print(lines[i], area_x + 8, area_y + 4 + (i - first) * line_h)
    end

    if keys.shift then
        love.graphics.setColor(0.95, 0.8, 0.3)
        love.graphics.print("SHIFT", area_x + area_w - 60, area_y + area_h - 22)
    end
    keys:draw(8, 280, VW - 16, VH - 288, small)
end

function love.load()
    font = love.graphics.newFont(16)
    small = love.graphics.newFont(14)
    keys = build_keys()
    refresh()
end

function love.draw()
    love.graphics.clear(0.07, 0.08, 0.11)
    love.graphics.setFont(font)
    if mode == "list" then
        draw_list()
    else
        draw_edit()
    end
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function love.gamepadpressed(_, button)
    if mode == "list" then
        if button == "dpup" then
            sel = math.max(1, sel - 1)
            armed = false
        elseif button == "dpdown" then
            sel = math.min(math.max(1, #notes), sel + 1)
            armed = false
        elseif button == "a" and #notes > 0 then
            open_note(notes[sel].id)
        elseif button == "x" then
            new_note()
        elseif button == "y" then
            delete_selected()
        elseif button == "start" then
            love.event.quit()
        end
        return
    end

    -- Editor.
    if button == "dpup" then keys:move(-1, 0)
    elseif button == "dpdown" then keys:move(1, 0)
    elseif button == "dpleft" then keys:move(0, -1)
    elseif button == "dpright" then keys:move(0, 1)
    elseif button == "a" then press_key()
    elseif button == "b" then backspace()
    elseif button == "x" then keys.shift = not keys.shift
    elseif button == "y" then type_text("\n")
    elseif button == "start" then close_note()
    end
end

function love.textinput(text)
    if mode == "edit" then
        type_text(text)
    end
end

function love.keypressed(key)
    if mode == "list" then
        if key == "up" then
            sel = math.max(1, sel - 1)
            armed = false
        elseif key == "down" then
            sel = math.min(math.max(1, #notes), sel + 1)
            armed = false
        elseif key == "return" and #notes > 0 then
            open_note(notes[sel].id)
        elseif key == "n" then
            new_note()
        elseif key == "delete" then
            delete_selected()
        elseif key == "escape" then
            love.event.quit()
        end
        return
    end

    if key == "escape" then
        close_note()
    elseif key == "backspace" then
        backspace()
    elseif key == "return" or key == "kpenter" then
        type_text("\n")
    end
end
