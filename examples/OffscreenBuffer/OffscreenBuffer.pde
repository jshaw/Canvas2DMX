/**
 * OffscreenBuffer
 *
 * Samples LED colors from a PGraphics buffer instead of the main canvas.
 * Useful when your LED mapping resolution should be independent of display size.
 * The buffer is 160x90; the sketch window displays it scaled up.
 */

import com.studiojordanshaw.canvas2dmx.*;
import dmxP512.*;                     // ← required when USE_ENTTEC_PRO = true  (install via Library Manager)
import processing.serial.*;           // ← required by dmxP512
import com.jaysonh.dmx4artists.*;    // ← required when USE_ENTTEC_PRO = false (install via Library Manager)

// ── Configure these for your setup ──────────────────────────────────────────
//
// USE_ENTTEC_PRO — SET THIS FIRST. Which dongle type are you using?     ← !!!
//   true  → ENTTEC USB Pro (or compatible pro-grade dongle)
//            Uses the dmxP512 library. Connects via DMX_PORT below.
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
//String DMX_CHANNEL_PATTERN = "drgbsc";
String DMX_CHANNEL_PATTERN = "grb";

// ────────────────────────────────────────────────────────────────────────────

Canvas2DMX c2d;
DmxP512 dmxPro;
DMXControl dmxOpen;
PGraphics ledBuffer;

void settings() {
  size(640, 360);
  pixelDensity(1);
}

void setup() {
  if (USE_ENTTEC_PRO) {
    dmxPro = new DmxP512(this, DMX_UNIVERSE, false);
    dmxPro.setupDmxPro(DMX_PORT, DMX_BAUDRATE);
  } else {
    dmxOpen = new DMXControl(0, DMX_UNIVERSE);
  }

  ledBuffer = createGraphics(160, 90);

  c2d = new Canvas2DMX(this);
  c2d.setChannelPattern(DMX_CHANNEL_PATTERN);
  c2d.setDefaultValue('d', 255);
  c2d.setResponse(2.6);
  c2d.setCanvasSize(ledBuffer.width, ledBuffer.height);
  c2d.mapLedGrid(0, 12, 6, ledBuffer.width / 2f, ledBuffer.height / 2f, 10, 12, 0, true, false);
  bootSequence();
}

void draw() {
  drawBuffer();

  image(ledBuffer, 0, 0, width, height);

  ledBuffer.loadPixels();
  int[] colors = c2d.getLedColors(ledBuffer.pixels);
  c2d.visualize(colors);

  pushMatrix();
  scale(width / (float)ledBuffer.width, height / (float)ledBuffer.height);
  c2d.showLedLocations();
  popMatrix();

  fill(255);
  textSize(12);
  String backend = USE_ENTTEC_PRO ? "ENTTEC Pro" : "Open DMX";
  text("OffscreenBuffer (" + backend + ") — mapping in 160x90, display scaled to window", 12, 14);

  sendDmx();
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
    c2d.sendToDmx(ledBuffer.pixels, (ch, val) -> dmxPro.set(ch + DMX_OFFSET - 1, val));
  } else {
    c2d.sendToDmx(ledBuffer.pixels, (ch, val) -> dmxOpen.sendValue(ch, val));
  }
}

void drawBuffer() {
  ledBuffer.beginDraw();
  ledBuffer.background(6, 8, 18);

  for (int y = 0; y < ledBuffer.height; y += 2) {
    float blend = map(y, 0, ledBuffer.height, 0, 1);
    ledBuffer.stroke(20, 40 + blend * 140, 120 + blend * 100);
    ledBuffer.line(0, y, ledBuffer.width, y);
  }

  float x = ledBuffer.width / 2f + cos(frameCount * 0.05f) * 45f;
  float y = ledBuffer.height / 2f + sin(frameCount * 0.08f) * 25f;
  ledBuffer.noStroke();
  ledBuffer.fill(255, 200, 40);
  ledBuffer.ellipse(x, y, 34, 34);
  ledBuffer.endDraw();
}
