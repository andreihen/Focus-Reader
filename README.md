# Focus Reader 0.1.0

Plugin independente de leitura guiada para KOReader: uma régua acompanha **linhas
reais do texto**, com o restante da página visível. Implementado em Lua, sem
bibliotecas externas no Kindle e sem alterações no núcleo do leitor.

**Estado:** versão inicial executada e testada no KOReader Linux oficial `v2026.07.1`.
Dispositivo-alvo informado: **Kindle Paperwhite Signature Edition, 12ª geração,
KOReader 2026.07.1**. A validação no aparelho físico ainda está pendente; os testes
Linux não medem toque, bateria ou ghosting do Paperwhite. O firmware permanece
informado apenas como 5.17.x, sem necessidade de alterá-lo para instalar o plugin.

## Funcionalidades

- Régua de 1 a 5 linhas; padrão 2. Passo independente de 1 a 3 linhas; padrão 1.
- Toque à direita avança, à esquerda retrocede. Direção e largura das zonas ajustáveis.
- Arraste vertical começando na régua, com ajuste à linha válida mais próxima.
- Modos toque, arraste e combinado (padrão), além de suspensão temporária dos gestos.
- Cinza suave, cinza forte, contorno, marcador lateral e sublinhado.
- Intensidade, espessura e margens com limites e escala de tela do próprio KOReader.
- Virada de página nativa em ambas as direções, após alcançar a última/primeira janela.
- Configurações globais e posição textual por livro em espaços de nomes próprios.
- Invalidação de geometria após fonte, margens, espaçamento, orientação e mudanças de página.
- Pedidos de refresh da união das regiões antiga e nova. Sem animação ou loop permanente.

Prioridade desta versão: **EPUB/texto ajustável, uma página/coluna, modo paginado**.
PDF, imagens sem texto, duas páginas e rolagem contínua ficam sem captura do plugin.
Layouts sobrepostos ambíguos são recusados com segurança. Veja [compatibilidade](docs/COMPATIBILITY.md).

## Instalação no Kindle

1. No KOReader, consulte **Ajuda → Sobre** e anote a versão. Faça backup da pasta
   de configuração do KOReader e dos sidecars `.sdr` dos livros que usará no teste.
   Não é preciso fazer novo jailbreak, alterar firmware ou mexer na partição do sistema.
2. Identifique a pasta **da instalação que você já usa**: ela contém `reader.lua`,
   `frontend/` e `plugins/`. No Kindle, o caminho comum é `/mnt/us/koreader/`, que
   aparece como `koreader/` na unidade USB. Esse caminho não foi verificado no seu
   aparelho; use a pasta existente, especialmente se possui mais de uma instalação.
3. Feche o KOReader, conecte por USB e extraia o ZIP. Copie apenas a pasta
   `focusreader.koplugin` para `plugins/` dessa instalação:

   ```text
   koreader/plugins/focusreader.koplugin/_meta.lua
   koreader/plugins/focusreader.koplugin/main.lua
   koreader/plugins/focusreader.koplugin/focusreader/…
   ```

   Evite uma pasta duplicada como `focusreader.koplugin/focusreader.koplugin/`.
4. Ejete o Kindle com segurança e inicie o KOReader como já faz. **Só esta instalação
   inicial exige reabrir o aplicativo**. No gerenciador de plugins, habilite Focus Reader
   se estiver desabilitado; o aplicativo pode pedir reinício para carregar plugins.
5. Abra um EPUB em modo paginado, com uma página visível. Abra o menu superior →
   ferramentas/mais ferramentas → **Focus Reader → Ativar**. A posição exata do item
   depende da organização de menus da versão instalada.

Depois de carregado, ativar/desativar, mover e personalizar não exige reinício,
KUAL nem saída do livro. Desative o Reading Ruler ou outro plugin de régua durante
a avaliação, para não disputar os mesmos gestos.

## Uso

- Toque no lado direito para avançar uma linha; toque no esquerdo para voltar.
  Por padrão, cada lado ocupa 45% da largura. Os 10% centrais e as faixas superior
  e inferior de 12% permanecem com a navegação normal. Links, destaques existentes
  e zonas nativas de menu têm prioridade sobre os toques da régua.
- Encoste na régua e mova verticalmente **antes de virar uma pressão longa**.
  Arraste também funciona sobre a régua no topo da página. Swipes horizontais
  continuam nativos. O ponto final preserva onde você pegou a régua e se ajusta
  à primeira linha do bloco mais próxima; não vira página por arraste.
- No final, o passo para no último bloco completo antes de virar no próximo toque.
  Isso impede que um passo maior pule as últimas linhas. Na página anterior, a
  régua começa no último bloco. Em páginas curtas, destaca apenas as linhas existentes.
- Em **Navegação**, selecione Toque, Arraste ou Combinado. O modo combinado é o padrão.
- **Suspender captura de gestos** mantém a régua e devolve a navegação ao leitor.
  Pressão longa e seleção nativa não são capturadas. Durante seleção ou diálogos,
  os comandos do plugin ficam suspensos automaticamente. Se outro plugin disputar
  gestos, use a suspensão ou o modo Toque/Arraste correspondente.
