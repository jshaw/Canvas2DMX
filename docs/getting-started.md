# 🚀 Getting Started with Canvas2DMX

Canvas2DMX lets you map pixels from your Processing sketch directly to DMX fixtures in real-time.  
This quickstart will guide you through installation and your first test sketch.

---

## 1. Requirements

- **Processing 4.x**
- **DMX4Artists library** by [Jayson-H](https://github.com/JaysonH/DMX4Artists)  
- **Compatible DMX controller** (ENTTEC USB Pro, SP201E, etc.)
- macOS / Windows / Linux with USB DMX adapter

---

## 2. Installation

1. Install the **DMX4Artists** library in Processing:
   - Open Processing → `Sketch` → `Import Library` → `Add Library…`
   - Search for **DMX4Artists** and install.

2. Download or clone the **Canvas2DMX** library:
   ```bash
   git clone https://github.com/jshaw/Canvas2DMX.git
   ```

3. Copy the built library folder into your Processing libraries directory:

   ```
   Documents/Processing/libraries/
   ```

4. Restart Processing.
   You should now see **Canvas2DMX** listed under `Sketch → Import Library`.

---

## 3. Your First Sketch

Create a new Processing sketch and paste the following code:

```java
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
```

Run the sketch — you’ll see LED markers drawn over your canvas, with sampled colors shown in a visualization strip at the bottom.

---

---

## 4. Configuration Methods

Canvas2DMX provides several methods to configure how colors are sampled and sent to DMX:

### Canvas Size (Off-Screen Buffers)

```java
c2d.setCanvasSize(int width, int height);
```

Set custom canvas dimensions for LED mapping. **Use this when sampling from a `PGraphics` buffer** that has different dimensions than your sketch window. By default, Canvas2DMX uses the sketch's `width` and `height`.

### Channel Pattern

```java
c2d.setChannelPattern("drgb");  // dimmer + RGB
c2d.setChannelPattern("rgb");   // just RGB (default)
c2d.setChannelPattern("rgbw");  // RGB + white
```

### Default Values

```java
c2d.setDefaultValue('d', 255);  // dimmer at full
c2d.setDefaultValue('s', 0);    // strobe off
```

### Response Curve

```java
c2d.setResponse(2.2);           // gamma correction
c2d.setTemperature(-0.3);       // warm color shift
```

---

## 5. Working with Off-Screen Buffers

For advanced workflows, you can sample from a `PGraphics` buffer instead of the main canvas. This is useful when you want to keep LED mapping resolution independent from display resolution.

```java
import com.studiojordanshaw.canvas2dmx.*;

Canvas2DMX c2d;
PGraphics ledBuffer;

void setup() {
  size(800, 600);
  
  // Create a smaller buffer for LED sampling
  ledBuffer = createGraphics(100, 100);
  
  c2d = new Canvas2DMX(this);
  
  // IMPORTANT: Tell Canvas2DMX the buffer dimensions
  c2d.setCanvasSize(100, 100);
  
  // Map LEDs relative to buffer coordinates
  c2d.mapLedStrip(0, 10, 50, 50, 8, 0, false);
}

void draw() {
  // Draw to the off-screen buffer
  ledBuffer.beginDraw();
  ledBuffer.background(0);
  ledBuffer.fill(255, 100, 0);
  ledBuffer.ellipse(
    map(mouseX, 0, width, 0, 100),
    map(mouseY, 0, height, 0, 100),
    30, 30
  );
  ledBuffer.endDraw();
  
  // Display buffer scaled up to window
  image(ledBuffer, 0, 0, width, height);
  
  // Sample from the buffer's pixels
  ledBuffer.loadPixels();
  int[] colors = c2d.getLedColors(ledBuffer.pixels);
  
  c2d.visualize(colors);
}
```

### Key Points

- Call `setCanvasSize()` **before** mapping LEDs
- LED coordinates should be relative to the buffer size, not the window size
- Use `getLedColors(buffer.pixels)` to sample from the buffer
- Don't forget to call `buffer.loadPixels()` before sampling

---

## 4. Next Steps

* Try the **examples** included with the library:

  * `Basics` — minimal LED mapping demo
  * `StripMapping` — mapping a line of LEDs
  * `InteractiveDemo` — drag shapes and see DMX output in real-time

* Check out:

  * [Advanced Features](release.md) (gamma correction, channel patterns)
  * [Troubleshooting](troubleshooting.md) if your DMX isn’t working

---

✅ That’s it! You’re ready to build interactive Processing sketches that control DMX lighting in real time.

---

## 📚 Learn More

* **[Canvas2DMX](https://github.com/jshaw/Canvas2DMX)** — repo link
* [Getting Started](getting-started.md) — installation and first sketch
* [Troubleshooting](troubleshooting.md) — common issues and fixes
* [Develop](develop.md) — contributing and building from source
* [Release](release.md) — packaging and Contribution Manager

---

## 📜 License

MIT License © 2025 [Studio Jordan Shaw](https://www.jordanshaw.com/)