local utf8 = require("utf8")
local dero = require("dero")
local dalgi = require("dalgi")

local BG_COLOR = { 254, 254, 254 }
local FONT_PATH = "NanumMyeongjo.ttc"
local FONT_POINT_SIZE = 18
local WINDOW_SIZE = {w = 500, h = 500}
local DEFAULT_TITLE = "Derömanizer"
local PADDING = 10
local INPUT_CHAR = "_"
local ICON_FILE = "icon.png"

local g_history
local g_history_index
local g_mode
local g_text
local g_converted
local g_unconverted
local g_font
local g_label
local g_output_file

local MODES = {
    default = 1,
    input = 1,
    lookup = 1,
}

function toggle_mode(mode_name)
    local old_mode = g_mode
    if mode_name == old_mode then -- restore defaults
        love.window.setTitle(DEFAULT_TITLE)
        g_mode = "default"
    elseif mode_name == "input" then
        love.window.setTitle(DEFAULT_TITLE.." - Input")
        g_mode = "input"
    elseif mode_name == "lookup" then
        love.window.setTitle(DEFAULT_TITLE.." - Lookup")
        g_mode = "lookup"
    elseif mode_name == "output" then
        if g_output_file ~= "" then
            love.window.setTitle(DEFAULT_TITLE.." Output -> "..g_output_file)
            g_mode = "output"
        end
    end
end

function love.load()    
    love.window.setMode(WINDOW_SIZE.w, WINDOW_SIZE.h, {
        resizable = true,
        minwidth = 100,
        minheight = 50,
    })
    love.window.setTitle(DEFAULT_TITLE)
    love.graphics.setBackgroundColor(BG_COLOR[1], BG_COLOR[2], BG_COLOR[3])
    love.window.setIcon(love.image.newImageData(ICON_FILE))
    
    g_history = dalgi.Array:new()
    --g_history:append({"il", "i", "sam", "sa"})
    g_history_index = #g_history + 1
    g_mode = "default"
    g_text = ""
    g_converted = ""
    g_unconverted = ""
    g_font = love.graphics.newFont(FONT_PATH, FONT_POINT_SIZE)
    g_label = love.graphics.newText(g_font, "")
    g_output_file = ""
    if #arg > 1 then
        local mode = arg[2]
        if MODES[mode] ~= nil then
            toggle_mode(mode)
        else
            print("Usage: derowin [mode]")
            print("Valid modes:")
            for mode, _ in pairs(MODES) do
                print("- "..mode)
            end
            love.event.quit()
        end
    end
end

function try_convert(text)
    --print("Converting: '" .. text .. "'")
    local offsets = {}
    for i, ch in utf8.codes(text) do
        table.insert(offsets, i)
    end
    table.insert(offsets, string.len(text)+1)
    table.sort(offsets, function (i, j) return i > j end)
    --print("Sorted...")
    for _, o in ipairs(offsets) do
        local part = string.sub(text, 1, o-1);
        --print("Converting...")
        local success, converted = dero.convert(part)
        --print("Part/succes: " .. part .. " / " .. tostring(success))
        if success then
            local rem = string.sub(text, o)
            --print("Found:     " .. converted)
            --print("Remainder: " .. rem)
            return converted, rem
        end
    end
    return "", text
end

function update_text_label(unconverted_text)
    local converted, remainder = try_convert(unconverted_text)
    --print("Converted/remainder: "..converted.." | "..remainder)
    local ww, _= love.graphics.getDimensions()
    g_label:setf({
        {0, 0, 0}, converted,
        {255, 0, 0}, remainder..INPUT_CHAR,
    }, ww - PADDING * 2, "left")
end

function love.textinput(text)
    g_text = g_text .. text
    update_text_label(g_text)
end

function cmd_copy()
    --print("COPY")
    local converted, remainder = try_convert(g_text)
    love.system.setClipboardText(converted .. remainder)
end

function is_browsing_history()
    return g_history_index <= #g_history
end

function move_back_history()
    --print("Back    ("..tostring(g_history_index)..")")
    if #g_history == 0 then
        return
    end
    if not is_browsing_history() then
        g_history:push(g_text)
    end
    if g_history_index ~= 1 then
        g_history_index = g_history_index - 1
        g_text = g_history[g_history_index]
        update_text_label(g_text)
    end
end

function move_forward_history()
    --print("Forwards ("..tostring(g_history_index)..")")
    local next_index = g_history_index + 1
    if next_index > #g_history then
        -- Don't do a thing
    elseif next_index == #g_history then
        g_text = g_history:pop()
        g_history_index = next_index
        update_text_label(g_text)
    else
        g_text = g_history[next_index]
        g_history_index = next_index
        update_text_label(g_text)
    end
end

function cmd_cut()
    --print("CUT")
    local converted, remainder = try_convert(g_text)
    love.system.setClipboardText(converted .. remainder)
    g_text = ""
    g_history:push(converted..remainder)
    g_history_index = g_history_index + 1
    update_text_label("")
    print(converted..remainder)
    return converted, remainder
end

function cmd_paste()
    g_text = g_text .. love.system.getClipboardText()
    update_text_label(g_text)
end

function cmd_lookup()
    --print("LOOKUP")
    local converted, remainder = cmd_cut()
    os.execute('open "dict://'..converted..remainder..'"')
end

function text_delete_backwards()
    if g_text == "" then return end
    local byteoffset = utf8.offset(g_text, -1)
    g_text = string.sub(g_text, 1, byteoffset - 1)
    update_text_label(g_text)
end

function text_add_newline()
    g_text = g_text .. "\n"
    update_text_label(g_text)
end

function love.keypressed(key, scancode, is_repeat)
    local cmd_down = love.keyboard.isDown("lgui", "rgui")
    local alt_down = love.keyboard.isDown("lmeta", "rmeta")
    local shift_down = love.keyboard.isDown("lshift", "rshift")
    --print("Keypress: "..(cmd_down and "Cmd " or "")..key)
    if cmd_down then
        if key == "c" then
            cmd_copy()
        elseif key == "v" then
            cmd_paste()
        elseif key == "x" then
            cmd_cut()
        elseif key == "i" then
            toggle_mode("input")
        elseif key == "l" then
            toggle_mode("lookup")
        elseif key == "o" then
            toggle_mode("output")
        end
    else
        if key == "return" then
            if g_mode == "default" then
                text_add_newline()
            
            elseif g_mode == "input" then
                if not shift_down then
                    cmd_cut()
                else
                    text_add_newline()
                end
            
            elseif g_mode == "lookup" then
                cmd_lookup()
            
            elseif g_mode == "output" then
                local file = io.open(g_output_file, "a")
                if file ~= nil then
                    local converted, remainder = cmd_cut()
                    file:write(converted..remainder)
                    file:close()
                else
                    print("Could not write to output file '"..g_output_file.."'")
                    toggle_mode("output")
                end
            end
        elseif key == "backspace" then
            text_delete_backwards()
        elseif key == "up" then
            move_back_history()
        elseif key == "down" then
            move_forward_history()
        end
    end
end

function love.draw()
    love.graphics.draw(g_label, PADDING, PADDING)
end

function love.resize(w, h)
    update_text_label(g_text)
end

function love.update(dt)
end

function love.quit()
end