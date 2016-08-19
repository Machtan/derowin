local M = {}
local ffi = require("ffi")
local dalgi = require("dalgi")

ffi.cdef[[
const char *dero_error_message(int32_t);
int32_t dero_convert(const char *text, const char **output);
void dero_free_converted(const char *);
void dero_explain_error(const char *);
]]

SOURCE = love.filesystem.getSource()
DERO_PATH = SOURCE .. "/libs/" .. "libdero.dylib"
local dero = dalgi.ffi_load_without_closing(ffi, DERO_PATH)

function M.convert(text)
    if text == nil then
        error("text must not be nil")
    end

    local tmp = {""}
    local out = ffi.new("const char *[1]", tmp)
    local error = dero.dero_convert(text, out)
    if error == 0 then
        local converted = ffi.string(out[0])
        dero.dero_free_converted(out[0])
        return true, converted
    else
        return false, text
    end
end

function M.explain_error(text)
    dero.dero_explain_error(text)
end

return M
