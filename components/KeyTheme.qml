import QtQuick
import qs.Commons

// Every Key Hints color, derived from the active Omarchy theme so it changes
// live on `omarchy theme set`. Light themes get a light dim layer with dark
// text; dark themes the reverse.
//
// A theme can tune any role in shell.keyhints.toml, and a user can do the same
// under [keyhints] in ~/.config/omarchy/shell.toml (which survives theme
// switches):
//   scrim, scrim-alpha, text, muted-alpha, heading, key, key-fill-alpha,
//   key-border, key-border-alpha, key-border-width
QtObject {
  function role(key, fallback) { return Color.flatColor(Color.pick("keyhints." + key, ""), fallback) }
  function alpha(key, fallback) { return Color.pickAlpha("keyhints." + key, fallback) }

  // Theme background, not black, so the dim matches the theme's tone.
  readonly property color scrim: Util.alpha(role("scrim", Color.background), alpha("scrim-alpha", 0.88))
  // The menu is the shell's other text-over-a-scrim surface.
  readonly property color text: role("text", Color.menu.text)
  readonly property color muted: Util.alpha(text, alpha("muted-alpha", 0.6))
  readonly property color heading: role("heading", Color.accent)
  readonly property color accent: Color.accent

  // Keycaps follow the theme's normal control state ([controls] in shell.toml).
  readonly property color keyText: role("key", text)
  readonly property color keyFill: Util.alpha(keyText, alpha("key-fill-alpha", Math.max(0.1, Style.normalFillAlpha)))
  readonly property color keyBorder: Util.alpha(
    role("key-border", Style.resolveStateColor(Style.normalColorToken, text, Color.accent, Color.urgent, text)),
    alpha("key-border-alpha", Style.normalBorderAlpha))
  readonly property int keyBorderWidth: Math.max(0, Math.round(Number(Color.pick("keyhints.key-border-width", Style.normalBorderWidth))))
  readonly property int keyRadius: Math.min(Style.cornerRadius, Style.space(4))
}
