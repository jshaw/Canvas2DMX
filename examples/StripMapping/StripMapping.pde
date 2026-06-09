/**
 * StripMapping
 *
 * Maps a linear LED strip across the canvas and sends it to a DMX fixture.
 * Demonstrates strip wiring direction and LED count controls.
 *
 * Controls:
 *   R     : reverse strip wiring direction
 *   [ / ] : decrease / increase LED count
 */

import com.studiojordanshaw.canvas2dmx.*;
import dmxP512.*;                     // ← required when USE_ENTTEC_PRO = true  (install via Library Manager)
import processing.serial.*;           // ← required by dmxP512
import com.jaysonh.dmx4artists.*;    // ← required when USE_ENTTEC_PRO = false (install via Library Manager)
import java.awt.Color;

// ── Configure these for your setup ──────────────────────────────────────────
//
// USE_ENTTEC_PRO — which dongle type are you using?
//   true  → ENTTEC USB Pro (or compatible pro-grade dongle)
//            Uses the dmxP512 library. Connects via serial port below.
//   false → FT232RL "cheap" dongle (transparent USB cable, "USB to DMX 512"
//            on Amazon, Open DMX USB clones, FreeStyler dongle, etc.)
//            Uses the DMX4Artists library. No port needed — auto-detected by index.
//
boolean USE_ENTTEC_PRO     = true;   // ← true = ENTTEC Pro  |  false = FT232RL cheap dongle

// DMX_PORT — serial port for your ENTTEC Pro dongle (only used when USE_ENTTEC_PRO=true).
//   To find your port: add  println(Serial.list());  to setup() and check the console.
//   Mac:     /dev/cu.usbserial-XXXXXXXX   ← must be cu. not tty.
//   Windows: COM3  (or COM4, COM5 — check Device Manager)
//   Linux:   /dev/ttyUSB0
String DMX_PORT            = "/dev/cu.usbserial-EN378576"; // ← change to your port

int    DMX_BAUDRATE        = 115000;  // ENTTEC Pro baud rate — do not change
int    DMX_UNIVERSE        = 512;     // full DMX universe; max 512 channels

// DMX_OFFSET — channel index correction for dmxP512 (only used when USE_ENTTEC_PRO=true).
//   1 = correct for most ENTTEC Pro setups (channels start at 1)
//   0 = try this only if all channels arrive one step too high
int    DMX_OFFSET          = 1;

// DMX_CHANNEL_PATTERN — must match your fixture's channel map (check its manual).
//   Each letter is one DMX channel in order:
//     d = dimmer (master brightness)   r = red    g = green   b = blue
//     w = white                        s = strobe  c = color change macro
//   Common patterns: "rgb"  "grb"  "drgb"  "drgbsc"  "rgbw"
String DMX_CHANNEL_PATTERN = "grb";

// ────────────────────────────────────────────────────────────────────────────

Canvas2DMX c2d;
DmxP512 dmxPro;
DMXControl dmxOpen;
PImage rainbow; // pre-built rainbow texture — scrolled each frame instead of redrawn
boolean dmxAvailable = false;

int ledCount = 16;
boolean reversed = false;
int scrollOffset = 0;

void settings() {
  size(520, 220);
  pixelDensity(1);
}

void setup() {
  initDmx();

  // Build a full-width rainbow image once — much faster than redrawing 520 lines per frame
  rainbow = createImage(width, height, RGB);
  rainbow.loadPixels();
  for (int x = 0; x < width; x++) {
    int col = Color.HSBtoRGB(x / (float)width, 1.0, 1.0) | 0xFF000000;
    for (int y = 0; y < height; y++) {
      rainbow.pixels[y * width + x] = col;
    }
  }
  rainbow.updatePixels();

  c2d = new Canvas2DMX(this);
  c2d.setChannelPattern(DMX_CHANNEL_PATTERN);
  c2d.setDefaultValue('d', 255);
  // Response / gamma correction — tune this for your LED type:
  //   WS2812 / WS2815 via SP201E : ~2.2–2.6  (LEDs are linear; human vision is not — without
  //                                            correction everything looks pale and washed out)
  //   Traditional DMX fixture    : 1.0–1.3    (fixture has its own curve; less correction needed)
  //   No correction              : 1.0        (use with ColorBandTest to verify raw values)
  c2d.setResponse(2.6);
  remapStrip();
  if (dmxAvailable) bootSequence();
  else println("No DMX device found — running StripMapping in preview-only mode.");
}

void draw() {
  // Scroll the pre-built rainbow — two image() calls to wrap around seamlessly
  scrollOffset = (scrollOffset + 1) % width;
  image(rainbow, -scrollOffset, 0);
  image(rainbow, width - scrollOffset, 0);

  colorMode(RGB, 255);
  fill(255);
  textSize(12);
  String backend = dmxAvailable ? (USE_ENTTEC_PRO ? "ENTTEC Pro" : "Open DMX") : "Preview only";
  text("StripMapping (" + backend + ") — R to reverse, [ ] to change LED count (" + ledCount + ")", 12, 12);

  int[] colors = c2d.getLedColors();
  c2d.visualize(colors);
  drawLedMarkers(colors); // filled dots showing actual sampled color per LED

  sendDmx();
}

// Draw each LED as a filled circle showing its actual sampled color
void drawLedMarkers(int[] colors) {
  int n = c2d.getMappedLedCount();
  pushStyle();
  for (int i = 0; i < n; i++) {
    PVector pos = c2d.getLedPosition(i);
    if (pos == null) continue;
    int col = (i < colors.length) ? colors[i] : color(0);
    fill(col);
    stroke(0, 100);
    strokeWeight(1);
    ellipse(pos.x, pos.y, 12, 12);
  }
  popStyle();
}

// Clears any LEDs left on from a previous sketch, flashes white to confirm
// the strip is alive, then blacks out ready for the draw loop.
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
    // Build the complete frame first, then write it to dmxP512 in one tight loop.
    // This minimises the window where dmxP512's send timer can fire mid-update,
    // which would cause a rolling/tearing effect where some LEDs update a frame late.
    int[] frame = c2d.buildDmxFrame(DMX_UNIVERSE);
    for (int i = 0; i < frame.length; i++) {
      dmxPro.set(i + DMX_OFFSET, frame[i]);
    }
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

void remapStrip() {
  c2d.clearLeds();
  c2d.mapLedStrip(0, ledCount, width / 2f, height / 2f, 24, 0, reversed);
}

void keyPressed() {
  if (key == 'r' || key == 'R') {
    reversed = !reversed;
    remapStrip();
  } else if (key == '[') {
    ledCount = max(4, ledCount - 1);
    remapStrip();
  } else if (key == ']') {
    ledCount = min(24, ledCount + 1);
    remapStrip();
  }
}
