/// Firebase project identifiers, injected at build time.
///
/// Nothing is hardcoded here. Values come from a local `.env` that is never
/// committed — see `.env.example` and `SYNC-SETUP.md`:
///
/// ```
/// flutter build apk --release --dart-define-from-file=../.env
/// ```
///
/// Note for anyone auditing this: a Firebase web API key is not a bearer
/// credential, and it cannot be kept private from users of the app — the web
/// build has to ship it in its JavaScript in order to call Firebase at all. It
/// is kept out of source control as good hygiene, not because that conceals it.
/// The real access control is `firestore.rules`, which permits a signed-in user
/// to read and write exactly one document, their own.
///
/// Sync stays switched off when these are absent, so a build with no `.env` —
/// or a fresh clone by someone else — still compiles and runs as a local-only
/// app rather than failing.
class FirebaseConfig {
  FirebaseConfig._();

  /// Firebase console → Project settings → General → Project ID.
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  /// Firebase console → Project settings → General → Web API Key.
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');

  /// Firestore database ID.
  ///
  /// `(default)` is what the console creates for a project's first database, and
  /// is almost certainly right. It is only configurable because the newer
  /// "Create a database" flow puts Database ID front and centre as an editable
  /// field, and a named database here would otherwise fail as an unexplained 404
  /// on every sync.
  static const databaseId = String.fromEnvironment(
    'FIREBASE_DATABASE_ID',
    defaultValue: '(default)',
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
    '/databases/$databaseId/documents/users/$uid/state/current',
  );
}
