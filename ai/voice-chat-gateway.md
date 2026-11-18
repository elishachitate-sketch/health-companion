# Basira voice/chat gateway integration

The mobile client uses a first-party authenticated WebSocket gateway rather than embedding provider credentials. Configure `BASIRA_VOICE_GATEWAY_URL` at build time as a `wss://` URL (for the Worker route: `wss://<worker-host>/voice`) and `VOICE_GATEWAY_URL` on the Worker as a secure upstream WebSocket service. The upstream must authenticate the forwarded bearer token, bind the session to an authorized case/purpose, implement the protocol below, and proxy only to an approved provider. The current Groq chat completion endpoint is not a realtime audio gateway; this Worker route does not itself transcribe, synthesize, or clinically interpret audio.

## Authentication and consent

- The client requires an active authenticated user for the live path; the host injects a short-lived access-token provider. The client sends the token in the first encrypted WebSocket data frame (`auth.authenticate`), never in the URL or WebSocket subprotocol. The Worker forwards only that first auth frame; the upstream must validate it and respond `auth.accepted` before any session or audio data is relayed. Treat tokens as sensitive and never log frames.
- Microphone use is disabled until the user enables the explicit voice-processing consent switch. The OS microphone permission is separately requested. Arabic recognition uses `ar-AE`; English recognition uses `en-US`. Transcribe Arabic speech in Arabic and do not translate it to English.
- Raw audio is sent as 16 kHz, mono, signed PCM16 chunks. Do not retain raw audio by default. Transcription and acoustic observations (hesitation/pause timing, speech rate) require separately reviewed purposes, a governed retention policy, and appropriate consent.
- STT/TTS locale is loaded from the local app language (`ar`/`ar-*` → `ar-AE`; otherwise → `en-US`). Arabic speech must be transcribed in Arabic and must not be translated to English. Replace that local preference adapter with the authenticated Consent & Access Agent response before production.

## Client-to-gateway event contract

1. Client upgrades to `/voice` with the `basira-voice-v1` protocol.
2. Client sends `auth.authenticate` with a short-lived access token. The gateway validates it and replies `auth.accepted` or `auth.rejected`. The Worker blocks all other client traffic until authentication succeeds.
3. Client sends `session.start` with an authorized pseudonymous case ID, locale, `appLanguage`, `languagePolicy`, audio format, modalities, VAD, and privacy preferences. The upstream must apply `languagePolicy` as system/developer instructions.
4. Client sends `session.update` on language changes, including the updated `appLanguage` and `languagePolicy`.
5. On microphone capture, the client sends `input_audio_buffer.begin` with transcription locale, selected app language, language policy, and requested non-content speech observations, then sends raw PCM binary frames. The upstream must detect each completed utterance's language and reply only in that language, falling back to the selected app language when unclear; never mix languages. Replies must be plain text, warm and short (2–3 sentences); Arabic should use Gulf-friendly Modern Standard Arabic suitable for Dubai, not Egyptian dialect. Capture remains open during server-VAD responses so a new `speech_started` event can cancel output and barge in. A user tapping the microphone control also cancels speech playback.
6. On explicit stop, the client sends `input_audio_buffer.commit` then `response.create`. With server VAD, the upstream may create responses on end-of-utterance while the mic remains open.
7. Gateway messages include `input_audio_transcription.delta`, `input_audio_transcription.completed`, optional `speech.observations`, `input_audio_buffer.speech_started`, `response.text.delta` (or `response.output_text.delta`), `response.audio.delta`, `response.audio.done`/`response.done`, and `error`.
8. Client sends a privacy-minimized `visit.routing_hint` after transcription. Treat it only as advisory: the Visit Coordination Agent must independently classify source content and enforce routing. `sudden_confusion` is urgent; hearing/daily-function flags route to clinician review.

## Audio frame contract

- Client microphone frames are **binary WebSocket messages** containing raw signed PCM16 little-endian, 16 kHz, mono audio. The upstream must not assume JSON/base64 wrapping for microphone chunks.
- `response.audio.delta` events contain base64-encoded PCM16 little-endian audio at 24 kHz mono. The client decodes and feeds chunks to its PCM player immediately; it drains on `response.audio.done` and reports turn completion on `response.done`.
- Emit `input_audio_buffer.speech_started` as soon as server VAD detects user speech during assistant playback. The client cancels current audio and drops buffered playback on this event.
- `input_audio_transcription.delta` is interpreted as incremental text appended to the in-progress utterance; `input_audio_transcription.completed` is the authoritative full utterance.
- `speech.observations` is only requested after its separate user opt-in. Send aggregate fields such as pause/hesitation counts or speech-rate summary only when approved by the privacy/clinical policy; never treat them as diagnostic.

## Text requests

HTTP chat remains available. It includes normalized locale, canonical `appLanguage`, and `visitRouting` metadata in the body. The Worker independently recalculates routing flags and detects reply language from the latest text message; never trust hidden client metadata as a clinical conclusion. A user-visible notice explains urgent human-support guidance or clinician-review routing. The standard chat API remains a separate HTTP request/response path, not token streaming.

## Operational boundary

The `/voice` Worker endpoint is only a secure WebSocket relay. `VOICE_GATEWAY_URL` must be a production service that implements first-frame authentication, audio ingestion, server VAD/barge-in, simultaneous transcription and audio/text generation, versioned orchestration events, consent enforcement, provider credential storage, rate limits, audit events and deletion behavior. Acoustic observations are a separate optional consent; the mobile defaults them off and does not persist the received measurements. Do not deploy the mobile live path until this upstream exists and has passed security, privacy, accessibility, clinical safety, Arabic dialect, and device-latency evaluation. No generated transcript, acoustic observation, or routing hint is a diagnosis or substitute for human review.
