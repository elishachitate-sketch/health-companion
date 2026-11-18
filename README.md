# Kuda+Lumi Health Companion

This folder contains the challenge-specific health companion product. The original Kuda+Lumi Companion remains outside this folder and is preserved as the reusable foundation.

## Product direction

Build a mobile-first wellbeing companion that supports daily check-ins, identifies early risk signals, provides safe self-care guidance, and connects users to appropriate human support. It must not diagnose or replace a clinician.

## Planned modules

- `product/` — challenge statement, user journeys, and pilot assumptions
- `ai/` — prompts, safety boundaries, evaluation cases, and model notes
- `design/` — health-specific screens and interaction decisions
- `data/` — synthetic test cases only; never commit real patient data
- `docs/` — privacy, consent, clinical safety, and validation documentation

## MVP workflow

1. The user completes a short daily wellbeing check-in.
2. The companion summarizes patterns without making a diagnosis.
3. The user receives one or two practical, personalized actions.
4. Red flags trigger clear escalation guidance and optional human support.
5. The user controls what is stored and what is shared.

## Initial success measures

- Check-in completion rate
- Return rate over seven days
- Appropriate escalation on synthetic red-flag cases
- User-reported usefulness and trust
- Fairness of results across test personas

## Development rule

Health Companion work should be developed on a separate Git branch and should not modify the existing Kuda+Lumi experience until an adaptation is explicitly approved.

## Separate Firebase backend

This is a standalone Flutter and Firebase Functions project. Its Groq backend is in `functions/`; it does not use the Firebase configuration from `companion_app`.

Create or select a dedicated Firebase project, then run these commands from this folder:

```bash
firebase login
firebase use --add
cd functions && npm install && cd ..
firebase functions:secrets:set GROQ_API_KEY
firebase deploy --only functions:healthCompanionChat
```

## Cloudflare Worker deployment

The primary Groq gateway is also available as `worker/src/index.js`:

```bash
npm install -g wrangler
wrangler login
wrangler secret put GROQ_API_KEY
wrangler deploy
```

Run the Flutter app with the deployed URL:

```bash
flutter run --dart-define=HEALTH_COMPANION_WORKER_URL=https://kuda-lumi-health-companion.<your-subdomain>.workers.dev
```
