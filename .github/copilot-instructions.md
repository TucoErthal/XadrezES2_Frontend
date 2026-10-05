## Regra para Título do PR
Sempre gere o título do Pull Request estritamente no seguinte padrão:
`[#<id_issue>] <Descrição no imperativo e em português>`

- Extraia o `<id_issue>` do nome da branch (ex: de `feat/42-comunicacao-backend-ia` extraia `42`).
- Escreva a descrição no imperativo e em português (ex: `Implementa comunicação Backend-IA`).
- Exemplo final de título: `[#42] Implementa comunicação Backend-IA`

# Instruções para Geração de Pull Requests

Ao gerar ou resumir Pull Requests para este repositório, siga estritamente estas diretrizes:

1. **Formato do Template**: Sempre preencha o arquivo de template `.github/PULL_REQUEST_TEMPLATE.md`.
2. **Issue Relacionada**:
   - Extraia o número da issue a partir do nome da branch (ex: de `feat/42-integração` extraia `42`) ou do título da PR (ex: `[#42]`).
   - Preencha o campo com `Closes #<ID_DA_ISSUE>`.
3. **O que foi feito**:
   - Analise os *commits* e os arquivos alterados (diff).
   - Resuma as alterações principais usando marcadores (`-`).
4. **Como testar**:
   - Forneça instruções passo a passo numeradas (`1.`, `2.`) descrevendo como subir e testar as alterações (ex: comandos Docker, chamadas HTTP, endpoints).
5. **Checklist**:
   - Mantenha os checkboxes do template e marque `[x]` apenas nos itens que foram confirmados nas alterações do código/diff (ex: se novos arquivos de teste foram criados, marque o item de testes).