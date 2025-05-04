use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize)]
#[serde(tag = "type", content = "payload")]
pub enum ClientMessage {
    JoinGame { username: String, game_id: u32 },
    CreateGame {username: String},
    StartGame,
    AddUnit{position_x: i32, position_y: i32},
    MoveUnit{unit_id: u32, position_x: i32, position_y: i32},
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(tag = "type", content = "payload")]
pub enum ServerMessage {
    GameJoined { player_id: u32, game_id: u32},
    GameCreated {player_id: u32, game_id: u32},
    PlayerJoined {player_id: u32, username: String},
    ActivePlayersList {
        players: Vec<PlayerInfo>,
    },
    StartGame{map_seed: u32},
    AddUnit{player_id: u32, unit_id: u32, position_x: i32, position_y: i32},
    MoveUnit{unit_id: u32, position_x: i32, position_y: i32},
}
#[derive(Serialize, Deserialize, Debug)]
pub struct PlayerInfo {
    pub(crate) player_id: u32,
    pub(crate) username: String,
}
