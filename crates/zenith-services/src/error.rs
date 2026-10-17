//! Structured error types for Zenith Services.

use thiserror::Error;

/// Root error type for all services within `zenith-services`.
#[derive(Debug, Error)]
pub enum ServiceError {
    #[error("D-Bus error: {0}")]
    Dbus(#[from] DbusError),

    #[error("Audio error: {0}")]
    Audio(#[from] AudioError),

    #[error("MPRIS error: {0}")]
    Mpris(#[from] MprisError),

    #[error("Notification error: {0}")]
    Notification(#[from] NotificationError),

    #[error("Lock poisoned: {0}")]
    LockPoisoned(String),

    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),
}

/// D-Bus connection and messaging errors.
#[derive(Debug, Error)]
pub enum DbusError {
    #[error("Zbus error: {0}")]
    Zbus(#[from] zbus::Error),

    #[error("D-Bus address resolution failed: {0}")]
    AddressResolutionFailed(String),

    #[error("D-Bus service unavailable: {0}")]
    ServiceUnavailable(String),

    #[error("D-Bus call timed out: {0}")]
    Timeout(String),
}

/// Audio management and hardware query errors.
#[derive(Debug, Error)]
pub enum AudioError {
    #[error("Lock poisoned: {0}")]
    LockPoisoned(String),

    #[error("Command execution failed: {0}")]
    CommandFailed(String),

    #[error("Device not found: {0}")]
    DeviceNotFound(u32),

    #[error("Worker channel disconnected")]
    ChannelDisconnected,

    #[error("D-Bus error: {0}")]
    Dbus(#[from] DbusError),
}

/// MPRIS player inspection and transport control errors.
#[derive(Debug, Error)]
pub enum MprisError {
    #[error("D-Bus error: {0}")]
    Dbus(#[from] DbusError),

    #[error("Zbus error: {0}")]
    Zbus(#[from] zbus::Error),

    #[error("Lock poisoned: {0}")]
    LockPoisoned(String),

    #[error("No media player active")]
    NoPlayerActive,

    #[error("Unsupported media transport command: '{0}'")]
    UnknownCommand(String),
}

/// Desktop notification daemon and state management errors.
#[derive(Debug, Error)]
pub enum NotificationError {
    #[error("D-Bus error: {0}")]
    Dbus(#[from] DbusError),

    #[error("Zbus error: {0}")]
    Zbus(#[from] zbus::Error),

    #[error("Lock poisoned: {0}")]
    LockPoisoned(String),

    #[error("Notification daemon registration failed: {0}")]
    RegistrationFailed(String),

    #[error("Notification item not found: {0}")]
    NotFound(u32),
}

impl<T> From<std::sync::PoisonError<T>> for ServiceError {
    fn from(err: std::sync::PoisonError<T>) -> Self {
        ServiceError::LockPoisoned(err.to_string())
    }
}

impl<T> From<std::sync::PoisonError<T>> for AudioError {
    fn from(err: std::sync::PoisonError<T>) -> Self {
        AudioError::LockPoisoned(err.to_string())
    }
}

impl<T> From<std::sync::PoisonError<T>> for MprisError {
    fn from(err: std::sync::PoisonError<T>) -> Self {
        MprisError::LockPoisoned(err.to_string())
    }
}

impl<T> From<std::sync::PoisonError<T>> for NotificationError {
    fn from(err: std::sync::PoisonError<T>) -> Self {
        NotificationError::LockPoisoned(err.to_string())
    }
}
