use std::sync::Arc;
use axum::Error;
use axum::extract::ws::{Message, WebSocket};
use futures_util::SinkExt;
use futures_util::stream::SplitSink;
use tokio::sync::{Mutex,watch};
use tokio::time::{Duration};
use std::collections::HashMap;
use crate::messages::{ServerMessage, PlayerInfo, Vector2i};
const TICK_LENGTH: u64 = 2;
#[derive(Debug)]
pub struct Game{
    pub game_id: u32,
    players: Arc<Mutex<Vec<Arc<Mutex<Player>>>>>,
    unit_count: u32,
    cities: HashMap<(i32,i32),Arc<Mutex<City>>>,
    ports: HashMap<(i32,i32),Arc<Mutex<Port>>>,
    tick_stopper: watch::Sender<bool>,
}
#[derive(Debug)]
pub struct City{
    owner_id: Option<u32>,
}
#[derive(Debug)]
pub struct Port{
}

#[derive(Debug)]
pub struct Player{
    pub player_id: Option<u32>,
    pub username: Option<String>,
    sender: SplitSink<WebSocket, Message>,
    pub connected: bool,
    units: Arc<Mutex<HashMap<(i32,i32), Arc<Mutex<Unit>>>>>,
}
#[derive(Debug)]
pub struct Unit{
    position: (i32, i32),
    count: u32,
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
impl Game {
    pub fn new(id: u32) -> Self {
        let (tick_stopper, _) = watch::channel(false);
        Self { game_id: id, players: Arc::new(Mutex::new(Vec::new())), unit_count: 0, cities: HashMap::new(), ports: HashMap::new(), tick_stopper }
    }
    pub async fn add_player(&mut self, player: Arc<Mutex<Player>>) -> u32 {
        let mut players = self.players.lock().await;
        players.push(player);
        return players.len() as u32 - 1;
    }
    pub async fn player_count(&mut self) -> usize {
        let players = self.players.lock().await;
        players.len()
    }
    pub async fn broadcast(&self, message: ServerMessage) {
        let mut players = self.players.lock().await;
        for player in players.iter_mut() {
            let mut player = player.lock().await;
            let player_id = player.player_id.unwrap();
            if player.connected {
                if let Err(e) = player.send_message(&message).await {
                    drop(player);
                    eprintln!("failed to send message to {:?}: {}", player_id, e);
                    self.disconnect_player(player_id).await;
                }
            }
        }
    }
    pub async fn disconnect_player(&self, player_id: u32) {
        let players = self.players.lock().await;
        let player = players[player_id as usize].clone();
        let mut player = player.lock().await;
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

    pub async fn send_message_to_player(&self, message: ServerMessage, player_id: u32) {
        let players = self.players.lock().await;
        let player: Arc<Mutex<Player>> = players[player_id as usize].clone();
        let mut player = player.lock().await;
        player.send_message(&message).await.unwrap()
    }
    pub async fn add_unit(&mut self, player_id: u32, position: (i32, i32), count: u32) {
        {
            let players = self.players.lock().await;
            let player: Arc<Mutex<Player>> = players[player_id as usize].clone();
            let player = player.lock().await;
            let mut units = player.units.lock().await;
            if let Some(existing_arc) = units.get(&position) {
                println!("Merging units at {:?}", position);
                let mut existing_unit = existing_arc.lock().await;
                existing_unit.count += count;
            } else {
                println!("Adding unit to empty position {:?}", position);
                units.insert(position, Arc::new(Mutex::new(Unit::new(position, count))));
            }
        }
        self.broadcast(ServerMessage::AddUnit { player_id, position_x: position.0, position_y: position.1,count }).await;
    }
    pub async fn move_unit(&self, player_id: u32, from_position: (i32, i32), to_position: (i32, i32)) -> Result<(), &str> {
        {
            println!("Player {player_id} is attempting to move unit from {:?} to {:?}", from_position, to_position);

            let players = self.players.lock().await;
            let player: Arc<Mutex<Player>> = players[player_id as usize].clone();
            let player = player.lock().await;
            let mut units = player.units.lock().await;

            let Some(unit_arc) = units.remove(&from_position) else {
                println!("Unit not found at position {:?}", from_position);
                return Err("unit not found");
            };
            let mut attack = false;

            println!("Unit found. Preparing to move...");
            let unit_clone = unit_arc.clone();
            let mut unit = unit_clone.lock().await;
            unit.position = to_position;
            drop(unit); // Drop early to allow reuse

            // Check for enemy unit
            for (id, other_player_arc) in players.iter().enumerate() { // DO NOT LOOK at this function
                if id as u32 == player_id {
                    continue;
                }

                let other_player = other_player_arc.lock().await;
                let mut other_units = other_player.units.lock().await;

                if let Some(enemy_arc) = other_units.get(&to_position) {
                    println!("Enemy unit detected at {:?}", to_position);
                    let mut enemy_unit = enemy_arc.lock().await;
                    let mut unit = unit_clone.lock().await;

                    println!("FIGHT: Attacker count: {}, Defender count: {}", unit.count, enemy_unit.count);

                    if unit.count > enemy_unit.count {
                        println!("Attacker wins. Remaining count: {}", unit.count - enemy_unit.count);
                        unit.count -= enemy_unit.count;
                        enemy_unit.count = 0;
                        drop(enemy_unit);
                        other_units.remove(&to_position);

                        // Move attacker in
                        drop(unit);
                        self.claim_city(to_position, player_id).await;
                        units.insert(to_position, unit_arc.clone());  // Insert once here
                    } else {
                        println!("Defender survives or tie. Remaining defender count: {}", enemy_unit.count - unit.count);
                        enemy_unit.count -= unit.count;
                        unit.count = 0;
                        // Attacker dies, no insert
                    }
                    attack = true;
                    break; // Exit loop after handling the first enemy unit
                }
            }

            // No enemy found – regular move or merge
            if !attack {
                let unit = unit_clone.lock().await;
                if let Some(existing_arc) = units.get(&to_position) {
                    println!("Merging units at {:?}", to_position);
                    let mut existing_unit = existing_arc.lock().await;
                    existing_unit.count += unit.count;
                } else {
                    println!("Moving unit to empty position {:?}", to_position);
                    drop(unit);
                    self.claim_city(to_position, player_id).await;
                    units.insert(to_position, unit_arc);  // Only insert here if no attack happened
                }
            }
        }

        self.broadcast(ServerMessage::MoveUnit {
            from_position_x: from_position.0,
            from_position_y: from_position.1,
            to_position_x: to_position.0,
            to_position_y: to_position.1,
        }).await;

        println!("Move completed and broadcasted successfully.");
        Ok(())
    }
    pub async fn set_cities(&mut self, cities_pos: Vec<Vector2i>) {
        for pos in cities_pos {
            let key = (pos.x, pos.y);
            let city = Arc::new(Mutex::new(City { owner_id: None, }));
            let _ = self.cities.insert(key, city);
        }
    }
    pub async fn set_ports(&mut self, ports_pos: Vec<Vector2i>) {
        for pos in ports_pos {
            let key = (pos.x, pos.y);
            let port = Arc::new(Mutex::new(Port {}));
            let _ = self.ports.insert(key, port);
        }
    }
    pub async fn claim_city(&self, position: (i32, i32), player_id: u32) {
        match self.cities.get(&position) {
            Some(city) => {
                let mut city = city.lock().await;
                city.owner_id = Some(player_id);
                println!("player {:?} claimed city at {:?}", player_id, position)
            }
            None => {}
        }
    }
    pub async fn start_tick(&self, game_mutex: Arc<Mutex<Game>>) {
        let mut shutdown_rx = self.tick_stopper.subscribe();
        tokio::spawn(async move {
            loop {
                tokio::select! {
                    _ = tokio::time::sleep(Duration::from_secs(TICK_LENGTH)) => {
                        let mut game = game_mutex.lock().await;
                        game.tick().await;
                    }
                    _ = shutdown_rx.changed() => {
                        if *shutdown_rx.borrow() {
                            println!("Game {} background loop stopped", game_mutex.lock().await.game_id);
                            break;
                        }
                    }
                }
            }
        });
    }
    pub async fn stop_tick(&self) {
        let _ = self.tick_stopper.send(true);
    }
    pub async fn tick(&mut self) {
        println!("TICK");
        for city in self.cities .clone(){
            let city_mutex = city.1.lock().await;
            match city_mutex.owner_id {
                Some(pid) => {
                    self.add_unit(pid, city.0, 1).await;
                }
                _ => {}
            }
        }
    }
}
impl Unit {
    pub fn new(position: (i32, i32), count: u32) -> Self {
        Self { position, count }
    }
}

