use eframe::egui;

#[derive(Default)]
pub struct SettingsViewState {
    #[cfg(target_os = "android")]
    pub bridge_port: String,
    #[cfg(target_os = "android")]
    pub bridge_running: bool,
    #[cfg(target_os = "android")]
    bridge: Option<crate::bridge::KeyboardBridgeHub>,
    pub status: String,
}

impl SettingsViewState {
    pub fn ui(&mut self, ui: &mut egui::Ui) {
        ui.heading("Settings");
        ui.add_space(8.0);

        #[cfg(target_os = "android")]
        {
            self.android_keyboard_bridge_ui(ui);
        }

        #[cfg(not(target_os = "android"))]
        {
            ui.group(|ui| {
                ui.label("Keyboard bridge");
                ui.label(
                    "Companion keyboard-bridge hub is available only on Android mobile builds. \
Desktop keyboard-bridge endpoints are disabled/omitted.",
                );
            });
        }

        ui.add_space(8.0);
        ui.group(|ui| {
            ui.label("Authenticator capture");
            ui.label("Camera/webcam QR scanning is removed on all platforms.");
            ui.label("Use image-file QR import (all platforms) or desktop window/region capture (Windows/Linux).");
        });
    }

    #[cfg(target_os = "android")]
    fn android_keyboard_bridge_ui(&mut self, ui: &mut egui::Ui) {
        ui.group(|ui| {
            ui.label("Keyboard bridge (Android only)");
            ui.label("Local companion keyboard-bridge hub for mobile keyboard paste integration.");
            if self.bridge_port.is_empty() {
                self.bridge_port = "8765".to_string();
            }
            ui.horizontal(|ui| {
                ui.label("Port");
                ui.text_edit_singleline(&mut self.bridge_port);
            });
            let running = self.bridge.as_ref().map(|b| b.is_running()).unwrap_or(false);
            ui.label(if running { "Status: running" } else { "Status: stopped" });
            ui.horizontal(|ui| {
                if ui.button("Start hub").clicked() {
                    let port = self.bridge_port.parse::<u16>().unwrap_or(8765);
                    let hub = crate::bridge::KeyboardBridgeHub::new(port);
                    match hub.start() {
                        Ok(()) => {
                            self.status = format!("Android keyboard-bridge hub started on 127.0.0.1:{port}.");
                            self.bridge = Some(hub);
                        }
                        Err(e) => {
                            self.status = format!("Failed to start keyboard-bridge hub: {e}");
                        }
                    }
                }
                if ui.button("Stop hub").clicked() {
                    if let Some(hub) = self.bridge.take() {
                        hub.stop();
                    }
                    self.status = "Android keyboard-bridge hub stopped.".into();
                }
            });
        });
        if !self.status.is_empty() {
            ui.label(&self.status);
        }
    }
}
