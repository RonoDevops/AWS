# Skill: Threat Modeling (STRIDE)

> Load this skill when: A new feature, service, or external-facing surface is being
> designed and needs security analysis BEFORE code is written.

## Context

In 100% AI development, security is not a phase — it's a constraint on every
decision. AI agents write functional code but don't naturally think adversarially.
This skill forces systematic threat analysis: for every feature, ask "how could
an attacker abuse this?" and build defenses into the design, not bolted on after.

## Threat Modeling Protocol

### Phase 1: Attack Surface Identification

```
For the feature being designed, identify ALL entry points:

EXTERNAL ATTACK SURFACE (internet-facing):
  [ ] API endpoints (public)
  [ ] Web application pages
  [ ] File upload endpoints
  [ ] WebSocket connections
  [ ] OAuth/SSO callback URLs
  [ ] Webhook receivers
  [ ] Public S3 buckets or CDN assets

INTERNAL ATTACK SURFACE (within the system):
  [ ] Service-to-service API calls
  [ ] Database connections
  [ ] Message queue consumers
  [ ] Background job processors
  [ ] Admin/internal APIs
  [ ] Logging and monitoring endpoints

DATA FLOWS:
  Map every path sensitive data takes:
    User input → API → Validation → Service → Database
    Database → Service → API → Response → Browser
    User upload → S3 → Processing → Database

TRUST BOUNDARIES:
  Where does trust level change?
    Internet ←→ Load Balancer (TLS termination)
    Load Balancer ←→ Application (internal network)
    Application ←→ Database (private subnet)
    Application ←→ External API (internet egress)
```

### Phase 2: STRIDE Analysis

For EACH entry point, apply all 6 threat categories:

```
FEATURE: User Registration API

┌─────────────────┬────────────────────────────────────────────────────────┐
│ THREAT           │ ANALYSIS                                              │
├─────────────────┼────────────────────────────────────────────────────────┤
│ S — SPOOFING     │ Can an attacker create accounts impersonating others? │
│                  │ Risk: Email spoofing — register with someone else's   │
│                  │       email to block them from registering later.     │
│                  │ Mitigation:                                           │
│                  │   ✓ Email verification required before account active │
│                  │   ✓ Rate limit registration per IP                    │
│                  │   ✓ CAPTCHA after 3 failed attempts from same IP     │
│                  │ Residual risk: LOW                                    │
├─────────────────┼────────────────────────────────────────────────────────┤
│ T — TAMPERING    │ Can request data be modified in transit?              │
│                  │ Risk: Man-in-the-middle modifying registration data   │
│                  │ Mitigation:                                           │
│                  │   ✓ HTTPS/TLS 1.3 enforced (HSTS header)            │
│                  │   ✓ Request body validation server-side              │
│                  │   ✓ CSRF token on form submission                    │
│                  │ Residual risk: NEGLIGIBLE                             │
├─────────────────┼────────────────────────────────────────────────────────┤
│ R — REPUDIATION  │ Can a user deny they created an account?             │
│                  │ Risk: User claims they didn't register                │
│                  │ Mitigation:                                           │
│                  │   ✓ Audit log: IP, timestamp, user-agent             │
│                  │   ✓ Email confirmation creates proof of ownership    │
│                  │   ✓ Logs stored immutably (CloudWatch + S3)          │
│                  │ Residual risk: LOW                                    │
├─────────────────┼────────────────────────────────────────────────────────┤
│ I — INFO         │ Can sensitive data leak?                              │
│   DISCLOSURE     │ Risk: Password or email exposed in logs/responses    │
│                  │ Mitigation:                                           │
│                  │   ✓ Passwords NEVER logged (mask in all contexts)    │
│                  │   ✓ Passwords hashed with bcrypt (cost 12)           │
│                  │   ✓ Error responses don't reveal internal details    │
│                  │   ✓ Email enumeration prevented (same response for   │
│                  │     exists/not-exists on login)                       │
│                  │ Residual risk: LOW                                    │
├─────────────────┼────────────────────────────────────────────────────────┤
│ D — DENIAL OF    │ Can the service be overwhelmed?                      │
│   SERVICE        │ Risk: Automated mass registration floods the system  │
│                  │ Mitigation:                                           │
│                  │   ✓ Rate limit: 10 registrations/min per IP         │
│                  │   ✓ WAF rate rules on API Gateway/ALB               │
│                  │   ✓ CAPTCHA after threshold                          │
│                  │   ✓ Email sending rate limit (prevent email bombing) │
│                  │ Residual risk: MEDIUM (sophisticated DDoS possible)  │
├─────────────────┼────────────────────────────────────────────────────────┤
│ E — ELEVATION    │ Can a user gain higher privileges?                   │
│   OF PRIVILEGE   │ Risk: User registers with admin role                 │
│                  │ Mitigation:                                           │
│                  │   ✓ Role field NOT accepted in registration request  │
│                  │   ✓ Default role = 'user' (server-enforced)         │
│                  │   ✓ Role changes require admin API + admin auth      │
│                  │   ✓ No mass assignment vulnerability (whitelist      │
│                  │     accepted fields explicitly)                       │
│                  │ Residual risk: LOW                                    │
└─────────────────┴────────────────────────────────────────────────────────┘
```

