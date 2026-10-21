--!strict
-- Zenith Design System - Continuous Dock Magnification & RK4 Spring Physics
-- Gaussian magnification curve, dynamic lateral displacement and Runge-Kutta 4th order integrator

local Magnification = {}

-- ═════════════════════════════════════════════════════════════════
-- 1. PHYSICS CONSTANTS & DEFAULT PARAMETERS
-- ═════════════════════════════════════════════════════════════════
Magnification.DEFAULTS = {
    peak_scale        = 1.42,   -- macOS/Quickshell standard peak zoom
    nominal_width     = 44.0,   -- Default dock slot width in pixels
    sigma_factor      = 1.15,   -- Gaussian standard deviation multiplier
    influence_factor  = 2.6,    -- Max interaction radius factor (sigma * factor)
    max_rise_offset   = 18.0,   -- Vertical elevation at peak scale
    -- RK4 Damped Harmonic Oscillator Presets (macOS-grade response)
    stiffness         = 240.0,  -- Spring constant (k)
    damping           = 18.0,   -- Damping coefficient (c)
    mass              = 1.0,    -- Unit mass (m)
    dt                = 1.0 / 144.0, -- Target 144Hz simulation step
}

-- ═════════════════════════════════════════════════════════════════
-- 2. RUNGE-KUTTA 4TH ORDER (RK4) SPRING INTEGRATOR
-- ═════════════════════════════════════════════════════════════════
-- Solves: m*x'' + c*x' + k*(x - x_target) = 0
function Magnification.rk4_step(
    pos: number,
    vel: number,
    target: number,
    dt_sec: number?,
    stiffness: number?,
    damping: number?,
    mass: number?
): (number, number, boolean)
    local dt = dt_sec or Magnification.DEFAULTS.dt
    local k = stiffness or Magnification.DEFAULTS.stiffness
    local c = damping or Magnification.DEFAULTS.damping
    local m = mass or Magnification.DEFAULTS.mass

    -- Instant settling test for micro-movement
    local delta = pos - target
    if math.abs(delta) < 0.0008 and math.abs(vel) < 0.0008 then
        return target, 0.0, true
    end

    local function accel(x: number, v: number): number
        return (-k * (x - target) - c * v) / m
    end

    -- k1
    local v1 = vel
    local a1 = accel(pos, v1)

    -- k2
    local p2 = pos + 0.5 * dt * v1
    local v2 = vel + 0.5 * dt * a1
    local a2 = accel(p2, v2)

    -- k3
    local p3 = pos + 0.5 * dt * v2
    local v3 = vel + 0.5 * dt * a2
    local a3 = accel(p3, v3)

    -- k4
    local p4 = pos + dt * v3
    local v4 = vel + dt * a3
    local a4 = accel(p4, v4)

    -- RK4 weighted sum
    local next_pos = pos + (dt / 6.0) * (v1 + 2.0 * v2 + 2.0 * v3 + v4)
    local next_vel = vel + (dt / 6.0) * (a1 + 2.0 * a2 + 2.0 * a3 + a4)

    -- Check if settled after step
    local is_settled = (math.abs(next_pos - target) < 0.0008 and math.abs(next_vel) < 0.0008)
    if is_settled then
        next_pos = target
        next_vel = 0.0
    end

    return next_pos, next_vel, is_settled
end

-- ═════════════════════════════════════════════════════════════════
-- 3. CONTINUOUS GAUSSIAN MAGNIFICATION CURVE
-- ═════════════════════════════════════════════════════════════════
-- Computes continuous target scale based on cursor distance to item anchor
function Magnification.gaussian_scale(
    distance: number,
    peak_scale: number?,
    sigma: number?,
    max_radius: number?
): number
    local peak = peak_scale or Magnification.DEFAULTS.peak_scale
    local s = sigma or (Magnification.DEFAULTS.nominal_width * Magnification.DEFAULTS.sigma_factor)
    local radius = max_radius or (s * Magnification.DEFAULTS.influence_factor)

    local d = math.abs(distance)
    if d > radius then
        return 1.0
    end

    -- Gaussian curve: 1.0 + (peak - 1.0) * exp(-d^2 / (2 * s^2))
    local exponent = -(d * d) / (2.0 * s * s)
    return 1.0 + (peak - 1.0) * math.exp(exponent)
