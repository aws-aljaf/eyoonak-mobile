/// Trims and uppercases a pairing code exactly the way the web app's
/// `DevicePairingRedeemPage.vue` does before posting it
/// (`code.value.trim().toUpperCase()`) — `DevicePairingCode::generateUniqueCode()`
/// on the backend only ever produces uppercase alphanumeric codes, but a
/// human typing one by hand (rather than scanning the QR/following its
/// link) may well type it in lowercase or with stray leading/trailing
/// whitespace from a copy-paste. Pulled out as a pure function so this
/// normalization is unit-testable without pumping a real form widget.
String normalizePairingCode(String raw) => raw.trim().toUpperCase();

/// The backend's codes are always exactly 8 characters
/// (`DevicePairingCode::generateUniqueCode()`) — this is a client-side
/// "don't bother submitting yet" check only, not a substitute for the
/// server's own validation (a well-formed-looking code can still be
/// expired, already used, or simply wrong).
bool isPlausiblePairingCode(String normalized) => normalized.length == 8;
