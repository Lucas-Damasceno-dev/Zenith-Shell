//! Advanced Text Editing Engine for Zenith-Shell.
//!
//! Provides text selection (click, drag, keyboard), word/line boundaries,
//! bidirectional clipboard support, atomic undo/redo stacks, and cursor spring physics.

use std::time::{Duration, Instant};
use zenith_core::SpringAnimation;

/// Direction for cursor movements.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CursorDirection {
    Left,
    Right,
    Home,
    End,
}

/// Core Text Editing Engine state and logic.
#[derive(Debug, Clone)]
pub struct TextEditorEngine {
    pub text: String,
    pub cursor: usize,
    pub selection_anchor: Option<usize>,
    pub undo_stack: Vec<(String, usize)>,
    pub redo_stack: Vec<(String, usize)>,
    pub last_click_instant: Option<Instant>,
    pub click_count: u8,
    pub cursor_spring: SpringAnimation,
}

impl Default for TextEditorEngine {
    fn default() -> Self {
        Self::new("")
    }
}

impl TextEditorEngine {
    /// Creates a new `TextEditorEngine` with initial text.
    pub fn new(initial_text: &str) -> Self {
        let len = initial_text.len();
        Self {
            text: initial_text.to_string(),
            cursor: len,
            selection_anchor: None,
            undo_stack: Vec::new(),
            redo_stack: Vec::new(),
            last_click_instant: None,
            click_count: 0,
            cursor_spring: SpringAnimation::new(len as f32, len as f32),
        }
    }

    /// Current text content.
    pub fn text(&self) -> &str {
        &self.text
    }

    /// Sets text directly, resetting selection and stacks if specified.
    pub fn set_text(&mut self, text: &str) {
        self.text = text.to_string();
        self.cursor = self.cursor.min(self.text.len());
        self.selection_anchor = None;
        self.cursor_spring.set_target(self.cursor as f32);
    }

    /// Clamp byte index to nearest valid UTF-8 character boundary.
    pub fn clamp_to_char_boundary(&self, idx: usize) -> usize {
        let mut i = idx.min(self.text.len());
        while i > 0 && !self.text.is_char_boundary(i) {
            i -= 1;
        }
        i
    }

    /// Returns the sorted byte range of current selection `[start, end]`.
    pub fn selection_range(&self) -> Option<(usize, usize)> {
        if let Some(anchor) = self.selection_anchor {
            if anchor != self.cursor {
                let start = anchor.min(self.cursor);
                let end = anchor.max(self.cursor);
                return Some((self.clamp_to_char_boundary(start), self.clamp_to_char_boundary(end)));
            }
        }
        None
    }

    /// Checks if a non-empty selection exists.
    pub fn has_selection(&self) -> bool {
        self.selection_range().is_some()
    }

    /// Returns the currently selected slice of text.
    pub fn selected_text(&self) -> Option<&str> {
        self.selection_range().map(|(start, end)| &self.text[start..end])
    }

    /// Clears any active selection anchor.
    pub fn clear_selection(&mut self) {
        self.selection_anchor = None;
    }

    /// Selects all text in the buffer (`Ctrl+A`).
    pub fn select_all(&mut self) {
        if !self.text.is_empty() {
            self.selection_anchor = Some(0);
            self.cursor = self.text.len();
            self.cursor_spring.set_target(self.cursor as f32);
        }
    }

    /// Selects word surrounding given byte index (double-click).
    pub fn select_word_at(&mut self, pos: usize) {
        let pos = self.clamp_to_char_boundary(pos);
        if self.text.is_empty() {
            return;
        }

        let chars: Vec<(usize, char)> = self.text.char_indices().collect();
        if chars.is_empty() {
            return;
        }

        let mut target_idx = 0;
        for (i, &(ci, _)) in chars.iter().enumerate() {
            if ci <= pos {
                target_idx = i;
            }
        }

        let is_word_char = |c: char| c.is_alphanumeric() || c == '_';
        let target_char = chars[target_idx].1;
        let is_target_word = is_word_char(target_char);

        // Find start boundary
        let mut s_idx = target_idx;
        while s_idx > 0 && is_word_char(chars[s_idx - 1].1) == is_target_word {
            s_idx -= 1;
        }
        let start = chars[s_idx].0;

        // Find end boundary
        let mut e_idx = target_idx;
        while e_idx + 1 < chars.len() && is_word_char(chars[e_idx + 1].1) == is_target_word {
            e_idx += 1;
        }
        let (last_byte, last_char) = chars[e_idx];
        let end = last_byte + last_char.len_utf8();

        self.selection_anchor = Some(start);
        self.cursor = end;
        self.cursor_spring.set_target(end as f32);
    }

    /// Selects the entire line / buffer (triple-click).
    pub fn select_line(&mut self) {
        self.select_all();
    }

