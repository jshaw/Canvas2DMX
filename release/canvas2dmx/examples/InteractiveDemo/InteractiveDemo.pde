import com.studiojordanshaw.canvas2dmx.*;
import com.jaysonh.dmx4artists.*; // your DMX lib

Canvas2DMX c2d;
DMXControl dmxController;

int numDmxChannels = 256;
boolean isDmxConnected = false;

// Circle position and interaction
float circleX, circleY;
float circleSize = 150;
boolean isDragging = false;

int circleColor = color(255, 0, 0);

void settings() {
  size(400, 400);
  pixelDensity(1); // recommended for precise sampling
}

void setup() {
  ellipseMode(CENTER);
  textSize(16);

  // pass PApplet to the library
  c2d = new Canvas2DMX(this);
  c2d.setShowLocations(true);

  // Channel pattern (example fixture): d=Dimmer, r,g,b, s=Strobe, c=Color change
  c2d.setChannelPattern("drgbsc");
  c2d.setStartAt(1); // first DMX channel to write

  // Defaults for non-RGB placeholders
  c2d.setDefaultValue('d', 255); // Dimmer full
  c2d.setDefaultValue('s', 0);   // Strobe off
  c2d.setDefaultValue('c', 0);   // Color change off

  // Try to initialize DMX controller (your 3-step fallbacks)
  try {
    dmxController = new DMXControl(0, numDmxChannels);
    println("DMX controller initialized using device index 0");
    isDmxConnected = true;
  } catch (Exception e1) {
    println("Method 1 failed: " + e1.getMessage());
    try {
      dmxController = new DMXControl("B001N0ZB", numDmxChannels);
      println("DMX controller initialized using serial number");
      isDmxConnected = true;
    } catch (Exception e2) {
      println("Method 2 failed: " + e2.getMessage());
      try {
        dmxController = new DMXControl("/dev/tty.usbserial-B001N0ZB", numDmxChannels);
        println("DMX controller initialized using /dev/tty.usbserial-B001N0ZB");
        isDmxConnected = true;
      } catch (Exception e3) {
        println("Method 3 failed: " + e3.getMessage());
        println("All initialization methods failed.");
        println("Device detected but connection failed. Check permissions or restart Processing.");
        dmxController = null;
        isDmxConnected = false;
      }
    }
  }

  // Map LEDs once (not in draw)
  c2d.mapLedStrip(0, 10, width/2f, height/2f, 10, radians(45), false);

  // Response & temperature
  c2d.setResponse(1.0);
  c2d.setTemperature(0.0);

  // Init draggable circle
  circleX = width / 2f;
  circleY = height / 2f;
}

void draw() {
  background(100, 150, 255);

  // Drag logic
  if (isDragging) {
    circleX = mouseX;
    circleY = mouseY;
  }

  // Draw the draggable circle
  fill(circleColor);
  noStroke();
  ellipse(circleX, circleY, circleSize, circleSize);

  // Subtle outline
  noFill();
  stroke(circleColor);
  strokeWeight(2);
  ellipse(circleX, circleY, circleSize + 10, circleSize + 10);
  noStroke();

  // Sample LED colors from current frame
  int[] colors = c2d.getLedColors(); // internally calls loadPixels()

  // Overlay LED markers (after scene)
  c2d.showLedLocations();

  // Debug (every ~0.5s at 60fps)
  if (frameCount % 30 == 0) {
    println("=== Frame " + frameCount + " DEBUG ===");
    println("Circle: (" + int(circleX) + ", " + int(circleY) + ")");
    println("Channel pattern: " + c2d.getChannelPattern());
    println("DMX start channel: " + c2d.getStartAt());

    for (int i = 0; i < min(colors.length, 4); i++) {
      int r = (int) red(colors[i]);
      int g = (int) green(colors[i]);
      int b = (int) blue(colors[i]);
      println("  LED " + i + ": R=" + r + " G=" + g + " B=" + b);

      int startCh = c2d.getStartAt() + (i * c2d.getChannelPattern().length());
      println("    DMX channels " + startCh + "–" + (startCh + c2d.getChannelPattern().length() - 1));
    }
    println("============================");
  }

  // Visualize sampled colors
  c2d.visualize(colors);

  // Send to DMX (if connected)
  if (isDmxConnected && dmxController != null) {
    try {
      c2d.sendToDmx((ch, val) -> dmxController.sendValue(ch, val));
    } catch (Exception e) {
      println("Error sending data to DMX: " + e.getMessage());
    }
  }

  // On-screen debug
  fill(0);
  text("DMX Connected: " + isDmxConnected, 10, 20);
  text("LEDs mapped: " + c2d.getMappedLedCount(), 10, 40);
  text("Frame: " + frameCount, 10, 60);
  text("Circle: (" + int(circleX) + ", " + int(circleY) + ")", 10, 80);
  text("Drag the red circle to see real-time DMX updates!", 10, height - 35);
}

