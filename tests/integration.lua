-- Runs against the unmodified official KOReader Linux release and native crengine.
local root,run_dir=assert(arg[1]),assert(arg[2])
local plugin_parent=arg[3] or root
require("setupkoenv")
package.path=plugin_parent.."/focusreader.koplugin/?.lua;"..root.."/?.lua;"..package.path
local H=require("tests/harness")
G_defaults=require("luadefaults"):open()
G_reader_settings=require("luasettings"):open(run_dir.."/settings.tests.lua")
G_reader_settings:saveSetting("document_metadata_folder","dir")
G_reader_settings:saveSetting("extra_plugin_paths",{plugin_parent})
einkfb=require("ffi/framebuffer")
einkfb.dummy=true
local Device=require("device")
Device.input.dummy=true
require("document/canvascontext"):init(Device)
local UIManager=require("ui/uimanager")
local Geom=require("ui/geometry")
local BB=require("ffi/blitbuffer")
local Event=require("ui/event")
local PluginLoader=require("pluginloader")
PluginLoader.enabled_plugins={}
PluginLoader.disabled_plugins={}
PluginLoader.loaded_plugins={}
local found
for _,plugin in ipairs(PluginLoader:_discover()) do
    if plugin.name=="focusreader" then found=plugin end
end
assert(found,"KOReader did not discover focusreader.koplugin")
PluginLoader:_load({found})
assert(#PluginLoader.enabled_plugins==1,"plugin load failed")
local ReaderUI=require("apps/reader/readerui")
local Registry=require("document/documentregistry")
local book=run_dir.."/focus-reader.epub"
local ui=ReaderUI:new{dimen=Device.screen:getSize(),document=Registry:openDocument(book)}
UIManager:show(ui)
local p=assert(ui.focusreader,"plugin instance missing")
local function pump()
    for _=1,3 do
        UIManager:shiftScheduledTasksBy(-1)
        UIManager:_checkTasks()
        UIManager:_repaint()
    end
end
local function closeDialogs()
    while UIManager:getTopmostVisibleWidget() and UIManager:getTopmostVisibleWidget()~=ui do
        UIManager:close(UIManager:getTopmostVisibleWidget())
    end
end
local function reset()
    closeDialogs()
    p.paused=false
    ui.rolling:onGotoPage(1)
    p:configure("enabled",true)
    for k,v in pairs({visible=true,lines=2,step=1,mode="combined",reverse=false,drag_refresh="line",style="soft"}) do
        p:configure(k,v)
    end
    pump(); closeDialogs(); p:setIndex(1); pump()
end
local function gesture(kind,x,y,extra)
    local g={ges=kind,pos=Geom:new{x=x,y=y,w=0,h=0}}
    for k,v in pairs(extra or {}) do g[k]=v end
    return ui:onGesture(g)
end
local function paint()
    local bb=BB.new(Device.screen:getWidth(),Device.screen:getHeight(),BB.TYPE_BB8)
    ui.view:paintTo(bb,0,0)
    return bb
end
pump()
H.test("T01 descoberta e inicialização pelo PluginLoader real",function()
    H.eq(p.settings.enabled,false)
    assert(ui.view.view_modules.focusreader==p)
    local items={}; p:addToMainMenu(items); assert(items.focusreader.sub_item_table)
end)
H.test("T02 geometria real: 12 linhas incluindo título, frase curta e recuo",function()
    reset(); assert(p.valid,p.reason); H.eq(#p.nav.lines,12)
    H.eq(p.nav.index,1); assert(p.rect.h>p.nav.lines[1].h)
    for i=2,#p.nav.lines do assert(p.nav.lines[i].y>p.nav.lines[i-1].y) end
    H.eq(ui.document:getPageFromXPointer(ui.document:getPageXPointer(2)),2)
end)
H.test("T03 desativar restaura todos os pixels e preserva o livro",function()
    reset(); p:configure("enabled",false); pump()
    local plain=paint()
    local page=ui.document:getCurrentPage()
    p:configure("enabled",true); pump(); local marked=paint()
    local changed,black=0,0
    for y=0,plain:getHeight()-1 do for x=0,plain:getWidth()-1 do
        local a,b=plain:getPixel(x,y):getColor8().a,marked:getPixel(x,y):getColor8().a
        if a~=b then
            changed=changed+1
            assert(x>=p.rect.x and x<p.rect.x+p.rect.w and y>=p.rect.y and y<p.rect.y+p.rect.h,"pixel outside ruler changed")
        end
        if a==0 then H.eq(b,0); black=black+1 end
    end end
    assert(changed>0 and black>0,"highlight must change background and preserve black text")
    marked:writePNG(root.."/tests/output/soft.png")
    p:configure("enabled",false); pump(); local restored=paint()
    for y=0,plain:getHeight()-1 do for x=0,plain:getWidth()-1 do
        H.eq(plain:getPixel(x,y):getColor8().a,restored:getPixel(x,y):getColor8().a)
    end end
    H.eq(ui.document:getCurrentPage(),page)
    plain:free(); marked:free(); restored:free()
end)
H.test("T04/T05 toques nativos avançam e retrocedem linhas sem virar a página",function()
    reset()
    gesture("tap",550,300); H.eq(p.nav.index,2); H.eq(ui.document:getCurrentPage(),1)
    gesture("tap",50,300); H.eq(p.nav.index,1)
    p:configure("lines",3); p:configure("step",2)
    gesture("tap",550,300); H.eq(p.nav.index,3)
    p:configure("reverse",true); gesture("tap",550,300); H.eq(p.nav.index,1)
end)
H.test("prioridades de links, destaques e menus precedem a captura do plugin",function()
    reset()
    local order={}
    for i,z in ipairs(ui._ordered_touch_zones) do order[z.def.id]=i end
    for _,id in ipairs({"tap_link","readerhighlight_tap","readermenu_tap","readerconfigmenu_tap"}) do
        assert(order[id]<order.focusreader_tap,id.." must precede Focus Reader")
    end
    assert(order.focusreader_tap<order.tap_forward)
    assert(not p:tap({pos={x=550,y=10}})); assert(not p:tap({pos={x=300,y=400}}))
end)
H.test("T06 arraste contínuo e liberação ajustam à linha válida",function()
    reset()
    local line=p.nav.lines[1]; local start=Geom:new{x=line.x+20,y=line.y+line.h/2,w=0,h=0}
    local target=p.nav.lines[4]; local y=target.y+target.h/2
    gesture("pan",start.x,y,{start_pos=start,relative={x=0,y=y-start.y}})
    assert(p.dragging); H.eq(p.nav.index,4)
    local target2=p.nav.lines[6]
    gesture("pan_release",start.x,target2.y+target2.h/2)
    H.eq(p.nav.index,6); assert(not p.dragging)
end)
H.test("arraste rápido termina em swipe; não vira página",function()
    reset()
    local line=p.nav.lines[1]; local dest=p.nav.lines[4]
    gesture("swipe",line.x+20,line.y+line.h/2,{direction="south",end_pos={x=line.x+20,y=dest.y+dest.h/2}})
    H.eq(p.nav.index,4); H.eq(ui.document:getCurrentPage(),1)
end)
H.test("modo econômico só atualiza ao soltar; toque/arraste são independentes",function()
    reset(); p:configure("mode","drag"); p:configure("drag_refresh","release")
    assert(not ui:checkRegisterTouchZone("focusreader_tap"))
    local line=p.nav.lines[1]; local dest=p.nav.lines[3]
    local start={x=line.x+20,y=line.y+line.h/2}
    p:pan({start_pos=start,pos={x=start.x,y=dest.y+dest.h/2},relative={x=0,y=100}})
    H.eq(p.nav.index,1)
    p:release({pos={x=start.x,y=dest.y+dest.h/2}}); H.eq(p.nav.index,3)
    p:configure("mode","tap"); assert(not ui:checkRegisterTouchZone("focusreader_pan"))
end)
H.test("T07/T08 todos os números de linhas e estilos pintam no Blitbuffer real",function()
    reset()
    for n=1,5 do
        p:configure("lines",n)
        local a,b=p.nav.lines[1],p.nav.lines[n]
        assert(p.rect.h>=b.y+b.h-a.y)
    end
    for _,style in ipairs({"soft","strong","outline","side","underline"}) do
        p:configure("style",style); pump(); local bb=paint()
        bb:writePNG(root.."/tests/output/"..style..".png"); bb:free()
    end
    local items={}; p:addToMainMenu(items)
    -- Open a real native control from the personalization menu.
    items.focusreader.sub_item_table[8].sub_item_table[1].callback()
    local spin=UIManager:getTopmostVisibleWidget(); assert(spin~=ui)
    spin.value=23; spin.callback(spin); H.eq(p.settings.intensity,23)
    closeDialogs()
end)
H.test("T09/T10 uma virada por comando com layout diferido e posição nas extremidades",function()
    reset(); p:setIndex(p.nav:lastStart())
    assert(p:move(1)); assert(p.turning); assert(not p:move(1)); H.eq(ui.document:getCurrentPage(),2)
    pump(); H.eq(p.nav.index,1); assert(not p.turning)
    p:move(-1); pump(); H.eq(ui.document:getCurrentPage(),1); H.eq(p.nav.index,p.nav:lastStart())
end)
H.test("fim do livro e páginas curtas não provocam navegação em loop",function()
    reset(); ui.rolling:onGotoPage(ui.document:getPageCount()); pump(); closeDialogs()
    assert(p.valid,p.reason); assert(#p.nav.lines<2)
    local last=ui.document:getCurrentPage()
    p:move(1); pump(); closeDialogs(); H.eq(ui.document:getCurrentPage(),last); assert(not p.turning)
end)
H.test("T11/T12 fonte, margem e espaçamento invalidam e recompõem a geometria",function()
    reset(); local before=p.nav.lines
    ui:handleEvent(Event:new("SetFontSize",26)); pump(); closeDialogs(); assert(p.valid,p.reason); assert(p.nav.lines~=before)
    before=p.nav.lines
    ui:handleEvent(Event:new("SetPageMargins",{25,20,25,20})); pump(); closeDialogs()
    assert(p.valid,p.reason); assert(p.nav.lines~=before); assert(p.bounds.x>=20)
    before=p.nav.lines
    ui:handleEvent(Event:new("SetLineSpace",140)); pump(); closeDialogs(); assert(p.nav.lines~=before)
end)
H.test("T13 seleção por pressão longa mantém prioridade e suspende comandos de linha",function()
    reset(); local line=p.nav.lines[3]
    ui.highlight:onHold(nil,{pos=Geom:new{x=line.x+10,y=line.y+line.h/2,w=0,h=0}})
    assert(ui.highlight.selected_text,"native long-press must select a word")
    assert(not p:canInteract()); assert(not p:move(1))
    ui.highlight:clear(); closeDialogs(); assert(p:canInteract())
end)
H.test("T14 menu fica acima da régua e bloqueia comandos enquanto aberto",function()
    reset(); local InfoMessage=require("ui/widget/infomessage")
    local dialog=InfoMessage:new{text="Teste de sobreposição"}
    UIManager:show(dialog); pump()
    assert(not p:move(1)); H.eq(p.nav.index,1)
    UIManager:close(dialog); pump(); assert(p:move(1)); H.eq(p.nav.index,2)
end)
H.test("movimentação restaura a região anterior e solicita apenas união parcial",function()
    reset(); p:configure("enabled",false); pump()
    local plain=paint()
    p:configure("enabled",true); pump()
    local requests={}
    local original=UIManager.setDirty
    UIManager.setDirty=function(manager,widget,mode,region,...)
        if widget==ui and mode=="ui" then requests[#requests+1]=region end
        return original(manager,widget,mode,region,...)
    end
    local old=p.rect
    p:setIndex(4); pump()
    UIManager.setDirty=original
    assert(#requests>=1)
    local r=requests[1]; assert(r.y<=old.y and r.y+r.h>=p.rect.y+p.rect.h)
    assert(r.h<Device.screen:getHeight(),"ruler move must not request full screen refresh")
    local moved=paint()
    for y=0,plain:getHeight()-1 do for x=0,plain:getWidth()-1 do
        if x<p.rect.x or x>=p.rect.x+p.rect.w or y<p.rect.y or y>=p.rect.y+p.rect.h then
            H.eq(plain:getPixel(x,y):getColor8().a,moved:getPixel(x,y):getColor8().a)
        end
    end end
    plain:free(); moved:free()
end)
H.test("mudança de dimensões gera geometria nova e zonas com tamanho atualizado",function()
    reset(); local before=p.nav.lines
    -- Actual native rotation, not just a mocked screen-size change.
    ui.view:onSetRotationMode(1); pump(); closeDialogs()
    assert(p.valid,p.reason); assert(p.nav.lines~=before)
    H.eq(Device.screen:getWidth(),800); H.eq(Device.screen:getHeight(),600)
    local zone=ui._zones.focusreader_tap.gs_range.range
    H.eq(zone.w,800); H.eq(zone.h,600)
    ui.view:onSetRotationMode(0); pump(); closeDialogs()
    H.eq(Device.screen:getWidth(),600); assert(p.valid,p.reason)
end)
H.test("leitura de várias páginas mantém todos os blocos e uma virada por extremidade",function()
    reset(); local commands=0
    for page=1,4 do
        H.eq(ui.document:getCurrentPage(),page); assert(p.valid,p.reason)
        local starts=p.nav:lastStart()
        for index=2,starts do
            assert(p:move(1)); H.eq(p.nav.index,index); H.eq(ui.document:getCurrentPage(),page)
            commands=commands+1
        end
        assert(p:move(1)); pump(); closeDialogs()
        H.eq(ui.document:getCurrentPage(),page+1); H.eq(p.nav.index,1)
    end
    assert(commands>30)
end)
H.test("T17 1000 movimentos não acumulam zonas, callbacks ou geometria antiga",function()
    reset(); collectgarbage("collect"); local before=collectgarbage("count")
    local initial_zones=#ui._ordered_touch_zones
    for _=1,500 do p:move(1); p:move(-1) end
    collectgarbage("collect"); local after=collectgarbage("count")
    H.eq(#ui._ordered_touch_zones,initial_zones)
    assert(after-before<256,"retained Lua memory unexpectedly grew")
    H.eq(p.nav.index,1)
    print(string.format("MEASURE Lua retained delta for 1000 moves: %.1f KiB",after-before))
    -- Same-line pan bursts must not repaint or leave a timer per input event.
    local old_repaint=p.repaint; local paints=0
    p.repaint=function(self) paints=paints+1; return old_repaint(self) end
    local line=p.nav.lines[1]; local start={x=line.x+10,y=line.y+line.h/2}
    for _=1,200 do p:pan({start_pos=start,pos=start,relative={x=0,y=0}}) end
    H.eq(paints,0)
    p:release({pos=start}); p.repaint=old_repaint
    -- Bursts crossing multiple rows retain one trailing callback, then release
    -- applies the newest destination and removes that callback immediately.
    local time=require("ui/time")
    for index=2,5 do
        local target=p.nav.lines[index]
        p.last_drag_time=time.now()
        p:pan({start_pos=start,pos={x=start.x,y=target.y+target.h/2},relative={x=0,y=100}})
        local pending=0
        for _,task in ipairs(UIManager._task_queue) do
            if task.action==p.drag_callback then pending=pending+1 end
        end
        H.eq(pending,1)
    end
    local target=p.nav.lines[5]
    p:release({pos={x=start.x,y=target.y+target.h/2}})
    H.eq(p.nav.index,5)
    for _,task in ipairs(UIManager._task_queue) do assert(task.action~=p.drag_callback) end
end)
H.test("suspensão, invisibilidade e desativação devolvem gestos",function()
    reset(); p:onFocusReaderPause(); assert(not ui:checkRegisterTouchZone("focusreader_tap")); assert(p.rect)
    p:onFocusReaderPause(); assert(ui:checkRegisterTouchZone("focusreader_tap"))
    p:configure("visible",false); assert(not p.rect); assert(not ui:checkRegisterTouchZone("focusreader_pan"))
    p:configure("enabled",false); pump(); local page=ui.document:getCurrentPage()
    gesture("tap",550,400); H.eq(ui.document:getCurrentPage(),page+1)
end)
H.test("duas páginas, rolagem e página sem texto falham sem capturar gestos",function()
    reset(); ui.document:setVisiblePageCount(2); p:invalidate(); pump()
    assert(not p.valid); assert(not ui:checkRegisterTouchZone("focusreader_tap"))
    ui.document:setVisiblePageCount(1); ui.view.view_mode="scroll"; p:invalidate(); pump(); assert(not p.valid)
    ui.view.view_mode="page"; p:invalidate(); pump()
    -- Actual empty chapter immediately before the final one.
    ui.rolling:onGotoPage(ui.document:getPageCount()-1); pump()
    H.eq(#p.nav.lines,0); assert(not p.valid); assert(not ui:checkRegisterTouchZone("focusreader_tap"))
    assert(not p:move(1)); H.eq(ui.document:getCurrentPage(),ui.document:getPageCount()-1)
end)
H.test("T15 preferências e XPointer por documento sobrevivem a fechar/reabrir",function()
    reset(); p:setIndex(4); p:configure("style","underline"); p:configure("step",2)
    local anchor=p.anchor; assert(type(anchor)=="string")
    ui:onClose(); assert(p.closed); H.eq(ui.view.view_modules.focusreader,nil)
    ui=ReaderUI:new{dimen=Device.screen:getSize(),document=Registry:openDocument(book)}
    UIManager:show(ui); p=assert(ui.focusreader); pump(); closeDialogs()
    H.eq(p.settings.style,"underline"); H.eq(p.settings.step,2); assert(p.valid,p.reason)
    H.eq(p.anchor,anchor); H.eq(p.nav.index,4)
end)
H.test("T16 fechamento remove zonas e callbacks; KOReader abre sem o plugin",function()
    ui:onClose(); assert(p.closed); assert(not ui:checkRegisterTouchZone("focusreader_tap"))
    PluginLoader.enabled_plugins={}
    ui=ReaderUI:new{dimen=Device.screen:getSize(),document=Registry:openDocument(book)}
    UIManager:show(ui); pump(); assert(not ui.focusreader)
    local page=ui.document:getCurrentPage()
    gesture("tap",550,400); H.eq(ui.document:getCurrentPage(),page+1)
    ui:onClose()
end)
H.finish()
