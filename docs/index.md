# Canvas2DMX

**Canvas2DMX** is a Processing library for pulling pixel data from your sketch and sending it to DMX lighting fixtures in real time.  
It gives you mapping helpers for strips, rings, grids, corners, and polygon fills, plus a backend-agnostic DMX API so you can bridge to USB DMX, Art-Net, sACN, or your own sender.

![Canvas2DMX demo image](_img/canvas2DMX_screenshot.jpg)

> Inspired by [FadeCandy](https://github.com/scanlime/fadecandy) and [Open Pixel Control](https://github.com/scanlime/fadecandy/tree/master/examples/Processing) by Micah Elizabeth Scott.

---

## ✨ Features

- Real-time color sampling from the Processing canvas
- Flexible LED mapping: single points, strips, rings, grids, square corners
- Polygon fill helpers for irregular shapes and row-based layouts
- Custom DMX channel patterns such as `"rgb"`, `"drgb"`, and `"drgbsc"`
- Default values for non-RGB channels like dimmer, strobe, and color wheel
- Gamma / response correction, color temperature adjustment, and custom curves
- Off-screen buffer support via `setCanvasSize()` for `PGraphics` workflows
- Built-in debug visualization with color swatches and LED markers

---

## 🚀 Quick Start

```java
import com.studiojordanshaw.canvas2dmx.*;
import com.jaysonh.dmx4artists.*;

Canvas2DMX c2d;
DMXControl dmx;

void setup() {
  size(400, 200);
  pixelDensity(1);

  c2d = new Canvas2DMX(this);
  c2d.mapLedStrip(0, 8, width/2f, height/2f, 40, 0, false);

  c2d.setChannelPattern("drgb");
  c2d.setDefaultValue('d', 255);
  c2d.setStartAt(1); // DMX channel numbers are 1-based

  try {
    dmx = new DMXControl(0, 512);
  } catch (Exception e) {
    println("DMX init failed: " + e.getMessage());
    dmx = null;
  }
}

void draw() {
  background(0);
  ellipse(mouseX, mouseY, 100, 100);

  int[] colors = c2d.getLedColors();
  c2d.visualize(colors);
  c2d.showLedLocations();

  if (dmx != null) {
    c2d.sendToDmx((ch, val) -> dmx.sendValue(ch, val));
  }
}
```

---

## 🧩 Example Lineup

Canvas2DMX now ships with a clearer example ladder:

- `Basics` shows one mapped LED, one sampled color, and console DMX preview
- `StripMapping` focuses on linear layouts, reversible wiring, and `buildDmxFrame()`
- `OffscreenBuffer` shows how to sample from a `PGraphics` buffer with `setCanvasSize()`
- `PolygonMapping` demonstrates arbitrary shape fills and scanline ordering
- `InteractiveDemo` lets you drag a live color source around a ring and switch fixture patterns

All examples work without hardware by printing DMX preview output to the console.

---

## 📸 Example Gallery

### Basics

![Basics example](_img/canvas2DMX_screenshot_2.png)

### Strip Mapping

![Strip mapping example](_img/canvas2DMX_screenshot_3.png)

### Off-Screen Buffer

![Off-screen buffer example](_img/canvas2DMX_screenshot_4.png)

### Polygon Mapping

![Polygon mapping example](_img/canvas2DMX_screenshot_5.png)

### Interactive Demo

![Interactive demo example](_img/canvas2DMX_screenshot_6.png)

---

## 🖼️ Off-Screen Buffers

If you render to a `PGraphics` buffer instead of the main sketch window, tell Canvas2DMX the sampling dimensions before mapping LEDs:

```java
PGraphics ledBuffer;
Canvas2DMX c2d;

void setup() {
  size(800, 600);

  ledBuffer = createGraphics(160, 90);
  c2d = new Canvas2DMX(this);
  c2d.setCanvasSize(ledBuffer.width, ledBuffer.height);
  c2d.mapLedGrid(0, 12, 6, 80, 45, 10, 12, 0, true, false);
}

void draw() {
  ledBuffer.beginDraw();
  ledBuffer.background(0);
  ledBuffer.fill(255, 120, 0);
  ledBuffer.ellipse(80, 45, 30, 30);
  ledBuffer.endDraw();

  ledBuffer.loadPixels();
  int[] colors = c2d.getLedColors(ledBuffer.pixels);
}
```

This keeps LED sampling resolution independent from display resolution and makes it easier to build performant lighting previews.

---

## 🎥 Demo Video

[![Watch the demo](_img/canvas2DMX_screenshot.jpg)](https://youtu.be/-gsM0a_rsXs?si=MXuY8Hiy-LBkyAh_)

---

## 📚 Learn More

- **[Canvas2DMX on GitHub](https://github.com/jshaw/Canvas2DMX)**
- [Getting Started](getting-started.md)
- [Troubleshooting](troubleshooting.md)
- [Develop](develop.md)
- [Release](release.md)

---

## 📜 License

MIT License © 2025 [Studio Jordan Shaw](https://www.jordanshaw.com/)
