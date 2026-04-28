# Tailscale Auth + MFA Enforcement Checklist

Last updated: 2026-03-04


Use this checklist to complete Task 3 auth hardening.

## 1) Identity Provider
- [ ] Tailscale SSO provider configured (Google/Microsoft/Okta).
- [ ] Tailnet join restricted to approved org domain/users.
- [ ] IdP conditional access policy created for Tailscale app.

## 2) MFA
- [ ] MFA required for all users at IdP.
- [ ] MFA required for admins with stronger policy (phishing-resistant if available).
- [ ] Legacy auth paths disabled (password-only or local-only bypass).

## 3) Group Mapping
- [ ] IdP group mapped to `group:platform-admins`.
- [ ] IdP group mapped to `group:devops-engineers`.
- [ ] IdP group mapped to `group:teammates-ro`.

## 4) Evidence
- [ ] Screenshot/export of IdP MFA policy.
- [ ] Screenshot of Tailscale user/group membership.
- [ ] ACL policy applied from `docs/templates/tailscale-acl.hujson`.