void keyPressed() {
  if (key == 's') {
    c2d.saveSettings("ledSettings.txt");
    println("Settings saved.");
  }
  if (key == 'l') {
    c2d.setShowLocations(!c2d.isShowLocationsEnabled());
    println("Show locations: " + c2d.isShowLocationsEnabled());
  }
  if (key == 'p') {
    println("LED positions:");
    int n = c2d.getMappedLedCount();
    for (int i = 0; i < n; i++) {
      int pos = c2d.getLedPixelLocation(i);
      if (pos >= 0) {
        int x = pos % width;
        int y = pos / width;
        println("  LED " + i + ": pixel[" + pos + "] = (" + x + ", " + y + ")");
      }
    }
  }
  if (key == 'r') {
    circleX = width / 2f;
    circleY = height / 2f;
    println("Circle reset to center");
  }

  // Quick presets for defaults
  if (key == '1') {
    c2d.setDefaultValue('d', 255);
    c2d.setDefaultValue('s', 0);
    c2d.setDefaultValue('c', 0);
    println("Settings: Dimmer=255, Strobe=OFF, Color Change=OFF");
  }
  if (key == '2') {
    c2d.setDefaultValue('d', 128);
    c2d.setDefaultValue('s', 0);
    c2d.setDefaultValue('c', 0);
    println("Settings: Dimmer=128, Strobe=OFF, Color Change=OFF");
  }
  if (key == '3') {
    c2d.setDefaultValue('d', 255);
    c2d.setDefaultValue('s', 128);
    c2d.setDefaultValue('c', 0);
    println("Settings: Dimmer=255, Strobe=ON, Color Change=OFF");
  }
  if (key == '4') {
    c2d.setDefaultValue('d', 255);
    c2d.setDefaultValue('s', 0);
    c2d.setDefaultValue('c', 0);
    println("Settings: Strobe turned OFF");
  }

  // Manual DMX tests
  if (key == 't' && dmxController != null) {
    dmxController.sendValue(1, 255);
    dmxController.sendValue(2, 255);
    dmxController.sendValue(3, 0);
    dmxController.sendValue(4, 0);
    dmxController.sendValue(5, 0);
    dmxController.sendValue(6, 0);
    println("Manual test: Sent RED to DMX channels 1–6");
  }
  if (key == 'y' && dmxController != null) {
    dmxController.sendValue(1, 255);
    dmxController.sendValue(2, 0);
    dmxController.sendValue(3, 255);
    dmxController.sendValue(4, 0);
    dmxController.sendValue(5, 0);
    dmxController.sendValue(6, 0);
    println("Manual test: Sent GREEN to DMX channels 1–6");
  }
  if (key == 'u' && dmxController != null) {
    dmxController.sendValue(1, 255);
    dmxController.sendValue(2, 0);
    dmxController.sendValue(3, 0);
    dmxController.sendValue(4, 255);
    dmxController.sendValue(5, 0);
    dmxController.sendValue(6, 0);
    println("Manual test: Sent BLUE to DMX channels 1–6");
  }
}

// Mouse interaction
void mousePressed() {
  float distance = dist(mouseX, mouseY, circleX, circleY);
  if (distance < circleSize / 2f) {
    isDragging = true;
    println("Started dragging circle");
  }
  circleColor = color(255, 204, 0);
}
void mouseReleased() {
  if (isDragging) {
    isDragging = false;
    println("Stopped dragging circle at (" + int(circleX) + ", " + int(circleY) + ")");
  }
  circleColor = color(255, 0, 0);
}
void mouseDragged() {
  if (isDragging) {
    circleX = constrain(mouseX, circleSize/2f, width - circleSize/2f);
    circleY = constrain(mouseY, circleSize/2f, height - circleSize/2f);
  }
}
