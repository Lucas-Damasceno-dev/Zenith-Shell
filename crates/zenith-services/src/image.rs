//! Zenith Services - Native raster (PNG) and vector (SVG) image decoding with caching.

use std::collections::HashMap;
use std::fs::File;
use std::io::BufReader;
use std::path::Path;
use std::sync::{Arc, OnceLock, RwLock};
use std::time::Instant;

use crate::SystemService;

/// Decoded RGBA image data buffer ready for blitting.
#[derive(Debug, Clone)]
pub struct DecodedImage {
    pub width: u32,
    pub height: u32,
    pub rgba: Vec<u8>,
}

type ImageCache = Arc<RwLock<HashMap<String, (DecodedImage, Instant)>>>;
static IMAGE_CACHE: OnceLock<ImageCache> = OnceLock::new();

pub struct ImageService;

impl ImageService {
    /// Invalidate in-memory image cache.
    pub fn invalidate_cache() {
        if let Some(cache) = IMAGE_CACHE.get() {
            if let Ok(mut guard) = cache.write() {
                guard.clear();
            }
        }
    }

    /// Load or retrieve cached RGBA image from disk path or inline SVG data.
    pub fn load_image(src: &str, target_width: Option<u32>, target_height: Option<u32>) -> Result<DecodedImage, Box<dyn std::error::Error>> {
        let cache = IMAGE_CACHE.get_or_init(|| Arc::new(RwLock::new(HashMap::new())));
        let key = format!("{}_{:?}_{:?}", src, target_width, target_height);

        if let Ok(guard) = cache.read() {
            if let Some((img, _)) = guard.get(&key) {
                return Ok(img.clone());
            }
        }

        let decoded = if src.trim_start().starts_with("<svg") {
            // Inline SVG
            let w = target_width.unwrap_or(32);
            let h = target_height.unwrap_or(32);
            let rgba = SystemService::render_svg(src, w, h)?;
            DecodedImage { width: w, height: h, rgba }
        } else if src.ends_with(".svg") {
            // SVG file
            let p = Path::new(src);
            let w = target_width.unwrap_or(32);
            let h = target_height.unwrap_or(32);
            let rgba = SystemService::render_svg_file(p, w, h)?;
            DecodedImage { width: w, height: h, rgba }
        } else if src.ends_with(".png") || Path::new(src).exists() {
            // PNG or raster file
            Self::decode_png_file(Path::new(src))?
        } else if let Some(icon_path) = crate::icon::XdgIconResolver::resolve(src, target_width.unwrap_or(32)) {
            let path_str = icon_path.to_string_lossy();
            if path_str.ends_with(".svg") {
                let w = target_width.unwrap_or(32);
                let h = target_height.unwrap_or(32);
                let rgba = SystemService::render_svg_file(&icon_path, w, h)?;
                DecodedImage { width: w, height: h, rgba }
            } else {
                Self::decode_png_file(&icon_path)?
            }
        } else {
            return Err(format!("Unsupported or non-existent image source: {}", src).into());
        };

        if let Ok(mut guard) = cache.write() {
            // Keep memory bounded: evict 16 oldest LRU items if cache exceeds 128 images
            if guard.len() > 128 {
                let mut entries: Vec<(String, Instant)> = guard.iter().map(|(k, (_, inst))| (k.clone(), *inst)).collect();
                entries.sort_unstable_by_key(|(_, inst)| *inst);
                for (k, _) in entries.into_iter().take(16) {
                    guard.remove(&k);
                }
            }
            guard.insert(key, (decoded.clone(), Instant::now()));
        }

        Ok(decoded)
    }

    /// Decode PNG file bytes into RGBA pixel buffer using the native `png` crate.
    pub fn decode_png_file(path: &Path) -> Result<DecodedImage, Box<dyn std::error::Error>> {
        let file = File::open(path)?;
        let reader = BufReader::new(file);
        Self::decode_png_reader(reader)
    }

    /// Decode PNG stream into RGBA pixel buffer.
    pub fn decode_png_reader<R: std::io::BufRead + std::io::Seek>(reader: R) -> Result<DecodedImage, Box<dyn std::error::Error>> {
        let decoder = png::Decoder::new(reader);
        let mut reader = decoder.read_info()?;
        let buf_size = reader.output_buffer_size().unwrap_or((reader.info().width * reader.info().height * 4) as usize);
        let mut buf = vec![0; buf_size];
        let info = reader.next_frame(&mut buf)?;

        let bytes = &buf[..info.buffer_size()];
        let width = info.width;
        let height = info.height;

        let rgba = match info.color_type {
            png::ColorType::Rgba => bytes.to_vec(),
            png::ColorType::Rgb => {
                let mut rgba = Vec::with_capacity((width * height * 4) as usize);
                for chunk in bytes.chunks_exact(3) {
                    rgba.extend_from_slice(&[chunk[0], chunk[1], chunk[2], 255]);
                }
                rgba
            }
            png::ColorType::Grayscale => {
                let mut rgba = Vec::with_capacity((width * height * 4) as usize);
                for &gray in bytes {
                    rgba.extend_from_slice(&[gray, gray, gray, 255]);
                }
                rgba
            }
            png::ColorType::GrayscaleAlpha => {
                let mut rgba = Vec::with_capacity((width * height * 4) as usize);
                for chunk in bytes.chunks_exact(2) {
                    rgba.extend_from_slice(&[chunk[0], chunk[0], chunk[0], chunk[1]]);
                }
                rgba
            }
            png::ColorType::Indexed => {
                return Err("Indexed PNG colors not directly supported, convert to RGBA".into());
            }
        };

        Ok(DecodedImage { width, height, rgba })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_svg_image_decode() {
        let svg = r#"<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"><rect width="16" height="16" fill="blue"/></svg>"#;
        let img = ImageService::load_image(svg, Some(16), Some(16)).expect("Failed to load SVG");
        assert_eq!(img.width, 16);
        assert_eq!(img.height, 16);
        assert_eq!(img.rgba.len(), 16 * 16 * 4);
    }

    #[test]
    fn test_image_cache_lru_eviction() {
        // Fill cache past 128 items and ensure it evicts without crashing or clearing everything
        for i in 0..140 {
            let svg = format!(r#"<svg xmlns="http://www.w3.org/2000/svg" width="{}" height="8"><rect width="4" height="8" fill="red"/></svg>"#, i + 1);
            let _ = ImageService::load_image(&svg, Some(8), Some(8));
        }
        if let Some(cache_arc) = IMAGE_CACHE.get() {
            let cache = cache_arc.read().unwrap();
            assert!(cache.len() <= 128);
            assert!(cache.len() > 100);
        }
    }
}
