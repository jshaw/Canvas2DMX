# Canvas2DMX: Map Processing Canvases to DMX

![Canvas2DMX demo image](docs/_img/canvas2DMX_screenshot_1.png)

**Canvas2DMX** is a Processing library for mapping pixels from your sketch directly to DMX fixtures.  
It lets you define LED mappings (strips, grids, rings, corners), apply color correction, and send data to any DMX backend or bridge (ENTTEC, DMX4Artists, OLA/Art-Net, SP201E translators, or your own).

### **Github Pages link: [Canvas2DMX](https://jshaw.github.io/Canvas2DMX/).**

---

Inspired by [FadeCandy](https://github.com/scanlime/fadecandy) and [Open Pixel Control (OPC)](https://github.com/scanlime/fadecandy/tree/master/examples/Processing) by Micah Elizabeth Scott.

---

## ✨ Features

- Real-time **color sampling** from Processing canvas
- Flexible **LED mapping**: strips, rings, grids, single points, square corners
- **Custom DMX channel patterns** (e.g. `"rgb"`, `"drgb"`, `"drgbsc"`)
- **Default channel values** for dimmer, strobe, color wheel, etc.
- **Gamma correction** and **color temperature adjustment**
- Built-in **visualization** (color bars, LED markers)
- **Agnostic DMX output**: works with DMX4Artists, ENTTEC, SP201E, or any controller via a simple callback
- **Off-screen buffer support** via `setCanvasSize()` for PGraphics workflows
- Ships with **eight examples** from beginner sampling to hardware-specific backends

---

## 🎥 Demo Video

[![Watch the demo](docs/_img/canvas2DMX_screenshot_1.png)](https://youtu.be/-gsM0a_rsXs?si=MXuY8Hiy-LBkyAh_)

> Click the thumbnail above to watch Canvas2DMX in action on YouTube.

---

## 📦 Installation

1. Install the required Processing libraries via **Sketch -> Import Library -> Add Library...**:
   - `dmxP512` for ENTTEC USB Pro devices
   - `DMX4Artists` for FT232RL / Open DMX devices

2. Install Canvas2DMX into your Processing sketchbook libraries folder:
   - release zip: unzip to `<Sketchbook>/libraries/canvas2dmx`
   - from this repo: run `./gradlew deployToProcessingSketchbook`

3. Restart Processing. The library will appear under **Sketch -> Import Library -> Canvas2DMX**.

4. Explore the included examples via  
   **File -> Examples -> Contributed Libraries -> Canvas2DMX**.  

---

## 🔌 Which dongle do I have?

Two families of USB DMX dongle exist and they need different libraries. Every example has a single flag to switch between them:

| Dongle | Library | `USE_ENTTEC_PRO` |
|---|---|---|
| **ENTTEC USB Pro** (or compatible pro-grade dongle) | **dmxP512** | `true` |
| **FT232RL "Open DMX"** — cheap USB cable, Amazon "USB to DMX 512", FreeStyler dongle | **DMX4Artists** | `false` |
| **Any dongle via OLA** — Open Lighting Architecture as middleware | UDP/Art-Net | use `HardwareOLA` example |

> Install both **dmxP512** and **DMX4Artists** via `Sketch -> Import Library -> Add Library` if you want to run the mixed-backend examples. `HardwareOpenDMX` and `HardwareOLA` are single-backend examples.

---

## 🚀 Basic Usage

```java
import com.studiojordanshaw.canvas2dmx.*;

Canvas2DMX c2d;

void setup() {
  size(400, 200);
  pixelDensity(1);

  c2d = new Canvas2DMX(this);
  c2d.mapLedStrip(0, 8, width/2f, height/2f, 40, 0, false);
  c2d.setChannelPattern("grb");
  c2d.setDefaultValue('d', 255);
  c2d.setStartAt(1);
}

void draw() {
  background(0);
  ellipse(mouseX, mouseY, 100, 100);

  int[] colors = c2d.getLedColors();
  c2d.visualize(colors);
  c2d.showLedLocations();

  // Replace this callback with your backend:
  // dmx.sendValue(ch, val), artnet.writeUniverse(...), etc.
  c2d.sendToDmx((ch, val) -> println("ch " + ch + " = " + val));
}
```

For hardware-specific setup, use the included examples:
- `Basics`, `StripMapping`, `OffscreenBuffer`, `PolygonMapping`, `InteractiveDemo`, `ColorBandTest` for switchable ENTTEC Pro / Open DMX sketches
- `HardwareOpenDMX` for DMX4Artists-only FT232RL output
- `HardwareOLA` for OLA / Art-Net output

---

## 🖼️ Off-Screen Buffer Support

When sampling from a `PGraphics` buffer instead of the main sketch canvas, use `setCanvasSize()` to tell Canvas2DMX the buffer dimensions. This is essential when your off-screen buffer has different dimensions than your sketch window.

```java
PGraphics buffer;
Canvas2DMX c2d;

void setup() {
  size(800, 600);
  
  // Create an off-screen buffer with different dimensions
  buffer = createGraphics(200, 200);
  
  c2d = new Canvas2DMX(this);
  
  // Tell Canvas2DMX the buffer dimensions (not the sketch window size)
  c2d.setCanvasSize(200, 200);
  
  // Map LEDs relative to the buffer size
  c2d.mapLedStrip(0, 10, 100, 100, 80, 0, false);
}

void draw() {
  // Draw to the off-screen buffer
  buffer.beginDraw();
  buffer.background(0);
  buffer.fill(255, 0, 0);
  buffer.ellipse(mouseX * 0.25, mouseY * 0.33, 50, 50);
  buffer.endDraw();
  
  // Display the buffer on screen (scaled up)
  image(buffer, 0, 0, width, height);
  
  // Sample LED colors from the buffer's pixels
  buffer.loadPixels();
  int[] colors = c2d.getLedColors(buffer.pixels);
  
  c2d.visualize(colors);
}
```

---

## 🧩 Examples

The library ships with examples, found in the Processing IDE under
**File → Examples → Contributed Libraries → Canvas2DMX**.

* **Basics** — the smallest possible sketch: one LED, one sampled color, live DMX output
* **StripMapping** — linear strip with reversible wiring and scrolling rainbow background
* **OffscreenBuffer** — sample from a `PGraphics` buffer with `setCanvasSize()`
* **PolygonMapping** — fill arbitrary shapes; interactive wiring direction and spacing controls
* **InteractiveDemo** — drag a color orb around a ring; press 1/2/3 to switch channel patterns
* **ColorBandTest** — diagnostic sketch: 4 solid color bands to verify channel mapping and gamma
* **HardwareOpenDMX** — FT232RL dongle only, using DMX4Artists directly
* **HardwareOLA** — any dongle via OLA middleware; sends Art-Net UDP to localhost

The general-purpose examples use the `USE_ENTTEC_PRO` flag — set it to `true` for ENTTEC Pro or `false` for FT232RL dongles. `HardwareOpenDMX` and `HardwareOLA` use dedicated backends instead.

---

### Why use off-screen buffers?

- **Performance**: Sample from a smaller buffer while displaying at full resolution
- **Flexibility**: Keep LED mapping resolution independent from display resolution
- **Effects**: Apply different processing to the DMX output vs. the display

---

## 🔧 LED Mapping Methods

### Single LED

```java
c2d.setLed(0, x, y);
```

### LED Strip

```java
c2d.mapLedStrip(0, 10, 200, 200, 20, radians(45), false);
```

### LED Ring

```java
c2d.mapLedRing(0, 12, 200, 200, 50, 0);
```

### LED Grid

```java
c2d.mapLedGrid(0, 8, 4, 200, 200, 20, 25, 0, true, false);
```

### Square Corners

```java
c2d.mapSquareCorners(0, 200, 200, 100, 45);
```

### Polygon Fill (Auto Spacing)

```java
Canvas2DMX.PolygonFillConfig cfg = new Canvas2DMX.PolygonFillConfig(20, 24)
  .startAt(0)        // 0=TL, 1=TR, 2=BR, 3=BL
  .serpentine(true)  // zigzag
  .horizontal(true) // rows (false = columns)
  .margin(5);

c2d.mapLedPolygon(0, shapeVerts, cfg);
```

### Row Layout (Fixed LEDs per Row)

Use this when each physical LED string has a fixed count per row (tapered gables, triangles, etc.).

```java
int[] rows = { 20, 18, 16, 14, 12, 10 };

Canvas2DMX.RowLayoutConfig rowCfg = new Canvas2DMX.RowLayoutConfig(rows)
  .startAt(0)        // 0=TL, 1=TR, 2=BR, 3=BL
  .serpentine(true)  // zigzag
  .horizontal(true) // rows (false = columns)
  .angleDeg(0)      // row direction angle in degrees
  .rowSpacing(0)    // 0 = evenly distributed across height
  .margin(5);

c2d.setRowLayout(0, shapeVerts, rowCfg);
```

---

## 🎚 DMX Channel Patterns

Configure fixtures with channel layouts:

```java
c2d.setChannelPattern("rgb");      // RGB only
c2d.setChannelPattern("rgbw");     // RGB + White
c2d.setChannelPattern("drgb");     // Dimmer + RGB
c2d.setChannelPattern("drgbsc");   // Dimmer + RGB + Strobe + Color wheel
c2d.setDefaultValue('d', 255);     // Default dimmer value
c2d.setDefaultValue('s', 0);       // Strobe off
```

---

## 🛠 Key Methods

### Core

* `setChannelPattern(String pattern)` — define fixture layout
* `setStartAt(int startAt)` — starting DMX channel (1-based)
* `setDefaultValue(char channel, int value)` — default values for non-RGB channels
* `getLedColors()` — sample pixels and apply corrections
* `sendToDmx(DmxSender)` — send DMX via any backend
* `buildDmxFrame(int universeSize)` — generate full DMX frame array
* `setCanvasSize(int width, int height)` — set custom canvas dimensions for LED mapping (for off-screen buffers)
* `mapLedPolygon(int start, float[][] verts, PolygonFillConfig cfg)` — fill any polygon with auto spacing
* `mapLedRowLayout(int start, float[][] verts, RowLayoutConfig cfg)` — fixed LEDs per row
* `setRowLayout(int start, float[][] verts, RowLayoutConfig cfg)` — alias of mapLedRowLayout


### Color Correction

* `setResponse(float gamma)` — gamma correction (1.0 = linear, 2.2 typical)
* `setTemperature(float t)` — adjust color temperature (-1 = warm, 1 = cool)
* `setCustomCurve(float[] curve)` — custom correction curve

### Visualization & Debugging

* `showLedLocations()` — draw LED markers on canvas
* `visualize(int[] colors)` — draw sampled LED colors
* `setShowLocations(boolean enabled)` — toggle marker drawing

---

## 🔒 Advanced Features

### Save & Load Settings

You can save the current response/temperature/curve settings to a file and reload them later.  
This is useful for keeping fixture profiles consistent across sketches.

```java
// Save current settings to a file
c2d.saveSettings("mySettings.txt");

// Later, reload them
c2d.loadSettings("mySettings.txt");
```

### Custom Response Curves

Instead of a simple gamma correction, you can define your own brightness curve.  
The curve is an array of values between `0.0` and `1.0` that remap input brightness → output brightness.  
This lets you calibrate your LEDs more precisely than with `setResponse()`.

```java
// Example: nonlinear custom brightness curve
float[] customCurve = {
  0.0,  // off
  0.05, // very dim
  0.2,
  0.5,
  0.8,
  1.0   // full brightness
};

c2d.setCustomCurve(customCurve);
```

---

## ⚠️ Troubleshooting

**Colors look washed out / pastel on LED strips**
* WS2812/WS2815 LEDs have linear output but human vision is perceptual — add gamma correction:
  ```java
  c2d.setResponse(2.2); // or up to 2.6; start here for WS2815 via SP201E
  ```
* Use `ColorBandTest` with `setResponse(1.0)` to verify raw channel mapping first, then dial in gamma.

**Red and green are swapped on the fixture**
* Your LED chip is GRB order — swap `r↔g` in the pattern:
  ```java
  c2d.setChannelPattern("dgrb");   // was "drgb"
  c2d.setChannelPattern("dgrbsc"); // was "drgbsc"
  ```

**DMX not connecting**
* Make sure you’re using the right library for your dongle:
  - ENTTEC USB Pro → **dmxP512**, `USE_ENTTEC_PRO = true`
  - FT232RL cheap dongle → **DMX4Artists**, `USE_ENTTEC_PRO = false`
  - These are **not interchangeable** — using the wrong one will silently do nothing
* On macOS, the port must use `cu.` prefix: `/dev/cu.usbserial-XXXXXXXX` (not `tty.`)
* To list all connected serial ports, add `println(Serial.list());` to `setup()`

**LED strip updates roll/cascade down the strip**
* dmxP512 sends DMX on a background timer thread. Use `buildDmxFrame()` for atomic updates:
  ```java
  int[] frame = c2d.buildDmxFrame(DMX_UNIVERSE);
  for (int i = 0; i < frame.length; i++) dmxPro.set(i + DMX_OFFSET, frame[i]);
  ```
* Also check your DMX→SPI translator for a "buffered" vs "streaming" mode setting.

**Colors wrong or always white**
* Ensure `pixelDensity(1)` in `setup()`
* Check LED positions with `c2d.showLedLocations()`
* Sample *after* drawing — `getLedColors()` reads the current frame

**Performance / slow updates**
* Pre-build background images in `setup()` instead of redrawing per-pixel in `draw()`
* Reduce LED count
* Use `frameRate(30)` if 60fps isn’t needed

See [troubleshooting.md](docs/troubleshooting.md) for the full guide.

---

## 🌟 Made with Canvas2DMX

Real-world installations by [Studio Jordan Shaw](https://www.jordanshaw.com) built using this library:

| | |
|---|---|
| [![Constellation Range](docs/_img/studiojordanshaw_constellation-range.jpg)](https://www.jordanshaw.com/home/constellation-range) | **[Constellation Range](https://www.jordanshaw.com/home/constellation-range)** — Six illuminated faceted peaks glowing with aurora-like gradients, responding to nearby Bluetooth signals. OCAD U Gala, 2026. |
| [![Same Material / Different Time](docs/_img/studiojordanshaw_samematerial_differenttime.jpg)](https://www.jordanshaw.com/home/same-material-different-time) | **[Same Material / Different Time](https://www.jordanshaw.com/home/same-material-different-time)** — Anamorphic LED installation transforming a tree into a sail through addressable strip lighting. Millennium Square. |
| [![Crosshatch](docs/_img/studiojordanshaw_crosshatch.png)](https://www.jordanshaw.com/home/crosshatch) | **[Crosshatch](https://www.jordanshaw.com/home/crosshatch)** — Kinetic interactive light installation where handles alter lighting, shadows, and projected patterns in real time. |
| [![Signal](docs/_img/studiojordanshaw_signal.png)](https://www.jordanshaw.com/home/signal) | **[Signal](https://www.jordanshaw.com/home/signal)** — Interactive light sculpture driven by open weather data and visitor interaction, exploring data transportation through the electromagnetic spectrum. |
| [![Rays](docs/_img/studiojordanshaw_rays.jpg)](https://www.jordanshaw.com/home/rays) | **[Rays](https://www.jordanshaw.com/home/rays)** — Infrared-interactive public light sculpture celebrating post-pandemic community reconnection. Hamilton. |

---

## 🗺 Roadmap / Missing Features

* Built-in Art-Net / sACN adapters so users do not need to write their own sender bridge
* Multi-universe output helpers when a mapped layout exceeds 512 DMX channels
* Fixture presets for common channel patterns instead of requiring manual pattern strings
* Alternate sampling modes such as averaged regions instead of single-pixel taps
* A calibration workflow for per-fixture white balance and brightness matching

---

## 📚 Inspirations

* [FadeCandy](https://github.com/scanlime/fadecandy) by Micah Elizabeth Scott
* [Open Pixel Control](https://github.com/scanlime/fadecandy/tree/master/examples/Processing)

**Original OPC Credit**: Micah Elizabeth Scott, 2013. Released into the public domain.

---

## 📜 License

MIT License © 2025 [Studio Jordan Shaw](https://www.jordanshaw.com/)
