import com.studiojordanshaw.canvas2dmx.*;
import com.jaysonh.dmx4artists.*;

Canvas2DMX c2d;
DMXControl dmxController;

void settings() {
  size(200, 200);
  pixelDensity(1);
}

void setup() {
  c2d = new Canvas2DMX(this);
  // Map one LED at the center
  c2d.setLed(0, width/2, height/2);
}

void draw() {
  // Animate background color
  background(frameCount % 255, 100, 200);

  // Get LED colors (samples canvas)
  int[] colors = c2d.getLedColors();

  // Visualize in a small swatch
  c2d.visualize(colors);

  // Show LED marker
  c2d.showLedLocations();
  
  // Send to DMX only if controller is connected
  if (dmxController != null) {
    c2d.sendToDmx((ch, val) -> dmxController.sendValue(ch, val));
  }
}
