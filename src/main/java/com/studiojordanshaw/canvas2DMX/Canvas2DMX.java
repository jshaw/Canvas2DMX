package com.studiojordanshaw.canvas2dmx;

import processing.core.PApplet;
import processing.core.PConstants;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.PrintWriter;
import java.util.Arrays;
import java.util.ArrayList;
import java.util.HashMap;

/**
 * Canvas2DMX
 * <p>
 * Samples colors from locations on the sketch canvas and sends them to DMX
 * fixtures using a configurable channel pattern (e.g., "rgb", "drgb", "rgbw").
 * Supports response curves, color temperature, mapping helpers, and a
 * "no-hardware" path so examples run in the PDE.
 *
 * <p>
 * Designed for ENTTEC USB Pro and compatible devices via DMXControl.
 * </p>
 *
 * <p>
 * Original inspiration: Open Pixel Control (Micah Elizabeth Scott, 2013).
 * </p>
 */
public class Canvas2DMX implements PConstants {

  /** Reference to the parent sketch for drawing and pixel access. */
  private final PApplet parent;

  // -1 means use parent.width
  private int canvasWidth = -1;
  private int canvasHeight = -1;

  /**
   * Mapped pixel indices into parent.pixels for each LED index; -1 for unmapped.
   */
  private int[] pixelLocations;

  /** Toggle for drawing LED index markers on top of the sketch. */
  private boolean enableShowLocations = true;

  /** Exponent for simple gamma/response (1.0 = linear). */
  private float response = 1.0f;

  /** Color temperature adjustment in [-1, 1] (warm .. cool). */
  private float temperature = 0.0f;

  /** Optional custom response curve lookup [0..1] -> [0..1]. */
  private float[] customCurve = null;

  /** Per-fixture channel pattern, e.g., "rgb", "drgb", "rgbw". */
  private String channelPattern = "rgb";

  /** Starting DMX channel (0-based index into logical stream you’re sending). */
  private int startAt = 0;

  /** Default values for non-r/g/b placeholders (e.g., 'd' for master dim). */
  private final HashMap<Character, Integer> defaultValues = new HashMap<>();

  /**
   * Construct the library. Call this once in your sketch's setup():
   *
   * <pre>
   * Canvas2DMX c2d = new Canvas2DMX(this);
   * </pre>
   *
   * @param parent the parent PApplet
   */
  public Canvas2DMX(PApplet parent) {
    this.parent = parent;
    // Make sure we cleanup when the sketch stops.
    parent.registerMethod("dispose", this);
  }

  /** Processing lifecycle hook for cleanup. */
  public void dispose() {
    // Close serial/DMX resources here if you own them.
    // (Left empty because DMXControl is passed-in by the user.)
  }

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /** Enable or disable drawing LED markers. */
  public void setShowLocations(boolean enabled) {
    this.enableShowLocations = enabled;
  }

  /** @return whether LED markers are drawn. */
  public boolean isShowLocationsEnabled() {
    return enableShowLocations;
  }

  /** Set simple response exponent (disables custom curve). */
  public void setResponse(float response) {
    this.response = response;
    this.customCurve = null;
  }

  /** Set custom canvas dimensions for LED mapping (for off-screen buffers). */
  public void setCanvasSize(int width, int height) {
    this.canvasWidth = width;
    this.canvasHeight = height;
  }

  private int getCanvasWidth() {
    return canvasWidth > 0 ? canvasWidth : parent.width;
  }

  private int getCanvasHeight() {
    return canvasHeight > 0 ? canvasHeight : parent.height;
  }

  /**
   * Provide a custom [0..1] → [0..1] response curve (disables simple exponent).
   */
  public void setCustomCurve(float[] curve) {
    this.customCurve = curve;
  }

  /** Set color temperature in [-1, 1] (negative = warm, positive = cool). */
  public void setTemperature(float temperature) {
    this.temperature = PApplet.constrain(temperature, -1f, 1f);
  }

