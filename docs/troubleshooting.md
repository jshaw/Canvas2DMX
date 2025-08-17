# Troubleshooting

Quick fixes for common issues when using **Canvas2DMX** with Processing.

---

## 🖥️ Colors look wrong / always white

**Likely:** HiDPI scaling or sampling the wrong pixels.

**Fix**
1. Force 1× pixel scale:
   ```java
   void settings() { size(400, 300); pixelDensity(1); }
   ```

2. Confirm mapping on-screen:

   ```java
   c2d.setShowLocations(true);
   c2d.showLedLocations();
   ```
3. Make sure you mapped an LED:

   ```java
   c2d.setLed(0, width/2, height/2);
   ```
4. Sample **after** drawing:

   ```java
   // draw scene...
   int[] colors = c2d.getLedColors();
   c2d.visualize(colors);
   c2d.showLedLocations();
   ```

---

## 🔌 DMX not connecting (no light output)

**Likely:** Wrong device selection, drivers, or permissions.

**Fix**

1. Try alternate initializers (DMX4Artists):

   ```java
   dmx = new DMXControl(0, 512);                          // first device
   dmx = new DMXControl("SERIAL_NUMBER", 512);            // by serial
   dmx = new DMXControl("/dev/tty.usbserial-XXXX", 512);  // explicit path
   ```
2. Verify you’re sending:

   ```java
   if (dmx != null) c2d.sendToDmx((ch, val) -> dmx.sendValue(ch, val));
   ```
3. OS tips:

   * **macOS:** System Settings → Privacy & Security (allow serial).
   * **Windows:** Install FTDI/ENTTEC drivers, check COM port.
   * **Linux:** Add user to `dialout`/`uucp`, check `/dev/ttyUSB*` perms.
4. Prove data is generated:

   ```java
   int[] frame = c2d.buildDmxFrame(32);
   println(java.util.Arrays.toString(frame));
   ```

---

## 📁 Library not showing in Processing

**Likely:** Wrong install path.

**Fix**

1. Check Processing **Sketchbook Location** (Preferences).
2. Ensure the folder exists:

   ```
   <Sketchbook>/libraries/canvas2dmx/
   ```
3. Reinstall & restart Processing:

   ```bash
   ./gradlew deployToProcessingSketchbook
   ```

   Or set a custom path in `gradle.properties`:

   ```
   sketchbook.dir=/Users/you/Documents/Processing4
   ```

---

## 🎛️ Fixture colors wrong (e.g., red/green swapped)

**Likely:** Channel pattern mismatch or dimmer not set.

**Fix**

```java
c2d.setChannelPattern("rgb");        // or "drgb", "drgbsc", etc.
c2d.setDefaultValue('d', 255);       // full brightness if using dimmer 'd'
c2d.setDefaultValue('s', 0);         // strobe off
c2d.setStartAt(1);                   // DMX is 1-based
```

Match your fixture’s manual.

---

## 🗺️ Markers off / some LEDs stay black

**Likely:** Off-canvas mapping or out-of-bounds sample.

**Fix**

```java
int n = c2d.getMappedLedCount();
for (int i = 0; i < n; i++) {
  int pos = c2d.getLedPixelLocation(i); // -1 = unmapped
  if (pos >= 0) println("LED " + i + " → pixel " + pos);
}
```

Re-map to valid `x,y` inside `0..width-1`, `0..height-1`.
Ensure you don’t clear the screen **after** `getLedColors()`.

---

## 🏃 Low performance / high CPU

**Fix**

* Map fewer LEDs, simplify drawing.
* Limit frame rate:

  ```java
  void setup() { frameRate(30); }
  ```
* Throttle logs:

  ```java
  if (frameCount % 30 == 0) println("debug...");
  ```

---

## 🌈 Gamma/brightness feels off

**Fix**

```java
c2d.setResponse(1.2f);                 // 1.0 = linear
c2d.setTemperature(0.15f);             // -1 warm … +1 cool
float[] curve = {0.0, 0.05, 0.2, 0.5, 0.8, 1.0}; // overrides response()
c2d.setCustomCurve(curve);
```

---

## 🧪 Verify pipeline without hardware

Log a tiny preview periodically:

```java
if (frameCount % 30 == 0) {
  c2d.sendToDmx((ch, val) -> { if (ch <= 16) println("ch " + ch + " = " + val); });
}
```

---

## 🆘 Still stuck?

1) First, try the included examples: **Basics**, **StripMapping**, **InteractiveDemo**.

2) If the problem persists, **open an issue** here:  
   👉 [Open an issue](https://github.com/jshaw/Canvas2DMX/issues)

**Please include:**
- **OS & version:** (macOS 14.5 / Windows 11 / Ubuntu 22.04)
- **Processing version:** (e.g., 4.3)
- **Canvas2DMX version:** (release tag or `library.properties`)
- **DMX backend:** (DMX4Artists version if applicable)
- **Controller & connection:** (model, serial/COM path, e.g., `/dev/tty.usbserial-B001N0ZB`)
- **Sketchbook path:** (Processing Preferences → Sketchbook Location)
- **Fixture config:** `startAt`, `setChannelPattern(...)`, any `setDefaultValue(...)`
- **LED mapping details:** how many LEDs, mapping method used (strip/ring/grid)
- **Minimal reproducible sketch:** a short sketch that triggers the issue
- **Console output / error messages:** copy/paste the relevant lines
- **Steps to reproduce:** numbered list (what you did, what you expected, what happened)

**Tip (no hardware): preview DMX output in console**
   ```java
   // Log the first 16 channels about twice per second
  if (frameCount % 30 == 0) {
    c2d.sendToDmx((ch, val) -> {
      if (ch <= 16) println("ch " + ch + " = " + val);
    });
  }
   ```

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