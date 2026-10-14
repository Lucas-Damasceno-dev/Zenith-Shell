//! Empirical Benchmarks for Zenith-Shell Sub-10ms Hot-Reload Pipeline.

use std::sync::Mutex;
use std::time::{Duration, Instant};
use zenith_tests::{realistic_bar_script, LatencyMetrics};
use zenith_wayland::HeadlessEngine;

static BENCH_MUTEX: Mutex<()> = Mutex::new(());

#[test]
fn bench_hot_reload_sub_10ms_latency() {
    let _lock = BENCH_MUTEX.lock().unwrap();
    let mut engine = HeadlessEngine::new().expect("Failed to initialize HeadlessEngine");

    // Cold warmup run
    let initial_script = realistic_bar_script("12:00:00", 15, 95);
    let _ = engine
        .compute_layout(&initial_script, 1920, 42)
        .expect("Initial layout computation failed");

    let iterations = 100;
    let mut durations = Vec::with_capacity(iterations);

    for i in 0..iterations {
        let clock = format!("12:{:02}:{:02}", i / 60, i % 60);
        let cpu = ((i * 7) % 100) as u32;
        let bat = (100 - (i % 50)) as u32;
        let script = realistic_bar_script(&clock, cpu, bat);

        // Measure reload cycle: compile/eval Luau + Taffy flexbox layout compute
        let start = Instant::now();
        let boxes = engine
            .compute_layout(&script, 1920, 42)
            .expect("Reload layout evaluation failed");
        let elapsed = start.elapsed();

        assert!(!boxes.is_empty(), "Computed boxes must not be empty");
        durations.push(elapsed);
    }

    let metrics = LatencyMetrics::compute(durations);
    metrics.print_report("Headless Luau Hot-Reload & Layout (100 Iterations)");

    // Target SLA verification: P95 must be sub-10ms
    assert!(
        metrics.p95 < Duration::from_millis(10),
        "P95 hot-reload latency ({:?}) exceeded 10ms SLA threshold!",
        metrics.p95
    );

    // Avg latency should typically be well below 5ms
    assert!(
        metrics.avg < Duration::from_millis(10),
        "Average hot-reload latency ({:?}) exceeded 10ms SLA threshold!",
        metrics.avg
    );
}

#[test]
fn bench_bytecode_cache_acceleration() {
    let _lock = BENCH_MUTEX.lock().unwrap();
    let mut engine = HeadlessEngine::new().expect("Failed to initialize HeadlessEngine");
    let script = realistic_bar_script("12:00:00", 25, 80);

    // Run first time (compilation + caching)
    let start_cold = Instant::now();
    let _ = engine.compute_layout(&script, 1920, 42).expect("Cold eval failed");
    let cold_duration = start_cold.elapsed();

    // Run repeated times (cached bytecode chunk retrieval + layout)
    let iterations = 50;
    let mut cached_durations = Vec::with_capacity(iterations);
    for _ in 0..iterations {
        let start_warm = Instant::now();
        let _ = engine.compute_layout(&script, 1920, 42).expect("Warm eval failed");
        cached_durations.push(start_warm.elapsed());
    }

    let metrics = LatencyMetrics::compute(cached_durations);
    metrics.print_report("Bytecode Cached Warm Reloads");

    println!("Cold compilation time: {:?}", cold_duration);
    println!("Warm cached avg time: {:?}", metrics.avg);

    // Warm reload should be sub-5ms
    assert!(
        metrics.p95 < Duration::from_millis(5),
        "Bytecode cached warm reload P95 ({:?}) should be sub-5ms",
        metrics.p95
    );
}

