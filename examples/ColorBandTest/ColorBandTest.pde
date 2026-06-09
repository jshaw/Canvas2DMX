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

// 4 bands × 20 LEDs = 80 LEDs total
static final int LEDS_PER_BAND = 20;
static final int BAND_W        = 72;
static final int BAND_H        = 168;
static final int BAND_GAP      = 12;
static final int STAGE_PAD     = 18;
static final int HUD_H         = 74;
static final int FOOTER_H      = 56;
static final int BAND_COUNT    = 4;

Canvas2DMX c2d;
DmxP512 dmxPro;
DMXControl dmxOpen;
boolean dmxAvailable = false;
String[] bandNames = { "RED", "GREEN", "BLUE", "WHITE" };
int[] bandColors;
float stageX;
float stageY;
float stageW;
float stageH;
float bandsX;
float bandsY;

void settings() {
  size(420, 330);
  pixelDensity(1);
}

void setup() {
  initDmx();
  bandColors = new int[] {
    color(255, 72, 72),
    color(48, 220, 120),
    color(72, 140, 255),
    color(255, 248, 232)
  };

  stageW = BAND_COUNT * BAND_W + (BAND_COUNT - 1) * BAND_GAP + STAGE_PAD * 2;
  stageH = BAND_H + STAGE_PAD * 2;
  stageX = (width - stageW) / 2f;
  stageY = HUD_H;
  bandsX = stageX + STAGE_PAD;
  bandsY = stageY + STAGE_PAD;

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

  for (int band = 0; band < BAND_COUNT; band++) {
    float bandCenterX = bandsX + band * (BAND_W + BAND_GAP) + BAND_W / 2.0f;
    println("Band " + band + " (" + bandNames[band] + "): LEDs " + ledIndex + "-" + (ledIndex+LEDS_PER_BAND-1));
    c2d.mapLedStrip(ledIndex, LEDS_PER_BAND, bandCenterX, bandsY + BAND_H / 2.0f, 7, HALF_PI, false);
    ledIndex += LEDS_PER_BAND;
  }

  println("Total LEDs mapped: " + c2d.getMappedLedCount());
  if (dmxAvailable) bootSequence();
  else println("No DMX device found — running ColorBandTest in preview-only mode.");
}

void draw() {
  drawBackdrop();
  drawStage();
  drawBands();

  int[] colors = c2d.getLedColors();
  drawLedMarkers(colors);
  c2d.visualize(colors);
  drawHud(colors);

  sendDmx();
}

void drawBackdrop() {
  noStroke();
  for (int y = 0; y < height; y += 4) {
    float mix = map(y, 0, height, 0, 1);
    fill(12 + 14 * mix, 18 + 18 * mix, 30 + 26 * mix);
    rect(0, y, width, 4);
  }

  fill(255, 255, 255, 12);
  ellipse(width * 0.2f, 58, 140, 140);
  ellipse(width * 0.82f, height - 54, 180, 180);
}

void drawStage() {
  fill(8, 12, 20, 210);
  noStroke();
  rect(stageX, stageY, stageW, stageH, 18);

  stroke(255, 255, 255, 26);
  strokeWeight(1.5f);
  noFill();
  rect(stageX + 7, stageY + 7, stageW - 14, stageH - 14, 14);
}

void drawBands() {
  textAlign(CENTER, CENTER);
  for (int band = 0; band < BAND_COUNT; band++) {
    float x = bandsX + band * (BAND_W + BAND_GAP);
    int col = bandColors[band];

    noStroke();
    fill(255, 255, 255, 18);
    rect(x - 2, bandsY - 2, BAND_W + 4, BAND_H + 4, 12);

    fill(col);
    rect(x, bandsY, BAND_W, BAND_H, 10);

    fill(band == 3 ? 24 : 255, band == 3 ? 24 : 255, band == 3 ? 24 : 255, 230);
    textSize(11);
    text(bandNames[band], x + BAND_W / 2.0f, bandsY + 16);
  }
}

void drawLedMarkers(int[] colors) {
  int n = c2d.getMappedLedCount();
  pushStyle();
  strokeWeight(1.2f);
  for (int i = 0; i < n; i++) {
    PVector pos = c2d.getLedPosition(i);
    if (pos == null) continue;
    int col = (i < colors.length) ? colors[i] : color(0);
    fill(col);
    stroke(0, 120);
    ellipse(pos.x, pos.y, 9, 9);
  }
  popStyle();
}

void drawHud(int[] colors) {
  float panelX = 14;
  float panelW = width - 28;

  fill(0, 150);
  noStroke();
  rect(panelX, 14, panelW, 46, 12);

  fill(255);
  textAlign(LEFT, TOP);
  textSize(15);
  text("ColorBandTest", 26, 24);

  textSize(11);
  fill(210);
  text("80 mapped LEDs across 4 fixed diagnostic bands", 26, 44);

  fill(0, 150);
  rect(panelX, height - FOOTER_H - 10, panelW, FOOTER_H, 12);

  String status = dmxAvailable ? (USE_ENTTEC_PRO ? "ENTTEC Pro live" : "Open DMX live") : "Preview only";
  String pattern = "Pattern: " + DMX_CHANNEL_PATTERN;
  String expectation = "Expected order:\nRED / GREEN / BLUE / WHITE";

  fill(255);
  textSize(11);
  text(status, 26, height - FOOTER_H + 4);
  text(pattern, 26, height - FOOTER_H + 20);
  float rightColX = panelX + panelW * 0.54f;
  float rightColW = panelW - (rightColX - panelX) - 12;
  text(expectation, rightColX, height - FOOTER_H + 4, rightColW, FOOTER_H - 12);
}

void bootSequence() {
  if (!dmxAvailable) return;
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
  if (!dmxAvailable) return;
  if (USE_ENTTEC_PRO) {
    c2d.sendToDmx((ch, val) -> dmxPro.set(ch + DMX_OFFSET - 1, val));
  } else {
    c2d.sendToDmx((ch, val) -> dmxOpen.sendValue(ch, val));
  }
}

void initDmx() {
  if (USE_ENTTEC_PRO) {
    String[] ports = Serial.list();
    boolean portFound = false;
    for (String p : ports) {
      if (p.equals(DMX_PORT)) { portFound = true; break; }
    }
    if (!portFound) {
      println("DMX port \"" + DMX_PORT + "\" not found. Running preview-only.");
      for (String p : ports) println("  " + p);
      return;
    }
    try {
      dmxPro = new DmxP512(this, DMX_UNIVERSE, false);
      dmxPro.setupDmxPro(DMX_PORT, DMX_BAUDRATE);
      dmxAvailable = true;
    } catch (Exception e) {
      println("Failed to open ENTTEC Pro: " + e.getMessage());
    }
  } else {
    try {
      dmxOpen = new DMXControl(0, DMX_UNIVERSE);
      dmxAvailable = true;
    } catch (Exception e) {
      println("No Open DMX device found: " + e.getMessage());
    }
  }
}