- Em **Personalização**, ajuste os controles nativos. O cinza forte acrescenta 18
  pontos percentuais à intensidade do suave. Intensidade vale para faixas; espessura
  vale para contorno, marcador e sublinhado. As margens são adicionais à caixa real
  do texto; não alteram margens nem fontes do livro.
- **Mostrar régua** oculta só a pintura. Os toques continuam ativos se habilitados;
  o arraste é removido enquanto a régua está invisível.
- **Atualização durante arraste** oferece cruzamento de linhas (eventos agrupados
  em intervalos de pelo menos 120 ms) ou somente ao soltar. Ao soltar, a posição
  final é aplicada imediatamente. Esse intervalo é uma escolha conservadora de
  implementação, não uma medição de latência do Paperwhite.
- **Alternar aparência agora** troca o estilo. Em ferramentas → gestos do KOReader,
  se o plugin Gestures estiver habilitado, procure ações `Focus Reader: …` para
  vincular ativação, avanço, retrocesso, aparência e suspensão a seus próprios gestos.
- Em páginas sem texto ou layout não suportado, o plugin não captura navegação.
  Use a virada normal; ele tenta detectar as linhas novamente na próxima página.
  **Disponibilidade e compatibilidade** explica o estado atual.

Preferências: arquivo próprio `settings/focusreader.lua` no diretório de dados
escolhido pelo KOReader. Posição por livro: chave `focusreader` no estado do documento,
salva pelo fluxo normal do KOReader. Não sobrescreve marcadores ou outras chaves.
A restauração usa um XPointer quando ele ainda pertence à página reaberta; se o
layout mudou e o ponto está fora dela, usa uma linha válida sem mudar a página do livro.
A suspensão é temporária e não persiste entre aberturas. Um fechamento abrupto pode
perder a última posição ainda não salva, mas os controles nativos não são alterados
em disco. **Restaurar padrões** desativa a régua e repõe suas preferências globais.

## Atualização e remoção

Com o KOReader fechado, guarde uma cópia da pasta antiga e substitua **somente**
`plugins/focusreader.koplugin`. Preserve `settings/` e os sidecars dos livros.
Para reverter, recoloque a pasta antiga. Para remover, desative no gerenciador de
plugins ou exclua apenas essa pasta e reabra o KOReader. O livro e suas configurações
continuam válidos. Remover preferências residuais é opcional: exclua somente
`settings/focusreader.lua` com o aplicativo fechado. Não remova pastas `.sdr`.

Se houver erro no carregamento, feche o leitor e remova a pasta do plugin por USB;
consulte `crash.log` na pasta de dados. Nenhum arquivo de sistema é substituído.

## Desenvolvimento e distribuição

```sh
make setup       # baixa runtime Linux oficial fixado, verifica SHA-256 e gera EPUB de teste
make test        # testes unitários e integração nativa headless
make package     # ZIP determinístico, manifesto de arquivos e SHA-256
```

O script cloud requer Linux x86_64, `curl`, `tar`/`xz`, `sha256sum`, `make` e Python 3.
O LuaJIT e as bibliotecas de teste vêm do runtime oficial; não são necessários npm,
servidor web, conta GitHub adicional ou credenciais da aplicação. Downloads usam
HTTPS e checksum fixado, sem desativar verificação. O runtime de desenvolvimento
fica fora do checkout em `/workspace/.focus-reader-tools-2026.07.1`; customize `FOCUS_TOOLS_DIR`
no script e `TOOLS_DIR` no Makefile se necessário.

O plugin instalado depende apenas do KOReader já existente. `make package` gera
`dist/focusreader-0.1.0.zip`, contendo a pasta instalável e documentação. Não publica
no GitHub nem altera a instalação do Kindle automaticamente.

```text
focusreader.koplugin/
├── _meta.lua              identificação para o carregador
├── main.lua               ciclo de vida, eventos, gestos e persistência
├── focusreader/
│   ├── line_detector.lua  caixas reais e validação de compatibilidade
│   ├── navigation.lua     blocos, passos e ajuste à linha
│   ├── focusview.lua      desenho e união das áreas de refresh
│   ├── settings.lua       padrões e validação de valores
│   └── menu.lua           menu e controles nativos
├── README.md              instalação e uso
├── LICENSE
└── THIRD_PARTY.md
```

[Pesquisa e arquitetura](docs/RESEARCH.md) · [Compatibilidade](docs/COMPATIBILITY.md) ·
[Relatório de testes e roteiro no Kindle](docs/TESTING.md) · [Próximas melhorias](docs/ROADMAP.md).

Licença MIT. Créditos ao Reading Ruler de Syakhisk Al-Azmi e ao KOReader;
consulte [avisos de terceiros](focusreader.koplugin/THIRD_PARTY.md).
