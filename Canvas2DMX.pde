import com.jaysonh.dmx4artists.*;

Canvas2Dmx canvas2Dmx;
DMXControl dmxController;

int numDmxChannels = 256; // number of channels we will use
boolean isDmxConnected = false; // To track DMX connection status

void setup() {
  size(400, 400);

  canvas2Dmx = new Canvas2Dmx();

  canvas2Dmx.enableShowLocations = true;
  
  // Set a custom DMX channel pattern
  canvas2Dmx.setChannelPattern("xrgbxxx"); // Example pattern with extra channels

  // Set the start channel index
  canvas2Dmx.setStartAt(10); // Start at channel 10

  // Set default values for unused channels
  canvas2Dmx.setDefaultValue('x', 255); // Set all 'x' channels to full intensity

  // Attempt to initialize the DMX controller
  try {
    dmxController = new DMXControl(0, numDmxChannels);
    println("DMX controller initialized.");
    isDmxConnected = true;
  } catch (Exception e) {
    println("DMX initialization failed: " + e.getMessage());
    dmxController = null; // No DMX device connected
    isDmxConnected = false;
  }

  // Map the 4 corners of a square to pixel locations
  // More intuitive mapping to center of canvas
  canvas2Dmx.mapSquareCorners(0, width / 2, height / 2, 100, 45); // 100px square, 45 degrees rotation
  canvas2Dmx.mapSquareCorners(0, width / 2, height / 2, 50, 25); // 100px square, 45 degrees rotation

  // Set the response value for color correction
  canvas2Dmx.setResponse(1.0); // Apply a stronger gamma correction
  canvas2Dmx.setTemperature(0.5); // Slightly cooler color temperature
}

void draw() {
  // Clear the canvas
  background(255);
  fill(255, 0, 0);
  ellipse(width / 2, height / 2, 150, 150);

  // Only send to DMX if the controller was successfully initialized
  if (isDmxConnected) {
    try {
      canvas2Dmx.sendToDmx(dmxController); // Send data to DMX controller
    } catch (Exception e) {
      println("Error sending data to DMX: " + e.getMessage());
    }
  } else {
    println("DMX controller not connected. Skipping DMX output.");
  }

  // Visualize the response correction and pixel locations
  color[] colors = canvas2Dmx.getLedColors();
  canvas2Dmx.visualize(colors);
  
  // Map the 4 corners of a square to pixel locations
  // More intuitive mapping to center of canvas
  canvas2Dmx.mapSquareCorners(0, width / 2, height / 2, 100, 45); // 100px square, 45 degrees rotation
  canvas2Dmx.mapSquareCorners(4, width / 2, height / 2, 50, 22); // 100px square, 45 degrees rotation
}

void keyPressed() {
  // Optionally save settings to a file when 's' is pressed
  if (key == 's') {
    canvas2Dmx.saveSettings("ledSettings.txt");
    println("Settings saved.");
  }
}
