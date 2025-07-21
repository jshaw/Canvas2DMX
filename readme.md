# Canvas2Dmx: A DMX Control Library for Processing

`Canvas2Dmx` is a flexible DMX control library for Processing that allows you to map pixel colors from a canvas to DMX channels, with support for customizable channel patterns and additional channel data. Inspired by the [FadeCandy](https://github.com/scanlime/fadecandy) and [Open Pixel Control (OPC)](https://github.com/scanlime/fadecandy/tree/master/examples/Processing) libraries created by Micah Elizabeth Scott, this library extends the ability to pull colors from Processing sketches and map them to DMX fixtures, providing support for various fixture types and channel configurations.

## Features

- **Real-time color sampling** from Processing canvas to DMX fixtures
- **Custom Channel Patterns**: Specify how RGB data is packed into DMX channels (e.g., `"rgb"`, `"drgbsc"`, `"xrgbxxx"`, etc.)
- **Dynamic Start Index**: Start sending DMX data from any specified channel index
- **Default Channel Values**: Set default values for channels that aren't used for RGB (e.g., intensity, white balance, strobe control)
- **Multiple LED mapping patterns** (strips, rings, grids, corners, individual LEDs)
- **Response and Color Correction**: Apply gamma correction and temperature adjustments to colors before sending to DMX fixtures
- **Interactive debugging tools** with visual LED position markers and real-time color feedback
- **Visualization**: Visualize the pixel colors on the Processing canvas with configurable marker sizes
- **Support for Various Color Models**: Expandable support for RGB, RGBA, RGBW, and more
- **Support for ENTTEC USB Pro and compatible DMX controllers**

## Requirements

- **Processing 4.x**
- **DMX4Artists library** by Jayson-H
- **Compatible DMX controller** (ENTTEC USB Pro, SP201E, etc.)
- **macOS/Windows/Linux** with USB DMX adapter

## Installation

1. **Install the DMX4Artists library** in Processing:
   - Sketch → Import Library → Add Library
   - Search for "DMX4Artists" and install

2. **Download and add the C2D.java file** to your sketch folder

3. **Connect your DMX controller** via USB

4. **Important**: Add `pixelDensity(1);` in your `setup()` function to ensure proper color sampling on high-DPI displays

## Basic Usage

Here is an example of how to use the `Canvas2Dmx` class in your Processing sketch:

```java
import com.jaysonh.dmx4artists.*;

Canvas2Dmx canvas2Dmx;
DMXControl dmxController;

void setup() {
  size(400, 400);
  pixelDensity(1); // Essential for proper color sampling on high-DPI displays
  
  canvas2Dmx = new Canvas2Dmx();
  
  // Initialize DMX controller
  try {
    dmxController = new DMXControl(0, 512); // Device index 0, 512 channels
    println("DMX controller initialized");
  } catch (Exception e) {
    println("DMX initialization failed: " + e.getMessage());
    dmxController = null;
  }

  // Set a custom DMX channel pattern for your fixture
  canvas2Dmx.setChannelPattern("drgbsc"); // Dimmer, Red, Green, Blue, Strobe, Color
  canvas2Dmx.setStartAt(1); // Start at channel 1

  // Set default values for non-color channels
  canvas2Dmx.setDefaultValue('d', 255); // Dimmer at full brightness
  canvas2Dmx.setDefaultValue('s', 0);   // Strobe off
  canvas2Dmx.setDefaultValue('c', 0);   // Color change off

  // Map the 4 corners of a square
  canvas2Dmx.mapSquareCorners(0, width / 2, height / 2, 100, 45); // 100px square, 45° rotation

  // Apply gamma correction and color temperature
  canvas2Dmx.setResponse(2.0);
  canvas2Dmx.setTemperature(0.5); // Slightly cooler

  // Set up the background and draw visuals
  background(255);
  fill(255, 0, 0);
  ellipse(width / 2, height / 2, 150, 150);
}

void draw() {
  // Sample colors from canvas
  loadPixels();
  color[] colors = canvas2Dmx.getLedColors(pixels);

  // Visualize the LED colors on the canvas
  canvas2Dmx.visualize(colors);
  
  // Show LED position markers (toggle with 'l' key)
  canvas2Dmx.showLedLocations();

  // Send colors to the DMX controller if connected
  if (dmxController != null) {
    canvas2Dmx.sendToDmx(dmxController);
  } else {
    println("DMX controller not connected. Skipping DMX output.");
  }
}

void keyPressed() {
  if (key == 'l') {
    canvas2Dmx.enableShowLocations = !canvas2Dmx.enableShowLocations;
    println("Show locations: " + canvas2Dmx.enableShowLocations);
  }
}
```

## LED Mapping Methods

### Single LED
```java
canvas2Dmx.setLed(0, x, y); // Map LED 0 to position (x, y)
```

### LED Strip
```java
canvas2Dmx.mapLedStrip(
  0,           // Starting LED index
  10,          // Number of LEDs
  200, 200,    // Center position
  20,          // Spacing between LEDs
  radians(45), // Angle in radians
  false        // Reversed order
);
```

### LED Ring
```java
canvas2Dmx.mapLedRing(
  0,           // Starting LED index
  12,          // Number of LEDs
  200, 200,    // Center position
  50,          // Radius
  0            // Starting angle
);
```

### LED Grid
```java
canvas2Dmx.mapLedGrid(
  0,           // Starting LED index
  8,           // LEDs per strip
  4,           // Number of strips
  200, 200,    // Center position
  20,          // LED spacing
  25,          // Strip spacing
  0,           // Angle
  true,        // Zigzag pattern
  false        // Flip direction
);
```

### Square Corners
```java
canvas2Dmx.mapSquareCorners(
  0,           // Starting LED index
  200, 200,    // Center position
  100,         // Size
  45           // Rotation degrees
);
```

## DMX Channel Patterns

Configure your fixture's channel layout:

```java
// Common patterns:
canvas2Dmx.setChannelPattern("rgb");      // Simple RGB
canvas2Dmx.setChannelPattern("rgbw");     // RGB + White
canvas2Dmx.setChannelPattern("drgb");     // Dimmer + RGB
canvas2Dmx.setChannelPattern("drgbsc");   // Dimmer + RGB + Strobe + Color
canvas2Dmx.setChannelPattern("xrgbxxx");  // Extra channels for complex fixtures

// Set default values for non-color channels:
canvas2Dmx.setDefaultValue('d', 255);     // Dimmer full
canvas2Dmx.setDefaultValue('s', 0);       // Strobe off
canvas2Dmx.setDefaultValue('c', 0);       // Color change off
canvas2Dmx.setDefaultValue('x', 255);     // Extra channels full intensity
```

## Key Methods

### Core Methods
- **`setChannelPattern(String pattern)`**: Set the channel pattern for DMX data (e.g., `"rgb"`, `"drgbsc"`)
- **`setStartAt(int startAt)`**: Set the starting DMX channel index
- **`setDefaultValue(char channel, int value)`**: Set default values for specific placeholders in the channel pattern
- **`getLedColors()`**: Extract pixel colors from the canvas and apply response curves
- **`sendToDmx(DMXControl dmxController)`**: Send the RGB values (with channel pattern) to the DMX controller

### Color Correction
- **`setResponse(float response)`**: Apply gamma correction to colors (1.0 = linear, 2.2 = typical gamma)
- **`setTemperature(float temperature)`**: Adjust color temperature (-1 = warm, 1 = cool)
- **`setCustomCurve(float[] curve)`**: Apply a custom response curve

### Mapping Methods
- **`setLed(int index, int x, int y)`**: Map a single LED to canvas coordinates
- **`mapLedStrip(...)`**: Map a linear strip of LEDs
- **`mapLedRing(...)`**: Map LEDs in a circular pattern
- **`mapLedGrid(...)`**: Map a rectangular grid of LEDs
- **`mapSquareCorners(...)`**: Map LEDs to the corners of a square

### Visualization and Debugging
- **`showLedLocations()`**: Draw LED position markers on canvas
- **`visualize(color[] colors)`**: Display color bar showing LED colors

## Interactive Controls

### Debug Keys
- **'l'** - Toggle LED position markers
- **'p'** - Print LED positions to console
- **'s'** - Save settings to file

### Manual DMX Testing
- **'t'** - Send red to all channels
- **'y'** - Send green to all channels  
- **'u'** - Send blue to all channels

### Fixture Control
- **'1'** - Full brightness, effects off
- **'2'** - Half brightness
- **'3'** - Enable strobe (be careful!)
- **'4'** - Disable strobe

## Advanced Features

### Save/Load Settings
```java
canvas2Dmx.saveSettings("mySettings.txt");
canvas2Dmx.loadSettings("mySettings.txt");
```

### Custom Response Curves
```java
float[] customCurve = {0.0, 0.1, 0.3, 0.7, 1.0};
canvas2Dmx.setCustomCurve(customCurve);
```

## Troubleshooting

### Common Issues

**Colors always white/wrong:**
- Ensure `pixelDensity(1)` is called in `setup()` - this is the most common issue on high-DPI displays
- Check LED positions with `'l'` key to see if they're where you expect
- Verify channel pattern matches your fixture's manual

**DMX not connecting:**
- Check USB cable and DMX controller
- Try different initialization methods:
```java
dmxController = new DMXControl(0, 256);                    // Device index
dmxController = new DMXControl("SERIAL_NUMBER", 256);      // Serial number  
dmxController = new DMXControl("/dev/tty.usbserial-XXX", 256); // Port path
```

**Performance issues:**
- Reduce number of LEDs
- Lower frame rate with `frameRate(30)`
- Disable debug output for production use

### Debug Information

Enable verbose debugging:
```java
canvas2Dmx.enableShowLocations = true; // Show LED markers
// Check console for color values and DMX channel assignments
```

## Roadmap

Here are some planned and recommended features that could enhance the utility of the `Canvas2Dmx` library:

### 1. **Dynamic Pattern Visualization**
- **Description**: Add a feature that visualizes the DMX channel pattern being sent to the fixtures. This can help with debugging or understanding how the channel pattern maps to colors and channel indices.
- **Use Case**: Displaying the mapping on-screen in a grid or overlay can help users understand how the DMX channels are populated.
- **Status**: Planned.

### 2. **Logging DMX Output Data**
- **Description**: Add logging of DMX data to a file for later review. This can capture the DMX channel values and save them to a file in case the user needs to debug or analyze the output.
- **Use Case**: Useful for troubleshooting or reviewing the behavior of the fixture over time.
- **Status**: Planned.

### 3. **Support for Color Models (e.g., RGBA, RGBW)**
- **Description**: Provide support for additional color models like RGBA (with alpha) or RGBW (with a white channel).
- **Use Case**: Many DMX fixtures use additional color channels like white or alpha. The user could choose between RGB, RGBW, and RGBA models.
- **Status**: Planned.

### 4. **Real-Time Adjustment and Visualization**
- **Description**: Allow real-time control of DMX settings (such as gamma, color temperature, and patterns) via keyboard input or sliders on the Processing canvas.
- **Use Case**: This would let users see how their changes affect the output in real time, without needing to recompile or adjust code.
- **Status**: Planned.

## Example Projects

- **Interactive painting** - Colors follow mouse movements
- **Audio visualizer** - LEDs respond to music analysis  
- **Generative patterns** - Algorithmic graphics control lighting
- **Game lighting** - Sync lights with game events
- **VJ performance** - Real-time visual effects

## Inspirations and References

The `Canvas2Dmx` library was inspired by the following:

- [**FadeCandy**](https://github.com/scanlime/fadecandy): A tool for controlling WS2811/WS2812 LED pixels created by Micah Elizabeth Scott.
- [**Open Pixel Control (OPC)**](https://github.com/scanlime/fadecandy/tree/master/examples/Processing): A simple protocol and client for driving individually addressable RGB LEDs.

**Original OPC Credit**: Micah Elizabeth Scott, 2013 - Simple Open Pixel Control client for Processing, designed to sample each LED's color from some point on the canvas. This file is released into the public domain.

## License

This project is released under the MIT License.