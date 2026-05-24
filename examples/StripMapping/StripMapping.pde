import com.studiojordanshaw.canvas2dmx.*;

Canvas2DMX c2d;

int ledCount = 16;
boolean reversed = false;

void settings() {
  size(520, 220);
  pixelDensity(1);
}

void setup() {
  c2d = new Canvas2DMX(this);
  c2d.setResponse(1.3f);
  remapStrip();
}

void draw() {
  background(8);

  for (int x = 0; x < width; x++) {
    float wave = sin(frameCount * 0.04f + x * 0.05f) * 0.5f + 0.5f;
    stroke(40 + wave * 180, 50 + x * 0.2f, 220 - wave * 100);
    line(x, 0, x, height);
  }

  fill(255);
  textSize(12);
  text("StripMapping: press R to reverse the strip wiring", 12, 12);
  text("Press [ or ] to change the LED count (" + ledCount + ")", 12, 28);

  int[] colors = c2d.getLedColors();
  c2d.visualize(colors);
  c2d.showLedLocations();

  if (frameCount % 45 == 0) {
    int[] frame = c2d.buildDmxFrame(64);
    println("Preview frame[0..11]:");
    for (int i = 0; i < 12; i++) {
      println("  ch " + (i + 1) + " = " + frame[i]);
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