  /** Set the DMX channel pattern, e.g., "rgb", "drgb", "rgbw". */
  public void setChannelPattern(String pattern) {
    if (pattern == null || pattern.isEmpty()) {
      throw new IllegalArgumentException("channelPattern must be non-empty");
    }
    this.channelPattern = pattern;
  }

  /** Set the starting channel index for the DMX stream. */
  public void setStartAt(int startAt) {
    if (startAt < 0)
      throw new IllegalArgumentException("startAt must be >= 0");
    this.startAt = startAt;
  }

  /**
   * Assign a default value (0–255) for a non-RGB placeholder char in the pattern.
   */
  public void setDefaultValue(char channel, int value) {
    defaultValues.put(channel, PApplet.constrain(value, 0, 255));
  }

  // ---------------------------------------------------------------------------
  // Mapping helpers (set where each LED samples from the canvas)
  // ---------------------------------------------------------------------------

  /** Map one LED to (x,y) in canvas coordinates. */
  public void setLed(int index, int x, int y) {
    if (index < 0)
      throw new IllegalArgumentException("LED index must be >= 0");

    // Ensure storage (2x length growth headroom is unnecessary; store 1:1)
    if (pixelLocations == null) {
      pixelLocations = new int[index + 1];
      Arrays.fill(pixelLocations, -1);
    } else if (index >= pixelLocations.length) {
      int oldLen = pixelLocations.length;
      pixelLocations = Arrays.copyOf(pixelLocations, index + 1);
      Arrays.fill(pixelLocations, oldLen, pixelLocations.length, -1);
    }

    int w = getCanvasWidth();
    int h = getCanvasHeight();

    // Constrain coordinate to canvas bounds
    x = PApplet.constrain(x, 0, w - 1);
    y = PApplet.constrain(y, 0, h - 1);
    
    int pixelIndex = x + w * y;
    pixelLocations[index] = pixelIndex;

    // x = PApplet.constrain(x, 0, parent.width - 1);
    // y = PApplet.constrain(y, 0, parent.height - 1);

    // int pixelIndex = x + parent.width * y;
    // pixelLocations[index] = pixelIndex;

    if (parent.frameCount < 5) {
      parent.println("setLed(" + index + ", " + x + ", " + y + ") -> pixel[" + pixelIndex + "]");
    }
  }

  /** Map a linear strip of LEDs. */
  public void mapLedStrip(int index, int count, float x, float y, float spacing, float angle, boolean reversed) {
    float s = PApplet.sin(angle);
    float c = PApplet.cos(angle);
    for (int i = 0; i < count; i++) {
      int tgt = reversed ? (index + count - 1 - i) : (index + i);
      float offset = (i - (count - 1) / 2.0f) * spacing;
      int xx = PApplet.round(x + offset * c);
      int yy = PApplet.round(y + offset * s);
      setLed(tgt, xx, yy);
    }
  }

  /** Map a ring of LEDs (clockwise from angle). */
  public void mapLedRing(int index, int count, float x, float y, float radius, float angle) {
    for (int i = 0; i < count; i++) {
      float a = angle + i * TWO_PI / count;
      int xx = PApplet.round(x - radius * PApplet.cos(a));
      int yy = PApplet.round(y - radius * PApplet.sin(a));
      setLed(index + i, xx, yy);
    }
  }

  /** Map a grid of LED strips with optional zigzag and flip. */
  public void mapLedGrid(int index, int stripLength, int numStrips, float x, float y,
      float ledSpacing, float stripSpacing, float angle,
      boolean zigzag, boolean flip) {
    float s = PApplet.sin(angle + HALF_PI);
    float c = PApplet.cos(angle + HALF_PI);
    for (int i = 0; i < numStrips; i++) {
      boolean rev = zigzag && ((i % 2) == 1) != flip;
      float o = (i - (numStrips - 1) / 2.0f) * stripSpacing;
      mapLedStrip(index + stripLength * i, stripLength,
          x + o * c, y + o * s, ledSpacing, angle, rev);
    }
  }

