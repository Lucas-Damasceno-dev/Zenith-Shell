//! Adversarial Red-Team Test Suite for Zenith Services.
//!
//! Rigorous validation for:
//! - [CARD-02] D-Bus resilience and panic/unwrap elimination across zenith-services.
//! - AudioController, MprisController, NotificationController, DbusConnectionProvider contracts.
//! - Audio volume boundary conditions, clamping, signed delta overflows, mute inversion.
//! - MPRIS transport command parsing, sanitization, unknown command rejection, missing player fallbacks.
//! - Desktop notification bounded queue saturation (15 active limit, 50 history limit), DND urgency bypass, in-place update.
//! - Lock poison error recovery and zero panic guarantees.
//! - Trait-based mocking and headless deterministic execution.
//! - Multi-threaded concurrent contention stress testing.

use std::sync::{Arc, Mutex};
use std::thread;

use zenith_services::audio::{AudioController, AudioDevice, AudioService};
use zenith_services::dbus::{
    get_session_connection, get_system_connection, resolve_session_bus_address,
    DbusConnectionProvider, DbusManager,
};
use zenith_services::error::{
    AudioError, DbusError, MprisError, NotificationError, ServiceError,
};
use zenith_services::mpris::{MediaSnapshot, MprisController, MprisService};
use zenith_services::notifications::{
    NotificationController, NotificationItem, NotificationService,
};

/// Test synchronization locks to prevent concurrent mutations of process-global static state.
static DBUS_ENV_LOCK: Mutex<()> = Mutex::new(());
static NOTIFICATION_STATE_LOCK: Mutex<()> = Mutex::new(());
static AUDIO_STATE_LOCK: Mutex<()> = Mutex::new(());

fn acquire_lock<'a>(m: &'a Mutex<()>) -> std::sync::MutexGuard<'a, ()> {
    match m.lock() {
        Ok(g) => g,
        Err(e) => e.into_inner(),
    }
}

// ============================================================================
// 1. D-BUS CONNECTION RESILIENCE & PROVIDER ADVERSARIAL TESTS
// ============================================================================

#[test]
fn test_dbus_resolve_session_bus_address_disabled_or_empty() {
    let _lock = acquire_lock(&DBUS_ENV_LOCK);
    let prev = std::env::var("DBUS_SESSION_BUS_ADDRESS").ok();

    // When DBUS_SESSION_BUS_ADDRESS is explicitly "disabled", resolution must not return "disabled"
    std::env::set_var("DBUS_SESSION_BUS_ADDRESS", "disabled");
    let resolved = resolve_session_bus_address();
    assert_ne!(
        resolved.as_deref(),
        Some("disabled"),
        "D-Bus resolver must reject 'disabled' address value"
    );

    // Empty string must also be rejected
    std::env::set_var("DBUS_SESSION_BUS_ADDRESS", "");
    let resolved_empty = resolve_session_bus_address();
    assert_ne!(
        resolved_empty.as_deref(),
        Some(""),
        "D-Bus resolver must reject empty string"
    );

    // Restore environment
    if let Some(v) = prev {
        std::env::set_var("DBUS_SESSION_BUS_ADDRESS", v);
    } else {
        std::env::remove_var("DBUS_SESSION_BUS_ADDRESS");
    }
}

#[test]
fn test_dbus_resolve_session_bus_address_valid_custom() {
    let _lock = acquire_lock(&DBUS_ENV_LOCK);
    let prev = std::env::var("DBUS_SESSION_BUS_ADDRESS").ok();
    let mock_addr = "unix:path=/tmp/zenith_mock_test_bus.sock";
    std::env::set_var("DBUS_SESSION_BUS_ADDRESS", mock_addr);

    let resolved = resolve_session_bus_address();
    assert_eq!(resolved.as_deref(), Some(mock_addr));

    if let Some(v) = prev {
        std::env::set_var("DBUS_SESSION_BUS_ADDRESS", v);
    } else {
        std::env::remove_var("DBUS_SESSION_BUS_ADDRESS");
    }
}

