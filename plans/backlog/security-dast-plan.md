# Security Enhancements

## Dynamic Application Security Testing (DAST)

To further enhance security, we should incorporate a DAST tool like OWASP ZAP into our CI/CD
pipeline.

### Plan:

1.  **Choose a DAST tool**: OWASP ZAP is a strong candidate due to its open-source nature and
    extensive features.
2.  **Integrate with CI/CD**: Configure the chosen tool to run automatically against the application
    during the integration or delivery workflow in GitHub Actions.
3.  **Baseline Scan**: Perform an initial scan to identify existing vulnerabilities.
4.  **Triage and Prioritize**: Analyze the results, filter out false positives, and prioritize the
    remediation of critical vulnerabilities.
5.  **Automate**: Set up the pipeline to fail or alert the team if new, high-severity
    vulnerabilities are detected.
