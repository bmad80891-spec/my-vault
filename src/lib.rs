pub mod core;

#[cfg(target_os = "android")]
pub mod bridge;

pub mod ui;

#[cfg(target_os = "android")]
pub use bridge::KeyboardBridgeHub;

#[cfg(not(target_os = "android"))]
pub fn start() -> eframe::Result<()> {
    let options = eframe::NativeOptions::default();
    eframe::run_native(
        "my_vault_rs",
        options,
        Box::new(|_cc| Ok(Box::new(ui::auth_view::AppState::default()))),
    )
}