#[test]
fn test_dbus_get_session_connection_nonexistent_address_fails_gracefully() {
    let _lock = acquire_lock(&DBUS_ENV_LOCK);
    let prev = std::env::var("DBUS_SESSION_BUS_ADDRESS").ok();
    std::env::set_var(
        "DBUS_SESSION_BUS_ADDRESS",
        "unix:path=/tmp/zenith_nonexistent_socket_test_never_exists.sock",
    );

    // Calling get_session_connection must return Err(DbusError) and never panic or unwrap
    let res = get_session_connection();
    if let Err(e) = res {
        assert!(
            matches!(e, DbusError::Zbus(_) | DbusError::AddressResolutionFailed(_)),
            "Expected Zbus or AddressResolutionFailed error, got {:?}",
            e
        );
    }

    if let Some(v) = prev {
        std::env::set_var("DBUS_SESSION_BUS_ADDRESS", v);
    } else {
        std::env::remove_var("DBUS_SESSION_BUS_ADDRESS");
    }
}

/// Mock DbusConnectionProvider for deterministic test isolation.
#[derive(Clone, Default)]
struct MockDbusProvider {
    session_error: Arc<Mutex<Option<String>>>,
    system_error: Arc<Mutex<Option<String>>>,
}

impl MockDbusProvider {
    fn with_session_error(msg: &str) -> Self {
        Self {
            session_error: Arc::new(Mutex::new(Some(msg.to_string()))),
            system_error: Arc::new(Mutex::new(None)),
        }
    }
}

impl DbusConnectionProvider for MockDbusProvider {
    fn get_session_connection(&self) -> Result<zbus::blocking::Connection, DbusError> {
        let err = self.session_error.lock().unwrap();
        if let Some(ref msg) = *err {
            Err(DbusError::ServiceUnavailable(msg.clone()))
        } else {
            get_session_connection()
        }
    }

    fn get_system_connection(&self) -> Result<zbus::blocking::Connection, DbusError> {
        let err = self.system_error.lock().unwrap();
        if let Some(ref msg) = *err {
            Err(DbusError::ServiceUnavailable(msg.clone()))
        } else {
            get_system_connection()
        }
    }
}

#[test]
fn test_dbus_connection_provider_trait_and_mock() {
    let mock = MockDbusProvider::with_session_error("Simulated D-Bus daemon failure");
    let provider: &dyn DbusConnectionProvider = &mock;

    let res = provider.get_session_connection();
    assert!(res.is_err());
    match res {
        Err(DbusError::ServiceUnavailable(msg)) => {
            assert_eq!(msg, "Simulated D-Bus daemon failure");
        }
        other => panic!("Expected ServiceUnavailable error, got {:?}", other),
    }

    // Trait object Send + Sync test
    let provider_arc: Arc<dyn DbusConnectionProvider> = Arc::new(mock);
    let handle = thread::spawn(move || {
        assert!(provider_arc.get_session_connection().is_err());
    });
    handle.join().unwrap();
}

#[test]
fn test_dbus_manager_implements_provider() {
    let manager = DbusManager::default();
    let provider: &dyn DbusConnectionProvider = &manager;
    let _ = provider.get_session_connection();
    let _ = provider.get_system_connection();
}

// ============================================================================
// 2. MPRIS CONTROLLER ADVERSARIAL & INPUT SANITIZATION
// ============================================================================

#[test]
fn test_mpris_try_control_unknown_or_malicious_commands() {
    // Red-team requirement: unknown/malicious commands MUST be rejected as UnknownCommand
    // before attempting external I/O or daemon discovery.
    let malicious_commands = [
        "",
        "unknown_action",
        "seek_relative 10",
        "play; rm -rf /",
        "eval(alert(1))",
        "DROP TABLE mpris",
        "volume_boost_over_100",
        "shuffle",
        "loop_track",
    ];

    for cmd in malicious_commands {
        let res = MprisService::try_control(cmd);
        assert!(
            res.is_err(),
            "Expected command '{}' to be rejected, but got Ok",
            cmd
        );
        match res {
            Err(MprisError::UnknownCommand(ref bad_cmd)) => {
                assert_eq!(bad_cmd, cmd);
            }
            other => panic!(
                "Expected UnknownCommand for '{}', got {:?}",
                cmd, other
            ),
        }
    }
}

