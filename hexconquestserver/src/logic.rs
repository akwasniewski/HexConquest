use std::sync::{Arc, MutexGuard};
use std::thread::sleep;
use std::time::Duration;
use axum::Error;
use axum::extract::ws::{Message, WebSocket};
use futures_util::SinkExt;
use futures_util::stream::SplitSink;
use tokio::sync::Mutex;
use tokio_util::sync::CancellationToken;
use tracing::debug;
use crate::messages::{ServerMessage, PlayerInfo};
#[derive(Debug)]
pub struct Player{
    player_id: Option<u32>,
    pub username: Option<String>,
    sender: SplitSink<WebSocket, Message>,
    pub connected: bool,
    cancel_token: CancellationToken,
}
#[derive(Debug)]
pub struct Game{
    game_id: u32,
    players: Arc<Mutex<Vec<Arc<Mutex<Player>>>>>,
}
impl Player{
    pub fn new(sender: SplitSink<WebSocket, Message>, cancel_token: CancellationToken) -> Self{
        Self { player_id: None, username: None, sender, cancel_token, connected: true}
    }
    pub async fn send_message(&mut self, message: &ServerMessage) -> Result<(), Error> {
            let message = serde_json::to_string(message).unwrap();
            self.sender.send(Message::Text(message.into())).await
    }
    pub fn disconnect(&mut self){
        self.connected=false;
        sleep(Duration::from_millis(50)); //sleeping so error messages can get trough
        self.cancel_token.cancel();
    }
    pub fn set_credentials(&mut self, name: String, id: u32){
        self.username=Some(name);
        self.player_id=Some(id);
    }
}
impl Game{
    pub fn new(id: u32) -> Self{
        Self { game_id: id, players: Arc::new(Mutex::new(Vec::new()))}
    }
    pub async fn add_player(&mut self, player: Arc<Mutex<Player>>) -> u32{
        let mut players = self.players.lock().await;
        players.push(player);
        return players.len() as u32 - 1;
    }
    pub async fn player_count(&mut self)->usize{
        let mut players = self.players.lock().await;
        players.len()
    }
    pub async fn broadcast(&self, message: ServerMessage){
        let mut players = self.players.lock().await;
        for player in players.iter_mut(){
            let mut player = player.lock().await;
            if (player.connected) {
                player.send_message(&message).await.expect("failed to send message");
            }
        }
    }
    pub async fn disconnect_player(&mut self, player_id: u32){
        let mut players = self.players.lock().await;
        let mut player = players[player_id as usize].clone();
        let mut player = player.lock().await;
        drop(players);
        player.disconnect();
    }
    pub async fn send_active_players(&self, player_id: u32) {
        let players = self.players.lock().await; // lock the players vec
        let mut players_info = Vec::new();

        for player in players.iter() {
            let player = player.lock().await; // lock each player individually
            players_info.push(PlayerInfo {
                player_id: player.player_id.unwrap(),
                username: player.username.clone().unwrap(),
            });
        }
        drop(players);
        self.send_message_to_player(ServerMessage::ActivePlayersList { players: players_info },
            player_id,
        ).await;
    }

    pub async fn send_message_to_player(&self, message: ServerMessage, player_id: u32){
        let players = self.players.lock().await;
        let player:Arc<Mutex<Player>>=players[player_id as usize].clone();
        let mut player =player.lock().await;
        player.send_message(&message).await.unwrap()
    }
}