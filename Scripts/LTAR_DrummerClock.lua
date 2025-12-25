-- @description Let's Talk About REAPER's DrummerClock
-- @version 2.3
-- @author Let's Talk About
-- @about
--   # Let's Talk About REAPER: DrummerClock
--   A high-visibility cinematic region clock for performers and engineers.
--   Developed as a collaboration between a Let's Talk About REAPER and Gemini (AI).
--   
--   Features:
--   - Configurable progress thresholds (Yellow/Red).
--   - Bold "PROJECT:" labeling for clear metadata view.
--   - Keyboard pass-through for transport (Spacebar/Record).
--   - Adaptive region color support.
-- @changelog
--   - Renamed script to "DrummerClock" for professional distribution.
--   - Updated GUI branding and internal metadata.
-- @provides
--   [main] .

local OS = reaper.GetOS()

-- Settings
local SETTINGS = {
    warning_beats = 4,
    bar_height_ratio = 0.1,
    always_on_top = 1,
    use_region_colors = 1,
    show_progress = 1,
    show_project_name = 1,
    yellow_threshold = 0.75,
    red_threshold = 0.90
}

function SaveSettings()
    for k, v in pairs(SETTINGS) do reaper.SetExtState("LTAR_Clock", k, tostring(v), true) end
end

function LoadSettings()
    for k, v in pairs(SETTINGS) do
        local saved = reaper.GetExtState("LTAR_Clock", k)
        if saved ~= "" then SETTINGS[k] = tonumber(saved) end
    end
end

function ShowMenu()
    local menu = (SETTINGS.show_progress == 1 and "!" or "") .. "Show Progress Bar|"
    menu = menu .. (SETTINGS.use_region_colors == 1 and "!" or "") .. "Use Region Colors|"
    menu = menu .. (SETTINGS.show_project_name == 1 and "!" or "") .. "Show Project Name|"
    menu = menu .. (SETTINGS.always_on_top == 1 and "!" or "") .. "Always On Top|"
    menu = menu .. ">Warning Flash Timing|"
    menu = menu .. (SETTINGS.warning_beats == 4 and "!" or "") .. "4 Beats (1 Bar)|"
    menu = menu .. (SETTINGS.warning_beats == 8 and "!" or "") .. "8 Beats (2 Bars)|"
    menu = menu .. (SETTINGS.warning_beats == 16 and "!" or "") .. "16 Beats (4 Bars)|<"
    menu = menu .. ">Yellow Threshold (Caution)|"
    menu = menu .. (SETTINGS.yellow_threshold == 0.50 and "!" or "") .. "50% Through|"
    menu = menu .. (SETTINGS.yellow_threshold == 0.75 and "!" or "") .. "75% Through (Default)|"
    menu = menu .. (SETTINGS.yellow_threshold == 0.85 and "!" or "") .. "85% Through|<"
    menu = menu .. ">Red Threshold (Urgent)|"
    menu = menu .. (SETTINGS.red_threshold == 0.90 and "!" or "") .. "90% Through (Default)|"
    menu = menu .. (SETTINGS.red_threshold == 0.95 and "!" or "") .. "95% Through|"
    menu = menu .. (SETTINGS.red_threshold == 0.98 and "!" or "") .. "98% Through|<"
    
    gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
    local choice = gfx.showmenu(menu)
    if choice > 0 then 
        if choice == 1 then SETTINGS.show_progress = 1 - SETTINGS.show_progress
        elseif choice == 2 then SETTINGS.use_region_colors = 1 - SETTINGS.use_region_colors
        elseif choice == 3 then SETTINGS.show_project_name = 1 - SETTINGS.show_project_name
        elseif choice == 4 then SETTINGS.always_on_top = 1 - SETTINGS.always_on_top
        elseif choice == 6 then SETTINGS.warning_beats = 4
        elseif choice == 7 then SETTINGS.warning_beats = 8
        elseif choice == 8 then SETTINGS.warning_beats = 16
        elseif choice == 10 then SETTINGS.yellow_threshold = 0.50
        elseif choice == 11 then SETTINGS.yellow_threshold = 0.75
        elseif choice == 12 then SETTINGS.yellow_threshold = 0.85
        elseif choice == 14 then SETTINGS.red_threshold = 0.90
        elseif choice == 15 then SETTINGS.red_threshold = 0.95
        elseif choice == 16 then SETTINGS.red_threshold = 0.98
        end
        SaveSettings()
    end