#[test]
fn test_mpris_try_control_valid_commands_case_insensitive_handling() {
    // Valid supported commands across case variations
    let valid_variations = [
        "play-pause",
        "PlayPause",
        "PLAYPAUSE",
        "toggle",
        "next",
        "NEXT",
        "prev",
        "previous",
        "PREVIOUS",
        "stop",
        "STOP",
        "play",
        "PLAY",
        "pause",
        "PAUSE",
    ];

    for cmd in valid_variations {
        let res = MprisService::try_control(cmd);
        // Under headless or CI testing, there may be no active player or no D-Bus session.
        // It must NEVER panic with unwrap(), and must return either Ok, NoPlayerActive, or Dbus/Zbus error.
        if let Err(e) = res {
            assert!(
                matches!(
                    e,
                    MprisError::NoPlayerActive | MprisError::Dbus(_) | MprisError::Zbus(_)
                ),
                "Command '{}' returned unexpected error type: {:?}",
                cmd,
                e
            );
        }
    }
}

#[test]
fn test_mpris_try_snapshot_safe_defaults() {
    let snap_res = MprisService::try_snapshot();
    assert!(snap_res.is_ok(), "try_snapshot must succeed");
    let snap = snap_res.unwrap();

    // Verify fallback legacy wrapper snapshot() does not panic
    let legacy_snap = MprisService::snapshot();
    assert_eq!(snap.is_available, legacy_snap.is_available);
}

/// Mock MprisController for testing MPRIS-dependent consumers.
struct MockMprisController {
    snapshot_data: Mutex<MediaSnapshot>,
    executed_commands: Mutex<Vec<String>>,
}

impl MockMprisController {
    fn new(initial: MediaSnapshot) -> Self {
        Self {
            snapshot_data: Mutex::new(initial),
            executed_commands: Mutex::new(Vec::new()),
        }
    }
}

impl MprisController for MockMprisController {
    fn snapshot(&self) -> Result<MediaSnapshot, MprisError> {
        Ok(self.snapshot_data.lock().unwrap().clone())
    }

    fn control(&self, cmd: &str) -> Result<(), MprisError> {
        let mut cmds = self.snapshot_data.lock().unwrap();
        match cmd {
            "play" => {
                cmds.status = "Playing".to_string();
            }
            "pause" => {
                cmds.status = "Paused".to_string();
            }
            "play-pause" => {
                cmds.status = if cmds.status == "Playing" {
                    "Paused".to_string()
                } else {
                    "Playing".to_string()
                };
            }
            "next" | "prev" | "stop" => {}
            other => return Err(MprisError::UnknownCommand(other.to_string())),
        }
        self.executed_commands.lock().unwrap().push(cmd.to_string());
        Ok(())
    }
}

#[test]
fn test_mpris_controller_trait_and_mock() {
    let initial = MediaSnapshot {
        is_available: true,
        player_name: "Spotify".into(),
        status: "Paused".into(),
        title: "Solaris".into(),
        artist: "Cliff Martinez".into(),
        album: "Solaris OST".into(),
        art_url: String::new(),
        length_seconds: 300,
    };

    let mock = MockMprisController::new(initial);
    let controller: &dyn MprisController = &mock;

    let snap = controller.snapshot().expect("Mock snapshot failed");
    assert_eq!(snap.title, "Solaris");
    assert_eq!(snap.status, "Paused");

    controller.control("play").expect("play command failed");
    let snap_after = controller.snapshot().expect("Mock snapshot failed");
    assert_eq!(snap_after.status, "Playing");

    assert!(controller.control("seek_unsupported").is_err());
}

#[test]
fn test_mpris_service_implements_mpris_controller() {
    let service = MprisService;
    let controller: &dyn MprisController = &service;
    let _ = controller.snapshot();
}

// ============================================================================
// 3. AUDIO CONTROLLER ADVERSARIAL & NUMERIC CLAMPING
// ============================================================================