    /// Records snapshot in undo stack and clears redo stack.
    fn push_undo_snapshot(&mut self) {
        self.undo_stack.push((self.text.clone(), self.cursor));
        if self.undo_stack.len() > 100 {
            self.undo_stack.remove(0);
        }
        self.redo_stack.clear();
    }

    /// Inserts text at cursor or replaces active selection.
    pub fn insert_text(&mut self, input: &str) {
        self.push_undo_snapshot();

        if let Some((start, end)) = self.selection_range() {
            self.text.replace_range(start..end, input);
            self.cursor = start + input.len();
            self.selection_anchor = None;
        } else {
            let cursor = self.clamp_to_char_boundary(self.cursor);
            self.text.insert_str(cursor, input);
            self.cursor = cursor + input.len();
        }
        self.cursor_spring.set_target(self.cursor as f32);
    }

    /// Backspace action: deletes selection or preceding character.
    pub fn backspace(&mut self) {
        if self.text.is_empty() {
            return;
        }

        self.push_undo_snapshot();

        if let Some((start, end)) = self.selection_range() {
            self.text.replace_range(start..end, "");
            self.cursor = start;
            self.selection_anchor = None;
        } else if self.cursor > 0 {
            let prev_idx = {
                let mut i = self.cursor - 1;
                while i > 0 && !self.text.is_char_boundary(i) {
                    i -= 1;
                }
                i
            };
            self.text.drain(prev_idx..self.cursor);
            self.cursor = prev_idx;
        }
        self.cursor_spring.set_target(self.cursor as f32);
    }

    /// Delete action: deletes selection or following character.
    pub fn delete(&mut self) {
        if self.text.is_empty() {
            return;
        }

        self.push_undo_snapshot();

        if let Some((start, end)) = self.selection_range() {
            self.text.replace_range(start..end, "");
            self.cursor = start;
            self.selection_anchor = None;
        } else if self.cursor < self.text.len() {
            let next_idx = {
                let mut i = self.cursor + 1;
                while i < self.text.len() && !self.text.is_char_boundary(i) {
                    i += 1;
                }
                i
            };
            self.text.drain(self.cursor..next_idx);
        }
        self.cursor_spring.set_target(self.cursor as f32);
    }

    /// Copy action: returns currently selected text.
    pub fn copy(&self) -> Option<String> {
        self.selected_text().map(|s| s.to_string())
    }

    /// Cut action: copies selected text and removes it from buffer.
    pub fn cut(&mut self) -> Option<String> {
        if let Some(text) = self.copy() {
            self.push_undo_snapshot();
            if let Some((start, end)) = self.selection_range() {
                self.text.replace_range(start..end, "");
                self.cursor = start;
                self.selection_anchor = None;
            }
            self.cursor_spring.set_target(self.cursor as f32);
            Some(text)
        } else {
            None
        }
    }

    /// Paste action: inserts text from clipboard.
    pub fn paste(&mut self, text: &str) {
        self.insert_text(text);
    }

    /// Undo action (`Ctrl+Z`).
    pub fn undo(&mut self) -> bool {
        if let Some((prev_text, prev_cursor)) = self.undo_stack.pop() {
            self.redo_stack.push((self.text.clone(), self.cursor));
            self.text = prev_text;
            self.cursor = self.clamp_to_char_boundary(prev_cursor);
            self.selection_anchor = None;
            self.cursor_spring.set_target(self.cursor as f32);
            true
        } else {
            false
        }
    }

    /// Redo action (`Ctrl+Shift+Z` / `Ctrl+Y`).
    pub fn redo(&mut self) -> bool {
        if let Some((next_text, next_cursor)) = self.redo_stack.pop() {
            self.undo_stack.push((self.text.clone(), self.cursor));
            self.text = next_text;
            self.cursor = self.clamp_to_char_boundary(next_cursor);
            self.selection_anchor = None;
            self.cursor_spring.set_target(self.cursor as f32);
            true
        } else {
            false
        }
    }

