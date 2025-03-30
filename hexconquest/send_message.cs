using Godot;
using System;

public class send_message : Button
{
	private Client _client;
	private Button _sendButton;

  public override void _Ready()
	{
		// Get the Client node safely
		_client = GetNode("/root/Client") as Client;
		if (_client == null)
		{
			GD.PrintErr("Client node found but not of type Client!");
			return;
		}

		// Get the SendButton node safely
		_sendButton = GetNode("/root/Client/SendButton") as Button;
		if (_sendButton == null)
		{
			GD.PrintErr("SendButton found but not a Button!");
			return;
		}

		// Connect the button signal
		_sendButton.Connect("pressed", this, nameof(OnSendButtonPressed));
	}

	private void OnSendButtonPressed()
	{
		if (_client != null)
		{
			_client.SendMessage("Hello from the Button!");
		}
		else
		{
			GD.Print("Client node not found!");
		}
	}
}
