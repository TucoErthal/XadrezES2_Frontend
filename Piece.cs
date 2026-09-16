using Godot;
using System;

public partial class Piece : Node3D
{
    public static readonly System.Collections.Generic.List<Piece> AllPieces = new();

    public MeshInstance3D VisualMesh { get; private set; }

    // Removed [Export] to hide from inspector
    public Vector2I BoardCoordinates { get; set; } = Vector2I.Zero;

    private StandardMaterial3D _tintedMaterial;

    public override void _Ready()
    {
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
        Player.OnGlobalDeselect += Deselect; 
    }

    public override void _ExitTree()
    {
        AllPieces.Remove(this);
        Player.OnGlobalDeselect -= Deselect; 
    }

    public void Select()
    {
        if (VisualMesh == null) return;

        if (_tintedMaterial == null)
        {
            Material originalMat = VisualMesh.GetActiveMaterial(0);
            if (originalMat is StandardMaterial3D stdMat)
            {
                _tintedMaterial = (StandardMaterial3D)stdMat.Duplicate();
                _tintedMaterial.AlbedoColor = Colors.Red;
            }
        }

        if (_tintedMaterial != null)
        {
            VisualMesh.MaterialOverride = _tintedMaterial;
        }
    }

    public void Deselect()
    {
        if (VisualMesh != null)
        {
            VisualMesh.MaterialOverride = null;
        }
    }
}