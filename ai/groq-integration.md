# Groq integration

The Health Companion uses Groq through the Firebase Callable Function `healthCompanionChat`.

## Configuration

Set the secret in Firebase; never place it in Flutter, `.env` files committed to Git, or the repository:

```bash
firebase functions:secrets:set GROQ_API_KEY
```

Deploy the functions after setting the secret:

```bash
firebase deploy --only functions:healthCompanionChat
```

The current model is `llama-3.3-70b-versatile`. Keep the model configurable in the server function so it can be evaluated or changed without exposing provider details to the mobile client.

## Safety boundary

The endpoint performs a lightweight acute-risk pre-scan and asks the model for structured metadata. This is a fail-safe layer, not a clinical safety system. Before pilot use, test it against synthetic cases and review the escalation language with qualified health and safeguarding professionals.