    /// Move cursor with or without selection extension.
    pub fn move_cursor(&mut self, direction: CursorDirection, extend_selection: bool) {
        if extend_selection && self.selection_anchor.is_none() {
            self.selection_anchor = Some(self.cursor);
        } else if !extend_selection && self.selection_anchor.is_some() {
            // Collapse selection towards direction
            if let Some((start, end)) = self.selection_range() {
                self.selection_anchor = None;
                match direction {
                    CursorDirection::Left => {
                        self.cursor = start;
                        self.cursor_spring.set_target(self.cursor as f32);
                        return;
                    }
                    CursorDirection::Right => {
                        self.cursor = end;
                        self.cursor_spring.set_target(self.cursor as f32);
                        return;
                    }
                    _ => {}
                }
            }
            self.selection_anchor = None;
        }

        match direction {
            CursorDirection::Left => {
                if self.cursor > 0 {
                    let mut i = self.cursor - 1;
                    while i > 0 && !self.text.is_char_boundary(i) {
                        i -= 1;
                    }
                    self.cursor = i;
                }
            }
            CursorDirection::Right => {
                if self.cursor < self.text.len() {
                    let mut i = self.cursor + 1;
                    while i < self.text.len() && !self.text.is_char_boundary(i) {
                        i += 1;
                    }
                    self.cursor = i;
                }
            }
            CursorDirection::Home => {
                self.cursor = 0;
            }
            CursorDirection::End => {
                self.cursor = self.text.len();
            }
        }

        self.cursor_spring.set_target(self.cursor as f32);
    }

    /// Handles mouse click with single/double/triple click detection.
    pub fn handle_click(&mut self, byte_idx: usize, extend_selection: bool, now: Instant) {
        let is_multi_click = self
            .last_click_instant
            .map(|t| now.duration_since(t) < Duration::from_millis(400))
            .unwrap_or(false);

        if is_multi_click {
            self.click_count = (self.click_count % 3) + 1;
        } else {
            self.click_count = 1;
        }
        self.last_click_instant = Some(now);

        let byte_idx = self.clamp_to_char_boundary(byte_idx);

        match self.click_count {
            1 => {
                if extend_selection {
                    if self.selection_anchor.is_none() {
                        self.selection_anchor = Some(self.cursor);
                    }
                } else {
                    self.selection_anchor = None;
                }
                self.cursor = byte_idx;
                self.cursor_spring.set_target(self.cursor as f32);
            }
            2 => {
                self.select_word_at(byte_idx);
            }
            3 => {
                self.select_line();
            }
            _ => {}
        }
    }

    /// Handles mouse drag event to extend selection.
    pub fn handle_drag(&mut self, byte_idx: usize) {
        let byte_idx = self.clamp_to_char_boundary(byte_idx);
        if self.selection_anchor.is_none() {
            self.selection_anchor = Some(self.cursor);
        }
        self.cursor = byte_idx;
        self.cursor_spring.set_target(self.cursor as f32);
    }

    /// Updates spring animation state.
    pub fn tick_spring(&mut self, dt: f32) {
        self.cursor_spring.step(dt);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_text_insert_and_selection() {
        let mut editor = TextEditorEngine::new("Hello World");
        assert_eq!(editor.cursor, 11);

        editor.select_all();
        assert_eq!(editor.selected_text(), Some("Hello World"));

        editor.insert_text("Zenith");
        assert_eq!(editor.text(), "Zenith");
        assert_eq!(editor.cursor, 6);
        assert!(!editor.has_selection());
    }

    #[test]
    fn test_undo_redo_stack() {
        let mut editor = TextEditorEngine::new("init");
        editor.insert_text(" -> first");
        assert_eq!(editor.text(), "init -> first");

        editor.insert_text(" -> second");
        assert_eq!(editor.text(), "init -> first -> second");

        assert!(editor.undo());
        assert_eq!(editor.text(), "init -> first");

        assert!(editor.undo());
        assert_eq!(editor.text(), "init");

        assert!(editor.redo());
        assert_eq!(editor.text(), "init -> first");

        assert!(editor.redo());
        assert_eq!(editor.text(), "init -> first -> second");
    }

    #[test]
    fn test_word_selection_double_click() {
        let mut editor = TextEditorEngine::new("alpha beta gamma");
        editor.select_word_at(7); // In the middle of "beta"
        assert_eq!(editor.selected_text(), Some("beta"));
        assert_eq!(editor.selection_range(), Some((6, 10)));
    }

    #[test]
    fn test_copy_cut_paste() {
        let mut editor = TextEditorEngine::new("cut me please");
        editor.select_word_at(0); // "cut"
        let cut = editor.cut();
        assert_eq!(cut, Some("cut".to_string()));
        assert_eq!(editor.text(), " me please");

        editor.move_cursor(CursorDirection::End, false);
        editor.paste(" right now");
        assert_eq!(editor.text(), " me please right now");
    }

    #[test]
    fn test_keyboard_selection_and_home_end() {
        let mut editor = TextEditorEngine::new("testing keyboard");
        editor.move_cursor(CursorDirection::Home, false);
        assert_eq!(editor.cursor, 0);

        // Shift + Right 7 times
        for _ in 0..7 {
            editor.move_cursor(CursorDirection::Right, true);
        }
        assert_eq!(editor.selected_text(), Some("testing"));

        // Shift + End
        editor.move_cursor(CursorDirection::End, true);
        assert_eq!(editor.selected_text(), Some("testing keyboard"));
    }
}
