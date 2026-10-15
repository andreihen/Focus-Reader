# Compatibilidade

| Situação | Comportamento nesta versão |
|---|---|
| KOReader Linux x86_64 oficial v2026.07.1 | Integração automatizada executada com LuaJIT, crengine, UIManager e Blitbuffer reais; versão fixada no ambiente |
| KOReader Linux x86_64 oficial v2026.07 | Também validado na primeira etapa; substituído pela versão exata informada |
| Código KOReader v2026.07.1 / v2026.07.2 | Tags apontam ao mesmo commit `9192014d8bd82a91dc1012473be0f238dedfdb54`; APIs inspecionadas nessa revisão |
| Kindle Paperwhite Signature Edition, 12ª geração, KOReader 2026.07.1 | Modelo e versão informados pelo usuário. Caminho KindlePaperWhite6 existente no código do KOReader; teste físico pendente |
| Firmware Kindle 5.17.x | Nenhuma dependência direta de firmware, jailbreak ou KUAL; operação inteiramente dentro do KOReader |
| EPUB, uma página, paginado | Caminho implementado e exercitado em fixture própria com títulos, recuos e alturas diferentes |
| Outros formatos refluíveis crengine | Aceitos por detecção de provedor/APIs; cobertura automatizada principal é EPUB |
| Duas páginas visíveis | Detectadas por API; régua/gestos suspensos e controles nativos disponíveis |
| Rolagem contínua | Detectada; suspensa. Voltar ao paginado reativa a detecção |
| PDF/DjVu | Fora do escopo; APIs/transformações diferentes, plugin não captura navegação |
| Página vazia ou só imagem | Sem linhas, sem captura. Usuário vira normalmente; não há loop nem salto automático de páginas |
| Capitulares com caixas sobrepostas | Página recusada com segurança. Ver disponibilidade no menu |
| Tabelas, colunas CSS dentro da página, texto vertical, floats complexos | Sem garantia de sequência de leitura; usar layout simples ou suspender o plugin. Duas páginas não equivale a detectar todos esses layouts |
| Escrita RTL/BiDi | Fragmentos de mesma faixa são agrupados, mas ordem complexa e direção de toque precisam de validação; reversão de toques disponível |
| Modo noturno | Usa pintura nativa antes da inversão; aparência física ainda pendente |
| Outros plugins de gestos | Gestos personalizados podem ter prioridade. Usar suspensão ou modo de interação alternativo; não habilitar duas réguas simultaneamente |
| Versões antigas de KOReader | Não foi estabelecida versão mínima universal. Verificação de APIs recusa provedor/modo incompatível; validar carregamento antes de usar em leitura longa |

O plugin não escolhe dimensões ou DPI de uma geração de Kindle. As duas resoluções
usadas em testes são condições do emulador (600×800 e 800×600), não pressupostos de
hardware. Espessuras e margens usam `screen:scaleBySize`; as linhas vêm do documento.

Eventos de gestos e `registerViewModule` são extensões do código KOReader que podem
mudar entre versões. Os handlers são removidos na desativação/fechamento; não são
salvos sobre as configurações do leitor. Gestures/ações externas não são removidas
do Dispatcher global ao fechar um livro: suas declarações não capturam eventos e
são substituídas pelo mesmo ID na próxima instância. A posição textual pode deixar
de existir após trocar o arquivo do livro, alterar sua versão DOM ou estilos;
a restauração tolera erro e usa posição válida da página já aberta.

Para validar uma versão diferente: executar o roteiro em [TESTING.md](TESTING.md),
registrar versão/modelo e anexar o trecho relevante de `crash.log` sem dados pessoais.
