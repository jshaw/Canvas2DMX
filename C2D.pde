/*
 * Canvas2DMX
 * 
 * C2D is a class to help visualize and draw pixels within a processing sketch. Inspired by OPC, 
 * it is designed to sample each LED's color from some point on the canvas
 * and send it via DMX to different controllers.
 * This original implimentation is done for ENTTEC USB Pro and SP201E
 * 
 * # TODO C2D also supports a pixelReset which is new since OPC's original implimentation
 * 
 * Canvas2DMX is a port and refactor of Open Pixel Control 
 *
 * Original OPC Credit
 * Micah Elizabeth Scott, 2013
 * Simple Open Pixel Control client for Processing,
 * designed to sample each LED's color from some point on the canvas.
 * This file is released into the public domain.
 *
 */

import java.util.Arrays;
import java.util.HashMap;
import java.util.ArrayList;
import java.io.BufferedReader;
import java.io.IOException;

class Canvas2Dmx {
  int[] pixelLocations;
  boolean enableShowLocations;
  float response;
  float temperature;
  float[] customCurve;
  String channelPattern = "rgb"; // Default pattern
  int startAt = 0; // Default start channel index
  HashMap<Character, Integer> defaultValues = new HashMap<Character, Integer>(); // Default values for channels

  // Constructor to initialize with default values
  Canvas2Dmx() {
    enableShowLocations = true;
    response = 1.0; // Default linear response
    temperature = 0.0; // No color temperature adjustment by default
  }

  // Method to set the response value
  void setResponse(float response) {
    this.response = response;
    this.customCurve = null; // Reset custom curve if response is set manually
  }

  // Method to set a custom response curve
  void setCustomCurve(float[] curve) {
    this.customCurve = curve;
  }

  // Method to set the color temperature (range from -1 to 1)
  void setTemperature(float temperature) {
    this.temperature = constrain(temperature, -1, 1); // -1 is very warm, 1 is very cool
  }

  // Method to apply the custom or default response curve to a color value
  color applyResponse(color c) {
    float r = red(c) / 255.0;
    float g = green(c) / 255.0;
    float b = blue(c) / 255.0;

    // Apply color temperature adjustment
    r += (temperature > 0 ? -temperature * 0.2 : temperature * 0.1);
    b += (temperature > 0 ? temperature * 0.1 : -temperature * 0.2);

    r = constrain(r, 0, 1);
    g = constrain(g, 0, 1);
    b = constrain(b, 0, 1);

    // Apply custom curve or default response
    if (customCurve != null) {
      int ri = (int)(r * (customCurve.length - 1));
      int gi = (int)(g * (customCurve.length - 1));
      int bi = (int)(b * (customCurve.length - 1));
      r = customCurve[ri];
      g = customCurve[gi];
      b = customCurve[bi];
    } else {
      r = pow(r, response);
      g = pow(g, response);
      b = pow(b, response);
    }

    return color(constrain(r * 255, 0, 255), constrain(g * 255, 0, 255), constrain(b * 255, 0, 255));
  }

  // Set the location of a single LED on the canvas
  void setLed(int index, int x, int y) {
    // Initialize array with proper size
    if (pixelLocations == null) {
      pixelLocations = new int[(index + 1) * 2]; // Give it some room to grow
      // Initialize all positions to -1 (invalid)
      Arrays.fill(pixelLocations, -1);
    } else if (index >= pixelLocations.length) {
      int oldLength = pixelLocations.length;
      pixelLocations = Arrays.copyOf(pixelLocations, (index + 1) * 2);
      // Initialize new positions to -1
      Arrays.fill(pixelLocations, oldLength, pixelLocations.length, -1);
    }
    
    // Bounds checking for canvas coordinates
    x = constrain(x, 0, width - 1);
    y = constrain(y, 0, height - 1);
    
    int pixelIndex = x + width * y;
    pixelLocations[index] = pixelIndex;
    
    // Debug output - let's see what's happening
    println("setLed(" + index + ", " + x + ", " + y + ") -> pixel[" + pixelIndex + "]");
    println("  Reverse check: pixel[" + pixelIndex + "] = (" + (pixelIndex % width) + ", " + (pixelIndex / width) + ")");
  }

