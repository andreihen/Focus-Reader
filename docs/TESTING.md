# Relatório de testes e validação no dispositivo

Execução no ambiente de desenvolvimento em **15/10/2026**. Runtime oficial
KOReader **v2026.07.1**, Linux x86_64, LuaJIT, framebuffer dummy,
crengine/Blitbuffer/UIManager reais. Fixture EPUB própria e determinística.
Nenhum Kindle foi conectado. Não há testes manuais realizados no hardware.
O usuário confirmou **Paperwhite Signature Edition de 12ª geração com KOReader
2026.07.1**. A execução inicial em v2026.07 também passou; os resultados abaixo
foram revalidados no runtime Linux oficial v2026.07.1. A versão do motor coincide
com a informada, mas a plataforma de execução continua sendo Linux desktop.

## Resultado automatizado

- **15 testes unitários aprovados, 0 falhas.** Defaults e limites, caixas fora de
  ordem, fragmentos duplicados, recuo após frase curta, caixas inválidas/recortadas,
  recusa de capitular ambígua, alturas variáveis, passo independente, limites de
  página, páginas curtas/vazias, snap, retângulos e pintura sem preenchimento opaco.
- **22 testes de integração aprovados, 0 falhas.** Carregamento pelo PluginLoader
  real, menu e SpinWidget nativos, 12 linhas esperadas da página inicial, gestos
  pela ReaderUI, passos/direção, drag e swipe, estilos, navegação em ambas as direções,
  quatro páginas de leitura consecutivas, alterações de layout, rotação, seleção,
  diálogos, refresh, persistência e abertura sem o plugin.
- Os modos econômicos de arraste são exercitados; 200 eventos sem trocar de linha
  não geraram repintura da régua. Não significa que nenhum outro componente do
  KOReader possa repintar.
- Desativação restaurou a página original **pixel a pixel** no Blitbuffer. Faixa
  cinza alterou fundo dentro da régua e preservou os pixels de texto preto.
- Movimento restaurou o conteúdo fora da nova régua; o pedido de refresh foi `ui`
  com a união das áreas antiga/nova, menor que a tela inteira.
- Rotação real do framebuffer: 600×800 → 800×600 → 600×800, com reconstrução de
  geometria e redimensionamento das zonas.
- 1.000 movimentos alternados não acumularam zonas nem posições. O crescimento
  observado de memória Lua retida em uma execução foi aproximadamente **2,6 KiB**,
  após coleta; varia com JIT/cache. O teste usa limite de regressão de 256 KiB, não
  uma meta de consumo no dispositivo. Não substitui uso prolongado físico.
- Nenhuma aprovação depende de uma suíte com zero testes. Nenhum teste foi marcado
  como skipped, xfail ou desabilitado. Hardware é uma fase manual pendente.
- Instalação limpa do runtime em outro diretório, com novo download HTTPS e checksum,
  seguida de ambas as suítes: aprovada. Reexecução do setup no ambiente preparado:
  aprovada. O código extraído do ZIP também passou pelos 22 testes de integração.

As falhas iniciais foram investigadas: um toque de teste caiu sobre um link real
(prioridade nativa correta), um swipe rápido na régua superior foi capturado pelo
menu (corrigido com override temporário condicionado à régua), e o teste de menu
usava um índice incorreto (corrigido). As suítes finais incluem esses caminhos.

## Reprodução

Na raiz do checkout:

```sh
make setup
make test
make package
```

`make setup` é idempotente e verifica o SHA-256 do arquivo oficial. O runtime e
bibliotecas ficam fora do checkout. Os testes de integração criam um diretório
`KO_HOME` temporário e uma cópia da fixture, removidos ao terminar, sem tocar em
livros ou configurações reais. A fixture pode ser gerada separadamente:

```sh
python3 tests/make_fixture.py tests/output
```

Logs finais e imagens dos cinco estilos são gerados em `tests/output/` (ignorado
pelo Git). O ZIP só inclui os arquivos do plugin e documentação, sem runtime,
configurações de teste ou logs. `make package` verifica bytecode LuaJIT quando o
runtime está disponível, testa integridade do ZIP e gera SHA-256 e manifesto.

## Matriz de aceitação

A coluna cloud descreve o que foi efetivamente exercitado. Todas as linhas ainda
precisam de confirmação no Kindle real, incluindo as aprovadas no runtime desktop.

