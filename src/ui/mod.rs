use eframe::egui;

pub mod auth_view;
pub mod settings_view;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Screen {
    Authenticator,
    Settings,
}
