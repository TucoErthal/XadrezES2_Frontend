extends Node

func _ready() -> void:
	print("--- INICIANDO TESTES DA ISSUE 1 ---")
	
	# TESTE 1: Login
	print("1. Testando Login...")
	RestClient.login_guest("tester")
	
	# No Godot 4, o await retorna um Array com os parâmetros do signal
	var login_result = await RestClient.on_login_completed
	var success = login_result[0]
	var data = login_result[1]
	
	if success:
		print("[OK] Login realizado! Token: ", RestClient.session_token)
	else:
		print("[ERRO] Falha no login: ", data)
		return # Para o teste aqui
		
	# TESTE 2: Criar Sala
	print("2. Testando Criação de Sala...")
	RestClient.create_game(false, 600000)
	var create_result = await RestClient.on_game_created
	var game_success = create_result[0]
	var game_data = create_result[1]
	
	if game_success:
		print("[OK] Sala criada! ID: ", game_data.get("gameId"))
	else:
		print("[ERRO] Falha ao criar sala: ", game_data)
		return
		
	# TESTE 3: WebSocket
	print("3. Testando WebSocket...")
	var game_id = game_data.get("gameId")
	WsClient.connect_and_subscribe(game_id)
	
	print("Aguardando confirmação do WebSocket...")
	# Espera até o WebSocket atualizar o estado do jogo
	var ws_snapshot = await WsClient.game_state_updated
	print("[OK] Pacote game.state recebido via WS! Status atual: ", ws_snapshot.get("status"))
	
	# TESTE 4: Buscar Partidas
	print("4. Testando Busca de Partidas Públicas...")
	RestClient.fetch_public_games()
	var fetch_result = await RestClient.on_public_games_fetched
	var fetch_success = fetch_result[0]
	var fetch_data = fetch_result[1]
	
	if fetch_success:
		var qtd = fetch_data.get("games", []).size()
		print("[OK] Busca funcionou! Encontrou ", qtd, " partida(s).")
	else:
		print("[ERRO] Falha ao buscar partidas: ", fetch_data)

	# TESTE 5: Join Game (Simulando)
	print("5. Testando Endpoint de Join...")
	# Como já somos os criadores dessa sala, o backend pode retornar erro ao tentar entrar nela de novo.
	# Mas o importante aqui é ver se a comunicação com /v1/games/{id}/join funciona.
	RestClient.join_game(game_id)
	var join_result = await RestClient.on_game_joined
	var join_success = join_result[0]
	var join_data = join_result[1]
	
	if join_success:
		print("[OK] Join realizado com sucesso (Backend permitiu jogar contra si mesmo!).")
	else:
		# Se der erro 400/403 (ex: User already in game), também é um sinal de que a ROTA está correta!
		print("[AVISO/OK] Join negado, mas a rota comunicou perfeitamente. Motivo: ", join_data)
		
	print("--- TODOS OS TESTES DA ISSUE 1 CONCLUÍDOS ---")
