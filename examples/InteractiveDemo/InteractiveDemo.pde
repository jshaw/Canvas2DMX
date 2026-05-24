import com.studiojordanshaw.canvas2dmx.*;

Canvas2DMX c2d;

float orbX;
float orbY;
float orbSize = 140;
boolean dragging = false;

String[] patterns = { "rgb", "drgb", "drgbsc" };
int patternIndex = 1;

void settings() {
  size(480, 420);
  pixelDensity(1);
}

void setup() {
  c2d = new Canvas2DMX(this);
  c2d.setShowLocations(true);
  c2d.setStartAt(1);
  applyPattern();
  c2d.mapLedRing(0, 12, width / 2f, height / 2f + 10, 95, -HALF_PI);

  orbX = width / 2f;
  orbY = height / 2f + 10;
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
  text("Pattern: " + c2d.getChannelPattern() + "   Mapped LEDs: " + c2d.getMappedLedCount(), 24, 58);

  if (frameCount % 30 == 0 && colors.length > 0) {
    c2d.sendToDmx((ch, val) -> {
      int visibleChannels = colors.length > 0 ? min(8, colors.length * c2d.getChannelPattern().length()) : 8;
      if (ch < c2d.getStartAt() + visibleChannels) {
        println("ch " + ch + " = " + val);
      }
    });
  }
}

void applyPattern() {
  c2d.setChannelPattern(patterns[patternIndex]);
  c2d.setDefaultValue('d', 255);
  c2d.setDefaultValue('s', 0);
  c2d.setDefaultValue('c', 0);
}

void keyPressed() {
  if (key == '1') {
    patternIndex = 0;
    applyPattern();
  } else if (key == '2') {
    patternIndex = 1;
    applyPattern();
  } else if (key == '3') {
    patternIndex = 2;
    applyPattern();
  } else if (key == 'l' || key == 'L') {
    c2d.setShowLocations(!c2d.isShowLocationsEnabled());
  } else if (key == 's' || key == 'S') {
    c2d.saveSettings("interactive-demo-settings.txt");
    println("Saved settings to interactive-demo-settings.txt");
  }
}

void mousePressed() {
  dragging = dist(mouseX, mouseY, orbX, orbY) < orbSize / 2f;
}

void mouseReleased() {
  dragging = false;
}
