using Godot;
using System;
using System.Text;

public class Client : Node
{
	// The URL we will connect to
	[Export] public string WebSocketUrl = "ws://127.0.0.1:7777/ws";

	// Our WebSocketClient instance
	private WebSocketClient _client;

	public override void _Ready()
	{
		_client = new WebSocketClient();

		_client.Connect("connection_closed", this, nameof(OnClosed));
		_client.Connect("connection_error", this, nameof(OnError));
		_client.Connect("connection_established", this, nameof(OnConnected));
		_client.Connect("data_received", this, nameof(OnDataReceived));

		Error err = _client.ConnectToUrl(WebSocketUrl);
		if (err != Error.Ok)
		{
			GD.Print("Unable to connect");
			SetProcess(false); // Stop the node's _Process() function from being called
		}
	}
	private void OnClosed()
	{
		GD.Print("Connection closed.");
		SetProcess(false); // Stop the node's _Process() function from being called
	}

	private void OnError()
	{
		GD.Print("Error with WebSocket connection.");
		SetProcess(false);
	}

	private void OnConnected()
	{
		GD.Print("Connected to WebSocket server.");
		byte[] data = Encoding.UTF8.GetBytes("Test packet");
		_client.GetPeer(1).PutPacket(data);
	}

	private void OnDataReceived()
	{
		byte[] packet = _client.GetPeer(1).GetPacket();
		string message = Encoding.UTF8.GetString(packet);
		GD.Print("Received data: " + message);  
	}

	public override void _Process(float delta)
	{
		// Poll the WebSocket to handle connection and communication.
		_client.Poll();
	}

  public void SendMessage(string message)
  {
	var peer = _client.GetPeer(1);
	if (peer != null)
	{
	  byte[] data = Encoding.UTF8.GetBytes(message);
	  peer.PutPacket(data);
	  GD.Print("Sent: " + message);
	}
	else
	{
	  GD.Print("WebSocket peer is not ready.");
	}
  }
}
