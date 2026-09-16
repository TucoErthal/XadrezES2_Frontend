using Godot;
using System; // Required for System.Action

public partial class Player : Node
{
    [Export] 
    public StringName SelectAction { get; set; } = "select";

    public Piece SelectedPiece { get; private set; }

    // This is the event all pieces subscribe to
    public static event Action OnGlobalDeselect;

    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event.IsActionPressed(SelectAction))
        {
            TrySelectPiece();
            GetViewport().SetInputAsHandled(); 
        }
    }

    private void TrySelectPiece()
    {
        Camera3D camera = GetViewport().GetCamera3D();
        if (camera == null) return;

        Vector2 mousePos = GetViewport().GetMousePosition();

        float rayLength = 1000.0f;
        Vector3 rayOrigin = camera.ProjectRayOrigin(mousePos);
        Vector3 rayNormal = camera.ProjectRayNormal(mousePos);
        Vector3 rayEnd = rayOrigin + rayNormal * rayLength;

        Piece closestPiece = null;
        float closestDistance = float.MaxValue;

        foreach (Piece piece in Piece.AllPieces)
        {
            // Use the cached mesh reference from the Piece script
            MeshInstance3D visualMesh = piece.VisualMesh;
            
            if (visualMesh == null || visualMesh.Mesh == null) continue;

            Transform3D inverseTransform = visualMesh.GlobalTransform.Inverse();
            Vector3 localRayOrigin = inverseTransform * rayOrigin;
            Vector3 localRayEnd = inverseTransform * rayEnd;

            Aabb bounds = visualMesh.Mesh.GetAabb();
            bool hit = bounds.IntersectsSegment(localRayOrigin, localRayEnd);

            if (hit)
            {
                float distanceSq = rayOrigin.DistanceSquaredTo(piece.GlobalPosition);
                if (distanceSq < closestDistance)
                {
                    closestDistance = distanceSq;
                    closestPiece = piece;
                }
            }
        }

        // If we clicked a piece
        if (closestPiece != null)
        {
            // First, trigger a deselect on EVERYTHING so the previous piece loses its red tint
            OnGlobalDeselect?.Invoke();

            SelectedPiece = closestPiece;
            SelectedPiece.Select();
            
            GD.Print($"SUCCESS! Selected Piece at {SelectedPiece.BoardCoordinates}");
        }
        // If we clicked the void
        else
        {
            SelectedPiece = null;
            
            // Trigger the deselect event to clear the red tint from whatever was selected
            OnGlobalDeselect?.Invoke(); 
            
            GD.Print("Clicked empty space. Selection cleared.");
        }
    }
}