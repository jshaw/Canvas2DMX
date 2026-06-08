/**
 * ColorBandTest
 *
 * Diagnostic sketch — 4 solid color bands (red / green / blue / white),
 * 10 LEDs per band, 40 LEDs total.
 *
 * Use this to verify that Canvas2DMX is sampling and sending the correct
 * colors before trying it with animated content.
 *
 * Expected result on your fixture:
 *   LEDs  0-9  → pure red
 *   LEDs 10-19 → pure green
 *   LEDs 20-29 → pure blue
 *   LEDs 30-39 → pure white
 */

import com.studiojordanshaw.canvas2dmx.*;
import dmxP512.*;                     // ← required when USE_ENTTEC_PRO = true  (install via Library Manager)
import processing.serial.*;           // ← required by dmxP512
import com.jaysonh.dmx4artists.*;    // ← required when USE_ENTTEC_PRO = false (install via Library Manager)

// ── Configure these for your setup ──────────────────────────────────────────
boolean USE_ENTTEC_PRO     = true;   // ← true = ENTTEC Pro  |  false = FT232RL cheap dongle

String DMX_PORT            = "/dev/cu.usbserial-EN378576"; // ← change to your port
int    DMX_BAUDRATE        = 115000;
int    DMX_UNIVERSE        = 512;
int    DMX_OFFSET          = 1;      // 1 = standard for ENTTEC Pro via dmxP512

// DMX_CHANNEL_PATTERN — two separate things to get right:
//
//   1. FIXTURE channel order  → what your fixture's manual says (e.g. "drgbsc")
//                                d=dimmer  r=red  g=green  b=blue  s=strobe  c=color change
//
//   2. LED CHIP color order   → some LEDs wire green before red (GRB chips).
//                                If red and green are swapped on the fixture,
//                                swap r↔g in the pattern: "drgbsc" → "dgrbsc"
//
//   For this test:  expected bands are RED / GREEN / BLUE / WHITE
//   If you see:     GREEN / RED / BLUE / WHITE  → swap r and g in the pattern
//
// Fixture channel map is "drgbsc" but LED chips are GRB (green before red),
// so swap r↔g in the color channels → "dgrbsc"
//
// WARNING: do NOT use "grb" without the leading "d" —
// that sends your green canvas value to ch1 (the dimmer), making everything
// dim or off whenever green is low. Always include "d" for fixtures with a dimmer channel.
String DMX_CHANNEL_PATTERN = "grb"; // ← WS2815 via SP201E (GRB chips, no dimmer channel)
// ────────────────────────────────────────────────────────────────────────────

// 4 bands × 10 LEDs = 40 LEDs, each band is 10px wide
static final int LEDS_PER_BAND = 20;
static final int BAND_W        = 20; // px per band

Canvas2DMX c2d;
DmxP512 dmxPro;
DMXControl dmxOpen;

void settings() {
  // Width = 4 bands × 10px; height is arbitrary — bands are vertical strips
  size(BAND_W * 4, 120);
  pixelDensity(1);
}

void setup() {
  if (USE_ENTTEC_PRO) {
    dmxPro = new DmxP512(this, DMX_UNIVERSE, false);
    dmxPro.setupDmxPro(DMX_PORT, DMX_BAUDRATE);
  } else {
    dmxOpen = new DMXControl(0, DMX_UNIVERSE);
  }

  c2d = new Canvas2DMX(this);
  c2d.setChannelPattern(DMX_CHANNEL_PATTERN);
  c2d.setDefaultValue('d', 255);
  c2d.setStartAt(1);
  // Response / gamma correction:
  //   1.0        → raw 1:1, use this to verify channel mapping (colors may look washed out)
  //   2.2 – 2.6  → correct for WS2812 / WS2815 — restores contrast and vivid color
  //   1.0 – 1.3  → for traditional DMX fixtures that apply their own curve
  c2d.setResponse(2.6);

  // Map 10 LEDs per band, centered vertically, spaced 1px apart within each band
  int ledIndex = 0;
  int[] bandColors = { color(255,0,0), color(0,255,0), color(0,0,255), color(255,255,255) };
  String[] bandNames = { "RED", "GREEN", "BLUE", "WHITE" };

  for (int band = 0; band < 4; band++) {
    float bandCenterX = band * BAND_W + BAND_W / 2.0;
    println("Band " + band + " (" + bandNames[band] + "): LEDs " + ledIndex + "-" + (ledIndex+LEDS_PER_BAND-1));
    c2d.mapLedStrip(ledIndex, LEDS_PER_BAND, bandCenterX, height / 2.0, 1, HALF_PI, false);
    ledIndex += LEDS_PER_BAND;
  }

  println("Total LEDs mapped: " + c2d.getMappedLedCount());
  bootSequence();
}

void draw() {
  // Draw the 4 solid color bands — no gradients, no gamma, pure color
  noStroke();
  fill(255, 0, 0);   rect(0,           0, BAND_W, height); // red
  fill(0, 255, 0);   rect(BAND_W,      0, BAND_W, height); // green
  fill(0, 0, 255);   rect(BAND_W * 2,  0, BAND_W, height); // blue
  fill(255,255,255); rect(BAND_W * 3,  0, BAND_W, height); // white

  int[] colors = c2d.getLedColors();

  // Draw the sampled color for each LED as a dot — should match the band exactly
  drawLedMarkers(colors);

  // Color swatch strip at bottom
  c2d.visualize(colors);

  sendDmx();
}

void drawLedMarkers(int[] colors) {
  int n = c2d.getMappedLedCount();
  pushStyle();
  strokeWeight(1);
  stroke(0, 80);
  for (int i = 0; i < n; i++) {
    PVector pos = c2d.getLedPosition(i);
    if (pos == null) continue;
    fill((i < colors.length) ? colors[i] : color(0));
    ellipse(pos.x, pos.y, 7, 7);
  }
  popStyle();
}

void bootSequence() {
  for (int i = 1; i <= 512; i++) {
    if (USE_ENTTEC_PRO) dmxPro.set(i + DMX_OFFSET - 1, 0);
    else dmxOpen.sendValue(i, 0);
  }
  delay(100);
  for (int i = 1; i <= 510; i++) {
    if (USE_ENTTEC_PRO) dmxPro.set(i + DMX_OFFSET - 1, 170);
    else dmxOpen.sendValue(i, 170);
  }
  delay(300);
  for (int i = 1; i <= 512; i++) {
    if (USE_ENTTEC_PRO) dmxPro.set(i + DMX_OFFSET - 1, 0);
    else dmxOpen.sendValue(i, 0);
  }
  delay(100);
  println("Boot sequence complete — strip cleared and confirmed.");
}

void sendDmx() {
  if (USE_ENTTEC_PRO) {
    c2d.sendToDmx((ch, val) -> dmxPro.set(ch + DMX_OFFSET - 1, val));
  } else {
    c2d.sendToDmx((ch, val) -> dmxOpen.sendValue(ch, val));
  }
}
