// Spicetify bakes its Stylix color.ini into Spotify in the Nix store. Keep
// the running renderer on the selected palette by updating those same CSS
// variables from Seele's local, read-only palette endpoint.
const slots = {
  text: "base05",
  subtext: "base05",
  main: "base00",
  "main-elevated": "base02",
  highlight: "base02",
  "highlight-elevated": "base03",
  sidebar: "base01",
  player: "base04",
  card: "base03",
  shadow: "base00",
  "selected-row": "base04",
  button: "base04",
  "button-active": "base04",
  "button-disabled": "base03",
  "tab-active": "base02",
  notification: "base02",
  "notification-error": "base08",
  equalizer: "base0B",
  misc: "base02",
};

let current = "";
let reading = false;
async function syncTheme() {
  if (reading) return;
  reading = true;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 3000);
  try {
    const response = await fetch("http://127.0.0.1:48725/palette", { cache: "no-store", signal: controller.signal });
    if (!response.ok) return;
    const { id, palette } = await response.json();
    if (typeof id !== "string" || !palette) return;
    const revision = JSON.stringify(palette);
    if (revision === current) return;
    const values = Object.entries(slots).map(([name, key]) => [name, palette[key]]);
    if (values.some(([, value]) => typeof value !== "string" || !/^#[0-9a-fA-F]{6}$/.test(value))) return;
    for (const [name, value] of values) {
      document.documentElement.style.setProperty(`--spice-${name}`, value);
      const [red, green, blue] = [1, 3, 5].map(offset => parseInt(value.slice(offset, offset + 2), 16));
      document.documentElement.style.setProperty(`--spice-rgb-${name}`, `${red},${green},${blue}`);
    }
    current = revision;
  } catch {
    // The packaged Stylix palette remains the fallback when the user service
    // is not running, including before the next Home Manager activation.
  } finally {
    clearTimeout(timeout);
    reading = false;
  }
}

syncTheme();
setInterval(syncTheme, 750);
