# Skill: Code Security Review (OWASP Top 10)

> Load this skill when: Code changes need security review before merging.
> Covers OWASP Top 10 vulnerability scanning, dependency audit, and secrets detection.

## Context

In 100% AI development, AI agents write functional code that often has subtle
security flaws. They'll concatenate SQL strings, forget auth checks on new
endpoints, log sensitive data, and trust user input. This skill systematically
audits every code change against known vulnerability patterns.

## Security Review Protocol

### Phase 1: Automated Scanning

Run these scans BEFORE manual review:

```
SCAN CHECKLIST:

1. SAST (Static Application Security Testing):
   Tool: bandit (Python), semgrep (multi-language)
   Command: bandit -r app/ -f json -ll  # Medium+ severity
   Command: semgrep --config=p/owasp-top-ten app/
   Gate: Zero HIGH/CRITICAL findings

2. Dependency Audit:
   Tool: safety (Python), npm audit (Node.js)
   Command: safety check --json
   Command: npm audit --production
   Gate: Zero CRITICAL CVEs, HIGH CVEs reviewed and mitigated

3. Secrets Detection:
   Tool: gitleaks, trufflehog
   Command: gitleaks detect --source . --no-git
   Gate: ZERO secrets in code (absolute zero tolerance)

4. Container Security (if applicable):
   Tool: trivy
   Command: trivy image myapp:latest --severity HIGH,CRITICAL
   Gate: Zero CRITICAL, HIGH reviewed

SCAN RESULTS FORMAT:
  PASS  → No findings at or above threshold
  FAIL  → Findings exist → produce detailed report
  ERROR → Scan tool failed → investigate and re-run
```

### Phase 2: OWASP Top 10 Manual Review

For each code change, check:

