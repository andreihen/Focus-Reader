local View = {}
function View.rect(region, bounds, settings, scale)
    if not region then return nil end
    local px, py = scale(settings.horizontal_padding), scale(settings.vertical_padding)
    local x = math.max(bounds.x,region.x-px)
    local y = math.max(bounds.y,region.y-py)
    local right = math.min(bounds.x+bounds.w,region.x+region.w+px)
    local bottom = math.min(bounds.y+bounds.h,region.y+region.h+py)
    return {x=math.floor(x),y=math.floor(y),w=math.max(0,math.ceil(right)-math.floor(x)),
        h=math.max(0,math.ceil(bottom)-math.floor(y))}
end
function View.union(a,b)
    if not a then return b end
    if not b then return a end
    local x,y = math.min(a.x,b.x),math.min(a.y,b.y)
    return {x=x,y=y,w=math.max(a.x+a.w,b.x+b.w)-x,h=math.max(a.y+a.h,b.y+b.h)-y}
end
function View.paint(bb, rect, settings, scale, offset_x, offset_y)
    if not rect or rect.w <= 0 or rect.h <= 0 then return end
    local x,y,w,h = rect.x+(offset_x or 0),rect.y+(offset_y or 0),rect.w,rect.h
    local thickness = math.min(scale(settings.thickness),math.floor(w/2),math.floor(h/2))
    if thickness < 1 then return end
    local style = settings.style
    local amount = (settings.intensity + (style == "strong" and 18 or 0))/100
    -- Multiplication by black opacity preserves black glyphs; opaque paintRect
    -- over the document would erase the words. It also works in night mode.
    if style == "soft" or style == "strong" then
        bb:darkenRect(x,y,w,h,amount)
    elseif style == "underline" then
        bb:darkenRect(x,y+h-thickness,w,thickness,0.65)
    elseif style == "side" then
        bb:darkenRect(x,y,thickness,h,0.65)
    elseif style == "outline" then
        bb:darkenRect(x,y,w,thickness,0.65)
        bb:darkenRect(x,y+h-thickness,w,thickness,0.65)
        bb:darkenRect(x,y+thickness,thickness,h-2*thickness,0.65)
        bb:darkenRect(x+w-thickness,y+thickness,thickness,h-2*thickness,0.65)
    end
end
return View
