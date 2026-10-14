//! Shared helpers, fixtures, and telemetry utilities for Zenith-Shell integration tests and benchmarks.

use std::time::Duration;

/// Telemetry metrics for latency benchmarking.
#[derive(Debug, Clone)]
pub struct LatencyMetrics {
    pub count: usize,
    pub min: Duration,
    pub max: Duration,
    pub avg: Duration,
    pub p95: Duration,
    pub p99: Duration,
}

impl LatencyMetrics {
    /// Computes statistical metrics from a slice of durations.
    pub fn compute(mut durations: Vec<Duration>) -> Self {
        assert!(!durations.is_empty(), "Durations slice cannot be empty");
        durations.sort();

        let count = durations.len();
        let total: Duration = durations.iter().sum();
        let avg = total / (count as u32);
        let min = durations[0];
        let max = durations[count - 1];

        let p95_idx = ((count as f64) * 0.95).floor() as usize;
        let p95 = durations[p95_idx.min(count - 1)];

        let p99_idx = ((count as f64) * 0.99).floor() as usize;
        let p99 = durations[p99_idx.min(count - 1)];

        Self {
            count,
            min,
            max,
            avg,
            p95,
            p99,
        }
    }

    /// Prints a human-readable telemetry report to stdout.
    pub fn print_report(&self, benchmark_name: &str) {
        println!("┌─────────────────────────────────────────────────────────────┐");
        println!("│ Benchmark: {:<48} │", benchmark_name);
        println!("├─────────────────────────────────────────────────────────────┤");
        println!("│ Iterations: {:<47} │", self.count);
        println!("│ Min Latency: {:<46.3?} │", self.min);
        println!("│ Avg Latency: {:<46.3?} │", self.avg);
        println!("│ P95 Latency: {:<46.3?} │", self.p95);
        println!("│ P99 Latency: {:<46.3?} │", self.p99);
        println!("│ Max Latency: {:<46.3?} │", self.max);
        println!("└─────────────────────────────────────────────────────────────┘");
    }
}

/// Generates a realistic Zenith status bar Luau script for hot-reload benchmarking.
pub fn realistic_bar_script(clock_text: &str, cpu_val: u32, battery_val: u32) -> String {
    format!(
        r##"
return Zenith.Box({{
    width = 1920,
    height = 42,
    background = Zenith.hex("#111318"),
    padding = 6,
    children = {{
        Zenith.Box({{
            direction = "row",
            spacing = 12,
            children = {{
                Zenith.Box({{
                    background = Zenith.hex("#1e232a"),
                    border_radius = 8,
                    padding = 8,
                    children = {{
                        Zenith.Text({{
                            text = "Arch Linux",
                            color = Zenith.hex("#5895e6"),
                            font_size = 14
                        }})
                    }}
                }}),
                Zenith.Box({{
                    background = Zenith.hex("#1e232a"),
                    border_radius = 8,
                    padding = 8,
                    children = {{
                        Zenith.Text({{
                            text = "CPU: {}%",
                            color = Zenith.hex("#a6e3a1"),
                            font_size = 13
                        }})
                    }}
                }}),
                Zenith.Box({{
                    background = Zenith.hex("#1e232a"),
                    border_radius = 8,
                    padding = 8,
                    children = {{
                        Zenith.Text({{
                            text = "BAT: {}%",
                            color = Zenith.hex("#f9e2af"),
                            font_size = 13
                        }})
                    }}
                }}),
                Zenith.Box({{
                    background = Zenith.hex("#282c34"),
                    border_radius = 8,
                    padding = 8,
                    children = {{
                        Zenith.Text({{
                            text = "{}",
                            color = Zenith.hex("#ffffff"),
                            font_size = 13
                        }})
                    }}
                }})
            }}
        }})
    }}
}})
"##,
        cpu_val, battery_val, clock_text
    )
}

/// Generates a complex Zenith UI script containing subsystems from Waves 1 & 2:
/// Sliders, Switches, TextInputs, Shadows, Tooltips, Custom Shaders, and Flexbox layouts.
pub fn realistic_complex_subsystems_script(slider_val: f32, switch_val: bool, search_query: &str) -> String {
    format!(
        r##"
return Zenith.Box({{
    width = 800,
    height = 500,
    background = Zenith.hex("#111318"),
    padding = 16,
    shadow = {{
        color = Zenith.rgba(0, 0, 0, 120),
        blur = 16,
        offset_x = 0,
        offset_y = 6,
    }},
    tooltip = "Control Center Overlay",
    children = {{
        Zenith.TextInput({{
            id = "control_search",
            text = "{}",
            placeholder = "Search system settings...",
            font_size = 14,
            active = true,
        }}),
        Zenith.Box({{
            direction = "row",
            spacing = 16,
            padding = 8,
            children = {{
                Zenith.Slider({{
                    id = "brightness_slider",
                    min = 0,
                    max = 100,
                    value = {:.1},
                    track_height = 8,
                    thumb_radius = 10,
                }}),
                Zenith.Switch({{
                    id = "wifi_toggle",
                    checked = {},
                }}),
            }}
        }}),
        Zenith.Shader({{
            fragment = "// Custom SDF glow\nvoid main() {{ gl_FragColor = vec4(0.2, 0.6, 1.0, 1.0); }}",
            uniforms = {{
                {{ "u_time", 1.0 }},
                {{ "u_intensity", 0.85 }}
            }},
        }}),
        Zenith.Text({{
            text = "Subsystems Active: Slider={:.1}, Switch={}",
            color = Zenith.hex("#ffffff"),
            font_size = 12,
        }})
    }}
}})
"##,
        search_query, slider_val, switch_val, slider_val, switch_val
    )
}
