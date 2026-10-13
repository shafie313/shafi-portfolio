NEXUS — Windows IT Diagnostics Toolkit v3.0

This project page introduces the supplied PowerShell script and provides the
script and project presentation as downloads.

WHAT THE SCRIPT DOES
- Runs selected, read-only Windows system, storage, network, service, printer,
  software, licensing, event-log and security-service checks.
- Saves a timestamped HTML report and CSV file in a Reports folder beside the
  script.
- Does not automatically repair the computer.

BEFORE RUNNING
- Review the script before running it.
- Use only a Windows 10/11 computer you own or are authorized to support.
- Follow your organization's security and PowerShell execution policies.
- The script asks for its configured access password. This simple prompt is
  not strong security.
- Some checks use DNS/HTTPS and ICMP network requests; local network policy
  can affect their results.
- A warning or failed ping is a clue to investigate, not proof of a fault.

FILES
- index.html, style.css, script.js: project page
- assets/NEXUS_Windows_IT_Diagnostics_Toolkit_v3.ps1: actual v3.0 script
- assets/NEXUS_Windows_IT_Diagnostics_Project.pptx: project overview slides
- assets/nexus-workflow.svg: explanatory illustration, not a test screenshot

Open index.html in a browser to preview the page. Add real screenshots or
sample reports only after testing on an authorized Windows computer.
