import com.studiojordanshaw.canvas2dmx.*;

Canvas2DMX c2d;
PGraphics ledBuffer;

void settings() {
  size(640, 360);
  pixelDensity(1);
}

void setup() {
  ledBuffer = createGraphics(160, 90);

  c2d = new Canvas2DMX(this);
  c2d.setCanvasSize(ledBuffer.width, ledBuffer.height);
  c2d.mapLedGrid(0, 12, 6, ledBuffer.width / 2f, ledBuffer.height / 2f, 10, 12, 0, true, false);
}

void draw() {
  drawBuffer();

  image(ledBuffer, 0, 0, width, height);

  ledBuffer.loadPixels();
  int[] colors = c2d.getLedColors(ledBuffer.pixels);
  c2d.visualize(colors);

  pushMatrix();
  float sx = width / (float) ledBuffer.width;
  float sy = height / (float) ledBuffer.height;
  scale(sx, sy);
  c2d.showLedLocations();
  popMatrix();

  fill(255);
  textSize(12);
  text("OffscreenBuffer: mapping is done in 160x90, display is scaled to the sketch window", 12, 14);
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
