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

**First: identify your dongle type.** The two most common dongles need completely different code paths.

| Symptom | Likely cause |
|---|---|
| ENTTEC Pro connected, nothing lights up | Wrong library — use dmxP512, not DMX4Artists |
| FT232RL dongle connected, nothing lights up | Wrong library — use DMX4Artists, not dmxP512 |
| Port opens but fixture doesn’t respond | Wrong baud rate, wrong port prefix, or fixture not in DMX mode |
| Port won’t open at all | Driver not installed, wrong port name, or permissions |

**ENTTEC USB Pro** (and compatible pro-grade dongles) → use **dmxP512**:
- Set `USE_ENTTEC_PRO = true` in any example
- Port must use `cu.` prefix on macOS: `/dev/cu.usbserial-XXXXXXXX`
- Baud rate must be `115000`

**FT232RL dongles** (cheap USB cables, FreeStyler, Amazon "USB to DMX 512") → use **DMX4Artists**:
- Set `USE_ENTTEC_PRO = false`, or use the `HardwareOpenDMX` example
- Install the FTDI VCP driver if the port doesn’t appear: https://ftdichip.com/drivers/vcp-drivers/
- Device is auto-detected by index — no port string needed

**OS tips:**
- **macOS:** System Settings → Privacy & Security → allow serial access
- **Windows:** Install FTDI or ENTTEC drivers, check Device Manager for COM port
- **Linux:** `sudo usermod -aG dialout $USER`, check `/dev/ttyUSB*`

**Prove data is being generated (works for any backend):**
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

## 💡 LED strip updates roll down the strip (cascade/tearing effect)

**Cause:** Libraries like dmxP512 send DMX on an internal timer thread. If that timer fires while `sendToDmx()` is mid-loop, the first LEDs go out in one DMX frame and the rest in the next — you see the update visibly propagating.

**Fix:** Use `buildDmxFrame()` to pre-compute the complete frame, then write it to the backend in one tight loop:

```java
void sendDmx() {
  int[] frame = c2d.buildDmxFrame(DMX_UNIVERSE);
  for (int i = 0; i < frame.length; i++) {
    dmxPro.set(i + DMX_OFFSET, frame[i]);
  }
}
```

This minimises the window in which the timer thread can interrupt between channel writes.

> **Note:** If the rolling effect persists, check your DMX→SPI translator's settings. Some devices (e.g. SP201E) have a **streaming mode** that pushes SPI data as each DMX channel arrives, and a **buffered mode** that waits for a full frame before outputting. Streaming mode will always roll — switch to buffered mode in the device's DIP switch settings.

---

## 🏃 Low performance / high CPU

**Fix**

* Map fewer LEDs, simplify drawing.
* Avoid per-pixel drawing with `line()` or `stroke()` in `draw()` — use `pixels[]` or a pre-built `PImage` instead.
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

1) First, try the included examples: **Basics**, **StripMapping**, **OffscreenBuffer**, **PolygonMapping**, **InteractiveDemo**.

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
* [Getting Started](getting-started.html) — installation and first sketch
* [Troubleshooting](troubleshooting.html) — common issues and fixes
* [Develop](develop.html) — contributing and building from source
* [Release](release.html) — packaging and Processing Library Manager submission

---

## 📜 License

MIT License © 2025 [Studio Jordan Shaw](https://www.jordanshaw.com/)
