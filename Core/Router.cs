using Godot;
using System.Collections.Generic;

public partial class Router : Node
{
	public static Router Instance { get; private set; }

	// Containers que vão segurar as telas e o mundo 3D
	public Node UIContainer { get; set; } 
	public Node3D LevelContainer { get; set; } // Adicionado para o 3D

	private Node _currentView;
	private Node _currentLevel; // Adicionado para controlar a fase atual

	private readonly Dictionary<string, string> _routes = new()
	{
		{ "Home", "res://UI/Screens/Home.tscn" },
		{ "Lobby", "res://UI/Screens/Lobby.tscn" },
		{ "GameUI", "res://UI/Screens/GameUI.tscn" }
	};

	public override void _Ready()
	{
		if (Instance == null)
		{
			Instance = this;
		}
		else
		{
			QueueFree();
		}
	}

	public void NavigateTo(string routeName)
	{
		if (!_routes.TryGetValue(routeName, out string path))
		{
			GD.PrintErr($"Rota '{routeName}' não configurada no dicionário.");
			return;
		}

		if (UIContainer == null) return;

		if (_currentView != null)
		{
			_currentView.QueueFree();
			_currentView = null;
		}

		PackedScene scene = GD.Load<PackedScene>(path);
		_currentView = scene.Instantiate();
		UIContainer.AddChild(_currentView);
	}

	// NOVA FUNÇÃO: Carrega o tabuleiro 3D
	public void LoadLevel(string levelPath)
	{
		if (LevelContainer == null)
		{
			GD.PrintErr("LevelContainer não foi definido no Router.");
			return;
		}

		if (_currentLevel != null)
		{
			_currentLevel.QueueFree();
			_currentLevel = null;
		}

		PackedScene scene = GD.Load<PackedScene>(levelPath);
		_currentLevel = scene.Instantiate();
		LevelContainer.AddChild(_currentLevel);
	}
}