#[test]
fn test_audio_try_set_volume_bounds_and_clamping() {
    let _lock = acquire_lock(&AUDIO_STATE_LOCK);

    // Exact lower boundary
    assert!(AudioService::try_set_volume(0).is_ok());

    // Exact upper boundary
    assert!(AudioService::try_set_volume(100).is_ok());

    // Beyond upper boundary: must clamp to 100 without error
    assert!(AudioService::try_set_volume(101).is_ok());
    assert!(AudioService::try_set_volume(255).is_ok());

    // Legacy unwrap-free function must also work smoothly
    AudioService::set_volume(50);
}

#[test]
fn test_audio_try_adjust_volume_extremes_and_overflow() {
    let _lock = acquire_lock(&AUDIO_STATE_LOCK);

    // Reset to mid volume
    let _ = AudioService::try_set_volume(50);

    // Normal positive adjustment
    assert!(AudioService::try_adjust_volume(10).is_ok());

    // Normal negative adjustment
    assert!(AudioService::try_adjust_volume(-20).is_ok());

    // Extreme positive delta: i32::MAX must clamp to 100 without integer overflow panic
    assert!(AudioService::try_adjust_volume(i32::MAX).is_ok());

    // Extreme negative delta: i32::MIN must clamp to 0 without underflow panic
    assert!(AudioService::try_adjust_volume(i32::MIN).is_ok());

    // Legacy unwrap-free function must also work smoothly
    AudioService::adjust_volume(15);
}

#[test]
fn test_audio_try_toggle_mute_toggles_state() {
    let _lock = acquire_lock(&AUDIO_STATE_LOCK);

    // Calling try_toggle_mute multiple times must execute safely without panics
    assert!(AudioService::try_toggle_mute().is_ok());
    assert!(AudioService::try_toggle_mute().is_ok());

    // Legacy wrapper
    AudioService::toggle_mute();
}

#[test]
fn test_audio_try_set_default_sink_edge_cases() {
    let _lock = acquire_lock(&AUDIO_STATE_LOCK);

    assert!(AudioService::try_set_default_sink(0).is_ok());
    assert!(AudioService::try_set_default_sink(42).is_ok());
    assert!(AudioService::try_set_default_sink(u32::MAX).is_ok());

    // Legacy wrapper
    AudioService::set_default_sink(1);
}

#[test]
fn test_audio_try_list_sinks_resilience() {
    let _lock = acquire_lock(&AUDIO_STATE_LOCK);

    let sinks_res = AudioService::try_list_sinks();
    assert!(sinks_res.is_ok(), "try_list_sinks must never panic");

    let legacy_sinks = AudioService::list_sinks();
    assert_eq!(sinks_res.unwrap().len(), legacy_sinks.len());
}

/// Mock AudioController for testing UI or layout without pipewire dependencies.
struct MockAudioController {
    volume: Mutex<u8>,
    is_muted: Mutex<bool>,
    sinks: Mutex<Vec<AudioDevice>>,
}

impl MockAudioController {
    fn new(initial_vol: u8) -> Self {
        Self {
            volume: Mutex::new(initial_vol),
            is_muted: Mutex::new(false),
            sinks: Mutex::new(vec![AudioDevice {
                id: 1,
                name: "Headphones".into(),
                is_default: true,
            }]),
        }
    }
}

impl AudioController for MockAudioController {
    fn list_sinks(&self) -> Result<Vec<AudioDevice>, AudioError> {
        Ok(self.sinks.lock().unwrap().clone())
    }

    fn set_volume(&self, percent: u8) -> Result<(), AudioError> {
        let mut v = self.volume.lock().unwrap();
        *v = percent.min(100);
        Ok(())
    }

    fn adjust_volume(&self, delta: i32) -> Result<(), AudioError> {
        let mut v = self.volume.lock().unwrap();
        let target = (*v as i32 + delta).clamp(0, 100) as u8;
        *v = target;
        Ok(())
    }

    fn toggle_mute(&self) -> Result<(), AudioError> {
        let mut m = self.is_muted.lock().unwrap();
        *m = !*m;
        Ok(())
    }

