// Embeds the Windows version resource so the exe carries product metadata in
// the file properties dialog. Version numbers come from Cargo.toml, so the
// resource always matches the crate version. Non-Windows targets skip it.

use std::env;

fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=Cargo.toml");

    if env::var("CARGO_CFG_TARGET_OS").as_deref() != Ok("windows") {
        return;
    }

    let mut res = tauri_winres::WindowsResource::new();
    res.set_language(0x0409)
        .set(
            "FileDescription",
            "foton-handoff - agent memory handoff CLI",
        )
        .set("ProductName", "foton-handoff")
        .set("CompanyName", "foton-handoff")
        .set("LegalCopyright", "Copyright (c) foton-handoff contributors")
        .set("OriginalFilename", "foton-handoff.exe")
        .set("InternalName", "foton-handoff")
        .set("Comments", "Chained project handoff memory for LLM agents");

    if let Err(e) = res.compile() {
        panic!("failed to embed Windows version resource: {e}");
    }
}