  /** Map the 4 rotated corners of a square centered at (x,y). */
  public void mapSquareCorners(int index, float x, float y, float size, float rotationDegrees) {
    float half = size / 2.0f;
    float a = PApplet.radians(rotationDegrees);
    float[] xOff = { -half, half, half, -half };
    float[] yOff = { -half, -half, half, half };
    for (int i = 0; i < 4; i++) {
      float rx = x + xOff[i] * PApplet.cos(a) - yOff[i] * PApplet.sin(a);
      float ry = y + xOff[i] * PApplet.sin(a) + yOff[i] * PApplet.cos(a);
      setLed(index + i, PApplet.round(rx), PApplet.round(ry));
    }
  }

  // ---------------------------------------------------------------------------
  // Sampling & processing
  // ---------------------------------------------------------------------------

  /**
   * Apply response/temperature to an ARGB color.
   * 
   * @param argb ARGB color from the canvas
   * @return processed ARGB color
   */
  public int applyResponse(int argb) {
    float r = parent.red(argb) / 255f;
    float g = parent.green(argb) / 255f;
    float b = parent.blue(argb) / 255f;

    // Temperature tweak (subtle, asymmetric by design)
    if (temperature > 0) {
      r -= temperature * 0.2f;
      b += temperature * 0.1f;
    } else if (temperature < 0) {
      r += temperature * 0.1f; // temperature is negative => subtract
      b -= temperature * 0.2f; // negative * negative => add
    }

    r = PApplet.constrain(r, 0, 1);
    g = PApplet.constrain(g, 0, 1);
    b = PApplet.constrain(b, 0, 1);

    if (customCurve != null && customCurve.length > 1) {
      int ri = (int) (r * (customCurve.length - 1));
      int gi = (int) (g * (customCurve.length - 1));
      int bi = (int) (b * (customCurve.length - 1));
      r = customCurve[ri];
      g = customCurve[gi];
      b = customCurve[bi];
    } else {
      r = PApplet.pow(r, response);
      g = PApplet.pow(g, response);
      b = PApplet.pow(b, response);
    }

    return parent.color(PApplet.constrain(r * 255f, 0, 255),
        PApplet.constrain(g * 255f, 0, 255),
        PApplet.constrain(b * 255f, 0, 255));
  }

  /**
   * Sample mapped LEDs from a provided pixel buffer (ARGB).
   * 
   * @param pixelArray parent.pixels or another ARGB buffer of size width*height
   * @return processed colors, one per mapped LED (may be length 0)
   */
  public int[] getLedColors(int[] pixelArray) {
    if (pixelLocations == null) {
      parent.println("Canvas2DMX: Warning: No LEDs mapped!");
      return new int[0];
    }

    // Determine highest valid LED index (contiguous-ish use)
    int validCount = 0;
    for (int i = 0; i < pixelLocations.length; i++) {
      if (pixelLocations[i] >= 0)
        validCount = i + 1;
    }

    int[] colors = new int[validCount];

    for (int i = 0; i < validCount; i++) {
      int loc = pixelLocations[i];
      if (loc >= 0 && loc < pixelArray.length) {
        int raw = pixelArray[loc];
        int processed = applyResponse(raw);
        colors[i] = processed;

        if (parent.frameCount % 30 == 0 && i < 2) {
          int x = loc % parent.width;
          int y = loc / parent.width;
          parent.println(String.format(
              "LED %d at (%d,%d): RAW(%d,%d,%d) PROC(%d,%d,%d)",
              i, x, y,
              (int) parent.red(raw), (int) parent.green(raw), (int) parent.blue(raw),
              (int) parent.red(processed), (int) parent.green(processed), (int) parent.blue(processed)));
        }
      } else {
        colors[i] = parent.color(0); // black
        if (loc >= 0) {
          parent.println("Canvas2DMX: Warning: pixel location out of bounds for LED " + i + " -> " + loc);
        }
      }
    }
    return colors;
  }

