# Melhorias futuras

1. Executar T01–T18 fisicamente no Paperwhite Signature Edition de 12ª geração
   com KOReader 2026.07.1 já informado e ajustar o agrupamento/intervalo de arraste
   com medições de ghosting.
2. Cobrir mais EPUBs, notas de rodapé, capitulares, imagens flutuantes, RTL/BiDi e
   tabelas antes de ampliar a promessa de precisão para layouts complexos.
3. Testar versões adicionais do KOReader em uma matriz de runtimes fixados, para
   determinar uma versão mínima com evidência em vez de presumir compatibilidade.
4. PDF/DjVu: adaptador de `getTextBoxes` com transformações da ReaderView, OCR opcional
   explicitamente separado e identificação de sequência de colunas.
5. Duas colunas/páginas: ordenação por coluna, limites independentes e continuidade
   entre ambas; não ordenar apenas por Y na tela inteira.
6. Rolagem contínua: limites do viewport e ajuste de posição textual com caches
   invalidados por `PosUpdate`, sem temporizadores permanentes.
7. Avaliar um caminho que restaure pequenos retângulos de fundo sem repintar toda
   a ReaderView. Só adotar se medições justificarem a complexidade e o custo de RAM.
8. Traduções via gettext e catálogo do plugin (interface atual em pt-BR); opções
   numéricas podem ser estendidas atualizando os limites de validação e o menu.
9. Automação de releases/CI e publicação no GitHub após revisão do projeto. Nenhum
   push, tag, release ou alteração no Kindle foi executado nesta entrega.