end

-- ═════════════════════════════════════════════════════════════════
-- 4. DYNAMIC LATERAL SPREADING DISPLACEMENT
-- ═════════════════════════════════════════════════════════════════
-- Pushes neighbor icons outwards when center icon expands, preventing overlap
function Magnification.calculate_lateral_offsets(
    slot_centers: { number },
    cursor_x: number?,
    scales: { number },
    nominal_w: number?
): { number }
    local w0 = nominal_w or Magnification.DEFAULTS.nominal_width
    local count = #slot_centers
    local offsets = table.create(count, 0.0)

    if not cursor_x or count <= 1 then
        return offsets
    end

    local s = w0 * Magnification.DEFAULTS.sigma_factor

    for i = 1, count do
        local xi = slot_centers[i]
        local dist_to_cursor = xi - cursor_x

        if math.abs(dist_to_cursor) > 0.01 then
            local sign = if dist_to_cursor > 0 then 1.0 else -1.0
            local push_sum = 0.0

            for k = 1, count do
                local scale_k = scales[k] or 1.0
                if scale_k > 1.001 then
                    local expansion = (scale_k - 1.0) * (w0 * 0.5)
                    local dist_k = math.abs(slot_centers[k] - cursor_x)
                    local weight = math.exp(-dist_k / (s * 1.5))
                    push_sum = push_sum + (expansion * weight)
                end
            end

            -- Attenuate offset based on distance from expansion center
            local attenuation = math.exp(-math.abs(dist_to_cursor) / (s * 2.2))
            offsets[i] = math.round(sign * push_sum * attenuation)
        end
    end

    return offsets
end

-- ═════════════════════════════════════════════════════════════════
-- 5. COMPREHENSIVE SLOT TRANSFORMS PIPELINE
-- ═════════════════════════════════════════════════════════════════
-- Generates scales, vertical rise offsets, and horizontal displacements for all slots
function Magnification.compute_transforms(
    slot_count: number,
    cursor_x: number?,
    is_dock_hovered: boolean,
    slot_spacing: number?,
    nominal_w: number?,
    peak_scale: number?
): { { scale: number, rise: number, offset_x: number } }
    local w0 = nominal_w or Magnification.DEFAULTS.nominal_width
    local spacing = slot_spacing or 6.0
    local peak = peak_scale or Magnification.DEFAULTS.peak_scale
    local sigma = w0 * Magnification.DEFAULTS.sigma_factor
    local max_rise = Magnification.DEFAULTS.max_rise_offset

    -- 1. Compute anchor center X for each slot in local dock coordinates
    local slot_centers = table.create(slot_count, 0.0)
    for i = 1, slot_count do
        slot_centers[i] = (i - 1) * (w0 + spacing) + (w0 * 0.5)
    end

    local results = table.create(slot_count)

    -- If dock is not hovered or cursor is nil, return neutral rest positions
    if not is_dock_hovered or cursor_x == nil then
        for i = 1, slot_count do
            results[i] = {
                scale = 1.0,
                rise = 0,
                offset_x = 0,
            }
        end
        return results
    end

    -- 2. Compute target Gaussian scale for each slot
    local target_scales = table.create(slot_count, 1.0)
    for i = 1, slot_count do
        local dist = math.abs(slot_centers[i] - cursor_x)
        target_scales[i] = Magnification.gaussian_scale(dist, peak, sigma)
    end

    -- 3. Compute dynamic lateral offsets
    local lateral_offsets = Magnification.calculate_lateral_offsets(slot_centers, cursor_x, target_scales, w0)

    -- 4. Package final transforms with vertical rise and spring tuning
    for i = 1, slot_count do
        local raw_scale = target_scales[i]
        local final_scale = raw_scale

        -- Native spring hook integration if available in engine
        if Zenith.Spring then
            local spring_anim = Zenith.Spring(1.0, raw_scale, 240, 18)
            if spring_anim and spring_anim.target then
                final_scale = spring_anim.target
            end
        end

        local rise_px = math.round((final_scale - 1.0) * max_rise)

        results[i] = {
            scale = final_scale,
            rise = rise_px,
            offset_x = lateral_offsets[i] or 0,
        }
    end

    return results
end

return Magnification
