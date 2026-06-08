/**
 * InteractiveDemo
 *
 * Drag the orb to move color across a 12-LED ring mapped to a DMX fixture.
 * Press 1/2/3 to cycle fixture channel patterns.
 *
 * Controls:
 *   Drag  : move the color orb
 *   1/2/3 : switch channel pattern (rgb / drgb / drgbsc)
 *   L     : toggle LED location markers
 *   S     : save response/temperature settings
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
boolean USE_ENTTEC_PRO = true;       // ← true = ENTTEC Pro  |  false = FT232RL cheap dongle

// DMX_PORT — serial port for your ENTTEC Pro dongle (only used when USE_ENTTEC_PRO=true).
//   To find your port: add  println(Serial.list());  to setup() and check the console.
//   Mac:     /dev/cu.usbserial-XXXXXXXX   ← must be cu. not tty.
//   Windows: COM3  (or COM4, COM5 — check Device Manager)
//   Linux:   /dev/ttyUSB0
//String DMX_PORT     = "/dev/cu.usbserial-XXXXXXXX"; // ← change to your port
String DMX_PORT     = "/dev/cu.usbserial-EN378576"; // ← change to your port

int    DMX_BAUDRATE = 115000;  // ENTTEC Pro baud rate — do not change
int    DMX_UNIVERSE = 512;     // full DMX universe; max 512 channels

// DMX_OFFSET — channel index correction for dmxP512 (only used when USE_ENTTEC_PRO=true).
//   1 = correct for most ENTTEC Pro setups (channels start at 1)
//   0 = try this only if all channels arrive one step too high
int    DMX_OFFSET   = 1;

// DMX_PATTERN_DEFAULT — startup channel pattern (press 1/2/3 at runtime to switch).
//   0 = "rgb"     plain RGB, no dimmer
//   1 = "drgb"    dimmer + RGB  (common for single-head wash fixtures)
//   2 = "drgbsc"  dimmer + RGB + strobe + color change  (common for par/wash fixtures)
int    DMX_PATTERN_DEFAULT = 2;

// ────────────────────────────────────────────────────────────────────────────

Canvas2DMX c2d;
DmxP512 dmxPro;
DMXControl dmxOpen;

float orbX;
float orbY;
float orbSize = 100;
boolean dragging = false;

String[] patterns = { "rgb", "drgb", "drgbsc", "grb" };
int patternIndex = DMX_PATTERN_DEFAULT;

void settings() {
  size(480, 420);
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
  c2d.setShowLocations(true);
  c2d.setStartAt(1);
  c2d.setResponse(2.6);
  applyPattern();
  c2d.mapLedRing(0, 12, width / 2f, height / 2f + 10, 95, -HALF_PI);

  orbX = width / 2f;
  orbY = height / 2f + 10;
  bootSequence();
}

void draw() {
  background(18, 22, 30);
  drawBackdrop();

  if (dragging) {
    orbX = constrain(mouseX, orbSize / 2f, width - orbSize / 2f);
    orbY = constrain(mouseY, 90 + orbSize / 2f, height - 70 - orbSize / 2f);
  }

  drawOrb();

  int[] colors = c2d.getLedColors();
  c2d.visualize(colors);
  c2d.showLedLocations();
  drawHud(colors);

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
    c2d.sendToDmx((ch, val) -> dmxPro.set(ch + DMX_OFFSET - 1, val));
  } else {
    c2d.sendToDmx((ch, val) -> dmxOpen.sendValue(ch, val));
  }
}

void drawBackdrop() {
  noStroke();
  for (int y = 0; y < height; y += 6) {
    float mix = map(y, 0, height, 0, 1);
    fill(20 + 50 * mix, 40 + 30 * mix, 80 + 60 * mix);
    rect(0, y, width, 6);
  }
}

void drawOrb() {
  noStroke();
  fill(255, 90, 60);
  ellipse(orbX, orbY, orbSize, orbSize);
  fill(255, 220, 120, 110);
  ellipse(orbX - 20, orbY - 20, orbSize * 0.4f, orbSize * 0.4f);
}

void drawHud(int[] colors) {
  fill(0, 170);
  noStroke();
  rect(12, 12, width - 24, 64, 8);

  fill(255);
  textSize(12);
  textAlign(LEFT, TOP);
  text("InteractiveDemo: drag the orb to move color across the LED ring", 24, 22);
  text("Press 1/2/3 for fixture pattern, L to toggle markers, S to save settings", 24, 40);
  text("Pattern: " + c2d.getChannelPattern() + "   LEDs: " + c2d.getMappedLedCount() + "   Offset: " + DMX_OFFSET, 24, 58);
}

void applyPattern() {
  c2d.setChannelPattern(patterns[patternIndex]);
  c2d.setDefaultValue('d', 255);
  c2d.setDefaultValue('s', 0);
  c2d.setDefaultValue('c', 0);
}

void keyPressed() {
  if (key == '1') { patternIndex = 0; applyPattern(); }
  else if (key == '2') { patternIndex = 1; applyPattern(); }
  else if (key == '3') { patternIndex = 2; applyPattern(); }
  else if (key == 'l' || key == 'L') { c2d.setShowLocations(!c2d.isShowLocationsEnabled()); }
  else if (key == 's' || key == 'S') {
    c2d.saveSettings("interactive-demo-settings.txt");
    println("Saved settings.");
  }
}

void mousePressed()  { dragging = dist(mouseX, mouseY, orbX, orbY) < orbSize / 2f; }
void mouseReleased() { dragging = false; }
