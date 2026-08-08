# Setting up sync

One-time, about five minutes. Needs your Google account, so it has to be you —
none of it can be scripted from here.

At the end the Windows app and the Android app share one list. Sign in once per
device with the same account.

---

## 1. Create the Firebase project

1. Go to <https://console.firebase.google.com>
2. **Create a project** → name it whatever you like (`whats-due` is fine)
3. Google Analytics: **disable it.** Nothing here needs it
4. Wait for it to finish, then **Continue**

## 2. Turn on email/password sign-in

1. Left sidebar → **Build** → **Authentication** → **Get started**
2. **Email/Password** → toggle **Enable** → **Save**

Leave "Email link (passwordless sign-in)" off.

## 3. Create the database

Left sidebar → **Build** → **Firestore Database** → **Create database**. The
wizard has three steps.

**Select edition → `Standard edition`** (the default).

Enterprise is the MongoDB-compatible edition: self-managed indexing, pipeline
and MongoDB operations, priced for that workload. This app fetches one document
by path and writes one document by path — there are no queries at all, so
nothing in Enterprise applies and Standard carries the generous free tier.

**Database ID and location**

- **Database ID: leave it as `(default)`.** A named database would work, but you
  would then have to tell me the name — the REST path defaults to `(default)`,
  and a mismatch shows up as every sync failing with a 404 rather than as
  anything helpful.
- **Location: `australia-southeast1`** (Sydney — closest, lowest latency).
  Location is permanent; the database has to be deleted and recreated to change
  it.

**Configure → production mode / locked rules.** The rules get replaced in the
next step anyway, and test mode would leave the database open to the world for
30 days.

## 4. Publish the security rules

This is the step that actually protects your data — don't skip it.

1. Firestore Database → **Rules** tab
2. Delete what's there and paste the contents of
   [`firestore.rules`](firestore.rules) from this repository
3. **Publish**

## 5. Create your account

1. **Authentication** → **Users** → **Add user**
2. Enter an email and a password (6+ characters). It does not need to be a real
   inbox — nothing is ever emailed to it — but use something you'll remember
3. **Add user**

You can also just tap *"No account yet? Create one"* in the app instead, which
does the same thing.

## 6. Get the two values I need

1. Click the **gear** → **Project settings** → **General** tab
2. Scroll to **Your apps**. If there is no web app yet, click the **`</>`**
   (web) icon, give it any nickname, **Register app**
3. Copy these two out of the config snippet:

```
projectId:  "..."
apiKey:     "..."
```

## 7. Put them in `.env`

From the repository root:

```bash
cp .env.example .env
```

Fill in `FIREBASE_PROJECT_ID` and `FIREBASE_API_KEY`. **`.env` is gitignored and
must stay that way.**

Every build that needs sync passes the file in (run from `app/`):

```bash
flutter build apk --release --split-per-abi --dart-define-from-file=../.env
```

```bash
flutter build windows --release --dart-define-from-file=../.env
```

```bash
flutter run -d windows --dart-define-from-file=../.env
```

Build without it and sync reports itself switched off. The app still works
completely, just on one device — nothing crashes and nothing is lost.

## 8. Add the same two as repository secrets

The release workflow builds the APK and cannot read your local `.env`. Add them
at **Settings → Secrets and variables → Actions → New repository secret**:

| Name | Value |
|---|---|
| `FIREBASE_PROJECT_ID` | your project ID |
| `FIREBASE_API_KEY` | your web API key |
| `FIREBASE_DATABASE_ID` | `(default)` — optional, assumed if absent |

Skip this and a released APK builds fine but reports sync as off. The workflow
prints a warning in that case so it isn't a silent surprise.

The same workflow also needs the signing key, or the APK it builds cannot
install over one you already have:

| Name | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | contents of `android-release.keystore.base64` |
| `ANDROID_KEYSTORE_PASSWORD` | the password in `keystore-secret.txt` |

Both files sit in the repository root and are gitignored. **Back up
`android-release.keystore` and its password somewhere safe** — losing them means
never being able to ship an update that installs over an existing one.

### A note on what this does and doesn't hide

Keeping these out of git is good hygiene and worth doing. It does **not** make
them private, and it's worth being clear why: the key is compiled into the app,
and anyone can unpack an APK. A Firebase web API key isn't a password — it
identifies the project and authorises nothing by itself.

What actually protects your assignments is [`firestore.rules`](firestore.rules),
which lets a signed-in user read and write exactly one document, their own, and
denies everything else. That is the control worth checking is published.

---

## What happens then

I wire the two values in, rebuild, and you sign in on each device.

The first device to sync uploads what it already has. Every device after that
pulls it down. From then on:

- It **pushes** a few seconds after you change anything
- It **pulls** when the app starts and when it comes back to the foreground
- There's a **Sync** link in the footer showing the current state, and a
  **Sync now** button

## The one case it can't merge

The whole list syncs as a single document, newest wins. If you edit on your
phone **and** on your desktop without a sync in between, one side's changes have
to lose.

The app detects that rather than silently picking. It stops, shows you both
sides — how many assignments each has and when each was edited — and asks which
to keep. Nothing is overwritten until you choose.

If you want to keep both, save a backup from the **Backup** screen first, take
one side, then re-import the other and merge.

## Cost

Free. Firestore's free tier is 50,000 reads and 20,000 writes per day; this app
does roughly one read and one write per sync, on a document of a few kilobytes.
You would have to try extremely hard to leave the free tier.

## Turning it off

Sign out on a device and it goes back to local-only — your assignments stay on
that device, nothing is deleted. Delete the Firebase project and both copies
keep working independently, exactly as they did before sync existed.