  // Map a strip of LEDs on the canvas
  void mapLedStrip(int index, int count, float x, float y, float spacing, float angle, boolean reversed) {
    float s = sin(angle);
    float c = cos(angle);
    for (int i = 0; i < count; i++) {
      setLed(reversed ? (index + count - 1 - i) : (index + i),
             (int)(x + (i - (count-1)/2.0) * spacing * c + 0.5),
             (int)(y + (i - (count-1)/2.0) * spacing * s + 0.5));
    }
  }

  // Map a ring of LEDs on the canvas
  void mapLedRing(int index, int count, float x, float y, float radius, float angle) {
    for (int i = 0; i < count; i++) {
      float a = angle + i * 2 * PI / count;
      setLed(index + i, (int)(x - radius * cos(a) + 0.5),
             (int)(y - radius * sin(a) + 0.5));
    }
  }

  // Map a grid of LEDs on the canvas
  void mapLedGrid(int index, int stripLength, int numStrips, float x, float y,
                  float ledSpacing, float stripSpacing, float angle, boolean zigzag, boolean flip) {
    float s = sin(angle + HALF_PI);
    float c = cos(angle + HALF_PI);
    for (int i = 0; i < numStrips; i++) {
      mapLedStrip(index + stripLength * i, stripLength,
                  x + (i - (numStrips-1)/2.0) * stripSpacing * c,
                  y + (i - (numStrips-1)/2.0) * stripSpacing * s,
                  ledSpacing, angle, zigzag && ((i % 2) == 1) != flip);
    }
  }

  // Map the 4 corners of a square
  void mapSquareCorners(int index, float x, float y, float size, float rotation) {
    float halfSize = size / 2.0;
    float angle = radians(rotation);

    // Calculate the positions of the 4 corners
    float[] xOffsets = {-halfSize, halfSize, halfSize, -halfSize};
    float[] yOffsets = {-halfSize, -halfSize, halfSize, halfSize};

    for (int i = 0; i < 4; i++) {
      float rotatedX = x + xOffsets[i] * cos(angle) - yOffsets[i] * sin(angle);
      float rotatedY = y + xOffsets[i] * sin(angle) + yOffsets[i] * cos(angle);
      // Added rounding
      setLed(index + i, (int)(rotatedX + 0.5), (int)(rotatedY + 0.5));
    }
  }

  // Extract pixel colors from the canvas, apply response curve, and return as an array
  color[] getLedColors(color[] pixelArray) {
    if (pixelLocations == null) {
      println("Warning: No LEDs mapped!");
      return new color[0];
    }
    
    // Count valid LED locations
    int validLeds = 0;
    for (int i = 0; i < pixelLocations.length; i++) {
      if (pixelLocations[i] >= 0) {
        validLeds = i + 1; // Track the highest valid index + 1
      }
    }
    
    color[] colors = new color[validLeds];
  
    for (int i = 0; i < validLeds; i++) {
      if (pixelLocations[i] >= 0 && pixelLocations[i] < pixelArray.length) {
        color rawColor = pixelArray[pixelLocations[i]];
        color processedColor = applyResponse(rawColor);
        colors[i] = processedColor;
        
        // Debug: print what we're actually sampling - BOTH raw and processed
        if (frameCount % 30 == 0 && i < 2) { // Debug first 2 LEDs every 30 frames
          int x = pixelLocations[i] % width;
          int y = pixelLocations[i] / width;
          println("LED " + i + " at (" + x + "," + y + "):");
          println("  RAW: R=" + red(rawColor) + " G=" + green(rawColor) + " B=" + blue(rawColor));
          println("  PROCESSED: R=" + red(processedColor) + " G=" + green(processedColor) + " B=" + blue(processedColor));
        }
      } else {
        colors[i] = color(0); // Default to black for invalid locations
        if (pixelLocations[i] >= 0) { // Only warn for initialized but out-of-bounds locations
          println("Warning: Pixel location out of bounds for LED " + i + " (location: " + pixelLocations[i] + ")");
        }
      }
    }
  
    return colors;
  }
  
  // Keep the old method for backward compatibility, but call loadPixels() here
  color[] getLedColors() {
    loadPixels(); // This might work better when called from within the class context
    return getLedColors(pixels);
  }
  
