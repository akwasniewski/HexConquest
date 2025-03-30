use axum::{
    body::Bytes,
    extract::ws::{Message, Utf8Bytes, WebSocket, WebSocketUpgrade},
    response::IntoResponse,
    routing::any,
    Router,
};
use axum_extra::TypedHeader;

use std::ops::ControlFlow;
use std::{net::SocketAddr, path::PathBuf};
use tower_http::{
    services::ServeDir,
    trace::{DefaultMakeSpan, TraceLayer},
};

use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

//allows to extract the IP of connecting user
use axum::extract::connect_info::ConnectInfo;
use axum::extract::ws::CloseFrame;

//allows to split the websocket stream into separate TX and RX branches
use futures::{sink::SinkExt, stream::StreamExt};

use tokio::sync::Mutex;
use std::sync::Arc;

mod logic;

use logic::{Game,Player};

#[tokio::main]
async fn main() {
    let game:Arc<Mutex<Game>> = Arc::new(Mutex::new(Game::new(1)));
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
        .route("/ws", any(|ws, user_agent, addr| {ws_handler(ws, user_agent, addr, game)}))
        // logging so we can see what's going on
        .layer(
            TraceLayer::new_for_http()
                .make_span_with(DefaultMakeSpan::default().include_headers(true)),
        );

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

/// The handler for the HTTP request (this gets called when the HTTP request lands at the start
/// of websocket negotiation). After this completes, the actual switching from HTTP to
/// websocket protocol will occur.
/// This is the last point where we can extract TCP/IP metadata such as IP address of the client
/// as well as things from HTTP headers such as user-agent of the browser etc.
async fn ws_handler(
    ws: WebSocketUpgrade,
    user_agent: Option<TypedHeader<headers::UserAgent>>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    game: Arc<Mutex<Game>>,
) -> impl IntoResponse {
    let user_agent = if let Some(TypedHeader(user_agent)) = user_agent {
        user_agent.to_string()
    } else {
        String::from("Unknown browser")
    };
    println!("`{user_agent}` at {addr} connected.");
    // finalize the upgrade process by returning upgrade callback.
    // we can customize the callback by sending additional info such as address.
    ws.on_upgrade(move |socket| handle_socket(socket, addr, game))
}

/// Actual websocket statemachine (one will be spawned per connection)
async fn handle_socket(mut socket: WebSocket, who: SocketAddr, game: Arc<Mutex<Game>>) {
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
    if let Some(msg) = socket.recv().await {
        let game = Arc::clone(&game);
        if let Ok(msg) = msg {
            if process_message(msg, who, game.clone()).await.is_break() {
                return;
            }
        } else {
            println!("client {who} abruptly disconnected");
            return;
        }
    }
    // By splitting socket we can send and receive at the same time. In this example we will send
    // unsolicited messages to client based on some sort of server's internal event (i.e .timer).
    let (sender, mut receiver) = socket.split();
    let mut game_lock = game.lock().await;
    let username = "username";
    let player_id = game_lock.player_count().await;
    let player = Player::new(player_id,username.to_string(), sender);
    game_lock.add_player(player).await;
    game_lock.broadcast(format!("New player {:?}, {:?} has joined",player_id, username).as_str()).await;
    drop(game_lock);
    // Spawn a task that will push several messages to the client (does not matter what client does)
    // let mut send_task = tokio::spawn(async move {
    //     let n_msg = 20;
    //     for i in 0..n_msg {
    //         // In case of any websocket error, we exit.
    //         if sender
    //             .send(Message::Text(format!("Server message {i} ...").into()))
    //             .await
    //             .is_err()
    //         {
    //             return i;
    //         }
    //     }
    //
    //     println!("Sending close to {who}...");
    //     if let Err(e) = sender
    //         .send(Message::Close(Some(CloseFrame {
    //             code: axum::extract::ws::close_code::NORMAL,
    //             reason: Utf8Bytes::from_static("Goodbye"),
    //         })))
    //         .await
    //     {
    //         println!("Could not send Close due to {e}, probably it is ok?");
    //     }
    //     n_msg
    // });

    // This second task will receive messages from client and print them on server console
    let mut recv_task = tokio::spawn({
    let game= Arc::clone(&game);
        async move {
            while let Some(Ok(msg)) = receiver.next().await {
                // print message and break if instructed to do so
                if process_message(msg, who, game.clone()).await.is_break() {
                    break;
                }
            }
        }
    });
    let _ = recv_task.await;
    // returning from the handler closes the websocket connection
    let mut game_lock = game.lock().await;
    game_lock.disconnect_player(player_id).await;
}

/// helper to print contents of messages to stdout. Has special treatment for Close.
async fn process_message(msg: Message, who: SocketAddr, game: Arc<Mutex<Game>>) -> ControlFlow<(), ()> {
    match msg {
        Message::Text(t) => {
            println!(">>> {who} sent str: {t:?}");
            let mut game_lock = game.lock().await;
            game_lock.broadcast(t.as_str()).await;
        }
        Message::Binary(d) => {
            println!(">>> {} sent {} bytes: {:?}", who, d.len(), d);
            let mut game_lock = game.lock().await;
            game_lock.broadcast(format!("Player sent {:?}", d).as_str()).await;
        }
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