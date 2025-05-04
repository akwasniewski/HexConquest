use std::sync::{Arc};
use axum::Error;
use axum::extract::ws::{Message, WebSocket};
use futures_util::SinkExt;
use futures_util::stream::SplitSink;
use tokio::sync::Mutex;
use std::collections::HashMap;
use crate::messages::{ServerMessage, PlayerInfo};
#[derive(Debug)]
pub struct Game{
    pub game_id: u32,
    players: Arc<Mutex<Vec<Arc<Mutex<Player>>>>>,
    unit_count: u32,
}
#[derive(Debug)]
pub struct Player{
    pub player_id: Option<u32>,
    pub username: Option<String>,
    sender: SplitSink<WebSocket, Message>,
    pub connected: bool,
    units: Arc<Mutex<HashMap<u32, Arc<Mutex<Unit>>>>>,
}
#[derive(Debug)]
pub struct Unit{
    position: (i32, i32),
}
impl Player{
    pub fn new(socket_sender: SplitSink<WebSocket, Message>) -> Self{
        Self { player_id: None, username: None, sender: socket_sender, connected: true, units: Arc::new(Mutex::new(HashMap::new()))}
    }
    pub async fn send_message(&mut self, message: &ServerMessage) -> Result<(), Error> {
        let message = serde_json::to_string(message).unwrap();
        self.sender.send(Message::Text(message.into())).await
    }
    pub fn disconnect(&mut self){
        self.connected=false;
    }
    pub fn set_credentials(&mut self, name: String, id: u32){
        self.username=Some(name);
        self.player_id=Some(id);
    }
}
impl Game{
    pub fn new(id: u32) -> Self{
        Self { game_id: id, players: Arc::new(Mutex::new(Vec::new())), unit_count: 0}
    }
    pub async fn add_player(&mut self, player: Arc<Mutex<Player>>) -> u32{
        let mut players = self.players.lock().await;
        players.push(player);
        return players.len() as u32 - 1;
    }
    pub async fn player_count(&mut self)->usize{
        let players = self.players.lock().await;
        players.len()
    }
    pub async fn broadcast(&self, message: ServerMessage){
        let mut players = self.players.lock().await;
        for player in players.iter_mut(){
            let mut player = player.lock().await;
            if player.connected {
                player.send_message(&message).await.expect("failed to send message");
            }
        }
    }
    pub async fn disconnect_player(&mut self, player_id: u32){
        let players = self.players.lock().await;
        let player = players[player_id as usize].clone();
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
    pub async fn add_unit(&mut self, player_id: u32, position: (i32, i32)){
        let players = self.players.lock().await;
        let player: Arc<Mutex<Player>>=players[player_id as usize].clone();
        let player =player.lock().await;
        let mut units = player.units.lock().await;
        let unit_id = self.unit_count;
        self.unit_count+=1;
        units.insert(unit_id, Arc::new(Mutex::new(Unit::new(position))));
        self.broadcast(ServerMessage::AddUnit{player_id, unit_id, position_x: position.0, position_y: position.1}).await;
    }
    pub async fn move_unit(&self, player_id: u32, unit_id: u32, position: (i32, i32)){
        let players = self.players.lock().await;
        let player: Arc<Mutex<Player>>=players[player_id as usize].clone();
        let player =player.lock().await;
        let units = player.units.lock().await;
        let mut unit = units.get(&unit_id).expect("player does not have this unit").lock().await;
        unit.position = position;
        self.broadcast(ServerMessage::MoveUnit{unit_id, position_x: position.0, position_y: position.1}).await;
    }
}
impl Unit{
    pub fn new(position: (i32, i32)) -> Self{
        Self {position}
    }
}
