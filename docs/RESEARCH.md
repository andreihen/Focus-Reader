# Pesquisa técnica e arquitetura

## Fontes examinadas

Pesquisa em 15/10/2026. Dispositivo-alvo posteriormente confirmado pelo usuário:
Kindle Paperwhite Signature Edition de 12ª geração, KOReader 2026.07.1.

| Fonte | Revisão examinada |
|---|---|
| [Reading Ruler](https://github.com/Syakhisk/readingruler.koplugin/tree/bb586fcd6ad4ef80ae7b08a177d30b7100a6d673) | `bb586fcd6ad4ef80ae7b08a177d30b7100a6d673`, MIT |
| [KOReader v2026.07.1](https://github.com/koreader/koreader/tree/v2026.07.1) | `9192014d8bd82a91dc1012473be0f238dedfdb54`, AGPL-3.0; mesmo commit do tag v2026.07.2 examinado inicialmente |
| [koreader-base](https://github.com/koreader/koreader-base/tree/6e4bc81af4e04f78d81677a323a780a71b29702a) | submódulo da versão acima |
| [crengine](https://github.com/koreader/crengine/tree/b32a88ffbbf505cf2ea5208c1a49002d70d3609f) | submódulo da base acima |
| [Documentação KOReader](https://koreader.rocks/doc/) | documentação geral; decisões confirmadas no código e runtime |

O runtime binário oficial usado na integração e fixado no ambiente agora é
**v2026.07.1**, correspondendo à versão informada. A primeira etapa usou v2026.07;
as suítes foram reexecutadas com o binário exato da nova referência. Não se afirma
que um Kindle físico foi testado. A ausência de assets no tag v2026.07.2 não se
aplica ao v2026.07.1: este oferece o runtime Linux utilizado.

No código `frontend/device/kindle/device.lua` dessa revisão, o modelo interno
`KindlePaperWhite6` possui suporte a toque e framebuffer MTK. O plugin continua
obtendo dimensões, escala, gestos e refresh pelas APIs do KOReader, sem codificar
dimensões/DPI do aparelho ou acessar diretamente seus drivers. A revisão corrente
`892034c96ef6c4f8606809133d16bb604f8853c1` foi examinada inicialmente, antes de fixar a referência.

## Como a referência funciona

`main.lua` inicializa `lib/settings`, `lib/ruler`, `lib/ui/ruler_ui` e o menu.
Registra view module por `ReaderView:registerViewModule`, ações no Dispatcher e
listeners de tap/swipe via `ges_events`. `lib/ruler.lua` obtém o intervalo da tela
com `getTextFromPositions(..., true)` e usa `sboxes`, percorrendo os fundos das
caixas para escolher a linha vizinha. A interface usa `LineWidget` dentro de
`MovableContainer`; `UIManager:setDirty("all", callback)` solicita refresh da união
antiga/nova. `GotoViewRel` solicita uma virada nativa quando faltam vizinhos.
As preferências usam `LuaSettings` em arquivo próprio; `PageUpdate` reposiciona.
Não há dependência de alteração no núcleo.

Limitações declaradas: duas colunas, saltos após final curto de parágrafo e ausência
de rolagem contínua. O cache consultado é indexado apenas por página, sem considerar
fonte, margem ou orientação; isso pode manter coordenadas antigas na mesma página.
A referência também guarda dimensões de tela na criação do objeto.

A causa histórica exata dos saltos relatados não pode ser demonstrada sem o livro
e o crengine da versão do autor. O motor atual contém, em `ldomXRange::getSegmentRects`
(`crengine/src/lvtinydom.cpp`), um comentário e uma correção específicos: inferir
mudança de linha pelo retorno do X pode fundir linhas quando o recuo seguinte é
maior que o fim da linha anterior. A versão inspecionada compara top/bottom em vez
disso. No binding `cre.cpp`, o caminho antigo **sem** `get_segments` ainda usa
retorno de X para concatenar palavras. A referência já pede segmentos por meio do
wrapper atual, portanto não é correto atribuir seu bug atual automaticamente àquele
caminho antigo. Focus Reader exige `get_segments=true`, evita selecionar só pelas
quinas sempre que há bookmarks da página, e acrescenta uma regressão executada no
motor real para o caso de frase curta seguida de grande recuo.

## APIs confirmadas e decisões

| Necessidade | API/fonte e decisão |
|---|---|
| Carregamento | `frontend/pluginloader.lua`: diretórios `.koplugin`, `_meta.lua`, `main.lua`, `is_doc_only`; `Widget:extend` para eventos |
| Menu | `ReaderMenu:registerToMainMenu`, `addToMainMenu`; `SpinWidget` e tabelas de submenu nativas |
| Desenho | `ReaderView:registerViewModule` e `paintTo(bb,x,y)` após o conteúdo; menus/diálogos ficam acima da ReaderUI |
| Geometria EPUB | `CreDocument:getPageXPointer`, `getScreenBoxesFromPositions(pos0,pos1,true)`; último intervalo usa `getTextFromPositions(...,true)` para obter o final |
| Coordenadas | Retângulos `Geom` em coordenadas de tela; limites a partir de `getPageMargins`, `getHeaderHeight` e dimensões atuais de `Device.screen` |
| Formatos | `getTextBoxes()` é interface dos provedores PDF/DjVu com coordenadas próprias; não é tratada como equivalente ao crengine |
| Gestos | `InputContainer:registerTouchZones`/`unRegisterTouchZones` na ReaderUI, IDs próprios e `overrides` temporários; sem editar zonas/configurações nativas |
| Movimento | Índice em linhas ordenadas por Y dentro de uma página/coluna; caixa une fragmentos com top/bottom quase iguais (tolerância de arredondamento de 1 pixel) |
| Paginação | `Event:new("GotoViewRel", ±1)` deixa capítulos, fluxos e limites com o navegador nativo; trava de pedido pendente e um único rebuild diferido |
| Layout | `PageUpdate`, `DocumentRerendered`, `SetDimensions`, `ChangeViewMode`, `PosUpdate`, `resetLayout`; invalida tudo e usa `UIManager:nextTick` após os handlers |
| Pintura cinza | `Blitbuffer:darkenRect` multiplica o fundo; preto continua preto. Uma faixa opaca desenhada sobre texto apagaria os glifos |
| Refresh | `UIManager:setDirty(reader_dialog,"ui",union_rect)`; repinta a camada de livro e atualiza a união no display; não altera taxa global de refresh |
| Estado | `LuaSettings` em `settings/focusreader.lua`; `doc_settings:saveSetting("focusreader",...)`, `ReadSettings`/`SaveSettings` |
| Restauração | `getWordFromPosition(...,true)` fornece XPointer; `getPageFromXPointer` e `getScreenPositionFromXPointer` remapeiam sem navegar |
| Fechamento | `CloseDocument`: remove zonas e callbacks próprios e a entrada `view_modules.focusreader`; não modifica preferências globais de gestos |

Todos esses caminhos foram exercitados no runtime oficial pelos testes de integração,
exceto compatibilidade em hardware físico, formato PDF e falha de energia.

## Desenho e e-ink

A régua faz parte da camada de pintura do livro. Cada repintura restaura primeiro o
conteúdo subjacente usando o fluxo normal da ReaderView, e só então aplica a régua.
Assim não acumula cinza ao repintar nem precisa capturar páginas inteiras em um
buffer extra. A solicitação ao display usa apenas a união das duas regiões.
Isso **não** significa que a CPU renderiza apenas esses pixels: a ReaderView pode
repintar o conteúdo inteiro a partir de seus caches. Esse custo precisa ser medido
no Kindle. O plugin não força full refresh a cada comando e não modifica a política
de página do KOReader. Atualizações `ui` não têm necessariamente a mesma contagem
de limpeza das atualizações `partial`; ghosting deve ser verificado fisicamente.

Comparação das estratégias de arraste:

- Atualizar cada pixel: muitos pedidos, redundância e maior risco de ghosting; não implementado.
- Cruzar linhas: ignora eventos dentro da mesma linha e agrupa bursts com intervalo
  mínimo de 120 ms. Existe no máximo um callback transitório; a liberação confirma
  o destino imediatamente. É o padrão; 120 ms não é uma promessa de latência.
- Somente ao soltar: nenhum redesenho intermediário, menor número de pedidos e
  menos feedback durante o movimento. Opção disponível para comparação no aparelho.

Não há thread, polling, animação, timer permanente ou escrita em disco por movimento.
A regressão de 1000 movimentos mede memória Lua retida e estabilidade do registro
de zonas; não mede bateria, RAM nativa total nem desgaste/refresh físico.

## Limites deliberados

Não há inferência de altura por tamanho de fonte. Capas/imagens sem linhas não
causam viradas automáticas em cascata. Caixas sobrepostas ambíguas (por exemplo,
capitulares de várias linhas) suspendem a régua em vez de inventar uma sequência.
Tabelas e colunas internas ao conteúdo não têm sequência de leitura garantida.
A detecção automática de duas páginas usa `getVisiblePageCount`; não é um detector
universal de colunas CSS ou tabelas. Não existe alteração de arquivos do núcleo.
