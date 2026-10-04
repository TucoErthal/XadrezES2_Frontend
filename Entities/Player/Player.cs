using Godot;
using System; 

public partial class Player : Node
{
    [Export] 
    public StringName SelectAction { get; set; } = "select";

    public Piece SelectedPiece { get; private set; }

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

        if (closestPiece != null)
        {
            OnGlobalDeselect?.Invoke();

            SelectedPiece = closestPiece;
            SelectedPiece.Select();
            
            GD.Print($"SUCCESS! Selected Piece at {SelectedPiece.BoardCoordinates}");
        }
        else 
        {
            // If we didn't click a piece, but one is currently selected, try to move it
            if (SelectedPiece != null && Board.Instance != null)
            {
                // Create a flat mathematical plane matching the board's position/rotation
                Plane boardPlane = new Plane(Board.Instance.GlobalTransform.Basis.Y, Board.Instance.GlobalPosition);
                Vector3? intersection = boardPlane.IntersectsRay(rayOrigin, rayNormal);

                if (intersection.HasValue)
                {
                    Vector2I boardCoords = Board.Instance.GetCoordinatesFromPosition(intersection.Value);

                    // Ensure the click was actually inside the 8x8 boundaries
                    if (boardCoords.X >= 0 && boardCoords.X <= 7 && boardCoords.Y >= 0 && boardCoords.Y <= 7)
                    {
                        Vector3? snapPosition = Board.Instance.GetPositionInBoard(boardCoords);
                        if (snapPosition.HasValue)
                        {
                            SelectedPiece.GlobalPosition = snapPosition.Value;
                            SelectedPiece.BoardCoordinates = boardCoords;
                            GD.Print($"Piece moved to {boardCoords}");
                        }
                    }
                }
            }

            SelectedPiece = null;
            OnGlobalDeselect?.Invoke(); 
            GD.Print("Selection cleared.");
        }
    }
}