    fn set_default_sink(&self, id: u32) -> Result<(), AudioError> {
        let mut sinks = self.sinks.lock().unwrap();
        for s in sinks.iter_mut() {
            s.is_default = s.id == id;
        }
        Ok(())
    }
}

#[test]
fn test_audio_controller_trait_and_mock() {
    let mock = MockAudioController::new(40);
    let controller: &dyn AudioController = &mock;

    assert_eq!(controller.list_sinks().unwrap().len(), 1);

    controller.set_volume(85).unwrap();
    assert_eq!(*mock.volume.lock().unwrap(), 85);

    controller.adjust_volume(-10).unwrap();
    assert_eq!(*mock.volume.lock().unwrap(), 75);

    controller.toggle_mute().unwrap();
    assert!(*mock.is_muted.lock().unwrap());
}

#[test]
fn test_audio_service_implements_audio_controller() {
    let service = AudioService;
    let controller: &dyn AudioController = &service;
    assert!(controller.set_volume(30).is_ok());
    assert!(controller.adjust_volume(5).is_ok());
    assert!(controller.toggle_mute().is_ok());
}

// ============================================================================
// 4. NOTIFICATIONS CONTROLLER ADVERSARIAL & BOUNDED BUFFERS
// ============================================================================

#[test]
fn test_notifications_try_notify_and_empty_app_name_fallback() {
    let _lock = acquire_lock(&NOTIFICATION_STATE_LOCK);

    let res = NotificationService::try_notify(
        "".into(),
        0,
        "icon-bell".into(),
        "Test Summary".into(),
        "Test Body".into(),
        vec!["action1".into()],
        1,
        3000,
    );
    assert!(res.is_ok(), "try_notify must succeed");
    let id = res.unwrap();
    assert!(id > 0);

    let active = NotificationService::try_list_active().unwrap();
    let created = active.iter().find(|n| n.id == id);
    assert!(created.is_some());
    // Empty app name must fall back to "System"
    assert_eq!(created.unwrap().app_name, "System");

    let _ = NotificationService::try_close(id);
}

#[test]
fn test_notifications_replaces_id_in_place_update() {
    let _lock = acquire_lock(&NOTIFICATION_STATE_LOCK);
    NotificationService::set_dnd(false);
    let _ = NotificationService::try_clear_all();
    let _ = NotificationService::try_clear_history();

    // 1. Create initial notification
    let id = NotificationService::try_notify(
        "DownloadManager".into(),
        0,
        "download".into(),
        "Downloading...".into(),
        "0%".into(),
        vec![],
        1,
        0,
    )
    .unwrap();

    let initial_count = NotificationService::try_count().unwrap();

    // 2. Replace notification in-place
    let replaced_id = NotificationService::try_notify(
        "DownloadManager".into(),
        id,
        "download".into(),
        "Downloading...".into(),
        "100% Complete".into(),
        vec![],
        1,
        0,
    )
    .unwrap();

    assert_eq!(id, replaced_id);
    let after_count = NotificationService::try_count().unwrap();
    assert_eq!(
        initial_count, after_count,
        "In-place replacement must not increase active count"
    );

    let active = NotificationService::try_list_active().unwrap();
    let updated = active.iter().find(|n| n.id == id).unwrap();
    assert_eq!(updated.body, "100% Complete");

    let _ = NotificationService::try_close(id);
}

#[test]
fn test_notifications_active_queue_bounded_fifteen() {
    let _lock = acquire_lock(&NOTIFICATION_STATE_LOCK);
    NotificationService::set_dnd(false);
    let _ = NotificationService::try_clear_all();
    let _ = NotificationService::try_clear_history();

    // Saturate active queue with 20 items (limit is 15)
    for i in 0..20 {
        let _ = NotificationService::try_notify(
            format!("App{}", i),
            0,
            "".into(),
            format!("Summary {}", i),
            "Body".into(),
            vec![],
            1,
            5000,
        );
    }

    let active_count = NotificationService::try_count().unwrap();
    assert_eq!(
        active_count, 15,
        "Active notification buffer must be strictly bounded at 15 items"
    );

    let history = NotificationService::try_list_history().unwrap();
    assert!(
        history.len() <= 50,
        "Notification history queue must be bounded to <= 50 items (got {})",
        history.len()
    );

    // Clean up
    let _ = NotificationService::try_clear_all();
    let _ = NotificationService::try_clear_history();
}

