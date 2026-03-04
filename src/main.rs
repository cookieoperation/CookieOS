use dioxus::prelude::*;
use std::process::Command;
use serde::Deserialize;
use reqwest;

#[derive(Debug, Clone, Deserialize, PartialEq)]
struct WeatherPoints {
    properties: WeatherPointsProperties,
}

#[derive(Debug, Clone, Deserialize, PartialEq)]
struct WeatherPointsProperties {
    forecast: String,
}

#[derive(Debug, Clone, Deserialize, PartialEq)]
struct Forecast {
    properties: ForecastProperties,
}

#[derive(Debug, Clone, Deserialize, PartialEq)]
struct ForecastProperties {
    periods: Vec<ForecastPeriod>,
}

#[derive(Debug, Clone, Deserialize, PartialEq)]
struct ForecastPeriod {
    name: String,
    temperature: i32,
    shortForecast: String,
}

fn main() {
    launch(app);
}

fn app() -> Element {
    let mut show_launcher = use_signal(|| false);
    let mut location = use_signal(|| "38.8894,-77.0352".to_string()); // DC Default
    let mut weather_data = use_signal(|| ("--".to_string(), "Loading...".to_string()));

    // Weather Fetcher
    let _ = use_resource(move || async move {
        let loc = location();
        let client = reqwest::Client::builder()
            .user_agent("CookieOS/1.0")
            .build()
            .ok()?;
        
        let points_url = format!("https://api.weather.gov/points/{}", loc);
        let resp = client.get(&points_url).send().await.ok()?.json::<WeatherPoints>().await.ok()?;
        let forecast_resp = client.get(&resp.properties.forecast).send().await.ok()?.json::<Forecast>().await.ok()?;
        
        if let Some(period) = forecast_resp.properties.periods.first() {
            weather_data.set((format!("{}°", period.temperature), period.shortForecast.clone()));
        }
        Some(())
    });

    rsx! {
        style { {include_str!("style.css")} }
        div { class: "app-container",
            TopBar {}

            div { class: "workspace",
                if show_launcher() {
                    LauncherPopup { on_close: move |_| show_launcher.set(false) }
                }

                if !show_terminal() {
                    HomeScreen { 
                        on_ai_click: move |_| show_terminal.set(true),
                        mascot_path: "bot_mascot.png"
                    }
                } else {
                    AiTerminal { on_home_click: move |_| show_terminal.set(false) }
                }
            }

            BottomNav { 
                on_home: move |_| { show_terminal.set(false); show_launcher.set(false); },
                on_launcher: move |_| show_launcher.toggle(),
                on_switcher: move |_| {}
            }
        }
    }
}

#[component]
fn SettingsView(location: Signal<String>) -> Element {
    rsx! {
        div { class: "settings-view",
            h2 { "Location Settings" }
            p { "Enter Lat,Lon for NWS Weather" }
            input { 
                class: "location-input",
                value: "{location}",
                oninput: move |evt| location.set(evt.value()),
                placeholder: "38.8894,-77.0352"
            }
        }
    }
}

#[component]
fn LauncherPopup(on_close: EventHandler<MouseEvent>) -> Element {
    rsx! {
        div { class: "launcher-overlay", onclick: on_close,
            div { class: "launcher-card", onclick: |e| e.stop_propagation(),
                div { class: "app-grid",
                    for app in [("Settings", "settings.png"), ("Files", "📦"), ("Terminal", "terminal.png"), ("Chrome", "chrome.png"), ("Camera", "📷"), ("Play Store", "📦")] {
                        div { 
                            class: "app-item",
                            onclick: move |_| {
                                if app.0 == "Settings" {
                                    // Launch the Kotlin Android App via Waydroid
                                    Command::new("waydroid")
                                        .arg("app")
                                        .arg("launch")
                                        .arg("com.cookieos.settings")
                                        .spawn()
                                        .ok();
                                }
                            },
                            div { class: "app-icon-circle",
                                if app.1.ends_with(".png") {
                                    img { src: "icons/{app.1}", width: "48" }
                                } else {
                                    span { "{app.1}" }
                                }
                            }
                            span { "{app.0}" }
                        }
                    }
                }
                // Location Settings at bottom of launcher
                div { class: "launcher-footer",
                    span { "📍" }
                    input { 
                        class: "launcher-loc-input",
                        placeholder: "Lat,Lon (e.g. 34.05,-118.24)",
                        value: "{location}",
                        oninput: move |evt| location.set(evt.value())
                    }
                }
            }
        }
    }
}

