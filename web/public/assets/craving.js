// The craving button on the home page: a five-minute countdown, like the app's
// SOS timer, that shows real lines from the app's meme library. Without this
// script the card shows one static line and no buttons.

const DURATION_SECONDS = 5 * 60;
const SECONDS_PER_LINE = 20;

const card = document.querySelector("[data-craving]");
if (card) {
  setUpCravingButton(card);
}

function shuffle(values) {
  const copy = [...values];
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

function setUpCravingButton(root) {
  const find = (selector) => root.querySelector(selector);
  const controls = find("[data-controls]");
  const start = find("[data-start]");
  const startLabel = find("[data-start-label]");
  const stop = find("[data-stop]");
  const ring = find("[data-ring]");
  const time = find("[data-time]");
  const label = find("[data-label]");
  const line = find("[data-line]");
  const kind = find("[data-kind]");
  const habit = find("[data-habit]");
  const data = document.getElementById("craving-lines");
  if (!controls || !start || !startLabel || !stop || !ring || !time || !label || !line || !kind || !habit || !data) {
    return;
  }

  const lines = JSON.parse(data.textContent || "[]");
  if (lines.length === 0) {
    return;
  }

  let order = shuffle(lines.map((_, index) => index));
  let position = 0;
  let interval = 0;
  let endsAt = 0;
  let lineShownAt = 0;
  let running = false;

  function showNextLine() {
    if (position >= order.length) {
      order = shuffle(order);
      position = 0;
    }
    const item = lines[order[position]];
    position += 1;
    line.textContent = item.text;
    kind.textContent = item.kind;
    habit.textContent = item.habit;
    lineShownAt = Date.now();
  }

  function showTime(remaining) {
    const minutes = Math.floor(remaining / 60);
    const seconds = String(remaining % 60).padStart(2, "0");
    time.textContent = `${minutes}:${seconds}`;
    ring.style.strokeDashoffset = String(100 - (remaining / DURATION_SECONDS) * 100);
  }

  function setIdle() {
    running = false;
    window.clearInterval(interval);
    root.classList.remove("is-done");
    label.textContent = "Hold on";
    startLabel.textContent = "I’m craving";
    stop.hidden = true;
    showTime(DURATION_SECONDS);
  }

  function finish() {
    running = false;
    window.clearInterval(interval);
    root.classList.add("is-done");
    label.textContent = "You made it";
    showTime(0);
    line.textContent = "Five minutes down. The craving lost this round.";
    kind.textContent = "Done";
    habit.textContent = "";
    startLabel.textContent = "Start again";
    stop.hidden = true;
  }

  function tick() {
    const remaining = Math.max(0, Math.ceil((endsAt - Date.now()) / 1000));
    showTime(remaining);
    if (remaining === 0) {
      finish();
    } else if (Date.now() - lineShownAt >= SECONDS_PER_LINE * 1000) {
      showNextLine();
    }
  }

  function begin() {
    running = true;
    root.classList.remove("is-done");
    endsAt = Date.now() + DURATION_SECONDS * 1000;
    label.textContent = "Hold on";
    startLabel.textContent = "Show another line";
    stop.hidden = false;
    showNextLine();
    showTime(DURATION_SECONDS);
    interval = window.setInterval(tick, 250);
  }

  start.addEventListener("click", () => {
    if (running) {
      showNextLine();
    } else {
      begin();
    }
  });

  stop.addEventListener("click", () => {
    setIdle();
    start.focus();
  });

  controls.hidden = false;
}
