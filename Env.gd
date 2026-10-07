extends Node

var api_url: String = "http://localhost:8080"
var ws_url: String = "ws://localhost:8080"

func _ready() -> void:
	var config := ConfigFile.new()
	
	var err = config.load("res://env.cfg")
	if err == OK:
		api_url = config.get_value("network", "api_url", api_url)
		ws_url = config.get_value("network", "ws_url", ws_url)
		print("Ambiente carregado. API: ", api_url)
	else:
		print("Arquivo env.cfg não encontrado. Usando defaults.")
