# Protecting Brain Health Earlier — Challenge Readiness

## Current demo claim

Basira is a prototype for consent-based, user-entered wellbeing reflection. It stores mood, sleep, walking, cognitive-practice, chat-tone, and voice-check-in entries in one local encrypted store and presents them as dated observations. These observations are not a validated cognitive assessment, diagnosis, risk score, or referral decision.

## Demonstrated in this repository

- English/Arabic UI and hearing/vision/companion preferences.
- User-entered sleep, mood, and walking logs.
- Cognitive practice with stored task scores, time, and dates. These are familiarization/practice activities, not a screening instrument.
- Local text-derived chat tone labels and speech-to-text-derived voice summaries.
- A review screen showing actual saved entries and empty states, with a descriptive-only interpretation warning.
- A local encrypted SQLCipher store, with an explicit delete action for the app's local profile.
- Prototype routing and workflow components, clearly separate from a real care-service integration.

## Not demonstrated / must not be claimed

- Locally validated language or culturally adapted cognitive assessment.
- Clinically meaningful-change thresholds, normative ranges, sensitivity, specificity, test–retest reliability, or reduced false referrals.
- Connected EHR, wearable, blood-pressure, metabolic/laboratory, family-history, or genomic data.
- Authenticated clinician review, referral submission, appointment booking, emergency monitoring, or closed-loop follow-up.
- Personalized clinical recommendations or improved population-health outcomes.
- The synthetic Python scoring module as a clinically validated method. Its parameters and routing labels are placeholders and must not drive live care.

## Evaluation plan before clinical use

1. Co-design the intended journey with Abu Dhabi clinicians, patients, caregivers, accessibility specialists, Arabic speakers, and relevant education groups.
2. Select an appropriate assessment/monitoring instrument and define provenance, language, form, accessibility, and administration protocol. Obtain local ethics, privacy, and clinical governance approval.
3. Run usability and accessibility studies before any diagnostic-performance study. Assess completion, comprehension, burden, and usability of sensory accommodations.
4. Establish a prospective validation protocol with an independent, qualified reference assessment and pre-specified analysis. Measure completion, test–retest reliability, sensitivity, specificity, meaningful-change performance, false-referral burden, and time to clinical assessment.
5. Report uncertainty and subgroup performance by relevant language, age, education, sensory and digital-access groups. Predefine sample-size, missing-data, small-cell, and fairness safeguards.
6. Add external data integrations only with source provenance, granular consent, authorization, security review, retention/deletion rules, and verified clinical ownership.
7. Pilot care routing with an authenticated human decision-maker and closed-loop referral/outcome capture. Keep urgent escalation instructions available, but never imply the app monitors emergencies.

## Judge-facing wording

Use: “We demonstrate a privacy-conscious prototype that brings user-entered wellbeing and practice observations into one longitudinal view and highlights the validation and human-care steps needed before clinical deployment.”

Do not use: “We detect dementia,” “clinically validated,” “predicts risk,” or claims of improved detection/referral unless supported by approved local validation and outcome data.
