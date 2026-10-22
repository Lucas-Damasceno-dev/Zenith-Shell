//! Wayland EGL and OpenGL ES 3.0 context management for Zenith Base v3.

use std::sync::Arc;
use khronos_egl as egl;
use wayland_client::protocol::wl_surface::WlSurface;
use wayland_client::Proxy;

pub type EglInstance = egl::DynamicInstance<egl::EGL1_5>;

pub type EglSwapBuffersWithDamageFn = unsafe extern "C" fn(
    *mut std::ffi::c_void,
    *mut std::ffi::c_void,
    *const i32,
    i32,
) -> egl::Boolean;

/// Thread-safe wrapper around EGL 1.5 display and context.
pub struct EglContext {
    pub egl: Arc<EglInstance>,
    pub display: egl::Display,
    pub config: egl::Config,
    pub context: egl::Context,
    pub gl: Arc<glow::Context>,
    pub swap_damage_fn: Option<EglSwapBuffersWithDamageFn>,
}

unsafe impl Send for EglContext {}
unsafe impl Sync for EglContext {}

/// Hardware-accelerated EGL surface wrapping a Wayland `WlSurface`.
pub struct EglSurface {
    egl: Arc<EglInstance>,
    display: egl::Display,
    surface: egl::Surface,
    window: wayland_egl::WlEglSurface,
    width: u32,
    height: u32,
    swap_damage_fn: Option<EglSwapBuffersWithDamageFn>,
}

unsafe impl Send for EglSurface {}

impl EglContext {
    /// Initialize EGL 1.5 and OpenGL ES 3.0 context from a native Wayland display pointer.
    ///
    /// # Safety
    ///
    /// - `wayland_display` must be a valid raw pointer to an active Wayland `wl_display`.
    /// - The native display pointer must remain valid for the lifetime of the EGL display and context.
    /// - Must be called on a thread capable of initializing EGL display connections.
    pub unsafe fn new(wayland_display: *mut std::ffi::c_void) -> Result<Self, Box<dyn std::error::Error>> {
        let egl_inst = egl::DynamicInstance::<egl::EGL1_5>::load_required()?;
        let egl = Arc::new(egl_inst);

        let display = egl
            .get_display(wayland_display)
            .ok_or("Failed to get EGL display from Wayland connection")?;

        let (major, minor) = egl.initialize(display)?;
        tracing::info!("Initialized EGL {}.{} on Wayland display", major, minor);

        egl.bind_api(egl::OPENGL_ES_API)?;

        let attribs = [
            egl::SURFACE_TYPE,
            egl::WINDOW_BIT,
            egl::RENDERABLE_TYPE,
            egl::OPENGL_ES3_BIT,
            egl::RED_SIZE,
            8,
            egl::GREEN_SIZE,
            8,
            egl::BLUE_SIZE,
            8,
            egl::ALPHA_SIZE,
            8,
            egl::DEPTH_SIZE,
            0,
            egl::STENCIL_SIZE,
            0,
            egl::NONE,
        ];

        let config = egl
            .choose_first_config(display, &attribs)?
            .ok_or("No matching EGL RGBA8888 GLES 3.0 configuration found")?;

        let ctx_attribs = [
            egl::CONTEXT_CLIENT_VERSION,
            3,
            egl::NONE,
        ];

        let context = egl.create_context(display, config, None, &ctx_attribs)?;

        // Ensure EGL context is current so OpenGL queries (e.g. GL_VERSION in glow, shader compilation) succeed.
        egl.make_current(display, None, None, Some(context))
            .map_err(|e| format!("Failed to make EGL context current (surfaceless): {:?}", e))?;

        let gl_res = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            let egl_clone = egl.clone();
            glow::Context::from_loader_function(move |name| {
                egl_clone
                    .get_proc_address(name)
                    .map(|p| p as *const _)
                    .unwrap_or(std::ptr::null())
            })
        }));

        let gl = match gl_res {
            Ok(g) => g,
            Err(e) => {
                let _ = egl.make_current(display, None, None, None);
                let _ = egl.destroy_context(display, context);
                return Err(format!("glow::Context initialization panicked: {:?}", e).into());
            }
        };

        let swap_damage_fn: Option<EglSwapBuffersWithDamageFn> = {
            let proc = egl
                .get_proc_address("eglSwapBuffersWithDamageEXT")
                .or_else(|| egl.get_proc_address("eglSwapBuffersWithDamageKHR"));
            if let Some(p) = proc {
                tracing::info!("Loaded EGL swap buffers with damage extension");
                Some(unsafe { std::mem::transmute::<extern "system" fn(), EglSwapBuffersWithDamageFn>(p) })
            } else {
                tracing::debug!("EGL swap buffers with damage extension not found, fallback to standard swap");
                None
            }
        };

        Ok(Self {
            egl,
            display,
            config,
            context,
            gl: Arc::new(gl),
            swap_damage_fn,
        })
    }

    /// Creates an EGL window surface for a SCTK / Wayland `WlSurface`.
    pub fn create_surface(
        &self,
        wl_surface: &WlSurface,
        width: u32,
        height: u32,
    ) -> Result<EglSurface, Box<dyn std::error::Error>> {
        let w = width.max(1) as i32;
        let h = height.max(1) as i32;
        let window = wayland_egl::WlEglSurface::new(wl_surface.id(), w, h)?;

        let surface = unsafe {
            self.egl
                .create_window_surface(self.display, self.config, window.ptr() as *mut _, None)?
        };

        Ok(EglSurface {
            egl: self.egl.clone(),
            display: self.display,
            surface,
            window,
            width: width.max(1),
            height: height.max(1),
            swap_damage_fn: self.swap_damage_fn,
        })
    }

    /// Makes this EGL context current for a given surface.
    pub fn make_current(&self, surface: &EglSurface) -> Result<(), egl::Error> {
        self.egl.make_current(
            self.display,
            Some(surface.surface),
            Some(surface.surface),
            Some(self.context),
        )
    }

    /// Unbinds current EGL context.
    pub fn make_not_current(&self) -> Result<(), egl::Error> {
        self.egl.make_current(self.display, None, None, None)
    }
}

