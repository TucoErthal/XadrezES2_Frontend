using Godot;

public partial class Board : MeshInstance3D
{
    public static Board Instance { get; private set; }

    public override void _Ready()
    {
        // Singleton Logic
        if (Instance == null)
        {
            Instance = this;
        }
        else if (this != Instance)
        {
            QueueFree(); // Destroi o node
        }
    }

    public Vector3? GetPositionInBoard(Vector2 coordinates)
    {
        if (coordinates.X < 0 || coordinates.X > 7 || coordinates.Y < 0 || coordinates.Y > 7)
        {
            GD.PrintErr("Coordenadas fora do tabuleiro!");
            return null;
        }

        float halfBoard = GetAabb().GetLongestAxisSize() / 2;
        float halfTile = GetAabb().GetLongestAxisSize() / 16;

        Vector3 localPosition = new(
            coordinates.X - halfBoard + halfTile,
            0,
            coordinates.Y - halfBoard + halfTile
        );

        return ToGlobal(localPosition);
    }
}