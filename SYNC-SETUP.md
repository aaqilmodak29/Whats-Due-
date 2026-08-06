# Setting up sync

One-time, about five minutes. Needs your Google account, so it has to be you —
none of it can be scripted from here.

At the end you get one list shared across the Windows app, the Android app and
the web build. Sign in once per device with the same account.

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

1. Left sidebar → **Build** → **Firestore Database** → **Create database**
2. Location: **`australia-southeast1`** (Sydney — closest to you, lowest latency)
3. Start in **production mode**. The rules get replaced in the next step anyway,
   and test mode would leave the database open to the world for 30 days

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

**Send me both.** They are not secrets — a Firebase web API key is a public
project identifier embedded in the JavaScript of every Firebase web app, and it
grants nothing on its own. What protects your data is the rules from step 4,
which only let a signed-in user touch their own document. They get committed to
the repository, which is normal and safe.

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
that device, nothing is deleted. Delete the Firebase project and all three
copies keep working independently, exactly as they did before sync existed.