  /**
   * Convenience: samples from the parent sketch's current frame.
   * Calls parent.loadPixels() internally.
   * 
   * @return processed colors, one per mapped LED
   */
  public int[] getLedColors() {
    parent.loadPixels();
    return getLedColors(parent.pixels);
  }

  // ---------------------------------------------------------------------------
  // Visualization helpers (for on-canvas debug overlays)
  // ---------------------------------------------------------------------------

  /**
   * Draw small markers and indices at mapped LED locations. Call after drawing
   * your scene.
   */
public void showLedLocations() {
  if (!enableShowLocations || pixelLocations == null)
    return;

  // Ensure pixels array is loaded
  if (parent.pixels == null) {
    parent.loadPixels();
  }

  int w = getCanvasWidth();
  
  int validCount = 0;
  for (int i = 0; i < pixelLocations.length; i++) {
    if (pixelLocations[i] >= 0)
      validCount = i + 1;
  }

  parent.pushStyle();
  for (int i = 0; i < validCount; i++) {
    int loc = pixelLocations[i];
    if (loc >= 0) {  // Remove the pixels.length check since we're not using pixels
      int y = loc / w;
      int x = loc % w;

      parent.noFill();
      parent.stroke(255, 255, 0);
      parent.strokeWeight(1);
      parent.ellipse(x, y, 2, 2);

      parent.fill(0);
      parent.textAlign(PConstants.CENTER, PConstants.CENTER);
      parent.textSize(4);
      parent.text(i, x + 2, y + 2);
    }
  }
  parent.popStyle();
}

  /** Quick swatch renderer for up to 20 LEDs at the bottom of the screen. */
  public void visualize(int[] processedColors) {
    parent.pushStyle();
    for (int i = 0; i < processedColors.length && i < 20; i++) {
      parent.fill(processedColors[i]);
      parent.noStroke();
      parent.rect(10 + i * 15, parent.height - 30, 12, 20);

      parent.fill(255);
      parent.textSize(6);
      parent.text(i, 10 + i * 15 + 1, parent.height - 12);
    }
    parent.popStyle();
  }

  // ---------------------------------------------------------------------------
  // DMX send
  // ---------------------------------------------------------------------------

  /**
   * Send processed LED colors to a DMX controller using the current channel
   * pattern.
   * 
   * @param dmxController an instance providing sendValue(int channel, int value)
   */
  /** Minimal DMX sender contract: deliver a (channel, value) pair. */
  @FunctionalInterface
  public interface DmxSender {
    void send(int channel, int value);
  }

  /**
   * Iterate over the current LED mapping and emit DMX channel/value pairs
   * using the current channelPattern and startAt. Agnostic to any backend.
   */
  public void sendToDmx(DmxSender sender) {
    if (sender == null) {
      parent.println("Canvas2DMX: Warning: DmxSender is null.");
      return;
    }
    int[] colors = getLedColors();
    if (colors.length == 0) {
      parent.println("Canvas2DMX: Warning: No LED colors to send.");
      return;
    }

    int dmxIndex = startAt; // DMX channels are 1-based by convention in this API
    for (int i = 0; i < colors.length; i++) {
      int r = (int) parent.red(colors[i]);
      int g = (int) parent.green(colors[i]);
      int b = (int) parent.blue(colors[i]);

      for (int j = 0; j < channelPattern.length(); j++) {
        char ch = channelPattern.charAt(j);
        int v;
        switch (ch) {
          case 'r':
            v = r;
            break;
          case 'g':
            v = g;
            break;
          case 'b':
            v = b;
            break;
          default:
            v = defaultValues.getOrDefault(ch, 0);
        }
        sender.send(dmxIndex++, v);
      }
    }

    if (parent.frameCount % 120 == 0) {
      parent.println("Canvas2DMX: Sent " + colors.length + " LEDs starting at channel " + startAt);
    }
  }

