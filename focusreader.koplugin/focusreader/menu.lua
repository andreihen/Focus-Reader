local UIManager = require("ui/uimanager")
local SpinWidget = require("ui/widget/spinwidget")
local Settings = require("focusreader/settings")
local _ = require("gettext")
local Menu = {}
local function choices(plugin,key,options)
    local result={}
    for _, option in ipairs(options) do
        local value,label=option[1],option[2]
        result[#result+1]={text=label,checked_func=function() return plugin.settings[key]==value end,
            callback=function() plugin:configure(key,value) end}
    end
    return result
end
local function number(plugin,key,title,min,max,unit,enabled)
    return {text_func=function() return title..": "..plugin.settings[key]..(unit or "") end,
        enabled_func=enabled,
        callback=function()
            UIManager:show(SpinWidget:new{
                title_text=title,value=plugin.settings[key],value_min=min,value_max=max,value_step=1,
                default_value=Settings.defaults[key],unit=unit,
                callback=function(spin) plugin:configure(key,spin.value) end,
            })
        end}
end
function Menu.add(plugin,items)
    local function band() return plugin.settings.style=="soft" or plugin.settings.style=="strong" end
    items.focusreader={text=_("Focus Reader"),sub_item_table={
        {text=_("Ativar"),checked_func=function() return plugin.settings.enabled end,
            callback=function() plugin:onFocusReaderToggle() end},
        {text=_("Mostrar régua"),checked_func=function() return plugin.settings.visible end,
            callback=function() plugin:configure("visible",not plugin.settings.visible) end},
        {text=_("Suspender captura de gestos"),checked_func=function() return plugin.paused end,
            callback=function() plugin:onFocusReaderPause() end,separator=true},
        {text=_("Aparência"),sub_item_table=choices(plugin,"style",{
            {"soft",_("Cinza suave")},{"strong",_("Cinza forte")},{"outline",_("Contorno")},
            {"side",_("Marcador lateral")},{"underline",_("Sublinhado")}})},
        {text=_("Quantidade de linhas"),sub_item_table=choices(plugin,"lines",{
            {1,"1"},{2,"2"},{3,"3"},{4,"4"},{5,"5"}})},
        {text=_("Avanço por comando"),sub_item_table=choices(plugin,"step",{{1,"1"},{2,"2"},{3,"3"}})},
        {text=_("Navegação"),sub_item_table=choices(plugin,"mode",{
            {"tap",_("Toque")},{"drag",_("Arraste")},{"combined",_("Combinado")}})},
        {text=_("Personalização"),sub_item_table={
            number(plugin,"intensity",_("Intensidade do cinza suave"),5,35,"%",band),
            number(plugin,"thickness",_("Espessura de contorno, marcador e sublinhado"),1,6,nil,function() return not band() end),
            number(plugin,"horizontal_padding",_("Margem horizontal adicional"),0,24),
            number(plugin,"vertical_padding",_("Margem vertical adicional"),0,12),
            number(plugin,"tap_width",_("Largura de cada zona lateral"),25,50,"%"),
            {text=_("Inverter avanço e retrocesso"),checked_func=function() return plugin.settings.reverse end,
                callback=function() plugin:configure("reverse",not plugin.settings.reverse) end},
            {text=_("Atualização durante arraste"),sub_item_table=choices(plugin,"drag_refresh",{
                {"line",_("Ao cruzar linhas (eventos agrupados)")},{"release",_("Somente ao soltar (menor número de atualizações)")}})},
        }},
        {text=_("Alternar aparência agora"),callback=function() plugin:onFocusReaderStyle() end},
        {text=_("Disponibilidade e compatibilidade"),callback=function() plugin:showStatus() end},
        {text=_("Restaurar padrões"),callback=function()
            plugin.settings=Settings.normalize({})
            plugin.paused=false
            plugin:configure("enabled",false)
        end},
    }}
end
return Menu
