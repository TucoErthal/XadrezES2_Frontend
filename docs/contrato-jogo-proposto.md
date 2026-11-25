# Proposta: comandos de jogo no WebSocket

> **Status: proposta.** O contrato atual do backend (`docs/API.md` do
> `chess-backend`) encerra dizendo: *"Comandos de movimento, abandono e empate
> não fazem parte deste contrato WebSocket nesta versão"*. Sem eles não existe
> como jogar. Este documento é o que o frontend implementou enquanto o formato
> definitivo não é fechado pelo grupo.

## Por que assim

A proposta reaproveita o que já está no contrato em vez de inventar estrutura
nova:

- o envelope `{type, requestId, ...}` das mensagens do cliente;
- o `revision` do snapshot, como trava otimista;
- o `game.state` como **única** resposta de sucesso — o cliente não aplica
  lance localmente, só redesenha o snapshot que o servidor devolve;
- o `game.error` com os códigos que já existem (`VALIDATION_ERROR`,
  `INVALID_GAME_STATE`, `STALE_REVISION`, `NOT_A_PARTICIPANT`).

O backend continua sendo a autoridade: valida a legalidade, aplica, atualiza o
relógio e publica o novo estado.

## Mensagens do cliente

### Lance

```json
{"type":"game.move","requestId":"mv-1","gameId":"<uuid>","revision":12,"uci":"e2e4"}
```

`uci` segue o formato UCI, com a peça da promoção no fim quando houver
(`e7e8q`). `revision` é a revisão em que o cliente baseou o lance.

### Desistência

```json
{"type":"game.resign","requestId":"rs-1","gameId":"<uuid>"}
```

### Empate

```json
{"type":"draw.offer","requestId":"do-1","gameId":"<uuid>"}
{"type":"draw.respond","requestId":"dr-1","gameId":"<uuid>","accept":true}
```

## Respostas

Sucesso: o servidor publica `game.state` com o snapshot novo, como já faz hoje
para a entrada do segundo jogador. O `drawOffer` do snapshot passa a refletir a
oferta pendente, e `result` é preenchido quando a partida termina
(`RESIGNATION`, `DRAW_AGREED`, `CHECKMATE`, `TIMEOUT`...).

Erro: `game.error` com o `requestId` correlato.

| Código | Quando |
| --- | --- |
| `VALIDATION_ERROR` | campo ausente ou `uci` malformado |
| `ILLEGAL_MOVE` | lance ilegal na posição |
| `STALE_REVISION` | `revision` não é mais a atual |
| `INVALID_GAME_STATE` | partida não está `ACTIVE`, ou não é a vez do jogador |
| `NOT_A_PARTICIPANT` | quem enviou não joga essa partida |

## O que falta decidir: partida contra o computador

O `POST /v1/games` cria sempre uma partida humano contra humano. O tema do
trabalho é jogar contra a máquina, e nenhum ponto do contrato REST prevê isso.

Sugestão mínima, sem mexer no resto do fluxo:

```json
POST /v1/games
{"visibility":"PRIVATE","timeControl":{...},"opponent":"AI","aiLevel":"MEDIUM"}
```

O backend cria o segundo jogador com `kind: "AI"` (o campo já existe no
snapshot), a partida já nasce `ACTIVE`, e a partir daí o fluxo é idêntico: o
backend enfileira o trabalho para o worker da IA pelo contrato
`docs/contracts/backend-ai.md` e publica `game.state` quando o lance volta.

## Onde isso está no código do frontend

Tudo o que depende desta proposta está em `Network/WsClient.gd`, nos métodos
`send_move`, `send_resign`, `send_draw_offer` e `send_draw_respond`. Se o
formato mudar, mudam só esses métodos.
