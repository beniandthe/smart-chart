# Smart Chart — Monetization Strategy

Status: Active for prototype and v1
Source of truth: `docs/core-design-document.md`

## 1. Purpose

This document makes the recommended Smart Chart pricing and entitlement model explicit.

The pricing model should support product trust, keep local ownership fair, and avoid adding recurring billing before the app provides real ongoing-service value.

## 2. Launch recommendation

Recommended launch structure:
- free download
- one-time Pro unlock
- no required subscription for v1

Recommended later structure:
- optional Studio subscription only after Smart Chart offers cloud-backed or service-heavy features that justify recurring billing

## 3. Pricing principles

- The free experience must be good enough for a musician to feel the speed and value of the app.
- Core local ownership should live in the one-time Pro tier, not behind recurring billing.
- Recurring billing should only pay for features that create ongoing infrastructure, support, or service costs.
- Monetization must not make musicians feel that their local charts are being held hostage.

## 4. Recommended tier structure

### Free

Recommended v1 access:
- create and edit a limited number of local charts
- local autosave
- recent chart library
- basic rhythm-aware chord chart workflow
- enough functionality to understand the editor loop before paying

Recommended initial limit:
- 5 local charts

Recommended exclusions:
- PDF export
- concert / Bb / Eb transposition views
- document-wide font presets beyond the starter default
- special notation toolbar actions beyond the most basic creation flow
- advanced rhythm editing and polish tools that go beyond the starter experience

### Pro unlock (one-time purchase)

Recommended Pro access:
- unlimited local charts
- PDF export and sharing
- concert / Bb / Eb transposition views
- document-wide font presets
- special notation toolbar tools
- advanced rhythm-aware chord editing features
- future local-only power-user editing improvements

Pro should feel like ownership of the full local chart tool.

### Studio subscription (later, optional)

Only add Studio after these or similar ongoing-service features exist:
- cloud sync and cloud backup
- cross-device chart organization
- shared band libraries
- setlists
- version history
- AI-assisted handwriting cleanup or recognition upgrades

Studio should extend Pro. It should not replace Pro.

## 5. Entitlement rules

- Free users can keep and reopen the local charts they already created.
- Pro unlock removes the local chart cap permanently.
- A later Studio subscription should gate only ongoing-service features.
- If a future Studio subscription expires, the user should keep access to their local charts and Pro-owned local editing features.
- Restore purchases must be supported from day one of monetization.

## 6. V1 implementation guidance

For v1, keep the implementation simple:
- represent entitlement state locally
- gate chart-count limits cleanly
- gate PDF export and advanced local tools behind Pro
- keep StoreKit isolated behind a small boundary
- do not make cloud infrastructure a dependency of the editor

## 7. Open tuning knobs

These values can be adjusted after early beta feedback:
- free local chart limit
- which local editing tools are included in the free starter experience
- whether PDF export is completely Pro-only or free users receive a limited export trial
- whether some notation or font tools are partially exposed in free mode for discovery

## 8. Current recommendation summary

Smart Chart should launch as a free download with a limited local chart library and a one-time Pro unlock for the full local authoring tool. A recurring plan should come later only if the app grows into a true sync, collaboration, organization, or AI-backed service.
