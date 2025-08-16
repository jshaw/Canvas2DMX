import com.studiojordanshaw.canvas2dmx.*;
import com.jaysonh.dmx4artists.*;

Canvas2DMX c2d;
DMXControl dmxController;

void settings() {
  size(400, 200);
  pixelDensity(1);
}

void setup() {
  c2d = new Canvas2DMX(this);
  c2d.mapLedStrip(0, 8, width/2f, height/2f, 40, 0, false);

  c2d.setResponse(1.2);
  c2d.setTemperature(0.2);

  // Initialize DMX (simplest case, first device)
  try {
    dmxController = new DMXControl(0, 512);
  } catch (Exception e) {
    println("DMX init failed: " + e.getMessage());
    dmxController = null;
  }
}

void draw() {
  background(0);
  for (int x = 0; x < width; x++) {
    stroke((x + frameCount) % 255, 200, 200);
    line(x, 0, x, height);
  }

  int[] colors = c2d.getLedColors();
  c2d.visualize(colors);
  c2d.showLedLocations();

  // Send to DMX only if controller is connected
  if (dmxController != null) {
    c2d.sendToDmx((ch, val) -> dmxController.sendValue(ch, val));
  }
}