impl EglSurface {
    /// Resizes the underlying `WlEglSurface` to match new Wayland buffer dimensions.
    pub fn resize(&mut self, width: u32, height: u32) {
        let w = width.max(1);
        let h = height.max(1);
        if self.width != w || self.height != h {
            self.width = w;
            self.height = h;
            self.window.resize(w as i32, h as i32, 0, 0);
        }
    }

    /// Swaps front and back buffers, presenting frame to Wayland compositor.
    pub fn swap_buffers(&self) -> Result<(), egl::Error> {
        self.egl.swap_buffers(self.display, self.surface)
    }

    /// Swaps front and back buffers with damage rect, using EXT or KHR extension if available.
    pub fn swap_buffers_with_damage(&self, damage: Option<crate::render::damage::DamageRect>) -> Result<(), egl::Error> {
        if let (Some(rect), Some(swap_damage)) = (damage, self.swap_damage_fn) {
            let rects = rect.to_egl_coords(self.height as i32);
            let dpy = self.display.as_ptr();
            let surf = self.surface.as_ptr();
            let res = unsafe { swap_damage(dpy, surf, rects.as_ptr(), 1) };
            if res == egl::TRUE {
                return Ok(());
            }
        }
        self.egl.swap_buffers(self.display, self.surface)
    }

    /// Queries the age of the current back buffer via `EGL_BUFFER_AGE_EXT` (0x313D).
    /// Returns:
    /// - `Some(0)`: The buffer contents are uninitialized/invalid (requires full damage).
    /// - `Some(1)`: The buffer contents match the previous frame (1 frame old).
    /// - `Some(n)`: The buffer contents are `n` frames old (requires union of damage over last `n` frames).
    /// - `None`: The extension is unsupported or query failed.
    pub fn query_buffer_age(&self) -> Option<i32> {
        const EGL_BUFFER_AGE_EXT: i32 = 0x313D;
        self.egl.query_surface(self.display, self.surface, EGL_BUFFER_AGE_EXT).ok()
    }

    #[inline]
    pub fn width(&self) -> u32 {
        self.width
    }

    #[inline]
    pub fn height(&self) -> u32 {
        self.height
    }
}

impl Drop for EglSurface {
    fn drop(&mut self) {
        let _ = self.egl.destroy_surface(self.display, self.surface);
    }
}
