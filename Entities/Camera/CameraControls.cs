using Godot;

public partial class CameraControls : Camera3D
{
    [ExportGroup("Nodes")]
    [Export] public Node3D FocusNode { get; set; }

    [ExportGroup("Input Actions")]
    [Export] public StringName ZoomInAction { get; set; } = "camera_zoom_in";
    [Export] public StringName ZoomOutAction { get; set; } = "camera_zoom_out";
    [Export] public StringName OrbitAction { get; set; } = "camera_orbit";
    [Export] public StringName PanAction { get; set; } = "camera_pan";

    [ExportGroup("Camera Settings")]
    [Export] public float MinDistance { get; set; } = 2.0f;
    [Export] public float MaxDistance { get; set; } = 50.0f;
    
    [Export(PropertyHint.Range, "0.01, 1.0")] 
    public float ZoomSpeed { get; set; } = 0.15f;
    
    [Export(PropertyHint.Range, "0.001, 0.05")] 
    public float OrbitSensitivity { get; set; } = 0.005f;
    
    [Export(PropertyHint.Range, "0.001, 0.05")] 
    public float PanSensitivity { get; set; } = 0.002f;

    [ExportGroup("Smoothing")]
    [Export] public float ZoomSmoothing { get; set; } = 10.0f;
    [Export] public float OrbitSmoothing { get; set; } = 15.0f;
    // Pan smoothing removed for instant 1:1 control

    // Target values for smoothed movements
    private float _targetDistance = 10.0f;
    private float _targetPitch = -Mathf.Pi / 4.0f;
    private float _targetYaw = 0.0f;

    // Current values (lerped towards targets for smoothness)
    private float _currentDistance;
    private float _currentPitch;
    private float _currentYaw;
    
    // Instant value for snappy panning
    private Vector3 _focusPoint = Vector3.Zero;

    public override void _Ready()
    {
        if (FocusNode != null)
        {
            // Detach the node's transform from the camera so they move independently
            FocusNode.TopLevel = true; 
            FocusNode.GlobalPosition = Vector3.Zero;
            _focusPoint = FocusNode.GlobalPosition;
        }
        else
        {
            GD.PrintErr("OrbitCamera: FocusNode is not assigned in the inspector!");
            _focusPoint = Vector3.Zero;
        }

        // Initialize current values to match targets immediately on spawn
        _currentDistance = _targetDistance;
        _currentPitch = _targetPitch;
        _currentYaw = _targetYaw;
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event is InputEventMouseMotion mouseMotion)
        {
            if (Input.IsActionPressed(OrbitAction))
            {
                // Orbiting modifies Yaw and Pitch
                _targetYaw -= mouseMotion.Relative.X * OrbitSensitivity;
                _targetPitch -= mouseMotion.Relative.Y * OrbitSensitivity;

                // Clamp pitch so the camera doesn't flip upside down (-89 to 89 degrees)
                float pitchLimit = Mathf.DegToRad(89.9f);
                _targetPitch = Mathf.Clamp(_targetPitch, -pitchLimit, pitchLimit);
            }
            else if (Input.IsActionPressed(PanAction))
            {
                // Get the camera's local Right and Forward vectors, flattened to the XZ floor
                Vector3 right = GlobalTransform.Basis.X;
                right.Y = 0;
                right = right.Normalized();

                Vector3 forward = -GlobalTransform.Basis.Z;
                forward.Y = 0;
                
                // Fallback in case we are looking straight down
                if (forward.LengthSquared() > 0.001f)
                    forward = forward.Normalized();
                else
                    forward = GlobalTransform.Basis.Y.Normalized();

                float scaledPanSpeed = PanSensitivity * _currentDistance;

                // Directly update the instant focus point
                _focusPoint -= right * mouseMotion.Relative.X * scaledPanSpeed;
                _focusPoint += forward * mouseMotion.Relative.Y * scaledPanSpeed;
            }
        }
        else if (@event.IsActionPressed(ZoomInAction))
        {
            _targetDistance -= _targetDistance * ZoomSpeed;
            _targetDistance = Mathf.Clamp(_targetDistance, MinDistance, MaxDistance);
        }
        else if (@event.IsActionPressed(ZoomOutAction))
        {
            _targetDistance += _targetDistance * ZoomSpeed;
            _targetDistance = Mathf.Clamp(_targetDistance, MinDistance, MaxDistance);
        }
    }

    public override void _Process(double delta)
    {
        float fDelta = (float)delta;

        // Smoothly interpolate zoom and orbit
        _currentDistance = Mathf.Lerp(_currentDistance, _targetDistance, ZoomSmoothing * fDelta);
        _currentPitch = Mathf.Lerp(_currentPitch, _targetPitch, OrbitSmoothing * fDelta);
        _currentYaw = Mathf.LerpAngle(_currentYaw, _targetYaw, OrbitSmoothing * fDelta);

        // Update the physical node's position in the world instantly
        if (FocusNode != null)
        {
            FocusNode.GlobalPosition = _focusPoint;
        }

        // Calculate the new camera position based on orbit angles and distance
        Basis basis = Basis.FromEuler(new Vector3(_currentPitch, _currentYaw, 0));
        Vector3 offset = basis * new Vector3(0, 0, _currentDistance);
        
        GlobalPosition = _focusPoint + offset;
        LookAt(_focusPoint, Vector3.Up);
    }
}