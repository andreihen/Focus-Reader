local Widget = require("ui/widget/widget")
local Device = require("device")
local UIManager = require("ui/uimanager")
local Geom = require("ui/geometry")
local Event = require("ui/event")
local LuaSettings = require("luasettings")
local DataStorage = require("datastorage")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local logger = require("logger")
local time = require("ui/time")
local Settings = require("focusreader/settings")
local Detector = require("focusreader/line_detector")
local Navigation = require("focusreader/navigation")
local FocusView = require("focusreader/focusview")
local Menu = require("focusreader/menu")
local _ = require("gettext")
local Screen = Device.screen

local FocusReader = Widget:extend{ name="focusreader", is_doc_only=true }

function FocusReader:init()
    self.store = LuaSettings:open(DataStorage:getSettingsDir() .. "/focusreader.lua")
    self.settings = Settings.normalize(self.store:readSetting("preferences"))
    self.nav = Navigation.new()
    self.zones = {}
    self.reason = _("Aguardando o layout do documento.")
    self.scale = function(value) return math.max(0, math.floor(Screen:scaleBySize(value)+0.5)) end
    self.rebuild_callback = function()
        if not self.closed then self:rebuild() end
    end
    self.drag_callback = function()
        if not self.closed and self.dragging and self.drag_index then
            self:setIndex(self.drag_index)
            self.last_drag_time = time.now()
        end
    end
    self.ui.menu:registerToMainMenu(self)
    self.view:registerViewModule("focusreader", self)
    self:registerActions()
end

function FocusReader:registerActions()
    local actions = {
        {"focusreader_toggle", "FocusReaderToggle", _("Focus Reader: ativar/desativar")},
        {"focusreader_next", "FocusReaderNext", _("Focus Reader: avançar")},
        {"focusreader_previous", "FocusReaderPrevious", _("Focus Reader: retroceder")},
        {"focusreader_style", "FocusReaderStyle", _("Focus Reader: alternar aparência")},
        {"focusreader_pause", "FocusReaderPause", _("Focus Reader: suspender/retomar gestos")},
    }
    for _, a in ipairs(actions) do
        Dispatcher:registerAction(a[1], {category="none",event=a[2],title=a[3],reader=true})
    end
end

function FocusReader:onReadSettings(config)
    local saved = config:readSetting("focusreader")
    if type(saved) == "table" and type(saved.anchor) == "string" then
        self.restore_anchor = saved.anchor
    end
end

function FocusReader:onReaderReady()
    self.ready = true
    self:invalidate()
end

function FocusReader:invalidate()
    self:cancelDrag()
    self.rect = nil
    self.valid = false
    self:clearZones()
    UIManager:unschedule(self.rebuild_callback)
    if self.ready and not self.closed and self.settings.enabled then
        -- One deferred pass, after all handlers have applied the new page/layout.
        UIManager:nextTick(self.rebuild_callback)
    end
end

function FocusReader:onPageUpdate(page)
    if self.page and page ~= self.page then
        self.target_edge = self.turn_direction and (self.turn_direction < 0 and "last" or "first") or "first"
        self.anchor = nil
    end
    self:invalidate()
end

function FocusReader:onDocumentRerendered() self:invalidate() end
function FocusReader:onSetDimensions() self:invalidate() end
function FocusReader:onChangeViewMode() self:invalidate() end
function FocusReader:onPosUpdate() self:invalidate() end
function FocusReader:resetLayout() self:invalidate() end

function FocusReader:rebuild()
    if self.closed or not self.ui.document or not self.settings.enabled then return end
    local document = self.ui.document
    local ok, supported, reason = pcall(Detector.supported, document, self.view)
    if not ok then reason, supported = tostring(supported), false end
    self.reason = reason
    self.valid = false
    if supported then
        self.bounds = Detector.bounds(document, Screen:getWidth(), Screen:getHeight())
        local success, lines = pcall(Detector.detect, document, self.bounds)
        if not success then
            self.reason = _("Não foi possível obter linhas inequívocas nesta página (layout complexo ou API incompatível). A navegação normal continua disponível.")
            logger.warn("Focus Reader: geometry failed", lines)
            lines = {}
        end
        local previous_index = self.nav.index
        self.nav:setLines(lines, self.settings.lines, previous_index)
        self.page = document:getCurrentPage()
        if self.target_edge then
            self.nav.index = self.target_edge == "last" and self.nav:lastStart() or 1
        else
            local anchor = self.restore_anchor or self.anchor
            if anchor and type(document.getScreenPositionFromXPointer) == "function"
                    and type(document.getPageFromXPointer) == "function" then
                local valid, y = pcall(function()
                    if document:getPageFromXPointer(anchor) == self.page then
                        return document:getScreenPositionFromXPointer(anchor)
                    end
                end)
                if valid and type(y) == "number" and #lines > 0 then
                    self.nav.index = self.nav:nearest(y + lines[1].h/2)
                end
            end
        end
        self.restore_anchor, self.target_edge = nil, nil
        self.valid = #lines > 0
        if not self.valid and not self.reason then
            self.reason = _("Página sem linhas de texto detectáveis. A navegação normal continua disponível.")
        end
    end
    self.turning, self.turn_direction = nil, nil
    if self.valid then self:rememberAnchor() end
    self:updateRect()
    self:updateZones()
    self:repaint()
