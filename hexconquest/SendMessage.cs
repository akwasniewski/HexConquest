using Godot;
public class SendMessage : Node
{
public override void _Ready()
{
	var button = new Button();
	button.Text = "Click me";
	button.Connect("pressed", this, nameof(ButtonPressed));
	AddChild(button);
}

private void ButtonPressed()
{
	GD.Print("Hello world!");
}
}
