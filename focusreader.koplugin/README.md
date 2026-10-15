# Focus Reader 0.1.0 — instalação e uso

Régua de linhas reais para KOReader. Versão inicial validada no runtime Linux
oficial v2026.07.1. Dispositivo-alvo: Kindle Paperwhite Signature Edition de 12ª
geração com KOReader 2026.07.1, informado pelo usuário. O teste físico ainda está pendente.

Com o KOReader fechado, copie esta pasta inteira para `plugins/` da instalação
existente. O caminho comum no Kindle é `/mnt/us/koreader/plugins/`, mas confirme a
pasta que contém `reader.lua`, `frontend/` e `plugins/`; não crie outra instalação.
Faça backup das configurações antes do primeiro teste. Reabra o KOReader e habilite
o plugin no gerenciador de plugins se necessário. Abra um EPUB com uma página
visível em modo paginado e use menu superior → ferramentas/mais ferramentas →
**Focus Reader → Ativar**. A posição do menu pode variar por versão.

Padrão: 2 linhas, passo de 1 linha, modo combinado. Toque à direita avança, à
esquerda volta. Arraste verticalmente a partir da régua para reposicionar. No menu,
escolha 1–5 linhas, passo de 1–3, toque/arraste/combinado, um de cinco estilos,
intensidade, espessura, margens, largura das zonas e inversão da direção. A régua
não muda o texto, o arquivo do livro, fontes ou margens do documento.

Menus e seleção por pressão longa continuam disponíveis. Links e destaques têm
prioridade sobre os toques. **Suspender captura de gestos** mantém a régua e
restaura os comandos nativos. **Mostrar régua** só oculta o desenho; desative ou
suspenda para devolver também os toques. No arraste, há atualização ao cruzar linhas
com eventos agrupados ou apenas ao soltar. Uma pressão longa inicia a seleção
nativa; comece a mover antes de manter o dedo parado.

Ativação, desativação e ajustes durante a leitura não exigem reinício nem KUAL.
As preferências ficam em `settings/focusreader.lua`; a âncora por livro usa apenas
a chave `focusreader` no estado gerenciado pelo KOReader. Páginas vazias, formatos
sem suporte, duas páginas e rolagem contínua devolvem a navegação ao leitor. Layouts
com capitulares sobrepostas podem ser recusados. Tabelas e colunas internas não
têm ordem garantida nesta versão.

Para remover ou atualizar, feche o KOReader e remova/substitua somente esta pasta.
Não remova livros, pastas `.sdr`, configurações do leitor nem arquivos do sistema.
A exclusão opcional de `settings/focusreader.lua` limpa as preferências globais do
plugin. Se o aplicativo falhar ao carregar, remova a pasta por USB e consulte
`crash.log`. Não é necessário alterar firmware ou executar jailbreak.

No ZIP, `MANUAL.md` e `docs/` contêm instruções completas, pesquisa, compatibilidade
e roteiro de aceitação T01–T18. No repositório, consulte o README na raiz.
Licença MIT; créditos e avisos em `THIRD_PARTY.md`.
