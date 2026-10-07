# XadrezES2 Frontend

Frontend do projeto XadrezES2, desenvolvido em Godot com GDScript. O projeto oferece a interface para autenticação, lobby, criação/entrada em salas e visualização de partidas de xadrez em um tabuleiro 3D.

## Release

Esta documentação corresponde à release **v0.2.0**.

## Objetivo

O objetivo do frontend é fornecer a experiência visual e interativa do jogo, integrando-se à API HTTP e ao servidor WebSocket do XadrezES2 para:

- autenticar e identificar o jogador;
- navegar entre as telas da aplicação;
- listar e criar salas;
- entrar em partidas por código;
- acompanhar o estado da partida em tempo real;
- representar o tabuleiro e as peças em 3D;
- permitir interação com o tabuleiro, incluindo seleção e movimentação local de peças.

## Estado atual

Na release `v0.2.0`, o projeto conta com:

- migração dos scripts principais de C# para GDScript;
- gerenciador central de rotas e carregamento de telas;
- telas de início, login, lobby, criação de sala, sala de espera e jogo;
- cliente REST para comunicação com a API;
- cliente WebSocket para atualização do estado da partida;
- sincronização do tabuleiro a partir de posições FEN recebidas do backend;
- tabuleiro 3D com câmera orbital, zoom e movimentação panorâmica;
- seleção visual de peças e identificação das peças no tabuleiro;
- configuração de ambiente por meio do arquivo `env.cfg`.

A aplicação ainda está em desenvolvimento. Algumas regras completas do xadrez, validações de jogadas e o fluxo definitivo de aplicação de movimentos dependem da integração e da evolução do backend.

## Requisitos

- [Godot 4.7](https://godotengine.org/), utilizando o renderer **Forward+**;
- backend do XadrezES2 em execução, caso sejam necessários login, lobby ou partidas online;
- acesso ao repositório localmente.

## Execução local

### 1. Clonar o repositório

```bash
git clone https://github.com/TucoErthal/XadrezES2_Frontend.git
cd XadrezES2_Frontend
```

Para executar exatamente o código desta release:

```bash
git checkout v0.2.0
```

### 2. Configurar o ambiente

Por padrão, o frontend tenta acessar a API e o WebSocket em `localhost:8080`.

Para alterar esses endereços, crie um arquivo `env.cfg` na raiz do projeto:

```ini
[network]
api_url="http://localhost:8080"
ws_url="ws://localhost:8080"
```

O arquivo `env.cfg` é ignorado pelo Git, permitindo configurações diferentes para cada ambiente local.

### 3. Importar e executar no Godot

1. Abra o Godot Project Manager.
2. Selecione **Import**.
3. Escolha o arquivo `project.godot` na raiz do repositório.
4. Abra o projeto usando Godot 4.7.
5. Execute o projeto com **Run Project** ou pressione `F6`/`F5`, conforme a cena selecionada.

A cena principal configurada no projeto é `Core/Main.tscn`.

### 4. Executar com o backend

Caso o backend esteja rodando em outro endereço, ajuste o `env.cfg` antes de iniciar o projeto. Verifique também se a API HTTP e o endpoint WebSocket estão disponíveis e se o CORS, quando aplicável, permite a conexão do cliente.

## Controles

Os controles são configurados no arquivo `project.godot` e podem ser alterados pelo editor do Godot:

- **Zoom:** ações `camera_zoom_in` e `camera_zoom_out`;
- **Rotação da câmera:** ação `camera_orbit` + movimento do mouse;
- **Movimentação da câmera:** ação `camera_pan` + movimento do mouse;
- **Seleção:** ação `select`.

## Estrutura principal

```text
Core/                  Inicialização e roteamento da aplicação
Entities/              Câmera, jogador e peças
Levels/                Tabuleiro, cena do jogo e gerenciamento da partida
UI/                    Telas e componentes da interface
Env.gd                 Configuração de API e WebSocket
project.godot          Configuração do projeto e ações de entrada
```

## Licença

Este projeto está licenciado sob a licença [MIT](LICENSE).
