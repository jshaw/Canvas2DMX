import com.studiojordanshaw.canvas2dmx.*;

Canvas2DMX c2d;

void settings() {
  size(320, 220);
  pixelDensity(1);
}

void setup() {
  c2d = new Canvas2DMX(this);
  c2d.setChannelPattern("drgb");
  c2d.setDefaultValue('d', 255);
  c2d.setStartAt(1);
  c2d.setLed(0, width / 2, height / 2 - 10);
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

  if (frameCount % 30 == 0) {
    c2d.sendToDmx((ch, val) -> {
      if (ch <= 4) {
        println("ch " + ch + " = " + val);
      }
    });
  }
}

void drawHud(int[] colors) {
  fill(255);
  textSize(12);
  textAlign(LEFT, TOP);
  text("Basics: sample one pixel and preview its DMX channels", 12, 10);
  text("No hardware required. Watch the console for channels 1-4.", 12, 28);

  if (colors.length > 0) {
    int sample = colors[0];
    text(
      "LED 0 RGB = " + int(red(sample)) + ", " + int(green(sample)) + ", " + int(blue(sample)),
      12, height - 48
    );
  }
}