#[component]
fn TopBar() -> Element {
    rsx! {
        div { class: "top-bar",
            span { "12:35 PM" }
            div { class: "spacer" }
            div { class: "status-icons",
                // Reactive Mac-style Cellular (4 bars)
                svg { width: "20", height: "16", viewBox: "0 0 20 16", class: "status-icon-mac",
                    rect { x: "0", y: "10", width: "3", height: "6", rx: "1", fill: "currentColor" }
                    rect { x: "5", y: "7", width: "3", height: "9", rx: "1", fill: "currentColor" }
                    rect { x: "10", y: "4", width: "3", height: "12", rx: "1", fill: "currentColor" }
                    rect { x: "15", y: "0", width: "3", height: "16", rx: "1", fill: "currentColor" }
                }
                // Reactive Mac-style Battery
                svg { width: "25", height: "14", viewBox: "0 0 25 14", class: "status-icon-mac",
                    // Shell
                    rect { x: "0", y: "0", width: "22", height: "14", rx: "3", fill: "none", stroke: "currentColor", stroke_width: "1.5" }
                    // Tip
                    path { d: "M23 4.5v5", fill: "none", stroke: "currentColor", stroke_width: "1.5", stroke_linecap: "round" }
                    // Fill (98%)
                    rect { x: "2.5", y: "2.5", width: "17", height: "9", rx: "1", fill: "currentColor" }
                }
                span { class: "battery-percent", "98%" }
            }
        }
    }
}

#[component]
fn BottomNav(on_home: EventHandler<MouseEvent>, on_launcher: EventHandler<MouseEvent>, on_switcher: EventHandler<MouseEvent>) -> Element {
    rsx! {
        div { class: "bottom-nav",
            div { class: "nav-content",
                // App Launcher (Aluminum Cookie)
                button { class: "nav-btn-launcher", onclick: on_launcher, 
                    img { src: "icons/launcher_cookie.png", width: "32" }
                }
                // Home (3D Mascot Bot)
                button { class: "nav-btn", onclick: on_home, 
                    img { src: "icons/bot_mascot.png", width: "36", style: "border-radius: 50%;" }
                }
                // Switcher (Premium SVG)
                button { class: "nav-btn switcher-btn", onclick: on_switcher, 
                    svg { width: "24", height: "24", viewBox: "0 0 24 24", fill: "currentColor",
                        rect { x: "2", y: "4", width: "16", height: "12", rx: "2" }
                        path { d: "M22 18h-2v-12h-12v-2h14z" }
                    }
                }
            }
            div { class: "gesture-pill" }
        }
    }
}

#[component]
fn HomeScreen(on_ai_click: EventHandler<MouseEvent>, mascot_path: String) -> Element {
    rsx! {
        div { class: "desktop-view",
            // Center Branding
            div { class: "hero-branding",
                div { class: "ribbon-container",
                    div { class: "ribbon-ring" }
                    img { src: "{mascot_path}", width: "140" }
                }
                h1 { "Sunday, Mar 1" }
                p { "☀️ 72°F • CookieOS" }
            }

            // Scattered Widgets
            Widget { 
                title: "Local Weather", value: "{weather_data().0}", footer: "{weather_data().1}", 
                class: "widget-scattered w-pos-1" 
            }
            Widget { 
                title: "Battery", value: "98%", footer: "Plugged in", 
                class: "widget-scattered w-pos-2" 
            }
            Widget { 
                title: "AI Core", value: "Ready", footer: "AOSP Smashed", 
                class: "widget-scattered w-pos-3",
                on_click: on_ai_click
            }
        }
    }
}

#[component]
fn WidgetCard(title: String, icon: String, value: String, footer: String) -> Element {
    rsx! {
        div { class: "widget-card",
            div { class: "card-header", span { "{icon}" }, span { "{title}" } }
            div { class: "card-value", "{value}" }
            div { class: "card-footer", "{footer}" }
        }
    }
}

#[component]
fn AiTerminal(on_home_click: EventHandler<MouseEvent>) -> Element {
    let mut terminal_output = use_signal(|| "Welcome to the JSX Native Fusion Shell.\nAndroid and Linux systems are online.\nNative Binder / Ashmem drivers initialized.\nUI powered by Rust + Dioxus (RSX).".to_string());
    let mut current_input = use_signal(|| String::new());

    let run_command = move |_| {
        let prompt = current_input();
        if prompt.is_empty() { return; }
        
        // Call the Python AI Shell for translation
        let output = Command::new("ai-shell")
            .arg(&prompt)
            .output();

        match output {
            Ok(cmd_output) => {
                let translated_cmd = String::from_utf8_lossy(&cmd_output.stdout).trim().to_string();
                let history = terminal_output();
                terminal_output.set(format!("{}\n~$ {}\n[Executing: {}]", history, prompt, translated_cmd));
                
                // Execute the translated command
                let exec_result = Command::new("sh")
                    .arg("-c")
                    .arg(&translated_cmd)
                    .output();
                
                if let Err(e) = exec_result {
                    let history = terminal_output();
                    terminal_output.set(format!("{}\nError: {}", history, e));
                }
            }
            Err(e) => {
                let history = terminal_output();
                terminal_output.set(format!("{}\nTranslation Error: {}", history, e));
            }
        }
        current_input.set(String::new());
    };

    rsx! {
        div { class: "terminal-view",
            div { class: "terminal-header", "ALUMINUM JSX AI CORE" }
            div { class: "terminal-body",
                pre { "{terminal_output}" }
            }
            div { class: "terminal-input-row",
                span { "~$" }
                input { 
                    class: "terminal-input", 
                    autofocus: true,
                    placeholder: "Enter command...",
                    value: "{current_input}",
                    oninput: move |evt| current_input.set(evt.value()),
                    onkeydown: move |evt| {
                        if evt.key() == Key::Enter {
                            run_command(());
                        }
                    }
                }
            }
        }
    }
}
