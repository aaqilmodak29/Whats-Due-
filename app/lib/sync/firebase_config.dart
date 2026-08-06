/// Firebase project identifiers.
///
/// **These are not secrets.** A Firebase web API key is a public project
/// identifier — it is embedded in the JavaScript of every Firebase web app and
/// is safe to commit. It grants nothing on its own: what actually protects the
/// data is the Firestore security rules, which only allow a signed-in user to
/// touch their own document. See `firestore.rules` at the repository root.
///
/// Sync stays switched off until these are filled in, so a fresh clone with no
/// project of its own still builds and runs as a local-only app.
class FirebaseConfig {
  FirebaseConfig._();

  /// Firebase console → Project settings → General → Project ID.
  static const projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'whats-due-sync',
  );

  /// Firebase console → Project settings → General → Web API Key.
  static const apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: '',
  );

  /// False when the project has not been wired up. The whole sync UI hides
  /// itself rather than offering a sign-in that cannot possibly work.
  static bool get isConfigured =>
      projectId.isNotEmpty && apiKey.isNotEmpty;

  // Firebase Auth and Firestore are both reached over their REST APIs rather
  // than through the FlutterFire plugins. Whole-document last-write-wins needs
  // exactly two operations — read a document, write a document — and the local
  // store already serves as the offline cache, so the native SDKs' offline
  // persistence and real-time listeners buy nothing. In exchange there are no
  // native dependencies at all: one identical code path on Windows, Android and
  // the web, and no Firebase C++ SDK to break a desktop build.
  static const _identity = 'https://identitytoolkit.googleapis.com/v1';
  static const _secureToken = 'https://securetoken.googleapis.com/v1';

  static Uri signUp() => Uri.parse('$_identity/accounts:signUp?key=$apiKey');
  static Uri signIn() =>
      Uri.parse('$_identity/accounts:signInWithPassword?key=$apiKey');
  static Uri refresh() => Uri.parse('$_secureToken/token?key=$apiKey');

  /// The single document holding this user's whole state.
  static Uri document(String uid) => Uri.parse(
    'https://firestore.googleapis.com/v1/projects/$projectId'
    '/databases/(default)/documents/users/$uid/state/current',
  );
}
