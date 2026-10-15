-- Values are validated even when loaded from an older or hand-edited settings file.
local Settings = {}
Settings.defaults = {
    enabled = false,
    visible = true,
    lines = 2,
    step = 1,
    mode = "combined",
    style = "soft",
    intensity = 18, -- percent black for the soft band; strong adds 18 points
    thickness = 2, -- logical pixels, scaled by KOReader
    horizontal_padding = 4,
    vertical_padding = 2,
    tap_width = 45, -- percent of screen on each side, leaves a neutral center
    reverse = false,
    drag_refresh = "line",
}
local ranges = {
    lines = {1, 5}, step = {1, 3}, intensity = {5, 35}, thickness = {1, 6},
    horizontal_padding = {0, 24}, vertical_padding = {0, 12}, tap_width = {25, 50},
}
local choices = {
    mode = {tap=true, drag=true, combined=true},
    style = {soft=true, strong=true, outline=true, side=true, underline=true},
    drag_refresh = {line=true, release=true},
}
function Settings.normalize(raw)
    local values = {}
    raw = type(raw) == "table" and raw or {}
    for key, default in pairs(Settings.defaults) do
        local value = raw[key]
        if ranges[key] then
            if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
                value = default
            end
            value = math.max(ranges[key][1], math.min(ranges[key][2], math.floor(value)))
        elseif choices[key] then
            if not choices[key][value] then value = default end
        elseif type(value) ~= type(default) then
            value = default
        end
        values[key] = value
    end
    return values
end
return Settings
