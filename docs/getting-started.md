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
