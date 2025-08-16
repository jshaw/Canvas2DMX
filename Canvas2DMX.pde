import com.jaysonh.dmx4artists.*;

Canvas2Dmx canvas2Dmx;
DMXControl dmxController;
int numDmxChannels = 256;
boolean isDmxConnected = false;

// Circle position and interaction
float circleX, circleY;
float circleSize = 150;
boolean isDragging = false;

color circleColor = color(255, 0, 0);

void setup() {
  size(400, 400);
  pixelDensity(1);
  ellipseMode(CENTER); 
  textSize(16); // Set global text size
  
  canvas2Dmx = new Canvas2Dmx();
  canvas2Dmx.enableShowLocations = true;
  
  // Set the correct DMX channel pattern for your fixture
  // Ch1=Dimmer, Ch2=Red, Ch3=Green, Ch4=Blue, Ch5=Strobe, Ch6=Color Change
  canvas2Dmx.setChannelPattern("drgbsc");
  canvas2Dmx.setStartAt(1);
  
  // Set channel values to control the fixture properly
  canvas2Dmx.setDefaultValue('d', 255); // Dimmer at full brightness
  canvas2Dmx.setDefaultValue('s', 0);   // Strobe OFF (0 = no strobe)
  canvas2Dmx.setDefaultValue('c', 0);   // Color change OFF (0 = manual control)
  
  // Attempt to initialize the DMX controller
  // Try different initialization methods since the library detects the device
  try {
    // Method 1: Try with device index (since library shows "deviceIndx: 0")
    dmxController = new DMXControl(0, numDmxChannels);
    println("DMX controller initialized using device index 0");
    isDmxConnected = true;
  } catch (Exception e1) {
    println("Method 1 failed: " + e1.getMessage());
    
    try {
      // Method 2: Try with just the serial number
      dmxController = new DMXControl("B001N0ZB", numDmxChannels);
      println("DMX controller initialized using serial number");
      isDmxConnected = true;
    } catch (Exception e2) {
      println("Method 2 failed: " + e2.getMessage());
      
      try {
        // Method 3: Try alternate port path
        dmxController = new DMXControl("/dev/tty.usbserial-B001N0ZB", numDmxChannels);
        println("DMX controller initialized using /dev/tty.usbserial-B001N0ZB");
        isDmxConnected = true;
      } catch (Exception e3) {
        println("Method 3 failed: " + e3.getMessage());
        println("All initialization methods failed.");
        println("Device detected but connection failed. Check device permissions or try restarting Processing.");
        dmxController = null;
        isDmxConnected = false;
      }
    }
  }
  
  // Map LEDs only once in setup, not in draw loop
  // canvas2Dmx.setLed(0, width / 2, height / 2);
  
  // Map the 4 corners of a square to pixel locations
  //canvas2Dmx.mapSquareCorners(0, width / 2, height / 2, 100, 45); // First 4 LEDs (indices 0-3)
  //canvas2Dmx.mapSquareCorners(4, width / 2, height / 2, 50, 22);  // Next 4 LEDs (indices 4-7)
  
  // Draw LED Strip
  canvas2Dmx.mapLedStrip(0, 10, width / 2, height / 2, 10, radians(45), false);
  
  // Set the response value for color correction
  canvas2Dmx.setResponse(1.0);
  canvas2Dmx.setTemperature(0.0); // Disable color temperature for testing
  
  // Initialize circle position
  circleX = width / 2;
  circleY = height / 2;
}

void draw() {
  background(100, 150, 255);
  
  // Update circle position if dragging
  if (isDragging) {
    circleX = mouseX;
    circleY = mouseY;
  }
  
  // Draw the draggable red circle
  fill(circleColor);
  ellipse(circleX, circleY, circleSize, circleSize);
  
  // Add a subtle outline to show it's interactive
  noFill();
  stroke(circleColor);
  strokeWeight(2);
  ellipse(circleX, circleY, circleSize + 10, circleSize + 10);
  noStroke();
  
  loadPixels(); // Load the current pixels into the pixels[] array
  
  // Get LED colors - pass the pixels array explicitly
  color[] colors = canvas2Dmx.getLedColors(pixels);
  
  updatePixels();
  
  // Show LED markers if enabled (drawn on top of scene)
  canvas2Dmx.showLedLocations();
  
  // Debug: Print LED colors and DMX data more frequently for testing
  if (frameCount % 30 == 0) { // Print every 30 frames (twice per second)
    println("=== Frame " + frameCount + " DEBUG ===");
    println("Circle position: (" + int(circleX) + ", " + int(circleY) + ")");
    println("Channel pattern: " + canvas2Dmx.channelPattern);
    println("DMX start channel: " + canvas2Dmx.startAt);
    
    for (int i = 0; i < colors.length && i < 4; i++) { // Just show first 4 LEDs
      int r = (int)red(colors[i]);
      int g = (int)green(colors[i]);  
      int b = (int)blue(colors[i]);
      println("  LED " + i + ": R=" + r + " G=" + g + " B=" + b);
      
      // Show what DMX channels this LED uses
      int startCh = canvas2Dmx.startAt + (i * canvas2Dmx.channelPattern.length());
      println("    DMX channels " + startCh + "-" + (startCh + canvas2Dmx.channelPattern.length() - 1));
    }
    println("============================");
  }
  
  // Visualize the colors
  canvas2Dmx.visualize(colors);
  
  // Send to DMX only if connected
  if (isDmxConnected && dmxController != null) {
    try {
      canvas2Dmx.sendToDmx(dmxController);
    } catch (Exception e) {
      println("Error sending data to DMX: " + e.getMessage());
    }
  }
  
  // Debug info on screen
  fill(0);
  text("DMX Connected: " + isDmxConnected, 10, 20);
  text("LEDs mapped: " + (canvas2Dmx.pixelLocations != null ? canvas2Dmx.pixelLocations.length : 0), 10, 40);
  text("Frame: " + frameCount, 10, 60);
  text("Circle: (" + int(circleX) + ", " + int(circleY) + ")", 10, 80);
  text("Drag the red circle to see real-time DMX updates!", 10, height - 35);
}

