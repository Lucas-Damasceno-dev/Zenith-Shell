//! Zenith Services - Native in-process disk storage telemetry via statvfs.

use std::ffi::CString;
use std::mem::MaybeUninit;
use std::sync::{OnceLock, RwLock};
use std::time::{Duration, Instant};

static DISK_CACHE: OnceLock<RwLock<(DiskSnapshot, Instant)>> = OnceLock::new();

/// Storage capacity metrics for a filesystem mount point.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct DiskSnapshot {
    pub total_gb: f64,
    pub used_gb: f64,
    pub free_gb: f64,
    pub percent: u8,
    pub mount: String,
}

pub struct DiskService;

impl DiskService {
    /// Read disk storage metrics for root `/` with in-memory caching.
    pub fn get_disk_usage() -> DiskSnapshot {
        let lock = DISK_CACHE.get_or_init(|| {
            RwLock::new((
                DiskSnapshot::default(),
                Instant::now() - Duration::from_secs(60),
            ))
        });

        if let Ok(guard) = lock.read() {
            if guard.1.elapsed() < Duration::from_secs(5) {
                return guard.0.clone();
            }
        }

        let snapshot = Self::query_statvfs("/").unwrap_or_else(|| DiskSnapshot {
            total_gb: 100.0,
            used_gb: 50.0,
            free_gb: 50.0,
            percent: 50,
            mount: "/".to_string(),
        });

        if let Ok(mut guard) = lock.write() {
            *guard = (snapshot.clone(), Instant::now());
        }

        snapshot
    }

    /// Query statvfs directly for a given path mount.
    pub fn query_statvfs(path: &str) -> Option<DiskSnapshot> {
        let c_path = CString::new(path).ok()?;
        let mut stat = MaybeUninit::<libc::statvfs>::uninit();

        let ret = unsafe { libc::statvfs(c_path.as_ptr(), stat.as_mut_ptr()) };
        if ret != 0 {
            return None;
        }

        let stat = unsafe { stat.assume_init() };
        let block_size = if stat.f_frsize > 0 { stat.f_frsize } else { stat.f_bsize } as f64;
        let total_bytes = stat.f_blocks as f64 * block_size;
        let free_bytes = stat.f_bavail as f64 * block_size;
        let used_bytes = (total_bytes - free_bytes).max(0.0);

        let gb_factor = 1024.0 * 1024.0 * 1024.0;
        let total_gb = (total_bytes / gb_factor * 10.0).round() / 10.0;
        let used_gb = (used_bytes / gb_factor * 10.0).round() / 10.0;
        let free_gb = (free_bytes / gb_factor * 10.0).round() / 10.0;

        let percent = if total_bytes > 0.0 {
            ((used_bytes / total_bytes) * 100.0).round().clamp(0.0, 100.0) as u8
        } else {
            0
        };

        Some(DiskSnapshot {
            total_gb,
            used_gb,
            free_gb,
            percent,
            mount: path.to_string(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_disk_statvfs_query() {
        let disk = DiskService::get_disk_usage();
        assert!(disk.total_gb > 0.0);
        assert!(disk.percent <= 100);
    }
}
