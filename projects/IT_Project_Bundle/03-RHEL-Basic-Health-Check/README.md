# RHEL Basic Health Check

**Requirements:** Bash on RHEL or another Linux distribution. The script does not intentionally change system settings. Some commands may be absent on minimal installations.

## Run
```bash
chmod +x rhel-health-check.sh
./rhel-health-check.sh
# Optional output directory and service name:
./rhel-health-check.sh ./reports sshd
```

Open the generated `reports/linux-health-*.txt` file. On RHEL, `sshd` is a common service name; choose another installed service if appropriate. Run without `sudo` first; use elevated privileges only if a specific check genuinely requires them.
