using Godot;
using System;

public class Client : Node
{
	private NetworkedMultiplayerENet peer;

	public override void _Ready()
	{
		SetNetworkMaster(GetTree().GetNetworkUniqueId()); // Ensure node can receive RPCs
		ConnectToServer();
	}

	public void ConnectToServer()
	{
		peer = new NetworkedMultiplayerENet();
		Error err = peer.CreateClient("127.0.0.1", 7777);
		
		if (err != Error.Ok)
		{
			GD.PrintErr("Failed to connect to server!");
			return;
		}
		
		GetTree().NetworkPeer = peer;
		peer.Connect("connection_succeeded", this, nameof(OnConnected));
		peer.Connect("connection_failed", this, nameof(OnConnectionFailed));
		peer.Connect("server_disconnected", this, nameof(OnDisconnected));
		GD.Print("Attempting to connect to server...");
	}

	private void OnConnected()
	{
		GD.Print("Connected to server!");
	}

	private void OnConnectionFailed()
	{
		GD.PrintErr("Failed to connect to server.");
	}

	private void OnDisconnected()
	{
		GD.Print("Disconnected from server.");
	}

	[Remote]
	public void ReceiveMessage(string message)
	{
		GD.Print($"Server message received: {message}");
	}
}
