/**
 * Basics
 *
 * The smallest possible Canvas2DMX sketch.
 * Maps one LED to the canvas center and sends it to a DMX fixture every frame.
 *
 * Configure the variables below to match your setup.
 */

import com.studiojordanshaw.canvas2dmx.*;
import dmxP512.*;                     // ← required when USE_ENTTEC_PRO = true  (install via Library Manager)
import processing.serial.*;           // ← required by dmxP512
import com.jaysonh.dmx4artists.*;    // ← required when USE_ENTTEC_PRO = false (install via Library Manager)

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
//String DMX_PORT            = "/dev/cu.usbserial-XXXXXXXX"; // ← change to your port
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
String DMX_CHANNEL_PATTERN = "drgbsc";

// ────────────────────────────────────────────────────────────────────────────

Canvas2DMX c2d;
DmxP512 dmxPro;
DMXControl dmxOpen;
boolean dmxAvailable = false;

void settings() {
  size(320, 220);
  pixelDensity(1);
}

void setup() {
  initDmx();

  c2d = new Canvas2DMX(this);
  c2d.setChannelPattern(DMX_CHANNEL_PATTERN);
  c2d.setDefaultValue('d', 255);
  c2d.setStartAt(1);
  c2d.setLed(0, width / 2, height / 2 - 10);

  if (dmxAvailable) bootSequence();
  else println("No DMX device found — running Basics in preview-only mode.");
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

  sendDmx();
}

// Clears any LEDs left on from a previous sketch, flashes white to confirm
// the strip is alive, then blacks out ready for the draw loop.
// SP201E and similar translators hold their last state — this resets cleanly.
void bootSequence() {
  if (!dmxAvailable) return;
  // 1. Black — clear residual state
  for (int i = 1; i <= 512; i++) {
    if (USE_ENTTEC_PRO) dmxPro.set(i + DMX_OFFSET - 1, 0);
    else dmxOpen.sendValue(i, 0);
  }
  delay(100);

  // 2. White flash at brightness 170 across all 170 LEDs (170 × 3ch = 510)
  for (int i = 1; i <= 510; i++) {
    if (USE_ENTTEC_PRO) dmxPro.set(i + DMX_OFFSET - 1, 170);
    else dmxOpen.sendValue(i, 170);
  }
  delay(300);

  // 3. Black again — ready for draw loop
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

void drawHud(int[] colors) {
  fill(255);
  textSize(12);
  textAlign(LEFT, TOP);
  String backend = dmxAvailable ? (USE_ENTTEC_PRO ? "ENTTEC Pro" : "Open DMX") : "Preview only";
  text("Basics — " + backend, 12, 10);
  text("Pattern: " + DMX_CHANNEL_PATTERN, 12, 28);

  if (colors.length > 0) {
    int sample = colors[0];
    text(
      "LED 0 RGB = " + int(red(sample)) + ", " + int(green(sample)) + ", " + int(blue(sample)),
      12, height - 48
    );
  }
}
