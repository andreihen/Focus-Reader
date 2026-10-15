local Navigation = {}
Navigation.__index = Navigation
function Navigation.new()
    return setmetatable({lines={}, index=1, count=2}, Navigation)
end
function Navigation:lastStart()
    return math.max(1, #self.lines - self.count + 1)
end
function Navigation:setLines(lines, count, index)
    self.lines, self.count = lines, count
    self.index = math.max(1, math.min(index or 1, self:lastStart()))
end
-- Clamp at the final complete window before requesting a page turn on the NEXT command.
-- This ensures a step larger than one never skips the end of a page.
function Navigation:move(direction, step)
    if #self.lines == 0 then return "empty" end
    local boundary = direction > 0 and self:lastStart() or 1
    if self.index == boundary then return "page" end
    self.index = math.max(1, math.min(self:lastStart(), self.index + direction * step))
    return "line"
end
function Navigation:nearest(y)
    local best, distance = 1, math.huge
    for i = 1, self:lastStart() do
        local line = self.lines[i]
        local d = math.abs(line.y + line.h / 2 - y)
        if d < distance then best, distance = i, d end
    end
    return best
end
function Navigation:region()
    if #self.lines == 0 then return nil end
    local first = self.lines[self.index]
    local x0, y0, x1, y1 = first.x, first.y, first.x + first.w, first.y + first.h
    for i = self.index + 1, math.min(#self.lines, self.index + self.count - 1) do
        local b = self.lines[i]
        x0, y0 = math.min(x0,b.x), math.min(y0,b.y)
        x1, y1 = math.max(x1,b.x+b.w), math.max(y1,b.y+b.h)
    end
    return {x=x0, y=y0, w=x1-x0, h=y1-y0}
end
return Navigation