#[test]
fn bench_complex_subsystems_hot_reload_latency() {
    let _lock = BENCH_MUTEX.lock().unwrap();
    let mut engine = HeadlessEngine::new().expect("Failed to initialize HeadlessEngine");

    // Cold warmup run for complex layout containing Sliders, Switches, TextInputs, Shaders, Shadows
    let initial_script = zenith_tests::realistic_complex_subsystems_script(50.0, true, "init");
    let warmup_boxes = engine
        .compute_layout(&initial_script, 800, 500)
        .expect("Initial complex layout computation failed");
    assert!(!warmup_boxes.is_empty(), "Warmup boxes should not be empty");

    let iterations = 50;
    let mut durations = Vec::with_capacity(iterations);

    for i in 0..iterations {
        let slider_val = ((i * 13) % 100) as f32;
        let switch_val = i % 2 == 0;
        let query = format!("query_{:03}", i);
        let script = zenith_tests::realistic_complex_subsystems_script(slider_val, switch_val, &query);

        let start = Instant::now();
        let boxes = engine
            .compute_layout(&script, 800, 500)
            .expect("Complex subsystems layout evaluation failed");
        let elapsed = start.elapsed();

        assert!(!boxes.is_empty(), "Computed boxes must not be empty");
        durations.push(elapsed);
    }

    let metrics = LatencyMetrics::compute(durations);
    metrics.print_report("Complex Subsystems Hot-Reload & Layout (50 Iterations)");

    // Target SLA verification: P95 must be sub-10ms even for complex subsystems
    assert!(
        metrics.p95 < Duration::from_millis(10),
        "P95 complex hot-reload latency ({:?}) exceeded 10ms SLA threshold!",
        metrics.p95
    );

    // Avg latency should be well below 5ms
    assert!(
        metrics.avg < Duration::from_millis(5),
        "Average complex hot-reload latency ({:?}) exceeded 5ms threshold!",
        metrics.avg
    );
}

#[test]
fn bench_damage_ring_and_scissor_latency() {
    let _lock = BENCH_MUTEX.lock().unwrap();
    use zenith_wayland::render::damage::{box_visual_bounds, DamageRect, DamageRing};

    let mut ring: DamageRing<2> = DamageRing::new();

    // Create realistic computed boxes with shadows and tooltips
    let mut engine = HeadlessEngine::new().expect("Failed to initialize HeadlessEngine");
    let script = zenith_tests::realistic_complex_subsystems_script(75.0, true, "search");
    let boxes = engine.compute_layout(&script, 800, 500).expect("Layout failed");
    assert!(!boxes.is_empty());

    let iterations = 200;
    let mut durations = Vec::with_capacity(iterations);

    for _i in 0..iterations {
        let start = Instant::now();

        // 1. Compute visual bounds considering shadow and tooltip expansion
        let (bx, by, bw, bh) = box_visual_bounds(&boxes[0], 800.0);
        let rect = DamageRect::new(bx as i32, by as i32, bw as i32, bh as i32);

        // 2. Rotate damage ring
        let accumulated = ring.rotate_damage(Some(rect), 800, 500);

        // 3. Convert to clamped OpenGL ES scissor rect
        let scissor = accumulated.and_then(|acc| acc.to_gl_scissor_valid(800, 500));
        assert!(scissor.is_some());

        let elapsed = start.elapsed();
        durations.push(elapsed);
    }

    let metrics = LatencyMetrics::compute(durations);
    metrics.print_report("Damage Ring & Scissor Validation (200 Iterations)");

    // Damage tracking & scissor validation overhead must be sub-100µs (0.1ms)
    assert!(
        metrics.p95 < Duration::from_micros(100),
        "DamageRing P95 latency ({:?}) should be sub-100µs",
        metrics.p95
    );
}

#[test]
fn bench_reactive_graph_latency() {
    let _lock = BENCH_MUTEX.lock().unwrap();
    use zenith_layout::{Color, NodeStyle, UiNode};
    use zenith_runtime::reactive::{BoundProperty, NodeBinding, ReactiveGraph};

    let graph = ReactiveGraph::new();
    let iterations = 200;
    let mut durations = Vec::with_capacity(iterations);

    for i in 0..iterations {
        let sig_id = ReactiveGraph::next_signal_id();
        let tree_id = format!("tree_{}", i);

        let test_node = UiNode::Text {
            text: format!("Value {}", i),
            font_size: 14.0,
            color: Color::rgb(255, 255, 255),
            style: NodeStyle::default(),
        };

        let start = Instant::now();

        graph.mount_tree(&tree_id, test_node);
        assert!(graph.is_tree_dirty(&tree_id), "Newly mounted tree should be dirty");
        graph.mark_tree_clean(&tree_id);
        assert!(!graph.is_tree_dirty(&tree_id), "Cleaned tree should not be dirty");

        graph.track_access(sig_id);
        graph.bind_node(
            sig_id,
            NodeBinding {
                tree_id: tree_id.clone(),
                node_path: vec![0],
                property: BoundProperty::Text,
            },
        );

        let elapsed = start.elapsed();
        durations.push(elapsed);
    }

    let metrics = LatencyMetrics::compute(durations);
    metrics.print_report("Reactive Graph Node Binding & Tracking (200 Iterations)");

    // Reactive graph operations should be sub-50µs
    assert!(
        metrics.p95 < Duration::from_micros(50),
        "ReactiveGraph P95 latency ({:?}) should be sub-50µs",
        metrics.p95
    );
}
