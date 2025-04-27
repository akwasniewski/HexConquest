use axum::{
    body::Bytes,
    extract::ws::{Message, Utf8Bytes, WebSocket, WebSocketUpgrade},
    response::IntoResponse,
    routing::any,
    Router,
};
use axum_extra::TypedHeader;
use tokio_util::sync::CancellationToken;
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

//allows to extract the IP of connecting user
use axum::extract::connect_info::ConnectInfo;
use axum::extract::ws::CloseFrame;

//allows to split the websocket stream into separate TX and RX branches
use futures::{sink::SinkExt, stream::StreamExt};

use tokio::sync::Mutex;
use std::sync::Arc;
use std::time::Duration;
use tokio::time::sleep;

mod logic;

use logic::{Game,Player};

mod messages; 
use messages::{ClientMessage, ServerMessage};

#[tokio::main]
async fn main() {
    // Configure CORS
    let cors = CorsLayer::new()
        .allow_origin(Any) // Allows all origins (use .allow_origin("http://your-godot-game.com") for specific domains)
        .allow_methods(Any) // Allows all methods (GET, POST, etc.)
        .allow_headers(Any); // Allows all headers
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

    // build our application with some routes
    let app = Router::new()
        .fallback_service(ServeDir::new(assets_dir).append_index_html_on_directories(true))
        .route("/ws", any(|ws, user_agent, addr| {ws_handler(ws, user_agent, addr, games)}))
        // logging so we can see what's going on
        .layer(
            TraceLayer::new_for_http()
                .make_span_with(DefaultMakeSpan::default().include_headers(true)),
        ).layer(cors);

    // run it with hyper
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
    // finalize the upgrade process by returning upgrade callback.
    // we can customize the callback by sending additional info such as address.
    ws.on_upgrade(move |socket| handle_socket(socket, addr, games))
}

/// Actual websocket statemachine (one will be spawned per connection)
async fn handle_socket(mut socket: WebSocket, who: SocketAddr, games: Arc<Mutex<HashMap<u32, Arc<Mutex<Game>>>>>) {
    // send a ping (unsupported by some browsers) just to kick things off and get a response
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
    let cancel_token = CancellationToken::new();
    let recv_token = cancel_token.clone();
    let player : Arc<Mutex<Player>> = Arc::new(Mutex::new(Player::new(sender,cancel_token)));

    let mut recv_task = tokio::spawn({
        async move {
            tokio::select! {
            _ = recv_token.cancelled() => {
                println!("Receive task was cancelled!");
            }
            _ = async {
                while let Some(Ok(msg)) = receiver.next().await {
                    if process_message(msg, player.clone(), games.clone()).await.is_break() {
                        break;
                    }
                }
            } => {}
        }
        }
    });
    let _ = recv_task.await;
}

async fn process_message(msg: Message, player: Arc<Mutex<Player>>, games: Arc<Mutex<HashMap<u32, Arc<Mutex<Game>>>>>) -> ControlFlow<(), ()> {
    let mut player_lock = player.lock().await;
    let who = player_lock.username.clone().unwrap_or_else(|| "Unknown".to_string());
    drop(player_lock);
    match msg {
        Message::Text(t) => {
            match serde_json::from_str::<ClientMessage>(&t){
                Ok(client_msg) => {
                    match client_msg {
                        ClientMessage::CreateGame { username } => {
                            let game_id: u32 = rng().random();
                            let mut games = games.lock().await;
                            games.insert(game_id, Arc::new(Mutex::new(Game::new(game_id))));
                            let game: Arc<Mutex<Game>> = games[&game_id].clone();
                            drop(games);
                            let mut game = game.lock().await;
                            let player_id = game.add_player(player.clone()).await;
                            let mut player = player.lock().await;
                            player.set_credentials(username.clone(), player_id);
                            player.send_message(&ServerMessage::GameCreated { player_id, game_id }).await.expect("failed to send message");
                            drop(player);
                            game.broadcast(ServerMessage::PlayerJoined { player_id, username: username.clone() }).await;
                            drop(game);

                            println!("Player {username} created a game with id {game_id}")
                        }
                        ClientMessage::JoinGame { username, game_id } => {
                            let games = games.lock().await;
                            match games.get(&game_id) {
                                Some(game) => {
                                    let mut game = game.lock().await;
                                    let player_id: u32 = game.add_player(player.clone()).await;
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
                                    player.send_message(&ServerMessage::Error {
                                        message: format!("Game {game_id} does not exist"),
                                    }).await.expect("failed to send error message");
                                    player.disconnect();
                                    println!("Player {username} tried to join non-existing game {game_id}");
                                }
                            }
                        }
                        ClientMessage::StartGame { game_id } => {
                            let games = games.lock().await;
                            match games.get(&game_id) {
                                Some(game) => {
                                    let mut game = game.lock().await;
                                    let map_seed: u32 = rng().random();
                                    game.broadcast(ServerMessage::StartGame { map_seed }).await;
                                    drop(game);
                                    println!("Game {game_id} started");
                                }
                                None => {}
                            }
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
    ControlFlow::Continue(())
}
