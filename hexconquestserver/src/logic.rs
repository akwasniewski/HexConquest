use std::sync::Arc;
use axum::Error;
use axum::extract::ws::{Message, WebSocket};
use futures_util::SinkExt;
use futures_util::stream::SplitSink;
use tokio::sync::Mutex;

#[derive(Debug)]
pub struct Player{
    pub username: String,
    sender: SplitSink<WebSocket, Message>
}
#[derive(Debug)]
pub struct Game{
    game_id: u32,
    players: Arc<Mutex<Vec<Player>>>
}
impl Player{
    pub fn new(name: String, socket_sender: SplitSink<WebSocket, Message>) -> Self{
        Self { username: name, sender: socket_sender}
    }
    pub async fn send_message(&mut self, message: &str) -> Result<(), Error> {
        self.sender.send(Message::Text(message.into())).await
    }
}
impl Game{
    pub fn new(id: u32) -> Self{
        Self { game_id: id, players: Arc::new(Mutex::new(Vec::new())),}
    }
    pub async fn add_player(&mut self, player: Player){
        let mut players = self.players.lock().await;
        players.push(player)
    }
    pub async fn broadcast(&self, message: &str){
        let mut players = self.players.lock().await;
        for player in players.iter_mut(){
            player.send_message(message).await.expect("failed to send message");
        }
    }
}