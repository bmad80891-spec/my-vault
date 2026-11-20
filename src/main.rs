fn main() -> eframe::Result<()> {
    #[cfg(not(target_os = "android"))]
    {
        my_vault_rs::start()
    }
    #[cfg(target_os = "android")]
    {
        Ok(())
    }
}
