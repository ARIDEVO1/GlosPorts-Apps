-- Engineering Calculator for goodluckOS. MIT licensed.

function love.conf(t)
    t.identity = "goodluck-calc"           -- variables are saved in ~/.local/share/love/goodluck-calc
    t.window.title = "Calculator"
    t.window.width = 640
    t.window.height = 480
    t.window.resizable = false
    t.window.usedpiscale = false
    t.modules.physics = false
    t.modules.video = false
    t.modules.touch = false
end