| ID | Comportamento | Evidência cloud | Kindle físico |
|---|---|---|---|
| T01 | Carregar KOReader/plugin | PluginLoader descobre e instancia; ReaderUI abre EPUB | Pendente |
| T02 | Ativar régua | Região real, pixels de fundo alterados | Pendente |
| T03 | Desativar | Restauro pixel a pixel e mesma página | Pendente |
| T04 | Avançar | Toque real ReaderUI, passo 1 e 2 independente de altura | Pendente |
| T05 | Retroceder | Índice anterior, inversão e limite inicial | Pendente |
| T06 | Arrastar | Pan, liberação e swipe rápido com ajuste | Pendente |
| T07 | Alterar altura | Configurações de 1 a 5 e cobertura real do bloco | Pendente |
| T08 | Aparência | Cinco estilos pintados; SpinWidget aplica ajuste | Pendente |
| T09 | Final da página | Virada nativa única, trava até rebuild | Pendente |
| T10 | Início da página | Volta nativa ao último bloco anterior | Pendente |
| T11 | Fonte | Evento nativo altera fonte e recompõe caixas | Pendente |
| T12 | Margens | Evento nativo altera margens; espaçamento também exercitado | Pendente |
| T13 | Dicionário | Pressão longa seleciona palavra e suspende plugin; consulta de verbete não executada | Pendente, incluindo consulta real |
| T14 | Menus | Diálogo nativo acima do leitor bloqueia comandos; prioridade das zonas verificada | Pendente, incluindo menus completos do usuário |
| T15 | Reabrir | Preferências em arquivo e mesma âncora/linha após nova ReaderUI | Pendente |
| T16 | Remover | Fecha sem zonas próprias e reabre com carregador sem plugin; navegação normal | Pendente, incluindo remoção por USB |
| T17 | Uso prolongado | Regressão de 1000 movimentos e 200 eventos redundantes | Pendente em sessão longa, bateria e RAM nativa |
| T18 | Título/parágrafo curto | 12 linhas reais esperadas, recuo maior que fim da linha anterior | Pendente em livros variados |

Outros checks: página final com uma linha, fim do livro sem loop, capítulo vazio,
duas páginas e scroll sem captura, seleção ativa sem captura, invisibilidade e
suspensão, novos limites e regiões após rotação, várias páginas consecutivas.

## Roteiro manual no Paperwhite

1. Modelo/versão já informados: Paperwhite Signature Edition, 12ª geração,
   KOReader 2026.07.1. Complete o registro com firmware completo, layout/DPI,
   plugins de gestos habilitados, modo diurno/noturno e política de refresh.
2. Faça backup; instale a pasta sem substituir componentes do KOReader. Execute T01–T03.
3. Use a fixture em `tests/output/focus-reader.epub` e um EPUB de leitura habitual.
   Execute T04–T10 e T18, com passos 1/2/3, alturas 1–5, capítulos e final do livro.
   Compare a sequência de cada linha, incluindo páginas com menos de cinco linhas.
4. Execute T11–T12; altere orientação, tamanho, margens e espaçamento. Nunca deve
   permanecer geometria da página anterior. Se o plugin se suspender, consulte o estado.
5. Execute T13–T14: pressão longa, consulta real no dicionário já instalado, fechar
   verbete, seleção/destaque, menu superior/inferior, links e gestos personalizados.
   Use Suspender captura de gestos para conferir retorno integral aos comandos nativos.
6. Execute T15–T16. Não remova `.sdr`; confirme leitura normal após desativação e
   remoção da pasta com o aplicativo fechado.
7. Para T17, faça uma sessão longa (por exemplo, 30 minutos) e registre crashes,
   crescimento de memória, quantidade de flashes e necessidade de refresh manual.
   Esse tempo é uma proposta de procedimento, não um ensaio já realizado.

## Comparação simples de desempenho e e-ink

Mesmo EPUB, página, fonte, brilho, bateria, orientação e configuração de refresh.
Realize séries de 20 movimentos em: leitura normal, régua ao cruzar linhas, régua
somente ao soltar. Repita os cinco estilos se observar diferença relevante.

| Condição | Tempo toque → imagem estável (vídeo, se disponível) | Flashes completos | Ghosting observado | Refresh manual necessário | Observações |
|---|---|---|---|---|---|
| Navegação normal | preencher | preencher | preencher | preencher | preencher |
| Régua: cruzar linhas | preencher | preencher | preencher | preencher | preencher |
| Régua: só ao soltar | preencher | preencher | preencher | preencher | preencher |

Compare mediana/variação, sem concluir a partir de um único toque. A virada de página
normal redesenha mais conteúdo, portanto compare também custo por página lida e
não apenas por comando. Uma amostra de bateria exige sessões suficientemente longas
e condições iguais; não se estima consumo elétrico a partir dos testes Linux.
Use o comando de refresh manual já configurado no KOReader quando precisar de limpeza.
Não habilite logs detalhados durante medições de latência sem registrar esse custo.
