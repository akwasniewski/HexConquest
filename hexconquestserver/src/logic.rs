use std::sync::Arc;
use axum::Error;
use axum::extract::ws::{Message, WebSocket};
use futures_util::SinkExt;
use futures_util::stream::SplitSink;
use tokio::sync::Mutex;

#[derive(Debug)]
pub struct Player{
    player_id: usize,
    pub username: String,
    sender: SplitSink<WebSocket, Message>,
    pub connected: bool,
}
#[derive(Debug)]
pub struct Game{
    game_id: usize,
    players: Arc<Mutex<Vec<Player>>>
}
impl Player{
    pub fn new(id: usize, name: String, socket_sender: SplitSink<WebSocket, Message>) -> Self{
        Self { player_id: id, username: name, sender: socket_sender, connected: true}
    }
    pub async fn send_message(&mut self, message: &str) -> Result<(), Error> {
        self.sender.send(Message::Text(message.into())).await
    }
    pub fn disconnect(&mut self){
        self.connected=false;
    }
}
impl Game{
    pub fn new(id: usize) -> Self{
        Self { game_id: id, players: Arc::new(Mutex::new(Vec::new()))}
    }
    pub async fn add_player(&mut self, player: Player){
        let mut players = self.players.lock().await;
        players.push(player);
    }
    pub async fn player_count(&mut self)->usize{
        let mut players = self.players.lock().await;
        players.len()
    }
    pub async fn broadcast(&self, message: &str){
        let mut players = self.players.lock().await;
        for player in players.iter_mut(){
            if (player.connected) {
                player.send_message(message).await.expect("failed to send message");
            }
        }
    }
    pub async fn disconnect_player(&mut self, player_id: usize){
        let mut players = self.players.lock().await;
        players[player_id].disconnect();
        drop(players);
        self.broadcast(format!("Player {} disconnected",player_id).as_str()).await;
    }
}