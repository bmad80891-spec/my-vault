//! Companion keyboard-bridge hub.
//!
//! Exposed only on Android mobile builds. Desktop targets do not compile or expose
//! keyboard-bridge endpoints, keeping keyboard paste integration mobile-only.

#![cfg(target_os = "android")]

use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc, Mutex,
};
use std::thread;
use std::time::Duration;

/// Android-only local keyboard-bridge hub for companion keyboard paste integration.
///
/// This hub is intentionally unavailable on desktop targets (Windows/Linux), where the
/// module/endpoints are omitted at compile time.
#[derive(Debug)]
pub struct KeyboardBridgeHub {
    running: Arc<AtomicBool>,
    port: u16,
    worker: Mutex<Option<thread::JoinHandle<()>>>,
}

impl KeyboardBridgeHub {
    /// Create a stopped hub bound to localhost on the given port.
    pub fn new(port: u16) -> Self {
        Self {
            running: Arc::new(AtomicBool::new(false)),
            port,
            worker: Mutex::new(None),
        }
    }

    /// Start the Android-only keyboard-bridge endpoint.
    pub fn start(&self) -> std::io::Result<()> {
        if self.running.swap(true, Ordering::SeqCst) {
            return Ok(());
        }
        let listener = TcpListener::bind(("127.0.0.1", self.port))?;
        listener.set_nonblocking(true)?;
        let running = Arc::clone(&self.running);
        let handle = thread::spawn(move || {
            while running.load(Ordering::SeqCst) {
                match listener.accept() {
                    Ok((mut stream, _addr)) => {
                        let _ = handle_client(&mut stream);
                    }
                    Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                        thread::sleep(Duration::from_millis(50));
                    }
                    Err(_) => {
                        thread::sleep(Duration::from_millis(100));
                    }
                }
            }
        });
        *self.worker.lock().expect("bridge worker lock") = Some(handle);
        Ok(())
    }

    /// Stop the Android-only keyboard-bridge endpoint.
    pub fn stop(&self) {
        self.running.store(false, Ordering::SeqCst);
        if let Some(handle) = self.worker.lock().expect("bridge worker lock").take() {
            let _ = handle.join();
        }
    }

    pub fn is_running(&self) -> bool {
        self.running.load(Ordering::SeqCst)
    }

    pub fn port(&self) -> u16 {
        self.port
    }
}

fn handle_client(stream: &mut TcpStream) -> std::io::Result<()> {
    let _ = stream.set_read_timeout(Some(Duration::from_secs(2)));
    let mut buf = [0u8; 512];
    let n = stream.read(&mut buf).unwrap_or(0);
    let req = String::from_utf8_lossy(&buf[..n]);
    let body = if req.contains("\"cmd\":\"ping\"") {
        "{\"status\":\"ok\",\"platform\":\"android\",\"keyboard_bridge\":true}"
    } else {
        "{\"status\":\"ok\",\"keyboard_bridge\":true}"
    };
    let resp = format!(
        "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
        body.len(),
        body
    );
    stream.write_all(resp.as_bytes())?;
    stream.flush()
}
