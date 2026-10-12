//! Input Method & Dead-Key Composition Subsystem for Zenith Base v3.
//!
//! Provides ABNT2 / international dead-key composition (accents, tildes, cedillas)
//! and text-input focus management with visual focus rings.

use smithay_client_toolkit::seat::keyboard::Keysym;

/// Maps a Keysym dead key to its accent char representation.
pub fn keysym_to_dead_key(keysym: Keysym) -> Option<char> {
    match keysym {
        Keysym::dead_tilde => Some('~'),
        Keysym::dead_acute => Some('\''),
        Keysym::dead_grave => Some('`'),
        Keysym::dead_circumflex => Some('^'),
        Keysym::dead_cedilla => Some(','),
        Keysym::dead_diaeresis => Some('"'),
        _ => None,
    }
}

/// Composes a dead-key accent with a base character (e.g. `~` + `a` -> `ã`).
pub fn compose_dead_key(dead: char, base: char) -> String {
    match (dead, base) {
        // Tilde (~)
        ('~', 'a') => "ã".to_string(),
        ('~', 'o') => "õ".to_string(),
        ('~', 'n') => "ñ".to_string(),
        ('~', 'A') => "Ã".to_string(),
        ('~', 'O') => "Õ".to_string(),
        ('~', 'N') => "Ñ".to_string(),
        ('~', ' ') | ('~', '~') => "~".to_string(),

        // Acute (')
        ('\'', 'a') => "á".to_string(),
        ('\'', 'e') => "é".to_string(),
        ('\'', 'i') => "í".to_string(),
        ('\'', 'o') => "ó".to_string(),
        ('\'', 'u') => "ú".to_string(),
        ('\'', 'c') => "ç".to_string(),
        ('\'', 'A') => "Á".to_string(),
        ('\'', 'E') => "É".to_string(),
        ('\'', 'I') => "Í".to_string(),
        ('\'', 'O') => "Ó".to_string(),
        ('\'', 'U') => "Ú".to_string(),
        ('\'', 'C') => "Ç".to_string(),
        ('\'', ' ') | ('\'', '\'') => "´".to_string(),

        // Grave (`)
        ('`', 'a') => "à".to_string(),
        ('`', 'e') => "è".to_string(),
        ('`', 'i') => "ì".to_string(),
        ('`', 'o') => "ò".to_string(),
        ('`', 'u') => "ù".to_string(),
        ('`', 'A') => "À".to_string(),
        ('`', 'E') => "È".to_string(),
        ('`', 'I') => "Ì".to_string(),
        ('`', 'O') => "Ò".to_string(),
        ('`', 'U') => "Ù".to_string(),
        ('`', ' ') | ('`', '`') => "`".to_string(),

        // Circumflex (^)
        ('^', 'a') => "â".to_string(),
        ('^', 'e') => "ê".to_string(),
        ('^', 'i') => "î".to_string(),
        ('^', 'o') => "ô".to_string(),
        ('^', 'u') => "û".to_string(),
        ('^', 'A') => "Â".to_string(),
        ('^', 'E') => "Ê".to_string(),
        ('^', 'I') => "Î".to_string(),
        ('^', 'O') => "Ô".to_string(),
        ('^', 'U') => "Û".to_string(),
        ('^', ' ') | ('^', '^') => "^".to_string(),

        // Cedilla (,)
        (',', 'c') => "ç".to_string(),
        (',', 'C') => "Ç".to_string(),
        (',', ' ') => "¸".to_string(),

        // Diaeresis (")
        ('"', 'a') => "ä".to_string(),
        ('"', 'e') => "ë".to_string(),
        ('"', 'i') => "ï".to_string(),
        ('"', 'o') => "ö".to_string(),
        ('"', 'u') => "ü".to_string(),
        ('"', 'A') => "Ä".to_string(),
        ('"', 'E') => "Ë".to_string(),
        ('"', 'I') => "Ï".to_string(),
        ('"', 'O') => "Ö".to_string(),
        ('"', 'U') => "Ü".to_string(),
        ('"', ' ') | ('"', '"') => "¨".to_string(),

        // Fallback: emit both characters sequentially
        (d, b) => format!("{}{}", d, b),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_abnt2_dead_key_compositions() {
        assert_eq!(compose_dead_key('~', 'a'), "ã");
        assert_eq!(compose_dead_key('~', 'o'), "õ");
        assert_eq!(compose_dead_key('\'', 'c'), "ç");
        assert_eq!(compose_dead_key('\'', 'e'), "é");
        assert_eq!(compose_dead_key('^', 'e'), "ê");
        assert_eq!(compose_dead_key('`', 'a'), "à");
        assert_eq!(compose_dead_key('"', 'u'), "ü");
    }

    #[test]
    fn test_dead_key_standalone_space() {
        assert_eq!(compose_dead_key('~', ' '), "~");
        assert_eq!(compose_dead_key('\'', ' '), "´");
        assert_eq!(compose_dead_key('^', ' '), "^");
    }

    #[test]
    fn test_uncomposable_fallback() {
        assert_eq!(compose_dead_key('~', 'z'), "~z");
    }
}
