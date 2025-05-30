use axum::{
    body::Bytes,
    extract::ws::{Message, WebSocket, WebSocketUpgrade},
    response::IntoResponse,
    routing::any,
    Router,
};
use axum_extra::TypedHeader;
use std::ops::ControlFlow;
use std::{net::SocketAddr, path::PathBuf};
use std::collections::HashMap;
use rand::{Rng, rng};
use tower_http::{
    services::ServeDir,
    trace::{DefaultMakeSpan, TraceLayer},
    cors::{Any, CorsLayer},
};

use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use axum::extract::connect_info::ConnectInfo;
use futures::stream::StreamExt;

use tokio::sync::Mutex;
use std::sync::Arc;

mod logic;

use logic::{Game,Player};

mod messages; 
use messages::{ClientMessage, ServerMessage};
const DEFAULT_COUNT_OF_UNIT: u32 = 10;
#[tokio::main]
async fn main() {
    let cors = CorsLayer::new()
        .allow_origin(Any) 
        .allow_methods(Any) 
        .allow_headers(Any); 
    let games:Arc<Mutex<HashMap<u32, Arc<Mutex<Game>>>>> = Arc::new(Mutex::new(HashMap::new()));
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| {
                format!("{}=debug,tower_http=debug", env!("CARGO_CRATE_NAME")).into()
            }),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    let assets_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("assets");

    let app = Router::new()
        .fallback_service(ServeDir::new(assets_dir).append_index_html_on_directories(true))
        .route("/ws", any(|ws, user_agent, addr| {ws_handler(ws, user_agent, addr, games)}))
        .layer(
            TraceLayer::new_for_http()
                .make_span_with(DefaultMakeSpan::default().include_headers(true)),
        ).layer(cors);

    let listener = tokio::net::TcpListener::bind("127.0.0.1:7777")
        .await
        .unwrap();
    tracing::debug!("listening on {}", listener.local_addr().unwrap());
    axum::serve(
        listener,
        app.into_make_service_with_connect_info::<SocketAddr>(),
    )
    .await
    .unwrap();
}
async fn ws_handler(
    ws: WebSocketUpgrade,
    user_agent: Option<TypedHeader<headers::UserAgent>>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    games: Arc<Mutex<HashMap<u32, Arc<Mutex<Game>>>>>,
) -> impl IntoResponse {
    let user_agent = if let Some(TypedHeader(user_agent)) = user_agent {
        user_agent.to_string()
    } else {
        String::from("Unknown browser")
    };
    println!("`{user_agent}` at {addr} connected.");
    ws.on_upgrade(move |socket| handle_socket(socket, addr, games))
}

async fn handle_socket(mut socket: WebSocket, who: SocketAddr, games: Arc<Mutex<HashMap<u32, Arc<Mutex<Game>>>>>) {
    if socket
        .send(Message::Ping(Bytes::from_static(&[1, 2, 3])))
        .await
        .is_ok()
    {
        println!("Pinged {who}...");
    } else {
        println!("Could not send ping {who}!");
        return;
    }

    let (sender, mut receiver) = socket.split();
    let player : Arc<Mutex<Player>> = Arc::new(Mutex::new(Player::new(sender)));
    let recv_task = tokio::spawn({
    async move{
        let mut player_id: Option<u32>=None;
        let mut game: Option<Arc<Mutex<Game>>>=None;
        while let Some(Ok(msg)) = receiver.next().await {
            match process_message(msg, player.clone(), games.clone(), game, player_id).await {
                ControlFlow::Continue((new_game, new_player_id)) => {
                    game=new_game;
                    player_id=new_player_id;
                }
                ControlFlow::Break(()) => {
                    break;
                }
            }
        } 

    }
    });
    let _ = recv_task.await;
}

