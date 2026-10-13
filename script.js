document.addEventListener("DOMContentLoaded", () => {
  "use strict";

  // Current year in footer
  const year = document.getElementById("year");
  if (year) year.textContent = String(new Date().getFullYear());

  // Mobile navigation
  const menuToggle = document.querySelector(".menu-toggle");
  const nav = document.querySelector("#primary-nav");

  if (menuToggle && nav) {
    menuToggle.addEventListener("click", () => {
      const isOpen = nav.classList.toggle("open");
      menuToggle.setAttribute("aria-expanded", String(isOpen));
    });

    nav.querySelectorAll("a").forEach((link) => {
      link.addEventListener("click", () => {
        nav.classList.remove("open");
        menuToggle.setAttribute("aria-expanded", "false");
      });
    });

    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape") {
        nav.classList.remove("open");
        menuToggle.setAttribute("aria-expanded", "false");
      }
    });
  }

  // Interactive workstation boot slider
  const monitor = document.getElementById("boot-monitor");
  const slider = document.getElementById("boot-slider");
  const statusText = document.getElementById("boot-status-text");
  const liveStatus = document.getElementById("boot-live-status");
  const resetButton = document.getElementById("boot-reset");

  if (monitor && slider && statusText && liveStatus && resetButton) {
    const bootLines = Array.from(monitor.querySelectorAll(".boot-line"));
    const sliderHandle = slider.querySelector(".slider-handle");
    let progress = 0;
    let isDragging = false;
    let pointerGrabOffset = 0;

    const updateProgress = (nextProgress) => {
      progress = Math.max(0, Math.min(100, nextProgress));
      const travel = Math.max(0, slider.clientWidth - 24 - (sliderHandle?.clientWidth ?? 36));
      const fade = 1 - progress / 100;

      monitor.style.setProperty("--boot-progress", String(progress));
      monitor.style.setProperty("--boot-progress-percent", `${progress}%`);
      monitor.style.setProperty("--slider-offset", `${travel * progress / 100}px`);
      monitor.style.setProperty("--backlight-opacity", String(0.025 + (progress / 100) * 0.2));
      monitor.style.setProperty("--noise-opacity", String(0.58 * fade));
      monitor.style.setProperty("--glitch-opacity", String(0.36 * fade));
      bootLines.forEach((line) => {
        line.classList.toggle("is-revealed", progress >= Number(line.dataset.step));
      });
      slider.setAttribute("aria-valuenow", String(Math.round(progress)));

      if (monitor.dataset.state !== "online") {
        monitor.dataset.state = progress > 0 ? "booting" : "standby";
        statusText.textContent = progress > 0 ? `BOOTING ${Math.round(progress)}%` : "STANDBY";
        slider.setAttribute(
          "aria-valuetext",
          progress > 0 ? `Booting workstation, ${Math.round(progress)} percent.` : "System standby. Use arrow keys to boot."
        );
      }
    };

    const completeBoot = () => {
      isDragging = false;
      slider.classList.remove("is-dragging");
      monitor.dataset.booting = "false";
      monitor.dataset.state = "online";
      updateProgress(100);
      statusText.textContent = "ONLINE";
      liveStatus.textContent = "Workstation online. Network connected. Diagnostics ready.";
      slider.setAttribute("aria-valuetext", "Workstation online.");
      resetButton.hidden = false;
    };

    const returnToStandby = () => {
      isDragging = false;
      slider.classList.remove("is-dragging");
      monitor.dataset.booting = "false";
      monitor.dataset.state = "standby";
      updateProgress(0);
      statusText.textContent = "STANDBY";
      liveStatus.textContent = "System status: standby.";
      slider.setAttribute("aria-valuetext", "System standby. Use arrow keys to boot.");
      resetButton.hidden = true;
    };

    slider.addEventListener("pointerdown", (event) => {
      if (monitor.dataset.state === "online" || event.button !== 0) return;

      event.preventDefault();
      isDragging = true;
      slider.classList.add("is-dragging");
      monitor.dataset.booting = "true";
      liveStatus.textContent = "Workstation booting.";
      const handleRect = sliderHandle?.getBoundingClientRect();
      const handleWidth = sliderHandle?.clientWidth ?? 36;
      const startedOnHandle = event.target instanceof Element && event.target.closest(".slider-handle");
      pointerGrabOffset = startedOnHandle && handleRect
        ? event.clientX - handleRect.left
        : handleWidth / 2;

      if (!startedOnHandle) {
        const sliderRect = slider.getBoundingClientRect();
        const travel = Math.max(1, slider.clientWidth - 24 - handleWidth);
        const handleStart = sliderRect.left + slider.clientLeft + 12;
        updateProgress(((event.clientX - handleStart - pointerGrabOffset) / travel) * 100);
      }

      slider.setPointerCapture(event.pointerId);
    });

    slider.addEventListener("pointermove", (event) => {
      if (!isDragging) return;
      const sliderRect = slider.getBoundingClientRect();
      const handleWidth = sliderHandle?.clientWidth ?? 36;
      const travel = Math.max(1, slider.clientWidth - 24 - handleWidth);
      const handleStart = sliderRect.left + slider.clientLeft + 12;
      updateProgress(((event.clientX - handleStart - pointerGrabOffset) / travel) * 100);
    });

    const finishPointerDrag = () => {
      if (!isDragging) return;
      if (progress >= 100) {
        completeBoot();
      } else {
        returnToStandby();
      }
    };

    slider.addEventListener("pointerup", finishPointerDrag);
    slider.addEventListener("pointercancel", returnToStandby);
    slider.addEventListener("lostpointercapture", finishPointerDrag);

    slider.addEventListener("keydown", (event) => {
      if (monitor.dataset.state === "online") return;
      let nextProgress;
      switch (event.key) {
        case "ArrowRight":
        case "ArrowUp":
          nextProgress = progress + 5;
          break;
        case "ArrowLeft":
        case "ArrowDown":
          nextProgress = progress - 5;
          break;
        case "PageUp":
          nextProgress = progress + 10;
          break;
        case "PageDown":
          nextProgress = progress - 10;
          break;
        case "Home":
          nextProgress = 0;
          break;
        case "End":
          nextProgress = 100;
          break;
        case "Escape":
          returnToStandby();
          event.preventDefault();
          return;
        default:
          return;
      }

      event.preventDefault();
      updateProgress(nextProgress);
      if (progress === 100) completeBoot();
      else if (progress === 0) {
        monitor.dataset.booting = "false";
        liveStatus.textContent = "System status: standby.";
      } else {
        monitor.dataset.booting = "true";
        liveStatus.textContent = `Workstation booting, ${Math.round(progress)} percent.`;
      }
    });

    resetButton.addEventListener("click", () => {
      returnToStandby();
      slider.focus();
    });

    updateProgress(0);
  }

  // Mouse-following light on expertise cards
  document.querySelectorAll(".skill-card").forEach((card) => {
    card.addEventListener("pointermove", (event) => {
      const rect = card.getBoundingClientRect();
      card.style.setProperty("--glow-x", `${event.clientX - rect.left}px`);
      card.style.setProperty("--glow-y", `${event.clientY - rect.top}px`);
    });

    card.addEventListener("pointerleave", () => {
      card.style.setProperty("--glow-x", "50%");
      card.style.setProperty("--glow-y", "0%");
    });
  });
});