  /**
   * Build a DMX frame (1-based addressing) of the requested length.
   * frame[0] corresponds to DMX channel 1. Values outside the active range are 0.
   * Handy if your backend prefers a single write() of a full universe.
   *
   * @param frameLength number of channels to produce (e.g., 512 for a universe)
   * @return int[] of length frameLength with values 0..255
   */
  public int[] buildDmxFrame(int frameLength) {
    if (frameLength <= 0)
      throw new IllegalArgumentException("frameLength must be > 0");
    int[] frame = new int[frameLength]; // zero-initialized

    int[] colors = getLedColors();
    if (colors.length == 0)
      return frame;

    int idx = startAt; // 1-based
    for (int i = 0; i < colors.length; i++) {
      int r = (int) parent.red(colors[i]);
      int g = (int) parent.green(colors[i]);
      int b = (int) parent.blue(colors[i]);

      for (int j = 0; j < channelPattern.length(); j++) {
        char ch = channelPattern.charAt(j);
        int v;
        switch (ch) {
          case 'r':
            v = r;
            break;
          case 'g':
            v = g;
            break;
          case 'b':
            v = b;
            break;
          default:
            v = defaultValues.getOrDefault(ch, 0);
        }
        // Map 1-based channel to 0-based array index; ignore out-of-range
        int arrIndex = idx - 1;
        if (arrIndex >= 0 && arrIndex < frame.length)
          frame[arrIndex] = v;
        idx++;
      }
    }
    return frame;
  }

  // ---------------------------------------------------------------------------
  // Save/Load settings (lightweight)
  // ---------------------------------------------------------------------------

  /**
   * Save response/temperature/customCurve to a text file in the sketch folder.
   */
  public void saveSettings(String filename) {
    PrintWriter out = parent.createWriter(filename);
    out.println(response);
    out.println(temperature);
    if (customCurve != null) {
      for (float v : customCurve)
        out.println(v);
    }
    out.close();
  }

  /**
   * Load response/temperature/customCurve from a text file in the sketch folder.
   */
  public void loadSettings(String filename) {
    BufferedReader reader = parent.createReader(filename);
    try {
      String line;
      if ((line = reader.readLine()) != null)
        response = Float.parseFloat(line);
      if ((line = reader.readLine()) != null)
        temperature = Float.parseFloat(line);

      ArrayList<Float> curve = new ArrayList<>();
      while ((line = reader.readLine()) != null)
        curve.add(Float.parseFloat(line));

      if (!curve.isEmpty()) {
        customCurve = new float[curve.size()];
        for (int i = 0; i < curve.size(); i++)
          customCurve[i] = curve.get(i);
      }
      reader.close();
    } catch (IOException e) {
      parent.println("Canvas2DMX: Error loading settings: " + e.getMessage());
    } catch (NumberFormatException e) {
      parent.println("Canvas2DMX: Error parsing settings: " + e.getMessage());
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers so examples don't touch internals
  // ---------------------------------------------------------------------------
  public int getMappedLedCount() {
    if (pixelLocations == null)
      return 0;
    int n = 0;
    for (int i = 0; i < pixelLocations.length; i++)
      if (pixelLocations[i] >= 0)
        n = i + 1;
    return n;
  }

  public int getLedPixelLocation(int i) {
    if (pixelLocations == null || i < 0 || i >= pixelLocations.length)
      return -1;
    return pixelLocations[i];
  }

  public int getStartAt() {
    return startAt;
  }

  public String getChannelPattern() {
    return channelPattern;
  }

  // ---------------------------------------------------------------------------
  // Optional convenience
  // ---------------------------------------------------------------------------

  /** One-time helper: warn if pixelDensity != 1 (sampling can misalign). */
  public void warnIfNonStandardPixelDensityOnce() {
    if (parent.pixelDensity != 1) {
      parent.println("Canvas2DMX: Note: pixelDensity != 1; sampling may misalign. Consider parent.pixelDensity(1).");
    }
  }

  // --- Minimal interface to avoid compile coupling if desired ---
  // You can delete this if you import your real DMXControl.
  public interface DMXControl {
    void sendValue(int channelIndex, int value);
  }
}