### Phase 3: Mitigation Priority Matrix

```
PRIORITY = Likelihood × Impact

| Threat | Likelihood | Impact | Priority | Status |
|--------|-----------|--------|----------|--------|
| Mass registration (DoS) | High | High | CRITICAL | Mitigated: rate limiting + WAF |
| Email enumeration | High | Medium | HIGH | Mitigated: uniform responses |
| SQL injection in email | Medium | Critical | HIGH | Mitigated: parameterized queries |
| Password in logs | Medium | High | HIGH | Mitigated: field masking |
| Mass assignment (role) | Low | Critical | HIGH | Mitigated: field whitelist |
| CSRF on registration | Low | Medium | MEDIUM | Mitigated: CSRF tokens |
| Brute force login | High | High | CRITICAL | Mitigated: lockout + rate limit |
```

### Phase 4: Security Requirements Output

```markdown
## Security Requirements for [Feature]

### Authentication
- [ ] Email verification required before account activation
- [ ] Password hashed with bcrypt, cost factor 12
- [ ] JWT tokens with 15-minute expiry, refresh tokens with 7-day expiry
- [ ] Refresh token rotation on each use (detect theft)

### Authorization
- [ ] Default role: 'user' (server-enforced, not client-provided)
- [ ] Role field excluded from create/update request schemas
- [ ] Every endpoint has explicit auth check (no auth = no access)
- [ ] Resource ownership verified (users can only access their own data)

### Input Validation
- [ ] Parameterized queries for ALL database operations
- [ ] Input length limits enforced server-side
- [ ] HTML/script tags stripped from text inputs
- [ ] File uploads: type whitelist, size limit, virus scan
- [ ] URL inputs validated against SSRF (no internal IPs)

### Rate Limiting
- [ ] Registration: 10/min per IP
- [ ] Login: 5/min per IP, lockout after 10 failed attempts
- [ ] Password reset: 3/hour per email
- [ ] API: 100/min per authenticated user, 20/min per anonymous IP

### Data Protection
- [ ] Encryption at rest: KMS for database, S3
- [ ] Encryption in transit: TLS 1.2+ (HSTS enforced)
- [ ] PII fields identified and tagged for compliance
- [ ] Passwords NEVER in logs, responses, or error messages
- [ ] Session tokens rotated on privilege change

### Logging & Monitoring
- [ ] Security events logged: login, logout, failed auth, role changes
- [ ] Logs do NOT contain: passwords, tokens, PII
- [ ] Alerts on: >10 failed logins from same IP, >100 registrations/hour
- [ ] Audit trail immutable (CloudWatch → S3 with object lock)
```

### Phase 5: Threat Model Document

```json
{
  "feature": "User Registration",
  "date": "2026-03-19",
  "attack_surface": {
    "external_endpoints": 1,
    "data_flows": 3,
    "trust_boundaries": 3
  },
  "threats_identified": 8,
  "threats_by_severity": {
    "critical": 2,
    "high": 3,
    "medium": 2,
    "low": 1
  },
  "mitigations_required": 8,
  "mitigations_implemented": 0,
  "residual_risk": "MEDIUM (DDoS remains partially mitigated)",
  "security_requirements": 22,
  "review_frequency": "Every sprint that modifies auth or adds external endpoints"
}
```

## Integration with Other Agents

```
HANDOFF:
  → Backend Dev:  Security requirements for implementation
  → Frontend Dev: CSP headers, CSRF tokens, input sanitization rules
  → DevOps:       WAF rules, security group rules, secret rotation
  → Cloud:        IAM policies, encryption config, network isolation
  → QA:           Security test scenarios (injection, auth bypass, etc.)
```