  // Simple method to draw LED location markers AFTER getting colors
  void showLedLocations() {
    if (!enableShowLocations || pixelLocations == null) return;
    
    // Count valid LED locations
    int validLeds = 0;
    for (int i = 0; i < pixelLocations.length; i++) {
      if (pixelLocations[i] >= 0) {
        validLeds = i + 1;
      }
    }
    
    // Save current drawing state
    pushStyle();
    
    // Draw on top of the current scene
    for (int i = 0; i < validLeds; i++) {
      if (pixelLocations[i] >= 0 && pixelLocations[i] < pixels.length) {
        int y = pixelLocations[i] / width;
        int x = pixelLocations[i] % width;
  
        // Draw marker
        //fill(255, 255, 0); // Bright yellow
        noFill();
        //noStroke();
        stroke(255, 255, 0);
        strokeWeight(1);
        ellipse(x - 3, y - 3, 6, 6);
        
        // Add LED index number
        fill(0);
        textAlign(CENTER, CENTER);
        textSize(10);
        text(i, x+4, y+4);
      }
    }
    
    // Restore drawing state
    popStyle();
  }
  
  // Method to set the DMX channel pattern
  void setChannelPattern(String pattern) {
    this.channelPattern = pattern;
  }

  // Method to set the starting channel index
  void setStartAt(int startAt) {
    this.startAt = startAt;
  }

  // Method to set default values for specific placeholders in the pattern
  void setDefaultValue(char channel, int value) {
    defaultValues.put(channel, value);
  }

  // Send colors to DMX controller
  void sendToDmx(DMXControl dmxController) {
    if (dmxController == null) {
      println("Warning: DMX controller is null");
      return;
    }
    
    color[] colors = getLedColors();
    if (colors.length == 0) {
      println("Warning: No LED colors to send to DMX");
      return;
    }
    
    int dmxChannelIndex = startAt;

    for (int i = 0; i < colors.length; i++) {
      int r = (int)red(colors[i]);
      int g = (int)green(colors[i]);
      int b = (int)blue(colors[i]);

      // Loop through the channel pattern and assign DMX values
      for (int j = 0; j < channelPattern.length(); j++) {
        char ch = channelPattern.charAt(j);

        switch (ch) {
          case 'r':
            dmxController.sendValue(dmxChannelIndex++, r);
            break;
          case 'g':
            dmxController.sendValue(dmxChannelIndex++, g);
            break;
          case 'b':
            dmxController.sendValue(dmxChannelIndex++, b);
            break;
          default:
            if (defaultValues.containsKey(ch)) {
              dmxController.sendValue(dmxChannelIndex++, defaultValues.get(ch));
            } else {
              dmxController.sendValue(dmxChannelIndex++, 0); // Default to 0 if no value provided
            }
            break;
        }
      }
    }
    
    // Debug output occasionally
    if (frameCount % 120 == 0) { // Every 2 seconds at 60fps
      println("Sent " + colors.length + " LEDs to DMX starting at channel " + startAt);
    }
  }

  // Save the current settings to a file
  void saveSettings(String filename) {
    PrintWriter output = createWriter(filename);
    output.println(response);
    output.println(temperature);
    if (customCurve != null) {
      for (float value : customCurve) {
        output.println(value);
      }
    }
    output.close();
  }

  // Load settings from a file
  void loadSettings(String filename) {
    BufferedReader reader = createReader(filename);
    try {
      String line;
      if ((line = reader.readLine()) != null) {
        response = Float.parseFloat(line);
      }
      if ((line = reader.readLine()) != null) {
        temperature = Float.parseFloat(line);
      }

      ArrayList<Float> curveList = new ArrayList<>();
      while ((line = reader.readLine()) != null) {
        curveList.add(Float.parseFloat(line));
      }
      
      if (curveList.size() > 0) {
        customCurve = new float[curveList.size()];
        for (int i = 0; i < curveList.size(); i++) {
          customCurve[i] = curveList.get(i);
        }
      }
      reader.close();
    } catch (IOException e) {
      println("Error loading settings: " + e.getMessage());
    } catch (NumberFormatException e) {
      println("Error parsing settings file: " + e.getMessage());
    }
  }

  // Visualization method to see how settings will affect the colors
  void visualize(color[] rgbArray) {
    pushStyle(); // Save current drawing style
    
    for (int i = 0; i < rgbArray.length && i < 20; i++) { // Limit to 20 for screen space
      color adjustedColor = rgbArray[i]; // Color is already processed by getLedColors()
      fill(adjustedColor);
      noStroke();
      rect(10 + i * 15, height - 30, 12, 20); // Visualize each color in a rectangle
      
      // Add LED number
      fill(255);
      textSize(6);
      text(i, 10 + i * 15 + 1, height - 12);
    }
    
    popStyle(); // Restore drawing style
  }
}
