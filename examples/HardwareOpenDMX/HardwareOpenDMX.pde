/**
 * HardwareOpenDMX
 *
 * For FT232RL-based "Open DMX" style dongles — cheap USB DMX cables,
 * FreeStyler dongles, ENTTEC Open DMX USB, and clones.
 *
 * Uses the DMX4Artists library which handles the raw BREAK + 250kbaud
 * signal generation for FTDI chips automatically.
 *
 * Install DMX4Artists: Sketch → Import Library → Add Library → search "DMX4Artists"
 * Repo: https://github.com/jaysonh/Dmx4Artists
 *
 * If you have multiple FTDI devices, change DMX_DEVICE_INDEX to select the right one.
 */

import com.studiojordanshaw.canvas2dmx.*;
import com.jaysonh.dmx4artists.*;     // ← DMX4Artists library — install via Sketch → Import Library → Add Library

// ── Configure these for your setup ──────────────────────────────────────────
//
// This example is for FT232RL-based "Open DMX" dongles ONLY.
// If you have an ENTTEC USB Pro, use the Basics example instead (USE_ENTTEC_PRO = true).
//
// DMX_DEVICE_INDEX — which FTDI device to use if you have more than one connected.
//   0 = first device found (correct for most setups with a single dongle)
//   1, 2 … = try higher numbers if 0 doesn't open
int    DMX_DEVICE_INDEX    = 0;

int    DMX_UNIVERSE        = 512;     // full DMX universe; max 512 channels

// DMX_CHANNEL_PATTERN — must match your fixture's channel map (check its manual).
//   Each letter is one DMX channel in order:
//     d = dimmer (master brightness)   r = red    g = green   b = blue
//     w = white                        s = strobe  c = color change macro
//   GRB LED chips (e.g. WS2815 via SP201E): swap r↔g → "dgrb" or "dgrbsc"
//   Common patterns: "rgb"  "grb"  "drgb"  "drgbsc"  "rgbw"
String DMX_CHANNEL_PATTERN = "drgbsc"; // ← change to match your fixture

// Response / gamma correction — tune this for your LED type:
//   WS2812 / WS2815 via SP201E : ~2.2–2.6  (linear LEDs need gamma to avoid washed-out look)
//   Traditional DMX fixture    : 1.0–1.3    (fixture has its own curve; less correction needed)
float  DMX_RESPONSE        = 1.0;

// ────────────────────────────────────────────────────────────────────────────

Canvas2DMX c2d;
DMXControl dmx;

void settings() {
  size(320, 220);
  pixelDensity(1);
}

void setup() {
  try {
    dmx = new DMXControl(DMX_DEVICE_INDEX, DMX_UNIVERSE);
    println("DMX4Artists connected to device " + DMX_DEVICE_INDEX);
  } catch (Exception e) {
    println("Could not open DMX device: " + e.getMessage());
    println("Check DMX_DEVICE_INDEX and that DMX4Artists is installed.");
    dmx = null;
  }

  c2d = new Canvas2DMX(this);
  c2d.setChannelPattern(DMX_CHANNEL_PATTERN);
  c2d.setDefaultValue('d', 255);
  c2d.setStartAt(1);
  c2d.setResponse(DMX_RESPONSE);
  c2d.setLed(0, width / 2, height / 2 - 10);
  if (dmx != null) bootSequence();
}

void draw() {
  background(14, 18, 28);

  float orbitX = width / 2f + cos(frameCount * 0.04f) * 70f;
  float orbitY = height / 2f - 10 + sin(frameCount * 0.06f) * 40f;

  noStroke();
  fill(30, 90, 180);
  rect(0, 0, width, height);

  fill(255, 180, 40);
  ellipse(orbitX, orbitY, 90, 90);

  int[] colors = c2d.getLedColors();
  c2d.visualize(colors);
  c2d.showLedLocations();
  drawHud(colors);

  if (dmx != null) {
    c2d.sendToDmx((ch, val) -> dmx.sendValue(ch, val));
  } else if (frameCount % 30 == 0) {
    c2d.sendToDmx((ch, val) -> { if (ch <= 4) println("ch " + ch + " = " + val); });
  }
}

void bootSequence() {
  for (int i = 1; i <= 512; i++) dmx.sendValue(i, 0);
  delay(100);
  for (int i = 1; i <= 510; i++) dmx.sendValue(i, 170);
  delay(300);
  for (int i = 1; i <= 512; i++) dmx.sendValue(i, 0);
  delay(100);
  println("Boot sequence complete — strip cleared and confirmed.");
}

void dispose() {
  if (dmx != null) dmx.close();
}

void drawHud(int[] colors) {
  fill(255);
  textSize(12);
  textAlign(LEFT, TOP);
  String status = (dmx != null) ? "DMX4Artists connected" : "No device — preview only";
  text("HardwareOpenDMX: " + status, 12, 10);
  text("Pattern: " + DMX_CHANNEL_PATTERN + "  |  device: " + DMX_DEVICE_INDEX, 12, 28);

  if (colors.length > 0) {
    int sample = colors[0];
    text(
      "LED 0 RGB = " + int(red(sample)) + ", " + int(green(sample)) + ", " + int(blue(sample)),
      12, height - 48
    );
  }
}