async fn process_message(msg: Message, player: Arc<Mutex<Player>>, games: Arc<Mutex<HashMap<u32, Arc<Mutex<Game>>>>>, mut game:Option<Arc<Mutex<Game>>>, mut player_id:  Option<u32>) -> ControlFlow<(),(Option<Arc<Mutex<Game>>>, Option<u32>)> {
    let who = player_id.unwrap_or(1);
    match msg {
        Message::Text(t) => {
            match serde_json::from_str::<ClientMessage>(&t){
                Ok(client_msg) => {
                    match client_msg {
                        ClientMessage::CreateGame { username } => {
                            let game_id: u32 = rng().random_range(0..1000);
                            let mut games_mutex = games.lock().await;
                            games_mutex.insert(game_id, Arc::new(Mutex::new(Game::new(game_id))));
                            game= Some(games_mutex[&game_id].clone());
                            let game=game.clone().unwrap();
                            let game_clone = game.clone();
                            drop(games_mutex);
                            let mut game_mutex = game_clone.lock().await; 
                            player_id = Some(game_mutex.add_player(player.clone()).await);
                            let player_id = player_id.unwrap();
                            let mut player = player.lock().await;
                            player.set_credentials(username.clone(), player_id);
                            player.send_message(&ServerMessage::GameCreated { player_id, game_id }).await.expect("failed to send message");
                            drop(player);
                            game_mutex.broadcast(ServerMessage::PlayerJoined { player_id, username: username.clone() }).await;
                            game_mutex.start_tick(game, games.clone()).await;

                            println!("Player {username} created a game with id {game_id}")
                        }
                        ClientMessage::JoinGame { username, game_id } => {
                            let games = games.lock().await;
                            match games.get(&game_id) {
                                Some(new_game) => {
                                    game = Some(new_game.clone());
                                    let game = game.clone().unwrap();
                                    let mut game = game.lock().await;
                                    player_id = Some(game.add_player(player.clone()).await);
                                    let player_id = player_id.unwrap();
                                    let mut player = player.lock().await;
                                    player.set_credentials(username.clone(), player_id);
                                    player.send_message(&ServerMessage::GameJoined { player_id, game_id }).await.expect("failed to send message");
                                    drop(player);
                                    game.send_active_players(player_id).await;
                                    game.broadcast(ServerMessage::PlayerJoined { player_id, username: username.clone() }).await;
                                    drop(game);
                                    println!("Player {username} joined game {game_id}");
                                }
                                None => {
                                    let mut player = player.lock().await;
                                    player.disconnect();
                                    println!("Player {username} tried to join non-existing game {game_id}");
                                }
                            }
                        }
                        ClientMessage::StartGame => {
                            let game = game.clone().unwrap();
                            let game_mutex = game.clone();
                            let game_mutex = game_mutex.lock().await;
                            let map_seed: u32 = rng().random();
                            game_mutex.broadcast(ServerMessage::StartGame { map_seed }).await;
                            println!("Game {:?} started", game_mutex.game_id);
                        }                        
                        ClientMessage::AddUnit {position_x, position_y} => {
                            let game = game.clone().unwrap();
                            let mut game = game.lock().await;
                            let player_id = player_id.unwrap();
                            game.add_unit(player_id, (position_x, position_y), DEFAULT_COUNT_OF_UNIT).await;
                            println!("{who} added a unit at {position_x}, {position_y}");
                        }
                        ClientMessage::MoveUnit {from_position_x, from_position_y, to_position_x, to_position_y } => {
                            let game = game.clone().unwrap();
                            let game = game.lock().await;
                            let player_id = player_id.unwrap();
                            match game.move_unit(player_id, (from_position_x, from_position_y), (to_position_x, to_position_y)).await{
                                Ok(()) => {}
                                Err(err) => {
                                    eprintln!("Error: {:?}", err);
                                }
                            } 
                        }
                        ClientMessage::SendCities {cities}=>{
                            let game = game.clone().unwrap();
                            let mut game = game.lock().await;
                            game.set_cities(cities).await;
                        }
                        ClientMessage::SendPorts {ports}=>{
                            let game = game.clone().unwrap();
                            let mut game = game.lock().await;
                            game.set_ports(ports).await;
                        }
                    }
                }
                Err(err) => {
                    println!("Failed to parse message from {}: {:?}", who, err);
                }

            }
        }
        Message::Binary(_) => todo!(),
        Message::Close(c) => {
            if let Some(cf) = c {
                println!(
                    ">>> {} sent close with code {} and reason `{}`",
                    who, cf.code, cf.reason
                );
            } else {
                println!(">>> {who} somehow sent close message without CloseFrame");
            }
            return ControlFlow::Break(());
        }
        Message::Pong(v) => {
            println!(">>> {who} sent pong with {v:?}");
        }
        Message::Ping(v) => {
            println!(">>> {who} sent ping with {v:?}");
        }
    }
    ControlFlow::Continue((game, player_id))
}
