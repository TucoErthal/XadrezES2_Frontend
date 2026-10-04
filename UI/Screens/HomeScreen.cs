using Godot;

// 1. Mudamos de Control para Button, pois o script está no nó Button
public partial class HomeScreen : Button 
{
	public override void _Ready()
	{
		// 2. Conecta o sinal de clique (Pressed) do botão à nossa função
		this.Pressed += OnStartButtonPressed;
	}

	public void OnStartButtonPressed()
	{
		// Carrega o mundo 3D (Tabuleiro, peças, câmera)
		Router.Instance.LoadLevel("res://Levels/Level.tscn");
		
		// Muda a interface para o GameUI (Isso faz o botão Jogar sumir)
		Router.Instance.NavigateTo("GameUI");
	}
}
