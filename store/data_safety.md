# Data safety form – Block Fit

Answers for Play Console → Policy → App content → **Data safety**, based on
what the app does (local-only game data) plus Google's published disclosure
guidance for the **Google Mobile Ads SDK** and **Google Play Billing**.

> Before submitting, double-check these against Google's current guidance,
> since SDK behaviour can change:
> - AdMob: https://developers.google.com/admob/android/privacy/play-data-disclosure
> - Play Billing: https://developer.android.com/google/play/billing/data-safety

## Section 1 – Data collection and security

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** (via the AdMob SDK) |
| Is all of the user data collected by your app encrypted in transit? | **Yes** |
| Do you provide a way for users to request that their data is deleted? | **No**. The app holds no account data, and its local data is erased by uninstalling or clearing app data. Ad data is handled by Google; you may describe Google's controls in the field provided. |

## Section 2 – Data types

Collected = sent off the device. "Shared" = transferred to a third party
(AdMob counts as sharing for advertising).

| Category → Data type | Collected | Shared | Ephemeral? | Required or optional | Purposes |
|---|---|---|---|---|---|
| Location → **Approximate location** (from IP address) | Yes | Yes | No | Required* | Advertising or marketing; Analytics; Fraud prevention, security and compliance |
| App activity → **App interactions** (ad views/taps) | Yes | Yes | No | Required* | Advertising or marketing; Analytics; Fraud prevention, security and compliance |
| App info and performance → **Crash logs** | Yes | Yes | No | Required* | Analytics; Fraud prevention, security and compliance |
| App info and performance → **Diagnostics** | Yes | Yes | No | Required* | Analytics; Fraud prevention, security and compliance |
| App info and performance → **Other app performance data** | Yes | Yes | No | Required* | Analytics; Fraud prevention, security and compliance |
| Device or other IDs → **Device or other IDs** (Advertising ID, app set ID) | Yes | Yes | No | Required* | Advertising or marketing; Analytics; Fraud prevention, security and compliance |

\*Players can't turn ads off entirely (except via the purchase), so mark these
as **required**. EEA/UK users control personalisation through the consent form.

**Not collected** (answer No / leave unticked): Personal info (name, email,
user IDs, address, phone), Financial info*, Health and fitness, Messages,
Photos and videos, Audio files, Files and docs, Calendar, Contacts, Web
browsing, Precise location.

\*Financial info → Purchase history: the "Remove Ads" purchase is processed by
Google Play. The app itself only checks ownership on the device and sends
nothing to Adivantech, so per Google's Play Billing guidance this is normally
**not** declared as collected by the app. If you later add server-side
purchase verification, declare **Purchase history** (Collected, Not shared,
Purpose: App functionality).

## Other App content declarations

| Declaration | Answer |
|---|---|
| **Ads** – Does your app contain ads? | **Yes** |
| **Target audience and content** | Choose **13+** age groups only (e.g. 13–15, 16–17, 18+). Selecting under-13 groups puts the app under the Families policy, which needs child-directed ad settings (not configured). |
| **Content rating** (IARC questionnaire) | Category: Game → Puzzle. No violence, sexual content, profanity, drugs, gambling or user interaction/sharing. Contains ads and in-app purchases. Expected rating: Everyone / PEGI 3. |
| **Advertising ID** | **Yes**, the app uses the Advertising ID (AdMob), for Advertising and Analytics. The `AD_ID` permission is added automatically by the ads SDK. |
| **Government apps / Financial features / Health** | Not applicable |
| **Privacy policy URL** | The public URL of `store/privacy_policy.html` |
