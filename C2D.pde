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
    if (pixelLocations == null) {
      pixelLocations = new int[index + 1];
    } else if (index >= pixelLocations.length) {
      pixelLocations = Arrays.copyOf(pixelLocations, index + 1);
    }
    pixelLocations[index] = x + width * y;
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
      setLed(index + i, (int)rotatedX, (int)rotatedY);
    }
  }

  // Extract pixel colors from the canvas, apply response curve, and return as an array
  color[] getLedColors() {
    color[] colors = new color[pixelLocations.length];
    loadPixels();
  
    for (int i = 0; i < pixelLocations.length; i++) {
      if (pixelLocations[i] >= 0 && pixelLocations[i] < pixels.length) {
        colors[i] = applyResponse(pixels[pixelLocations[i]]);
      } else {
        colors[i] = color(0); // Default to black or some safe color
        println("Warning: Pixel location out of bounds for LED " + i);
      }
  
      if (enableShowLocations) {
        int y = pixelLocations[i] / width;
        int x = pixelLocations[i] % width;
  
        noStroke();
        //fill(255, 255, 0, 150); // Semi-transparent yellow
        fill(0); // Semi-transparent yellow
        rect(x - 2, y - 2, 2, 2);
        
        //println("in show locations");
      }
    }
  
    return colors;
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

void sendToDmx(DMXControl dmxController) {
    color[] colors = getLedColors();
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
      response = Float.parseFloat(reader.readLine());
      temperature = Float.parseFloat(reader.readLine());

      ArrayList<Float> curveList = new ArrayList<>();
      String line;
      while ((line = reader.readLine()) != null) {
        curveList.add(Float.parseFloat(line));
      }
      customCurve = new float[curveList.size()];
      for (int i = 0; i < curveList.size(); i++) {
        customCurve[i] = curveList.get(i);
      }
    } catch (IOException e) {
      e.printStackTrace();
    }
  }

  // Visualization method to see how settings will affect the colors
  void visualize(color[] rgbArray) {
    for (int i = 0; i < rgbArray.length; i++) {
      color adjustedColor = applyResponse(rgbArray[i]);
      fill(adjustedColor);
      rect(50 + i * 30, 50, 20, 20); // Visualize each color in a rectangle
    }
  }
}
