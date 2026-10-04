using Godot;

public partial class Main : Node
{
	[Export] public Node3D LevelContainer { get; set; }
	[Export] public CanvasLayer UIContainer { get; set; }

	public override void _Ready()
	{
		// Informa ao Router onde pendurar as telas e as fases
		Router.Instance.UIContainer = UIContainer;
		Router.Instance.LevelContainer = LevelContainer;

		// Inicia o aplicativo na tela Home
		Router.Instance.NavigateTo("Home");
	}
}
