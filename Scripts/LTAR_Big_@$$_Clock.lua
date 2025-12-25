-- @description Let's Talk About REAPER's Big @$$ Clock
-- @version 2.2
-- @author Let's Talk About REAPER
-- @about
--   A high-visibility cinematic region clock for drummers and engineers.
--   Features configurable progress thresholds and transport pass-through.
-- @changelog
--   - Added keyboard pass-through for transport controls.
--   - Restored configurable yellow/red thresholds.
--   - Added "PROJECT:" bold labeling.
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
    if gfx.w < 20 or gfx.h < 20 then reaper.defer(main) return end
    
    -- IMPROVED PASSTHROUGH
    local char = gfx.getchar()
    if char >= 0 and char ~= 27 then 
        reaper.defer(main) 
        -- 32 is Spacebar. If any key is pressed, pass it to REAPER's main window.
        if char ~= 0 then 
            reaper.JS_Window_SetFocus(reaper.GetMainHwnd()) -- Force focus back to REAPER for the action
            reaper.Main_OnCommand(reaper.NamedCommandLookup("_BR_FOCUS_ARRANGE_WND"), 0) -- Focus arrange
            reaper.Main_OnCommand(40044, 0) -- Transport: Play/stop (standard spacebar action)
        end
    else 
        gfx.quit() 
    end

    local cur, nxt, countdown, progress, is_warning, cur_color, proj_name = get_logic()
    if gfx.mouse_cap == 2 then ShowMenu() end
    if gfx.mouse_cap == 1 and gfx.mouse_x > gfx.w - 50 and gfx.mouse_y < 50 then ShowMenu() end
    if is_warning then gfx.set(0.3, 0, 0, 1) else gfx.set(0, 0, 0, 1) end
    gfx.rect(0, 0, gfx.w, gfx.h, 1)
    draw_gear(gfx.w - 25, 25, 12)
    gfx.set(0.4, 0.4, 0.4, 1); gfx.line(gfx.w - 25, gfx.h, gfx.w, gfx.h - 25); gfx.line(gfx.w - 18, gfx.h, gfx.w, gfx.h - 18)

    local current_y = gfx.h * 0.05
    current_y = current_y + draw_text_centered("LET'S TALK ABOUT REAPER: BIG @$$ CLOCK", current_y, gfx.h * 0.045, 0.4, 0.4, 0.4, false) + 5
    if SETTINGS.show_project_name == 1 then current_y = current_y + draw_project_line(proj_name, current_y, gfx.h * 0.04) + (gfx.h * 0.05) end
    local r, g, b = reaper.ColorFromNative(cur_color)
    current_y = current_y + draw_text_centered(cur, current_y, gfx.h * 0.25, r/255, g/255, b/255, true) + (gfx.h * 0.05)
    current_y = current_y + draw_text_centered("NEXT: " .. nxt, current_y, gfx.h * 0.10, 0.5, 0.5, 0.5, false) + (gfx.h * 0.05)
    draw_text_centered(countdown, current_y, gfx.h * 0.20, 0, 0.85, 0.85, true)

    if SETTINGS.show_progress == 1 then
        local bh = math.max(15, gfx.h * SETTINGS.bar_height_ratio)
        gfx.set(0.12, 0.12, 0.12, 1); gfx.rect(0, gfx.h - bh, gfx.w, bh, 1)
        if progress < SETTINGS.yellow_threshold then gfx.set(0, 0.55, 0.2, 1)
        elseif progress < SETTINGS.red_threshold then gfx.set(0.65, 0.65, 0, 1)
        else gfx.set(0.75, 0, 0, 1) end
        gfx.rect(0, gfx.h - bh, gfx.w * progress, bh, 1)
    end
    gfx.update()
end

LoadSettings()
local _, _, sw, sh = reaper.my_getViewport(0, 0, 0, 0, 0, 0, 0, 0, true)
gfx.init("Let's Talk About REAPER's Big @$$ Clock", sw * 0.5, sh * 0.5, 0)
main()
