using Godot;
using System; // Required for System.Action

public partial class Piece : Node3D
{
    public static readonly System.Collections.Generic.List<Piece> AllPieces = new();

    // Cache the mesh so other scripts can access it quickly
    public MeshInstance3D VisualMesh { get; private set; }

    [Export] 
    public Vector2I BoardCoordinates { get; set; } = Vector2I.Zero;

    // Stores our unique red-tinted material
    private StandardMaterial3D _tintedMaterial;

    public override void _Ready()
    {
        // Search for the MeshInstance3D child once and cache it
        foreach (Node child in GetChildren())
        {
            if (child is MeshInstance3D mi3d)
            {
                VisualMesh = mi3d;
                break;
            }
        }
    }

    public override void _EnterTree()
    {
        AllPieces.Add(this);
        // Subscribe to the global deselect event
        Player.OnGlobalDeselect += Deselect; 
    }

    public override void _ExitTree()
    {
        AllPieces.Remove(this);
        // ALWAYS unsubscribe when destroyed to prevent memory leaks
        Player.OnGlobalDeselect -= Deselect; 
    }

    public void Select()
    {
        if (VisualMesh == null) return;

        // If we haven't created the red material yet, duplicate the original and tint it
        if (_tintedMaterial == null)
        {
            Material originalMat = VisualMesh.GetActiveMaterial(0);
            if (originalMat is StandardMaterial3D stdMat)
            {
                _tintedMaterial = (StandardMaterial3D)stdMat.Duplicate();
                _tintedMaterial.AlbedoColor = Colors.Red;
            }
            else
            {
                GD.PrintErr("Piece material is not a StandardMaterial3D, cannot tint.");
            }
        }

        // Apply the override
        if (_tintedMaterial != null)
        {
            VisualMesh.MaterialOverride = _tintedMaterial;
        }
    }

    public void Deselect()
    {
        // Clearing the override instantly restores the original material
        if (VisualMesh != null)
        {
            VisualMesh.MaterialOverride = null;
        }
    }
}