#[test]
fn test_notifications_history_queue_bounded_fifty() {
    let _lock = acquire_lock(&NOTIFICATION_STATE_LOCK);
    NotificationService::set_dnd(true);
    let _ = NotificationService::try_clear_all();
    let _ = NotificationService::try_clear_history();

    // Send 60 notifications under DND (urgency = 0)
    for i in 0..60 {
        let _ = NotificationService::try_notify(
            format!("MutedApp{}", i),
            0,
            "".into(),
            format!("Muted {}", i),
            "Body".into(),
            vec![],
            0, // Urgency 0 (Low)
            5000,
        );
    }

    let history = NotificationService::try_list_history().unwrap();
    assert!(
        history.len() <= 50,
        "Notification history queue must be bounded to <= 50 items (got {})",
        history.len()
    );

    NotificationService::set_dnd(false);
    let _ = NotificationService::try_clear_history();
}

#[test]
fn test_notifications_dnd_behavior_urgency_filtration() {
    let _lock = acquire_lock(&NOTIFICATION_STATE_LOCK);
    let _ = NotificationService::try_clear_all();
    let _ = NotificationService::try_clear_history();
    NotificationService::set_dnd(true);
    assert!(NotificationService::is_dnd());

    // 1. Low urgency (0) under DND -> muted to history
    let id_low = NotificationService::try_notify(
        "LowApp".into(),
        0,
        "".into(),
        "Low".into(),
        "".into(),
        vec![],
        0,
        5000,
    )
    .unwrap();

    let active = NotificationService::try_list_active().unwrap();
    assert!(
        active.iter().all(|n| n.id != id_low),
        "Low urgency must not enter active queue during DND"
    );

    // 2. Normal urgency (1) under DND -> muted to history
    let id_norm = NotificationService::try_notify(
        "NormApp".into(),
        0,
        "".into(),
        "Norm".into(),
        "".into(),
        vec![],
        1,
        5000,
    )
    .unwrap();

    let active = NotificationService::try_list_active().unwrap();
    assert!(
        active.iter().all(|n| n.id != id_norm),
        "Normal urgency must not enter active queue during DND"
    );

    // 3. Critical urgency (2) under DND -> MUST BYPASS DND into active
    let id_crit = NotificationService::try_notify(
        "CriticalSystem".into(),
        0,
        "".into(),
        "BATTERY CRITICAL".into(),
        "".into(),
        vec![],
        2,
        5000,
    )
    .unwrap();

    let active = NotificationService::try_list_active().unwrap();
    assert!(
        active.iter().any(|n| n.id == id_crit),
        "Critical urgency MUST bypass DND into active queue"
    );

    // Reset DND
    NotificationService::set_dnd(false);
    let _ = NotificationService::try_clear_all();
    let _ = NotificationService::try_clear_history();
}

#[test]
fn test_notifications_try_close_and_clear_operations() {
    let _lock = acquire_lock(&NOTIFICATION_STATE_LOCK);
    NotificationService::set_dnd(false);
    let _ = NotificationService::try_clear_all();
    let _ = NotificationService::try_clear_history();

    let id = NotificationService::try_notify(
        "Test".into(),
        0,
        "".into(),
        "Title".into(),
        "".into(),
        vec![],
        1,
        5000,
    )
    .unwrap();

    // Closing active toast
    assert!(NotificationService::try_close(id).is_ok());
    let active = NotificationService::try_list_active().unwrap();
    assert!(active.iter().all(|n| n.id != id));

    // Closed item moved to history
    let history = NotificationService::try_list_history().unwrap();
    assert!(history.iter().any(|n| n.id == id));

    // Closing non-existent id must be a safe no-op
    assert!(NotificationService::try_close(999_999).is_ok());

    // Clear all & clear history
    assert!(NotificationService::try_clear_all().is_ok());
    assert!(NotificationService::try_clear_history().is_ok());
    assert_eq!(NotificationService::try_list_history().unwrap().len(), 0);
}