end

function FocusReader:updateRect()
    self.rect = nil
    if self.valid and self.settings.enabled and self.settings.visible then
        self.rect = FocusView.rect(self.nav:region(), self.bounds, self.settings, self.scale)
    end
end

function FocusReader:repaint()
    local dirty = FocusView.union(self.drawn_rect, self.rect)
    if dirty and not self.closed then
        -- KOReader repaints the reader layer (including the underlying cached
        -- page), THEN sends only this union to the display as a UI refresh.
        UIManager:setDirty(self.ui.dialog or self.ui, "ui", Geom:new(dirty))
    end
end

function FocusReader:paintTo(bb, x, y)
    if self.rect and not self.closed then
        FocusView.paint(bb, self.rect, self.settings, self.scale, x, y)
        self.drawn_rect = self.rect
    else
        self.drawn_rect = nil
    end
end

function FocusReader:rememberAnchor()
    if not self.valid or not self.document.getWordFromPosition then return end
    local line = self.nav.lines[self.nav.index]
    if not line then return end
    local ok, word = pcall(self.document.getWordFromPosition, self.document,
        {x=math.floor(line.x + math.min(line.w/2,self.scale(10))), y=math.floor(line.y+line.h/2)}, true)
    self.anchor = ok and word and word.pos0 or nil
end

function FocusReader:setIndex(index)
    index = math.max(1, math.min(self.nav:lastStart(), index))
    if index == self.nav.index then return end
    self.nav.index = index
    self:rememberAnchor()
    self:updateRect()
    self:repaint()
end

function FocusReader:canInteract()
    if self.closed or not self.settings.enabled or not self.valid or self.paused or self.turning then return false end
    local top = UIManager:getTopmostVisibleWidget()
    if top and top ~= (self.ui.dialog or self.ui) then return false end
    local highlight = self.ui.highlight
    return not (highlight and (highlight.hold_pos or highlight.selected_text or highlight.select_mode))
end

function FocusReader:move(direction)
    if not self:canInteract() then return false end
    self:cancelDrag()
    local result = self.nav:move(direction,self.settings.step)
    if result == "line" then
        self:rememberAnchor()
        self:updateRect()
        self:repaint()
    elseif result == "page" then
        -- Exactly one native page request. Never recursively skip a blank page.
        self.turning, self.turn_direction = true, direction
        self.ui:handleEvent(Event:new("GotoViewRel",direction))
        -- Also rebuild when the reader remains at the beginning/end of the book.
        UIManager:unschedule(self.rebuild_callback)
        if not self.closed and self.ui.document then UIManager:nextTick(self.rebuild_callback) end
    end
    return result ~= "empty"
end

function FocusReader:clearZones()
    if #self.zones > 0 then self.ui:unRegisterTouchZones(self.zones) end
    self.zones = {}
end

function FocusReader:updateZones()
    self:clearZones()
    if not Device:isTouchDevice() or not self.settings.enabled or not self.valid or self.paused then return end
    local function zone(id, gesture, overrides, handler)
        self.zones[#self.zones+1] = {
            id="focusreader_"..id, ges=gesture,
            screen_zone={ratio_x=0,ratio_y=0,ratio_w=1,ratio_h=1},
            overrides=overrides,handler=handler,
        }
    end
    if self.settings.mode ~= "drag" then
        zone("tap","tap",{"tap_forward","tap_backward"},function(ges) return self:tap(ges) end)
    end
    if self.settings.mode ~= "tap" and self.settings.visible then
        zone("pan","pan",{"rolling_pan","readermenu_pan","readermenu_ext_pan","readerconfigmenu_pan","readerconfigmenu_ext_pan"},function(ges) return self:pan(ges) end)
        zone("release","pan_release",{"rolling_pan_release"},function(ges) return self:release(ges) end)
        zone("swipe","swipe",{"rolling_swipe","readermenu_swipe","readermenu_ext_swipe","readerconfigmenu_swipe","readerconfigmenu_ext_swipe"},function(ges) return self:swipe(ges) end)
    end
    self.ui:registerTouchZones(self.zones)
end

function FocusReader:tap(ges)
    if not self:canInteract() then return false end
    local p, width, height = ges.pos, Screen:getWidth(), Screen:getHeight()
    -- Keep top/bottom menus, corners and a central strip available to KOReader.
    if not p or p.y < height*0.12 or p.y >= height*0.88 then return false end
    local side = self.settings.tap_width/100
    local direction
    if p.x < width*side then direction=-1
    elseif p.x >= width*(1-side) then direction=1 end
    if not direction then return false end
    if self.settings.reverse then direction=-direction end
    return self:move(direction)
