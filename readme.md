# Canvas2Dmx: A DMX Control Library for Processing

`Canvas2Dmx` is a flexible DMX control library for Processing that allows you to map pixel colors from a canvas to DMX channels, with support for customizable channel patterns and additional channel data. Inspired by the [FadeCandy](https://github.com/scanlime/fadecandy) and [Open Pixel Control (OPC)](https://github.com/scanlime/fadecandy/tree/master/examples/Processing) libraries created by Micah Elizabeth Scott, this library extends the ability to pull colors from Processing sketches and map them to DMX fixtures, providing support for various fixture types and channel configurations.

## Features

- **Custom Channel Patterns**: Specify how RGB data is packed into DMX channels (e.g., `"rgb"`, `"xrgbxxx"`, etc.).
- **Dynamic Start Index**: Start sending DMX data from any specified channel index.
- **Default Channel Values**: Set default values for channels that aren't used for RGB (e.g., intensity, white balance).
- **Response and Color Correction**: Apply gamma correction and temperature adjustments to the colors before sending them to DMX fixtures.
- **Visualization**: Visualize the pixel colors on the Processing canvas with configurable marker sizes.
- **Support for Various Color Models**: Expandable support for RGB, RGBA, RGBW, and more.

## Installation

1. Download or clone the repository.
2. Add the `Canvas2Dmx` class to your Processing sketch.
3. Install the `Dmx4Artists` library if not already installed.

## Usage

Here is an example of how to use the `Canvas2Dmx` class in your Processing sketch:

```java
import com.jaysonh.dmx4artists.*;

Canvas2Dmx canvas2Dmx;
DMXControl dmxController;

void setup() {
  size(400, 400);
  
  canvas2Dmx = new Canvas2Dmx();
  dmxController = new DMXControl(0, 512); // Initialize with 512 DMX channels

  // Set a custom DMX channel pattern
  canvas2Dmx.setChannelPattern("xrgbxxx"); // Extra channels for each RGB set

  // Set the start channel index
  canvas2Dmx.setStartAt(10); // Start at channel 10

  // Set default values for unused channels
  canvas2Dmx.setDefaultValue('x', 255); // Full intensity for extra channels

  // Map the 4 corners of a square
  canvas2Dmx.mapSquareCorners(0, width / 2, height / 2, 100, 45); // 100px square

  // Apply gamma correction and color temperature
  canvas2Dmx.setResponse(2.0);
  canvas2Dmx.setTemperature(0.5); // Slightly cooler

  // Set up the background and draw visuals
  background(255);
  fill(255, 0, 0);
  ellipse(width / 2, height / 2, 150, 150);
}

void draw() {
  color[] colors = canvas2Dmx.getLedColors();

  // Visualize the LED colors on the canvas
  canvas2Dmx.visualize(colors);

  // Send colors to the DMX controller if connected
  if (dmxController != null) {
    canvas2Dmx.sendToDmx(dmxController);
  } else {
    println("DMX controller not connected. Skipping DMX output.");
  }
}
```

Key Methods
-----------

-   **`setChannelPattern(String pattern)`**: Set the channel pattern for DMX data (e.g., `"rgb"`, `"xrgbxxx"`).
-   **`setStartAt(int startAt)`**: Set the starting DMX channel index.
-   **`setDefaultValue(char channel, int value)`**: Set default values for specific placeholders in the channel pattern (e.g., set intensity for extra channels).
-   **`setResponse(float response)`**: Apply gamma correction to colors.
-   **`setTemperature(float temperature)`**: Adjust the color temperature (from warm to cool).
-   **`mapSquareCorners(int index, float x, float y, float size, float rotation)`**: Map LEDs to the corners of a square.
-   **`sendToDmx(DMXControl dmxController)`**: Send the RGB values (with channel pattern) to the DMX controller.

Inspirations and References
---------------------------

The `Canvas2Dmx` library was inspired by the following:

-   [**FadeCandy**](https://github.com/scanlime/fadecandy): A tool for controlling WS2811/WS2812 LED pixels created by Micah Elizabeth Scott.
-   [**Open Pixel Control (OPC)**](https://github.com/scanlime/fadecandy/tree/master/examples/Processing): A simple protocol and client for driving individually addressable RGB LEDs.

Roadmap
-------

Here are some planned and recommended features that could enhance the utility of the `Canvas2Dmx` library:

### 1\. **Dynamic Pattern Visualization**

-   **Description**: Add a feature that visualizes the DMX channel pattern being sent to the fixtures. This can help with debugging or understanding how the channel pattern maps to colors and channel indices.
-   **Use Case**: Displaying the mapping on-screen in a grid or overlay can help users understand how the DMX channels are populated.
-   **Status**: Planned.

### 2\. **Logging DMX Output Data**

-   **Description**: Add logging of DMX data to a file for later review. This can capture the DMX channel values and save them to a file in case the user needs to debug or analyze the output.
-   **Use Case**: Useful for troubleshooting or reviewing the behavior of the fixture over time.
-   **Status**: Planned.

### 3\. **Support for Color Models (e.g., RGBA, RGBW)**

-   **Description**: Provide support for additional color models like RGBA (with alpha) or RGBW (with a white channel).
-   **Use Case**: Many DMX fixtures use additional color channels like white or alpha. The user could choose between RGB, RGBW, and RGBA models.
-   **Status**: Planned.

### 4\. **Real-Time Adjustment and Visualization**

-   **Description**: Allow real-time control of DMX settings (such as gamma, color temperature, and patterns) via keyboard input or sliders on the Processing canvas.
-   **Use Case**: This would let users see how their changes affect the output in real time, without needing to recompile or adjust code.
-   **Status**: Planned.

License
-------
This project is released under the MIT License.