end

function get_logic()
    local play_state = reaper.GetPlayState()
    local is_playing = (play_state & 1 == 1)
    local play_pos = is_playing and reaper.GetPlayPosition2() or reaper.GetCursorPosition()
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    local cur_name, nxt_name, cur_start, cur_end, nxt_start = "---", "END", 0, 0, reaper.GetProjectLength(0)
    local cur_color = 0xFFD700FF 
    
    for i = 0, (num_markers + num_regions) - 1 do
        local _, isrgn, pos, rgnend, name, _, color = reaper.EnumProjectMarkers3(0, i)
        if isrgn then
            if play_pos >= pos and play_pos < rgnend then
                cur_name, cur_start, cur_end = (name ~= "" and name or "Region "..i), pos, rgnend
                if SETTINGS.use_region_colors == 1 and color ~= 0 then cur_color = color end
            elseif pos > play_pos then
                nxt_start, nxt_name = pos, (name ~= "" and name or "Region "..i)
                break
            end
        end
    end
    
    local countdown_str = "--M  --B"
    local is_warning = false
    if is_playing then
        local _, m_now, _, b_now = reaper.TimeMap2_timeToBeats(0, play_pos)
        local _, m_next, _, b_next = reaper.TimeMap2_timeToBeats(0, nxt_start)
        local diff_m, diff_b = m_next - m_now, b_next - b_now
        if diff_b < 0 then diff_b, diff_m = diff_b + (reaper.TimeMap_GetTimeSigAtTime(0, play_pos) or 4), diff_m - 1 end
        countdown_str = string.format("%dM  %dB", math.max(0, diff_m), math.max(0, math.floor(diff_b)))
        if nxt_name ~= "END" then
            local total_beats_rem = (diff_m * (reaper.TimeMap_GetTimeSigAtTime(0, play_pos) or 4)) + diff_b
            is_warning = (total_beats_rem <= SETTINGS.warning_beats)
        end
    end
    
    local progress = (cur_end > cur_start) and (play_pos - cur_start) / (cur_end - cur_start) or 0
    local _, proj_name = reaper.EnumProjects(-1)
    proj_name = (proj_name == "" or proj_name == nil) and "Untitled" or proj_name:match("([^/\\]+)%.rpp$") or proj_name
    return cur_name, nxt_name, countdown_str, progress, is_warning, cur_color, proj_name
end

function draw_gear(x, y, size)
    gfx.set(0.35, 0.35, 0.35, 1)
    for i = 0, 7 do
        local ang = i * (math.pi / 4)
        gfx.line(x + math.cos(ang)*size*0.5, y + math.sin(ang)*size*0.5, x + math.cos(ang)*size, y + math.sin(ang)*size)
    end
    gfx.circle(x, y, size * 0.5, 0)
end

function draw_project_line(name, y_pos, size)
    local font = (OS:match("OSX") or OS:match("macOS")) and "Helvetica" or "Arial"
    local safe_size = math.max(12, math.floor(size))
    gfx.setfont(1, font, safe_size, 98)
    local w1, _ = gfx.measurestr("PROJECT: ")
    gfx.setfont(2, font, safe_size, 0)
    local w2, h2 = gfx.measurestr(name)
    local start_x = (gfx.w - (w1 + w2)) / 2
    gfx.x, gfx.y = start_x, y_pos
    gfx.setfont(1, font, safe_size, 98); gfx.set(0.4, 0.4, 0.4, 1); gfx.drawstr("PROJECT: ")
    gfx.x = start_x + w1; gfx.setfont(2, font, safe_size, 0); gfx.drawstr(name)
    return h2
end

function draw_text_centered(str, y_pos, size, r, g, b, bold)
    local font = (OS:match("OSX") or OS:match("macOS")) and "Helvetica" or "Arial"
    local safe_size = math.max(12, math.floor(size))
    gfx.setfont(1, font, safe_size, bold and 98 or 0); gfx.set(r, g, b, 1)
    local w, h = gfx.measurestr(str); gfx.x, gfx.y = (gfx.w - w) / 2, y_pos; gfx.drawstr(str)
    return h
end

function main()
    if gfx.w < 20 or gfx.h < 20 then reaper.defer
