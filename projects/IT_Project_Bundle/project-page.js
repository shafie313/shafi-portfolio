document.addEventListener("DOMContentLoaded", () => {
  const year = document.getElementById("case-year");
  if (year) year.textContent = String(new Date().getFullYear());

  document.querySelectorAll(".case-copy").forEach((button) => {
    button.addEventListener("click", async () => {
      const block = button.closest(".case-code");
      const code = block && block.querySelector("pre");
      const status = block && block.querySelector(".case-copy-status");
      if (!code || !status) return;

      try {
        await navigator.clipboard.writeText(code.innerText);
        status.textContent = "Commands copied.";
      } catch {
        status.textContent = "Copy unavailable in this browser context. Select the commands and copy them manually.";
      }
    });
  });
});
