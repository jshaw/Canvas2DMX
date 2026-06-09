/**
 * PolygonMapping
 *
 * Fills arbitrary polygon shapes with LEDs and sends them to a DMX fixture.
 * Demonstrates different fill orientations, serpentine wiring, and spacing.
 *
 * Controls:
 *   1-4   : change start corner (1=TL, 2=TR, 3=BR, 4=BL)
 *   S     : toggle serpentine (zigzag) wiring
 *   H     : toggle horizontal / vertical fill
 *   + / - : adjust LED spacing
 *   [ / ] : adjust row spacing
 *   SPACE : cycle through shape presets
 *   O     : toggle LED dot outlines / strokes
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
boolean dmxAvailable = false;

PVector[] currentShape;
String shapeName = "Triangle";

int startCorner  = 0;
boolean serpentine = true;
boolean horizontal = true;
float ledSpacing   = 20;
float rowSpacing   = 22;
float margin       = 5;

int shapeIndex     = -1;
boolean showStrokes = true;
int mappedLedCount = 0;

void settings() {
  size(600, 500);
  pixelDensity(1);
}

void setup() {
  initDmx();

  colorMode(HSB, 255);
  c2d = new Canvas2DMX(this);
  c2d.setChannelPattern(DMX_CHANNEL_PATTERN);
  c2d.setDefaultValue('d', 255);
  c2d.setResponse(2.6);
  c2d.setTemperature(0.1);

  cycleShape();
  remapPolygon();
  if (dmxAvailable) bootSequence();
  else println("No DMX device found — running PolygonMapping in preview-only mode.");

  println("=== Polygon Mapping Demo ===");
  printControls();
}

void draw() {
  background(20);
  noStroke();
  for (int y = 0; y < height; y++) {
    float hue = (y * 0.5 + frameCount * 0.5) % 255;
    fill(hue, 180, 200);
    rect(0, y, width, 1);
  }

  drawPolygonOutline();

  int[] colors = c2d.getLedColors();
  c2d.visualize(colors);
  drawLedMarkers(colors);
  drawFirstLedMarker();

  drawInfoPanel();

  sendDmx();
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

void remapPolygon() {
  c2d.clearLeds();
  Canvas2DMX.PolygonFillConfig config = new Canvas2DMX.PolygonFillConfig(ledSpacing, rowSpacing)
    .startAt(startCorner)
    .serpentine(serpentine)
    .horizontal(horizontal)
    .margin(margin);
  mappedLedCount = c2d.mapLedPolygon(0, currentShape, config);
  println("Remapped: " + mappedLedCount + " LEDs");
}

void cycleShape() {
  shapeIndex = (shapeIndex + 1) % 5;
  float cx = width / 2;
  float cy = height / 2;

  switch (shapeIndex) {
    case 0:
      shapeName = "Triangle";
      currentShape = new PVector[] {
        new PVector(cx, cy - 120),
        new PVector(cx - 140, cy + 100),
        new PVector(cx + 140, cy + 100)
      };
      break;
    case 1:
      shapeName = "Rectangle";
      currentShape = new PVector[] {
        new PVector(cx - 150, cy - 80),
        new PVector(cx + 150, cy - 80),
        new PVector(cx + 150, cy + 80),
        new PVector(cx - 150, cy + 80)
      };
      break;
    case 2:
      shapeName = "Pentagon";
      currentShape = createRegularPolygon(cx, cy, 120, 5, -HALF_PI);
      break;
    case 3:
      shapeName = "Hexagon";
      currentShape = createRegularPolygon(cx, cy, 110, 6, 0);
      break;
    case 4:
      shapeName = "Diamond";
      currentShape = new PVector[] {
        new PVector(cx, cy - 140),
        new PVector(cx + 100, cy),
        new PVector(cx, cy + 140),
        new PVector(cx - 100, cy)
      };
      break;
  }
}

PVector[] createRegularPolygon(float cx, float cy, float radius, int sides, float startAngle) {
  PVector[] verts = new PVector[sides];
  for (int i = 0; i < sides; i++) {
    float angle = startAngle + TWO_PI * i / sides;
    verts[i] = new PVector(cx + cos(angle) * radius, cy + sin(angle) * radius);
  }
  return verts;
}

// Draw each LED as a filled dot showing its actual sampled color
void drawLedMarkers(int[] colors) {
  int n = c2d.getMappedLedCount();
  pushStyle();
  for (int i = 0; i < n; i++) {
    PVector pos = c2d.getLedPosition(i);
    if (pos == null) continue;
    int col = (i < colors.length) ? colors[i] : color(0);
    fill(col);
    if (showStrokes) { stroke(0, 120); strokeWeight(1); }
    else noStroke();
    ellipse(pos.x, pos.y, 10, 10);
  }
  popStyle();
}

void drawFirstLedMarker() {
  PVector pos = c2d.getLedPosition(0);
  if (pos == null) return;

  // Pulsing ring so it's easy to spot against any background
  float pulse = 0.5f + 0.5f * sin(frameCount * 0.1f);

  pushStyle();
  noFill();
  stroke(255, 255, 0, 180 + pulse * 75);
  strokeWeight(2.5f);
  ellipse(pos.x, pos.y, 28 + pulse * 8, 28 + pulse * 8);

  // Label
  fill(255, 255, 0);
  textSize(11);
  textAlign(LEFT, CENTER);
  text("LED 0", pos.x + 10, pos.y);
  popStyle();
}

void drawPolygonOutline() {
  stroke(255, 100);
  strokeWeight(2);
  noFill();
  beginShape();
  for (PVector v : currentShape) vertex(v.x, v.y);
  endShape(CLOSE);

  fill(255);
  noStroke();
  for (int i = 0; i < currentShape.length; i++) {
    PVector v = currentShape[i];
    ellipse(v.x, v.y, 8, 8);
    if (i == 0) { textSize(10); text("v0", v.x + 10, v.y); }
  }
}

void drawInfoPanel() {
  fill(0, 180);
  noStroke();
  rect(10, 10, 210, 200, 8);

  fill(255);
  textSize(14);
  textAlign(LEFT, TOP);

  int y = 20;
  int lh = 18;
  text("Shape: " + shapeName,                          20, y); y += lh;
  text("LEDs: " + mappedLedCount,                      20, y); y += lh;
  y += 5;
  text("Start Corner: " + cornerName(startCorner),     20, y); y += lh;
  text("Serpentine: " + (serpentine ? "ON" : "OFF"),   20, y); y += lh;
  text("Fill: " + (horizontal ? "Horizontal" : "Vertical"), 20, y); y += lh;
  text("LED Spacing: " + nf(ledSpacing, 0, 1),         20, y); y += lh;
  text("Row Spacing: " + nf(rowSpacing, 0, 1),         20, y); y += lh;
  text("DMX Offset: " + DMX_OFFSET,                    20, y);

  drawCornerIndicator(170, 150, startCorner);
}

String cornerName(int corner) {
  switch (corner) {
    case 0: return "Top-Left";
    case 1: return "Top-Right";
    case 2: return "Bottom-Right";
    case 3: return "Bottom-Left";
    default: return "?";
  }
}

void drawCornerIndicator(float x, float y, int corner) {
  float s = 30;
  stroke(100); strokeWeight(1); noFill();
  rect(x - s/2, y - s/2, s, s);

  fill(0, 255, 100); noStroke();
  float cx = x - s/2, cy = y - s/2;
  switch (corner) {
    case 0: ellipse(cx,     cy,     10, 10); break;
    case 1: ellipse(cx + s, cy,     10, 10); break;
    case 2: ellipse(cx + s, cy + s, 10, 10); break;
    case 3: ellipse(cx,     cy + s, 10, 10); break;
  }

  stroke(0, 255, 100); strokeWeight(2);
  if (horizontal) {
    float ay = y;
    float ax1 = (corner == 0 || corner == 3) ? x - 10 : x + 10;
    float ax2 = (corner == 0 || corner == 3) ? x + 10 : x - 10;
    line(ax1, ay, ax2, ay);
  } else {
    float ax = x;
    float ay1 = (corner == 0 || corner == 1) ? y - 10 : y + 10;
    float ay2 = (corner == 0 || corner == 1) ? y + 10 : y - 10;
    line(ax, ay1, ax, ay2);
  }
}

void keyPressed() {
  boolean needsRemap = false;

  switch (key) {
    case '1': startCorner = 0; needsRemap = true; break;
    case '2': startCorner = 1; needsRemap = true; break;
    case '3': startCorner = 2; needsRemap = true; break;
    case '4': startCorner = 3; needsRemap = true; break;
    case 's': case 'S': serpentine = !serpentine; needsRemap = true; break;
    case 'h': case 'H': horizontal = !horizontal; needsRemap = true; break;
    case '+': case '=': ledSpacing = min(50, ledSpacing + 2); needsRemap = true; break;
    case '-': case '_': ledSpacing = max(5,  ledSpacing - 2); needsRemap = true; break;
    case ']': rowSpacing = min(50, rowSpacing + 2); needsRemap = true; break;
    case '[': rowSpacing = max(5,  rowSpacing - 2); needsRemap = true; break;
    case ' ': cycleShape(); needsRemap = true; break;
    case 'o': case 'O': showStrokes = !showStrokes; break;
  }

  if (needsRemap) remapPolygon();
}

void printControls() {
  println("Controls:");
  println("  1-4   : Set start corner");
  println("  S     : Toggle serpentine");
  println("  H     : Toggle horizontal/vertical fill");
  println("  +/-   : Adjust LED spacing");
  println("  [/]   : Adjust row spacing");
  println("  SPACE : Cycle shapes");
  println("  O     : Toggle LED dot outlines");
}
