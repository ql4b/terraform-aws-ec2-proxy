# Security Policy

## Supported Versions

This module follows semantic versioning. Security fixes are applied to the
latest major version line. Older major versions are not maintained unless a
maintenance branch (`N.x`) exists.

| Version | Supported          |
| ------- | ------------------ |
| 3.x     | :white_check_mark: |
| < 3.0   | :x:                |

## Reporting a Vulnerability

Please report security vulnerabilities privately rather than opening a public
issue.

- Use GitHub's [private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
  on this repository (Security tab → "Report a vulnerability"), or
- Open a regular issue **only** for non-sensitive, low-severity concerns.

When reporting, please include:

- A description of the issue and its impact.
- Steps to reproduce or a proof of concept.
- The module version (or commit) affected.

You can expect an initial acknowledgement within a reasonable time frame. Once
a fix is available it will be released under a new semantic-version tag with the
advisory referenced in the release notes.

## Scope

This is a disposable, single-instance proxy module intended for IP
diversification. It is **not** designed for high-availability or long-lived
production traffic. Review the README "Known Limitations" before deploying, in
particular: the proxy tunnels HTTPS (CONNECT) without destination ACLs, and
basic-auth credentials appear base64-encoded in launch-template user_data.