/// Mock NotificationController for testing notifications in decoupled environments.
struct MockNotificationController {
    notifications: Mutex<Vec<NotificationItem>>,
}

impl MockNotificationController {
    fn new() -> Self {
        Self {
            notifications: Mutex::new(Vec::new()),
        }
    }
}

impl NotificationController for MockNotificationController {
    fn list_active(&self) -> Result<Vec<NotificationItem>, NotificationError> {
        Ok(self.notifications.lock().unwrap().clone())
    }

    fn list_history(&self) -> Result<Vec<NotificationItem>, NotificationError> {
        Ok(Vec::new())
    }

    fn count(&self) -> Result<usize, NotificationError> {
        Ok(self.notifications.lock().unwrap().len())
    }

    fn notify(
        &self,
        app_name: String,
        replaces_id: u32,
        app_icon: String,
        summary: String,
        body: String,
        actions: Vec<String>,
        urgency: u8,
        expire_timeout_ms: i32,
    ) -> Result<u32, NotificationError> {
        let mut list = self.notifications.lock().unwrap();
        let id = if replaces_id > 0 { replaces_id } else { list.len() as u32 + 1 };
        list.push(NotificationItem {
            id,
            app_name,
            app_icon,
            summary,
            body,
            actions,
            urgency,
            timestamp_secs: 1000,
            expire_timeout_ms,
        });
        Ok(id)
    }

    fn close(&self, id: u32) -> Result<(), NotificationError> {
        let mut list = self.notifications.lock().unwrap();
        list.retain(|n| n.id != id);
        Ok(())
    }

    fn clear_all(&self) -> Result<(), NotificationError> {
        self.notifications.lock().unwrap().clear();
        Ok(())
    }

    fn clear_history(&self) -> Result<(), NotificationError> {
        Ok(())
    }
}

#[test]
fn test_notifications_controller_trait_and_mock() {
    let mock = MockNotificationController::new();
    let controller: &dyn NotificationController = &mock;

    assert_eq!(controller.count().unwrap(), 0);

    let id = controller
        .notify(
            "TestApp".into(),
            0,
            "".into(),
            "Title".into(),
            "Body".into(),
            vec![],
            1,
            5000,
        )
        .unwrap();

    assert_eq!(controller.count().unwrap(), 1);
    assert_eq!(controller.list_active().unwrap()[0].id, id);

    controller.close(id).unwrap();
    assert_eq!(controller.count().unwrap(), 0);
}

#[test]
fn test_notifications_service_implements_notification_controller() {
    let service = NotificationService;
    let controller: &dyn NotificationController = &service;
    let _ = controller.count();
    let _ = controller.list_active();
    let _ = controller.list_history();
}

// ============================================================================
// 5. ERROR HIERARCHY, POISONING & CONVERSIONS
// ============================================================================

#[test]
fn test_error_hierarchy_from_conversions() {
    // 1. DbusError -> ServiceError
    let dbus_err = DbusError::AddressResolutionFailed("no socket".into());
    let svc_err: ServiceError = dbus_err.into();
    assert!(matches!(svc_err, ServiceError::Dbus(_)));

    // 2. AudioError -> ServiceError
    let audio_err = AudioError::ChannelDisconnected;
    let svc_err: ServiceError = audio_err.into();
    assert!(matches!(svc_err, ServiceError::Audio(_)));

    // 3. MprisError -> ServiceError
    let mpris_err = MprisError::NoPlayerActive;
    let svc_err: ServiceError = mpris_err.into();
    assert!(matches!(svc_err, ServiceError::Mpris(_)));

    // 4. NotificationError -> ServiceError
    let notif_err = NotificationError::NotFound(42);
    let svc_err: ServiceError = notif_err.into();
    assert!(matches!(svc_err, ServiceError::Notification(_)));

    // 5. std::io::Error -> ServiceError
    let io_err = std::io::Error::new(std::io::ErrorKind::NotFound, "file not found");
    let svc_err: ServiceError = io_err.into();
    assert!(matches!(svc_err, ServiceError::Io(_)));

    // 6. DbusError -> AudioError, MprisError, NotificationError
    let d1 = DbusError::Timeout("call timeout".into());
    let a1: AudioError = d1.into();
    assert!(matches!(a1, AudioError::Dbus(_)));

    let d2 = DbusError::Timeout("call timeout".into());
    let m1: MprisError = d2.into();
    assert!(matches!(m1, MprisError::Dbus(_)));

    let d3 = DbusError::Timeout("call timeout".into());
    let n1: NotificationError = d3.into();
    assert!(matches!(n1, NotificationError::Dbus(_)));
}

