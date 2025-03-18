using Godot;
using System;

public class Server : Node
{
	private NetworkedMultiplayerENet peer;

	public override void _Ready()
	{
		StartServer();
	}

	public void StartServer()
	{
		peer = new NetworkedMultiplayerENet();
		Error err = peer.CreateServer(7777, 10); // Port 7777, Max 10 Players

		if (err != Error.Ok)
		{
			GD.PrintErr("Failed to start server!");
			return;
		}

		GetTree().NetworkPeer = peer;
		peer.Connect("peer_connected", this, nameof(OnClientConnected));
		peer.Connect("peer_disconnected", this, nameof(OnClientDisconnected));

		GD.Print("Server started on port 7777");
	}

	private void OnClientConnected(int id)
	{
		GD.Print($"Client {id} connected");
		RpcId(id, "ReceiveMessage", "Welcome to the server!");
	}

	private void OnClientDisconnected(int id)
	{
		GD.Print($"Client {id} disconnected");
	}
}
