-- No font-size estimates or equal-height screen subdivisions.
local Detector = {}
local function finite(n)
    return type(n) == "number" and n == n and math.abs(n) < math.huge
end
function Detector.normalize(boxes, bounds)
    local fragments = {}
    for _, b in ipairs(boxes or {}) do
        if finite(b.x) and finite(b.y) and finite(b.w) and finite(b.h) and b.w > 0 and b.h > 0 then
            local x, y = math.max(bounds.x,b.x), math.max(bounds.y,b.y)
            local right = math.min(bounds.x+bounds.w,b.x+b.w)
            local bottom = math.min(bounds.y+bounds.h,b.y+b.h)
            if right > x and bottom > y then
                fragments[#fragments+1] = {x=x,y=y,w=right-x,h=bottom-y}
            end
        end
    end
    table.sort(fragments, function(a,b)
        if a.y == b.y then return a.x < b.x end
        return a.y < b.y
    end)
    local lines = {}
    for _, b in ipairs(fragments) do
        local previous = lines[#lines]
        -- Use near-equal top AND bottom, rather than overlap alone. A drop cap
        -- must not bridge several adjacent lines into one tall merged line.
        if previous and math.abs(previous.y-b.y) <= 1
                and math.abs(previous.y+previous.h-b.y-b.h) <= 1 then
            local right = math.max(previous.x+previous.w,b.x+b.w)
            previous.x = math.min(previous.x,b.x)
            previous.w = right-previous.x
            previous.h = math.max(previous.y+previous.h,b.y+b.h)-previous.y
        else
            lines[#lines+1] = b
        end
    end
    for i = 2, #lines do
        if lines[i].y < lines[i-1].y + lines[i-1].h - 1 then
            -- Initial letters spanning several rows and other overlapping blocks
            -- cannot be unambiguously interpreted as ordinary reading lines.
            error("Caixas de texto sobrepostas: capitular ou layout complexo")
        end
    end
    return lines
end
function Detector.supported(document, view)
    if not document or document.provider ~= "crengine" then
        return false, "Esta versão exige texto ajustável do crengine (por exemplo, EPUB). PDF e imagens não são suportados."
    end
    if view.view_mode ~= "page" then
        return false, "Selecione o modo de leitura paginada do KOReader; rolagem contínua ainda não é suportada."
    end
    for _, method in ipairs({"getVisiblePageCount", "getCurrentPage", "getPageCount", "getPageXPointer",
            "getScreenBoxesFromPositions", "getTextFromPositions", "getPageMargins", "getHeaderHeight"}) do
        if type(document[method]) ~= "function" then
            return false, "API ausente no KOReader: " .. method .. ". Consulte docs/COMPATIBILITY.md."
        end
    end
    if document:getVisiblePageCount() ~= 1 then
        return false, "Use uma página/coluna visível. O Focus Reader não captura gestos no modo de duas páginas."
    end
    return true
end
function Detector.bounds(document, width, height)
    local margins = document:getPageMargins()
    local left, right = margins.left or 0, margins.right or 0
    local top = (margins.top or 0) + document:getHeaderHeight()
    local bottom = height - (margins.bottom or 0)
    return {x=left,y=top,w=math.max(0,width-left-right),h=math.max(0,bottom-top)}
end
function Detector.detect(document, bounds)
    if bounds.w <= 0 or bounds.h <= 0 then return {} end
    local page = document:getCurrentPage()
    local start = document:getPageXPointer(page)
    local ending
    if page < document:getPageCount() then ending = document:getPageXPointer(page+1) end
    if not start or start == "" or not ending or ending == "" then
        -- Last page (or no usable page bookmark): ask the real selection engine
        -- for its range, explicitly without drawing a selection.
        local range = document:getTextFromPositions(
            {x=bounds.x,y=bounds.y},
            {x=bounds.x+bounds.w-1,y=bounds.y+bounds.h-1}, true)
        if not range or not range.text or not range.text:find("%S") then return {} end
        start = start and start ~= "" and start or range.pos0
        ending = range.pos1
    end
    if not start or not ending then return {} end
    local boxes = document:getScreenBoxesFromPositions(start, ending, true)
    if boxes and #boxes > 2048 then error("Geometria excessivamente complexa nesta página") end
    return Detector.normalize(boxes, bounds)
end
return Detector
