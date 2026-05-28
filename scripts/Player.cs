using Godot;

public partial class Player : CharacterBody2D
{
	// Speed in pixels per second. [Export] makes it editable in Inspector.
	[Export] public float Speed = 300.0f;

	public override void _PhysicsProcess(double delta)
	{
		GD.Print("Physics running!");

		Vector2 direction = Input.GetVector("move_left", "move_right", "move_up", "move_down");
		Velocity = direction * Speed;
		MoveAndSlide();
	}
}