void keyPressed() {
  if (key == 's') {
    canvas2Dmx.saveSettings("ledSettings.txt");
    println("Settings saved.");
  }
  
  // Toggle location display with 'l' key for debugging
  if (key == 'l') {
    canvas2Dmx.enableShowLocations = !canvas2Dmx.enableShowLocations;
    println("Show locations: " + canvas2Dmx.enableShowLocations);
  }
  
  // Print LED positions with 'p' key for debugging
  if (key == 'p') {
    println("LED positions:");
    if (canvas2Dmx.pixelLocations != null) {
      for (int i = 0; i < canvas2Dmx.pixelLocations.length; i++) {
        int pos = canvas2Dmx.pixelLocations[i];
        int x = pos % width;
        int y = pos / width;
        println("  LED " + i + ": pixel[" + pos + "] = (" + x + ", " + y + ")");
      }
    } else {
      println("  No LEDs mapped!");
    }
  }
  
  // Reset circle to center
  if (key == 'r') {
    circleX = width / 2;
    circleY = height / 2;
    println("Circle reset to center");
  }
  
  // Test different fixture settings
  if (key == '1') {
    // Full brightness, no strobe, no color change
    canvas2Dmx.setDefaultValue('d', 255);
    canvas2Dmx.setDefaultValue('s', 0);
    canvas2Dmx.setDefaultValue('c', 0);
    println("Settings: Dimmer=255, Strobe=OFF, Color Change=OFF");
  }
  if (key == '2') {
    // Half brightness
    canvas2Dmx.setDefaultValue('d', 128);
    canvas2Dmx.setDefaultValue('s', 0);
    canvas2Dmx.setDefaultValue('c', 0);
    println("Settings: Dimmer=128, Strobe=OFF, Color Change=OFF");
  }
  if (key == '3') {
    // Test strobe (be careful!)
    canvas2Dmx.setDefaultValue('d', 255);
    canvas2Dmx.setDefaultValue('s', 128);
    canvas2Dmx.setDefaultValue('c', 0);
    println("Settings: Dimmer=255, Strobe=ON, Color Change=OFF");
  }
  if (key == '4') {
    // Turn off strobe if it was on
    canvas2Dmx.setDefaultValue('d', 255);
    canvas2Dmx.setDefaultValue('s', 0);
    canvas2Dmx.setDefaultValue('c', 0);
    println("Settings: Strobe turned OFF");
  }
  
  // Manual DMX testing keys
  if (key == 't') {
    // Test: Send red directly to DMX
    if (dmxController != null) {
      dmxController.sendValue(1, 255); // Ch1: Dimmer full
      dmxController.sendValue(2, 255); // Ch2: Red full  
      dmxController.sendValue(3, 0);   // Ch3: Green off
      dmxController.sendValue(4, 0);   // Ch4: Blue off
      dmxController.sendValue(5, 0);   // Ch5: Strobe off
      dmxController.sendValue(6, 0);   // Ch6: Color change off
      println("Manual test: Sent RED to DMX channels 1-6");
    }
  }
  if (key == 'y') {
    // Test: Send green directly to DMX
    if (dmxController != null) {
      dmxController.sendValue(1, 255); // Ch1: Dimmer full
      dmxController.sendValue(2, 0);   // Ch2: Red off
      dmxController.sendValue(3, 255); // Ch3: Green full
      dmxController.sendValue(4, 0);   // Ch4: Blue off  
      dmxController.sendValue(5, 0);   // Ch5: Strobe off
      dmxController.sendValue(6, 0);   // Ch6: Color change off
      println("Manual test: Sent GREEN to DMX channels 1-6");
    }
  }
  if (key == 'u') {
    // Test: Send blue directly to DMX
    if (dmxController != null) {
      dmxController.sendValue(1, 255); // Ch1: Dimmer full
      dmxController.sendValue(2, 0);   // Ch2: Red off
      dmxController.sendValue(3, 0);   // Ch3: Green off
      dmxController.sendValue(4, 255); // Ch4: Blue full
      dmxController.sendValue(5, 0);   // Ch5: Strobe off
      dmxController.sendValue(6, 0);   // Ch6: Color change off
      println("Manual test: Sent BLUE to DMX channels 1-6");
    }
  }
}

// Mouse interaction functions
void mousePressed() {
  // Check if mouse is over the circle
  float distance = dist(mouseX, mouseY, circleX, circleY);
  if (distance < circleSize / 2) {
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
    // Constrain circle to stay within canvas bounds
    circleX = constrain(mouseX, circleSize/2, width - circleSize/2);
    circleY = constrain(mouseY, circleSize/2, height - circleSize/2);
  }
}
