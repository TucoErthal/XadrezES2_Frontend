## Regra para Título do PR
Sempre gere o título do Pull Request estritamente no seguinte padrão:
`[#<id_issue>] <Descrição no imperativo e em português>`

- Extraia o `<id_issue>` do nome da branch (ex: de `feat/42-comunicacao-backend-ia` extraia `42`).
- Escreva a descrição no imperativo e em português (ex: `Implementa comunicação Backend-IA`).
- Exemplo final de título: `[#42] Implementa comunicação Backend-IA`

# Instruções para Geração de Pull Requests

Ao gerar ou resumir Pull Requests para este repositório, siga estritamente estas diretrizes:

1. **Formato do Título do PR**:
   - Use estritamente o padrão: `[#<id_issue>] <Descrição no imperativo e em português>`
   - Extraia o `<id_issue>` do nome da branch (ex: de `feat/42-comunicacao-backend-ia` extraia `42`).
   - Exemplo: `[#42] Implementa comunicação Backend-IA`

2. **Estrutura dos Títulos de Seção**:
   - Utilize exatamente estes títulos em Markdown, sem adicionar sufixos ou parênteses:
     - `## O que foi feito`
     - `## Issue Relacionada`
     - `## Como testar`

3. **Preenchimento dos Campos**:
   - **O que foi feito**: Resuma as alterações do diff em tópicos (`-`).
   - **Issue Relacionada**: Preencha com `Closes #<ID_DA_ISSUE>`.
   - **Como testar**: Liste o passo a passo numerado (`1.`, `2.`). Caso a alteração não seja testável diretamente via execução (ex: alterações puramente em documentação ou pipelines CI/CD), escreva `N/A`.