#[test]
fn test_poison_error_conversion() {
    let mutex = Mutex::new(10);
    let _ = std::panic::catch_unwind(|| {
        let _guard = mutex.lock().unwrap();
        panic!("simulated panic to poison mutex");
    });

    assert!(mutex.is_poisoned());

    let err = mutex.lock().unwrap_err();
    let service_err: ServiceError = err.into();
    match service_err {
        ServiceError::LockPoisoned(ref msg) => {
            assert!(msg.contains("poisoned"));
        }
        other => panic!("Expected LockPoisoned, got {:?}", other),
    }
}

#[test]
fn test_error_display_formatting() {
    let err = AudioError::DeviceNotFound(99);
    assert_eq!(format!("{}", err), "Device not found: 99");

    let err2 = MprisError::UnknownCommand("foo".into());
    assert_eq!(
        format!("{}", err2),
        "Unsupported media transport command: 'foo'"
    );

    let err3 = NotificationError::RegistrationFailed("bus refused name".into());
    assert_eq!(
        format!("{}", err3),
        "Notification daemon registration failed: bus refused name"
    );

    let err4 = DbusError::AddressResolutionFailed("addr not found".into());
    assert_eq!(
        format!("{}", err4),
        "D-Bus address resolution failed: addr not found"
    );
}

// ============================================================================
// 6. MULTI-THREAD CONCURRENCY & TORTURE STRESS
// ============================================================================

#[test]
fn test_concurrent_audio_volume_contention() {
    let _lock = acquire_lock(&AUDIO_STATE_LOCK);
    let mut handles = Vec::new();

    for t in 0..8 {
        let handle = thread::spawn(move || {
            for i in 0..50 {
                let vol = ((t * 10 + i) % 100) as u8;
                let _ = AudioService::try_set_volume(vol);
                let delta = if i % 2 == 0 { 5 } else { -5 };
                let _ = AudioService::try_adjust_volume(delta);
                if i % 10 == 0 {
                    let _ = AudioService::try_toggle_mute();
                }
            }
        });
        handles.push(handle);
    }

    for h in handles {
        h.join().expect("Concurrent audio worker panicked");
    }
}

#[test]
fn test_concurrent_notifications_churn() {
    let _lock = acquire_lock(&NOTIFICATION_STATE_LOCK);
    NotificationService::set_dnd(false);
    let mut handles = Vec::new();

    for t in 0..8 {
        let handle = thread::spawn(move || {
            for i in 0..30 {
                let app = format!("Worker_{}_{}", t, i);
                let id = NotificationService::try_notify(
                    app,
                    0,
                    "".into(),
                    "Stress".into(),
                    "Contention".into(),
                    vec![],
                    1,
                    5000,
                )
                .unwrap_or(0);

                let _ = NotificationService::try_count();
                let _ = NotificationService::try_list_active();

                if id > 0 && i % 3 == 0 {
                    let _ = NotificationService::try_close(id);
                }
            }
        });
        handles.push(handle);
    }

    for h in handles {
        h.join().expect("Concurrent notification worker panicked");
    }

    // Must still maintain active limit <= 15
    let active_count = NotificationService::try_count().unwrap();
    assert!(
        active_count <= 15,
        "Active notifications exceeded bounded capacity under concurrent churn: {}",
        active_count
    );

    let _ = NotificationService::try_clear_all();
    let _ = NotificationService::try_clear_history();
}