end

function FocusReader:hitRuler(pos)
    if not self.rect or not pos then return false end
    local r, padding = self.rect, self.scale(10)
    return pos.x >= r.x-padding and pos.x <= r.x+r.w+padding
       and pos.y >= r.y-padding and pos.y <= r.y+r.h+padding
end

function FocusReader:pan(ges)
    if not self:canInteract() then self:cancelDrag(); return false end
    if not self.dragging then
        local start = ges.start_pos
        if not start and ges.relative then
            start = {x=ges.pos.x-ges.relative.x,y=ges.pos.y-ges.relative.y}
        end
        if not self:hitRuler(start) then return false end
        -- Horizontal page swipes remain native.
        if ges.relative and math.abs(ges.relative.x) > math.abs(ges.relative.y) then return false end
        local line = self.nav.lines[self.nav.index]
        self.dragging, self.drag_offset = true, start.y-(line.y+line.h/2)
    end
    self.drag_index = self.nav:nearest(ges.pos.y-self.drag_offset)
    if self.settings.drag_refresh == "line" and self.drag_index ~= self.nav.index then
        -- Coalesce bursts; no repaint while the pointer stays on the same line.
        if not self.last_drag_time or time.now()-self.last_drag_time >= time.ms(120) then
            UIManager:unschedule(self.drag_callback)
            self:setIndex(self.drag_index)
            self.last_drag_time = time.now()
        else
            UIManager:unschedule(self.drag_callback)
            UIManager:scheduleIn(0.12,self.drag_callback)
        end
    end
    return true
end

function FocusReader:release(ges)
    if not self.dragging then return false end
    if self:canInteract() then
        self:setIndex(self.nav:nearest(ges.pos.y-self.drag_offset))
    end
    self:cancelDrag()
    return true
end

function FocusReader:swipe(ges)
    -- A quick drag ends as a swipe, not as pan_release, in KOReader.
    if self.dragging then return self:release({pos=ges.end_pos or ges.pos}) end
    if not self:canInteract() or (ges.direction ~= "north" and ges.direction ~= "south")
            or not self:hitRuler(ges.pos) or not ges.end_pos then return false end
    local line = self.nav.lines[self.nav.index]
    local offset = ges.pos.y-(line.y+line.h/2)
    self:setIndex(self.nav:nearest(ges.end_pos.y-offset))
    return true
end

function FocusReader:cancelDrag()
    UIManager:unschedule(self.drag_callback)
    self.dragging, self.drag_index, self.last_drag_time = nil, nil, nil
end

function FocusReader:configure(key,value)
    local values = {}
    for k,v in pairs(self.settings) do values[k]=v end
    values[key]=value
    self.settings = Settings.normalize(values)
    self.store:saveSetting("preferences",self.settings)
    self.store:flush()
    if key == "enabled" then
        if self.settings.enabled then
            self:rebuild()
            if not self.valid then self:showStatus() end
        else
            UIManager:unschedule(self.rebuild_callback)
            self:cancelDrag()
            self.rect=nil
            self:clearZones()
            self:repaint()
        end
    else
        self:cancelDrag()
        self.nav:setLines(self.nav.lines,self.settings.lines,self.nav.index)
        self:updateRect()
        self:updateZones()
        self:repaint()
    end
end

function FocusReader:showStatus()
    UIManager:show(InfoMessage:new{text=self.reason or _("Focus Reader disponível: texto ajustável, uma página, leitura paginada.")})
end
function FocusReader:addToMainMenu(items) Menu.add(self,items) end
function FocusReader:onFocusReaderToggle() self:configure("enabled",not self.settings.enabled); return true end
function FocusReader:onFocusReaderNext() return self:move(1) end
function FocusReader:onFocusReaderPrevious() return self:move(-1) end
function FocusReader:onFocusReaderStyle()
    local styles={"soft","strong","outline","side","underline"}
    for i,v in ipairs(styles) do
        if self.settings.style == v then self:configure("style",styles[i % #styles+1]); break end
    end
    return true
end
function FocusReader:onFocusReaderPause()
    self.paused=not self.paused
    self:cancelDrag()
    self:updateZones()
    return true
end
function FocusReader:onSaveSettings()
    self.ui.doc_settings:saveSetting("focusreader",{version=1,anchor=self.anchor})
end
function FocusReader:onCloseDocument()
    self.closed=true
    UIManager:unschedule(self.rebuild_callback)
    self:cancelDrag()
    self:clearZones()
    self.view.view_modules.focusreader=nil
    self.nav:setLines({},self.settings.lines)
    self.rect,self.drawn_rect=nil,nil
end
return FocusReader