```
A01 — BROKEN ACCESS CONTROL:

  CHECK EVERY NEW ENDPOINT:
    [ ] Has authentication check (middleware or decorator)
    [ ] Has authorization check (role/permission verification)
    [ ] Resource ownership verified (user can only access THEIR data)
    [ ] No IDOR (Insecure Direct Object Reference):
        BAD:  GET /api/users/123 → returns any user's data
        GOOD: GET /api/users/123 → returns data only if requester IS user 123 or admin
    [ ] No path traversal:
        BAD:  GET /files/../../../etc/passwd
        GOOD: Validate path is within allowed directory
    [ ] CORS configured correctly (not Access-Control-Allow-Origin: *)

  PATTERN TO FIND:
    - Endpoints without @require_auth or auth middleware
    - Database queries using user-provided ID without ownership check
    - Admin functions accessible without admin role check


A02 — CRYPTOGRAPHIC FAILURES:

  [ ] Passwords hashed with bcrypt/argon2 (NEVER MD5, SHA1, SHA256)
  [ ] Sensitive data encrypted at rest (database, S3, logs)
  [ ] TLS 1.2+ for all data in transit
  [ ] No sensitive data in URLs (tokens, passwords in query params)
  [ ] No sensitive data in logs
  [ ] Cryptographic keys from secrets manager (not hardcoded)
  [ ] Random values use cryptographic RNG (secrets module, not random)

  PATTERN TO FIND:
    - hashlib.md5(), hashlib.sha1() for passwords
    - random.randint() for tokens (should be secrets.token_urlsafe())
    - Sensitive fields in log statements


A03 — INJECTION:

  SQL INJECTION:
    BAD:  f"SELECT * FROM users WHERE email = '{email}'"
    GOOD: cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
    GOOD: User.query.filter_by(email=email).first()  # ORM

  COMMAND INJECTION:
    BAD:  os.system(f"convert {filename} output.png")
    GOOD: subprocess.run(["convert", filename, "output.png"], check=True)

  TEMPLATE INJECTION:
    BAD:  render_template_string(user_input)
    GOOD: render_template("template.html", data=user_input)

  LDAP/NoSQL/XSS:
    [ ] All user input sanitized/escaped before rendering in HTML
    [ ] Content-Security-Policy header set
    [ ] X-Content-Type-Options: nosniff header set

  PATTERN TO FIND:
    - String concatenation/f-strings in SQL queries
    - os.system(), subprocess with shell=True
    - User input passed to eval(), exec(), render_template_string()


A04 — INSECURE DESIGN:

  [ ] Rate limiting on authentication endpoints
  [ ] Account lockout after N failed attempts
  [ ] Email verification before account activation
  [ ] Password complexity requirements enforced server-side
  [ ] Business logic abuse prevention (e.g., can't apply 100 coupons)
  [ ] Proper session management (expiry, rotation, invalidation)

  PATTERN TO FIND:
    - Auth endpoints without rate limiting
    - No account lockout mechanism
    - Business rules enforced only in frontend


A05 — SECURITY MISCONFIGURATION:

  [ ] Debug mode OFF in production
  [ ] Default credentials changed/removed
  [ ] Stack traces NOT exposed in error responses
  [ ] Unnecessary HTTP methods disabled
  [ ] CORS not set to wildcard (*)
  [ ] Security headers present:
      - Strict-Transport-Security
      - Content-Security-Policy
      - X-Frame-Options
      - X-Content-Type-Options
      - Referrer-Policy

  PATTERN TO FIND:
    - DEBUG=True, app.debug=True
    - Detailed error messages in HTTP responses
    - CORS: Access-Control-Allow-Origin: *


A06 — VULNERABLE COMPONENTS:

  [ ] All dependencies at latest patch version
  [ ] No known CVEs in dependency tree
  [ ] Unused dependencies removed
  [ ] Dependencies pinned to specific versions (not ranges)

  PATTERN TO FIND:
    - requirements.txt with unpinned versions (package>=1.0)
    - package.json with * or latest versions
    - Known vulnerable packages (check safety/npm audit)


A07 — IDENTIFICATION AND AUTH FAILURES:

  [ ] Passwords minimum 8 characters + complexity
  [ ] Multi-factor authentication available for admin accounts
  [ ] Session tokens regenerated after login
  [ ] Session timeout implemented (idle + absolute)
  [ ] Password reset tokens: single-use, time-limited, random

  PATTERN TO FIND:
    - Session tokens not rotated on auth state change
    - Password reset links without expiry
    - Reusable OTP/verification codes


A08 — SOFTWARE AND DATA INTEGRITY:

  [ ] CI/CD pipeline protected (no public write access)
  [ ] Dependencies verified (checksums, lock files committed)
  [ ] Deserialization of user input uses safe methods
  [ ] Auto-update mechanisms verify signatures

  PATTERN TO FIND:
    - pickle.loads(user_data), yaml.load(user_data) without SafeLoader
    - Missing lock files (package-lock.json, poetry.lock)


A09 — SECURITY LOGGING AND MONITORING:

  [ ] Failed login attempts logged
  [ ] Authorization failures logged
  [ ] Input validation failures logged
  [ ] Logs include: timestamp, user ID, action, IP, result
  [ ] Logs do NOT include: passwords, tokens, session IDs, PII

  PATTERN TO FIND:
    - logger.info(f"Login attempt: {username}:{password}")
    - No logging on auth failures
    - Sensitive data in exception messages that get logged


A10 — SERVER-SIDE REQUEST FORGERY (SSRF):

  [ ] User-provided URLs validated (scheme, host whitelist)
  [ ] Internal network access blocked (no 10.x, 172.x, 192.168.x)
  [ ] DNS rebinding protection
  [ ] Metadata endpoint blocked (169.254.169.254)

  PATTERN TO FIND:
    - requests.get(user_url) without URL validation
    - urllib.request.urlopen(user_input)
    - fetch() with user-controlled URLs
```

### Phase 3: Security Review Report

```json
{
  "review_id": "SEC-REV-001",
  "date": "2026-03-19",
  "files_reviewed": 12,
  "scan_results": {
    "sast": { "critical": 0, "high": 0, "medium": 1, "low": 3 },
    "dependencies": { "critical": 0, "high": 0, "medium": 2 },
    "secrets": { "found": 0 }
  },
  "manual_findings": [
    {
      "id": "SEC-001",
      "severity": "HIGH",
      "category": "A01-Broken-Access-Control",
      "file": "api/routes/users.py",
      "line": 45,
      "title": "Missing ownership check on GET /users/:id",
      "description": "Any authenticated user can view any other user's profile. No check that requesting user's ID matches the requested profile ID.",
      "remediation": "Add ownership check: if request.user.id != user_id and request.user.role != 'admin': raise ForbiddenError()",
      "cwe": "CWE-639"
    }
  ],
  "gate_decision": "FAIL — 1 HIGH finding must be fixed",
  "approved": false
}
```

## Security Gate Rules

```
PASS:  0 critical + 0 high + 0 secrets
FAIL:  Any critical OR any high OR any secret found
WARN:  Medium findings → developer decides (document acceptance)
```
