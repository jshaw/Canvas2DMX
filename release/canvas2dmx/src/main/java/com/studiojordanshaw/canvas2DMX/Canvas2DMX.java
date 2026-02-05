package com.studiojordanshaw.canvas2dmx;

import processing.core.PApplet;
import processing.core.PConstants;
import processing.core.PVector;

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

  /** Starting DMX channel (0-based index into logical stream you're sending). */
  private int startAt = 0;

  /** Default values for non-r/g/b placeholders (e.g., 'd' for master dim). */
  private final HashMap<Character, Integer> defaultValues = new HashMap<>();

  // ---------------------------------------------------------------------------
  // Polygon Fill Configuration (Inner Class)
  // ---------------------------------------------------------------------------

  /**
   * Configuration for polygon LED fill orientation.
   * Controls how LEDs are ordered when filling an arbitrary polygon.
   */
  public static class PolygonFillConfig {
    
    /** Starting corner: 0=TopLeft, 1=TopRight, 2=BottomRight, 3=BottomLeft */
    public int startCorner = 0;
    
    /** If true, alternate row directions (serpentine/zigzag wiring) */
    public boolean serpentine = true;
    
    /** Primary fill direction: true=horizontal rows, false=vertical columns */
    public boolean horizontal = true;
    
    /** Spacing between LEDs along the primary axis (pixels) */
    public float ledSpacing = 8.0f;
    
    /** Spacing between rows/columns (pixels) */
    public float rowSpacing = 8.0f;

    /**
     * If > 0, force an exact number of LEDs per row/column segment.
     * When enabled, ledSpacing is ignored for that axis and LEDs are
     * distributed evenly between the segment endpoints.
     */
    public int ledsPerRow = -1;
    
    /** Rotation angle in radians (applied to fill pattern, not polygon) */
    public float angle = 0.0f;
    
    /** Margin inset from polygon edges (pixels) */
    public float margin = 1.0f;
    
    public PolygonFillConfig() {}
    
    public PolygonFillConfig(float ledSpacing, float rowSpacing) {
      this.ledSpacing = ledSpacing;
      this.rowSpacing = rowSpacing;
    }
    
    // Fluent setters for easy chaining
    public PolygonFillConfig startAt(int corner) { this.startCorner = corner; return this; }
    public PolygonFillConfig serpentine(boolean s) { this.serpentine = s; return this; }
    public PolygonFillConfig horizontal(boolean h) { this.horizontal = h; return this; }
    public PolygonFillConfig spacing(float led, float row) { 
      this.ledSpacing = led; this.rowSpacing = row; return this; 
    }
    public PolygonFillConfig rowLedCount(int count) { this.ledsPerRow = count; return this; }
    public PolygonFillConfig angle(float a) { this.angle = a; return this; }
    public PolygonFillConfig margin(float m) { this.margin = m; return this; }
  }

  // ---------------------------------------------------------------------------
  // Row Layout Configuration (Inner Class)
  // ---------------------------------------------------------------------------

  /**
   * Configuration for row-based polygon LED fill using fixed LED counts per row.
   * Each row's LEDs are distributed across the polygon's width at that row.
   */
  public static class RowLayoutConfig {

    /** LEDs per row (top-to-bottom if startCorner is top, else bottom-to-top). */
    public int[] ledsPerRow;

    /** Starting corner: 0=TopLeft, 1=TopRight, 2=BottomRight, 3=BottomLeft */
    public int startCorner = 0;

    /** If true, alternate row directions (serpentine/zigzag wiring) */
    public boolean serpentine = true;

    /** Primary fill direction: true=horizontal rows, false=vertical columns */
    public boolean horizontal = true;

    /** Row/column spacing (pixels). If &lt;= 0, rows are evenly distributed. */
    public float rowSpacing = 0.0f;

    /** Row direction angle in degrees (0 = left-to-right) */
    public float angleDeg = 0.0f;

    /** Margin inset from polygon edges (pixels) */
    public float margin = 1.0f;

    public RowLayoutConfig(int[] ledsPerRow) {
      this.ledsPerRow = ledsPerRow;
    }

    // Fluent setters for easy chaining
    public RowLayoutConfig startAt(int corner) { this.startCorner = corner; return this; }
    public RowLayoutConfig serpentine(boolean s) { this.serpentine = s; return this; }
    public RowLayoutConfig horizontal(boolean h) { this.horizontal = h; return this; }
    public RowLayoutConfig rowSpacing(float r) { this.rowSpacing = r; return this; }
    public RowLayoutConfig angleDeg(float degrees) { this.angleDeg = degrees; return this; }
    public RowLayoutConfig margin(float m) { this.margin = m; return this; }
  }

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

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

  /** Clear all LED mappings. Call before remapping to avoid stale markers. */
  public void clearLeds() {
    if (pixelLocations != null) {
      Arrays.fill(pixelLocations, -1);
    }
  }

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
      float ry = x + xOff[i] * PApplet.sin(a) + yOff[i] * PApplet.cos(a);
      setLed(index + i, PApplet.round(rx), PApplet.round(ry));
    }
  }

  // ---------------------------------------------------------------------------
  // Polygon Fill Mapping
  // ---------------------------------------------------------------------------

  /**
   * Fill an arbitrary polygon with LEDs using scanline algorithm.
   * 
   * @param startIndex  First LED index to use
   * @param vertices    Array of polygon vertices as float[][] where each element is {x, y}
   * @param config      Fill configuration (orientation, spacing, etc.)
   * @return            Number of LEDs mapped (next available index = startIndex + return value)
   */
  public int mapLedPolygon(int startIndex, float[][] vertices, PolygonFillConfig config) {
    if (vertices == null || vertices.length < 3) {
      parent.println("mapLedPolygon: Need at least 3 vertices");
      return 0;
    }
    
    // Convert float[][] to internal format
    float[] xVerts = new float[vertices.length];
    float[] yVerts = new float[vertices.length];
    for (int i = 0; i < vertices.length; i++) {
      xVerts[i] = vertices[i][0];
      yVerts[i] = vertices[i][1];
    }
    
    return mapLedPolygonInternal(startIndex, xVerts, yVerts, config);
  }

  /**
   * Fill an arbitrary polygon with LEDs using scanline algorithm.
   * Overload accepting PVector array (Processing-friendly).
   * 
   * @param startIndex  First LED index to use
   * @param vertices    Array of PVector vertices
   * @param config      Fill configuration (orientation, spacing, etc.)
   * @return            Number of LEDs mapped (next available index = startIndex + return value)
   */
  public int mapLedPolygon(int startIndex, Object[] vertices, PolygonFillConfig config) {
    if (vertices == null || vertices.length < 3) {
      parent.println("mapLedPolygon: Need at least 3 vertices");
      return 0;
    }
    
    float[] xVerts = new float[vertices.length];
    float[] yVerts = new float[vertices.length];
    
    for (int i = 0; i < vertices.length; i++) {
      // Use reflection to get x,y from PVector without direct dependency
      try {
        java.lang.reflect.Field xField = vertices[i].getClass().getField("x");
        java.lang.reflect.Field yField = vertices[i].getClass().getField("y");
        xVerts[i] = xField.getFloat(vertices[i]);
        yVerts[i] = yField.getFloat(vertices[i]);
      } catch (Exception e) {
        parent.println("mapLedPolygon: Invalid vertex object at index " + i);
        return 0;
      }
    }
    
    return mapLedPolygonInternal(startIndex, xVerts, yVerts, config);
  }

  // ---------------------------------------------------------------------------
  // Row Layout Mapping (Fixed LEDs per Row)
  // ---------------------------------------------------------------------------

  /**
   * Fill an arbitrary polygon with LEDs using fixed counts per row.
   *
   * @param startIndex First LED index to use
   * @param vertices   Array of polygon vertices as float[][] where each element is {x, y}
   * @param config     Row layout configuration (counts, direction, etc.)
   * @return           Number of LEDs mapped (next available index = startIndex + return value)
   */
  public int mapLedRowLayout(int startIndex, float[][] vertices, RowLayoutConfig config) {
    if (vertices == null || vertices.length < 3) {
      parent.println("mapLedRowLayout: Need at least 3 vertices");
      return 0;
    }
    if (config == null || config.ledsPerRow == null || config.ledsPerRow.length == 0) {
      parent.println("mapLedRowLayout: ledsPerRow must be provided");
      return 0;
    }

    float[] xVerts = new float[vertices.length];
    float[] yVerts = new float[vertices.length];
    for (int i = 0; i < vertices.length; i++) {
      xVerts[i] = vertices[i][0];
      yVerts[i] = vertices[i][1];
    }

    return mapLedRowLayoutInternal(startIndex, xVerts, yVerts, config);
  }

  /**
   * Fill an arbitrary polygon with LEDs using fixed counts per row.
   * Overload accepting PVector array (Processing-friendly).
   */
  public int mapLedRowLayout(int startIndex, Object[] vertices, RowLayoutConfig config) {
    if (vertices == null || vertices.length < 3) {
      parent.println("mapLedRowLayout: Need at least 3 vertices");
      return 0;
    }
    if (config == null || config.ledsPerRow == null || config.ledsPerRow.length == 0) {
      parent.println("mapLedRowLayout: ledsPerRow must be provided");
      return 0;
    }

    float[] xVerts = new float[vertices.length];
    float[] yVerts = new float[vertices.length];

    for (int i = 0; i < vertices.length; i++) {
      try {
        java.lang.reflect.Field xField = vertices[i].getClass().getField("x");
        java.lang.reflect.Field yField = vertices[i].getClass().getField("y");
        xVerts[i] = xField.getFloat(vertices[i]);
        yVerts[i] = yField.getFloat(vertices[i]);
      } catch (Exception e) {
        parent.println("mapLedRowLayout: Invalid vertex object at index " + i);
        return 0;
      }
    }

    return mapLedRowLayoutInternal(startIndex, xVerts, yVerts, config);
  }

  /**
   * Convenience alias for projects that conceptually refer to this as "setRowLayout".
   */
  public int setRowLayout(int startIndex, float[][] vertices, RowLayoutConfig config) {
    return mapLedRowLayout(startIndex, vertices, config);
  }

  /**
   * Internal row layout implementation with fixed LEDs per row.
   */
  private int mapLedRowLayoutInternal(int startIndex, float[] xVerts, float[] yVerts, RowLayoutConfig config) {
    int numVerts = xVerts.length;
    int rowCount = config.ledsPerRow.length;

    // 1. Find bounding box
    float minX = xVerts[0], maxX = xVerts[0];
    float minY = yVerts[0], maxY = yVerts[0];
    for (int i = 1; i < numVerts; i++) {
      minX = Math.min(minX, xVerts[i]);
      maxX = Math.max(maxX, xVerts[i]);
      minY = Math.min(minY, yVerts[i]);
      maxY = Math.max(maxY, yVerts[i]);
    }

    // 2. Calculate fill center (for rotation)
    float centerX = (minX + maxX) / 2.0f;
    float centerY = (minY + maxY) / 2.0f;

    float angleRad = PApplet.radians(config.angleDeg);

    // If an angle is provided, rotate polygon into row-aligned space.
    float[] xUse = xVerts;
    float[] yUse = yVerts;
    if (Math.abs(angleRad) > 0.0001f) {
      xUse = new float[numVerts];
      yUse = new float[numVerts];
      for (int i = 0; i < numVerts; i++) {
        float[] pt = rotatePointF(xVerts[i], yVerts[i], centerX, centerY, -angleRad);
        xUse[i] = pt[0];
        yUse[i] = pt[1];
      }

      // Recompute bounds in rotated space
      minX = xUse[0];
      maxX = xUse[0];
      minY = yUse[0];
      maxY = yUse[0];
      for (int i = 1; i < numVerts; i++) {
        minX = Math.min(minX, xUse[i]);
        maxX = Math.max(maxX, xUse[i]);
        minY = Math.min(minY, yUse[i]);
        maxY = Math.max(maxY, yUse[i]);
      }
    }

    // Apply margin to bounding box (in the layout space)
    minX += config.margin;
    maxX -= config.margin;
    minY += config.margin;
    maxY -= config.margin;

    ArrayList<int[]> ledPositions = new ArrayList<int[]>();

    if (config.horizontal) {
      float rowStart;
      float rowDir;

      boolean topStart = (config.startCorner == 0 || config.startCorner == 1);
      if (config.rowSpacing > 0) {
        rowStart = topStart ? minY : maxY;
        rowDir = topStart ? config.rowSpacing : -config.rowSpacing;
      } else {
        rowStart = topStart ? minY : maxY;
        rowDir = topStart ? 1.0f : -1.0f; // direction only; spacing handled by interpolation
      }

      for (int rowIndex = 0; rowIndex < rowCount; rowIndex++) {
        float y;
        if (config.rowSpacing > 0) {
          y = rowStart + rowDir * rowIndex;
        } else {
          if (rowCount == 1) {
            y = (minY + maxY) * 0.5f;
          } else {
            float t = rowIndex / (float) (rowCount - 1);
            y = topStart ? (minY + (maxY - minY) * t) : (maxY - (maxY - minY) * t);
          }
        }

        // Get X intersections for this scanline
        ArrayList<Float> intersections = scanlineIntersections(xUse, yUse, y);
        if (intersections.size() < 2)
          continue;
        java.util.Collections.sort(intersections);

        int ledsInRow = config.ledsPerRow[rowIndex];
        if (ledsInRow <= 0)
          continue;

        ArrayList<int[]> rowLeds = distributeAcrossSegments(intersections, ledsInRow, y, true,
            centerX, centerY, angleRad, config.margin);

        // Apply direction based on start corner and serpentine
        boolean reverseRow = false;
        if (config.startCorner == 1 || config.startCorner == 2) {
          reverseRow = true;
        }
        if (config.serpentine && (rowIndex % 2 == 1)) {
          reverseRow = !reverseRow;
        }
        if (reverseRow) {
          java.util.Collections.reverse(rowLeds);
        }

        ledPositions.addAll(rowLeds);
      }
    } else {
      float colStart;
      float colDir;

      boolean leftStart = (config.startCorner == 0 || config.startCorner == 3);
      if (config.rowSpacing > 0) {
        colStart = leftStart ? minX : maxX;
        colDir = leftStart ? config.rowSpacing : -config.rowSpacing;
      } else {
        colStart = leftStart ? minX : maxX;
        colDir = leftStart ? 1.0f : -1.0f; // direction only; spacing handled by interpolation
      }

      for (int colIndex = 0; colIndex < rowCount; colIndex++) {
        float x;
        if (config.rowSpacing > 0) {
          x = colStart + colDir * colIndex;
        } else {
          if (rowCount == 1) {
            x = (minX + maxX) * 0.5f;
          } else {
            float t = colIndex / (float) (rowCount - 1);
            x = leftStart ? (minX + (maxX - minX) * t) : (maxX - (maxX - minX) * t);
          }
        }

        ArrayList<Float> intersections = scanlineIntersectionsVertical(xUse, yUse, x);
        if (intersections.size() < 2)
          continue;
        java.util.Collections.sort(intersections);

        int ledsInCol = config.ledsPerRow[colIndex];
        if (ledsInCol <= 0)
          continue;

        ArrayList<int[]> colLeds = distributeAcrossSegments(intersections, ledsInCol, x, false,
            centerX, centerY, angleRad, config.margin);

        boolean reverseCol = false;
        if (config.startCorner == 2 || config.startCorner == 3) {
          reverseCol = true;
        }
        if (config.serpentine && (colIndex % 2 == 1)) {
          reverseCol = !reverseCol;
        }
        if (reverseCol) {
          java.util.Collections.reverse(colLeds);
        }

        ledPositions.addAll(colLeds);
      }
    }

    int ledCount = 0;
    for (int[] pos : ledPositions) {
      setLed(startIndex + ledCount, pos[0], pos[1]);
      ledCount++;
    }

    if (parent.frameCount < 5) {
      parent.println("mapLedRowLayout: Mapped " + ledCount + " LEDs starting at index " + startIndex);
    }

    return ledCount;
  }

  /**
   * Internal polygon fill implementation using scanline algorithm.
   */
  private int mapLedPolygonInternal(int startIndex, float[] xVerts, float[] yVerts, PolygonFillConfig config) {
    int numVerts = xVerts.length;
    
    // 1. Find bounding box
    float minX = xVerts[0], maxX = xVerts[0];
    float minY = yVerts[0], maxY = yVerts[0];
    for (int i = 1; i < numVerts; i++) {
      minX = Math.min(minX, xVerts[i]);
      maxX = Math.max(maxX, xVerts[i]);
      minY = Math.min(minY, yVerts[i]);
      maxY = Math.max(maxY, yVerts[i]);
    }
    
    // Apply margin to bounding box
    minX += config.margin;
    maxX -= config.margin;
    minY += config.margin;
    maxY -= config.margin;
    
    // 2. Calculate fill center (for rotation)
    float centerX = (minX + maxX) / 2.0f;
    float centerY = (minY + maxY) / 2.0f;
    
    // 3. Generate scanlines based on configuration
    ArrayList<int[]> ledPositions = new ArrayList<int[]>();
    
    if (config.horizontal) {
      // Horizontal scanlines (rows)
      float rowStart, rowEnd, rowDir;
      
      // Determine row direction based on start corner
      if (config.startCorner == 0 || config.startCorner == 1) {
        // Top-Left or Top-Right: start from top
        rowStart = minY;
        rowEnd = maxY;
        rowDir = config.rowSpacing;
      } else {
        // Bottom-Left or Bottom-Right: start from bottom
        rowStart = maxY;
        rowEnd = minY;
        rowDir = -config.rowSpacing;
      }
      
      int rowIndex = 0;
      for (float y = rowStart; (rowDir > 0 ? y <= rowEnd : y >= rowEnd); y += rowDir) {
        // Get X intersections for this scanline
        ArrayList<Float> intersections = scanlineIntersections(xVerts, yVerts, y);
        
        if (intersections.size() >= 2) {
          // Sort intersections
          java.util.Collections.sort(intersections);
          
          // Process pairs of intersections (entry/exit points)
          for (int i = 0; i < intersections.size() - 1; i += 2) {
            float xStart = intersections.get(i) + config.margin;
            float xEnd = intersections.get(i + 1) - config.margin;
            
            // Generate LED positions along this segment
            ArrayList<int[]> rowLeds = new ArrayList<int[]>();
            if (config.ledsPerRow > 0) {
              int count = config.ledsPerRow;
              if (count == 1) {
                float x = (xStart + xEnd) * 0.5f;
                int[] pos = applyRotation(x, y, centerX, centerY, config.angle);
                rowLeds.add(pos);
              } else {
                float step = (xEnd - xStart) / (count - 1);
                for (int k = 0; k < count; k++) {
                  float x = xStart + step * k;
                  int[] pos = applyRotation(x, y, centerX, centerY, config.angle);
                  rowLeds.add(pos);
                }
              }
            } else {
              for (float x = xStart; x <= xEnd; x += config.ledSpacing) {
                // Apply rotation around center if needed
                int[] pos = applyRotation(x, y, centerX, centerY, config.angle);
                rowLeds.add(pos);
              }
            }
            
            // Apply direction based on start corner and serpentine
            boolean reverseRow = false;
            if (config.startCorner == 1 || config.startCorner == 2) {
              // Right-side start: first row goes right-to-left
              reverseRow = true;
            }
            if (config.serpentine && (rowIndex % 2 == 1)) {
              reverseRow = !reverseRow;
            }
            
            if (reverseRow) {
              java.util.Collections.reverse(rowLeds);
            }
            
            ledPositions.addAll(rowLeds);
          }
        }
        rowIndex++;
      }
      
    } else {
      // Vertical scanlines (columns)
      float colStart, colEnd, colDir;
      
      // Determine column direction based on start corner
      if (config.startCorner == 0 || config.startCorner == 3) {
        // Left side: start from left
        colStart = minX;
        colEnd = maxX;
        colDir = config.rowSpacing; // rowSpacing used for column spacing
      } else {
        // Right side: start from right
        colStart = maxX;
        colEnd = minX;
        colDir = -config.rowSpacing;
      }
      
      int colIndex = 0;
      for (float x = colStart; (colDir > 0 ? x <= colEnd : x >= colEnd); x += colDir) {
        // Get Y intersections for this vertical scanline
        ArrayList<Float> intersections = scanlineIntersectionsVertical(xVerts, yVerts, x);
        
        if (intersections.size() >= 2) {
          java.util.Collections.sort(intersections);
          
          for (int i = 0; i < intersections.size() - 1; i += 2) {
            float yStart = intersections.get(i) + config.margin;
            float yEnd = intersections.get(i + 1) - config.margin;
            
            ArrayList<int[]> colLeds = new ArrayList<int[]>();
            if (config.ledsPerRow > 0) {
              int count = config.ledsPerRow;
              if (count == 1) {
                float y = (yStart + yEnd) * 0.5f;
                int[] pos = applyRotation(x, y, centerX, centerY, config.angle);
                colLeds.add(pos);
              } else {
                float step = (yEnd - yStart) / (count - 1);
                for (int k = 0; k < count; k++) {
                  float y = yStart + step * k;
                  int[] pos = applyRotation(x, y, centerX, centerY, config.angle);
                  colLeds.add(pos);
                }
              }
            } else {
              for (float y = yStart; y <= yEnd; y += config.ledSpacing) {
                int[] pos = applyRotation(x, y, centerX, centerY, config.angle);
                colLeds.add(pos);
              }
            }
            
            // Apply direction based on start corner and serpentine
            boolean reverseCol = false;
            if (config.startCorner == 2 || config.startCorner == 3) {
              // Bottom start: first column goes bottom-to-top
              reverseCol = true;
            }
            if (config.serpentine && (colIndex % 2 == 1)) {
              reverseCol = !reverseCol;
            }
            
            if (reverseCol) {
              java.util.Collections.reverse(colLeds);
            }
            
            ledPositions.addAll(colLeds);
          }
        }
        colIndex++;
      }
    }
    
    // 4. Map all LED positions
    int ledCount = 0;
    for (int[] pos : ledPositions) {
      setLed(startIndex + ledCount, pos[0], pos[1]);
      ledCount++;
    }
    
    if (parent.frameCount < 5) {
      parent.println("mapLedPolygon: Mapped " + ledCount + " LEDs starting at index " + startIndex);
    }
    
    return ledCount;
  }

  /**
   * Find X intersections of a horizontal scanline with polygon edges.
   */
  private ArrayList<Float> scanlineIntersections(float[] xVerts, float[] yVerts, float scanY) {
    ArrayList<Float> intersections = new ArrayList<Float>();
    int numVerts = xVerts.length;
    
    for (int i = 0; i < numVerts; i++) {
      int j = (i + 1) % numVerts;
      float y1 = yVerts[i];
      float y2 = yVerts[j];
      
      // Check if scanline crosses this edge
      if ((y1 <= scanY && y2 > scanY) || (y2 <= scanY && y1 > scanY)) {
        // Calculate X intersection
        float x1 = xVerts[i];
        float x2 = xVerts[j];
        float t = (scanY - y1) / (y2 - y1);
        float xIntersect = x1 + t * (x2 - x1);
        intersections.add(xIntersect);
      }
    }
    
    return intersections;
  }

  /**
   * Find Y intersections of a vertical scanline with polygon edges.
   */
  private ArrayList<Float> scanlineIntersectionsVertical(float[] xVerts, float[] yVerts, float scanX) {
    ArrayList<Float> intersections = new ArrayList<Float>();
    int numVerts = xVerts.length;
    
    for (int i = 0; i < numVerts; i++) {
      int j = (i + 1) % numVerts;
      float x1 = xVerts[i];
      float x2 = xVerts[j];
      
      // Check if scanline crosses this edge
      if ((x1 <= scanX && x2 > scanX) || (x2 <= scanX && x1 > scanX)) {
        float y1 = yVerts[i];
        float y2 = yVerts[j];
        float t = (scanX - x1) / (x2 - x1);
        float yIntersect = y1 + t * (y2 - y1);
        intersections.add(yIntersect);
      }
    }
    
    return intersections;
  }

  /**
   * Distribute a fixed number of LEDs across multiple scanline segments.
   * The intersections list must be sorted (entry/exit pairs).
   */
  private ArrayList<int[]> distributeAcrossSegments(ArrayList<Float> intersections, int count,
      float fixedCoord, boolean horizontal, float centerX, float centerY, float angleRad, float margin) {
    ArrayList<int[]> result = new ArrayList<int[]>();

    if (count <= 0 || intersections.size() < 2) {
      return result;
    }

    // Build segment list (start/end), applying margin.
    ArrayList<float[]> segments = new ArrayList<float[]>();
    float totalLen = 0.0f;
    for (int i = 0; i < intersections.size() - 1; i += 2) {
      float start = intersections.get(i) + margin;
      float end = intersections.get(i + 1) - margin;
      if (end <= start)
        continue;
      segments.add(new float[] { start, end });
      totalLen += (end - start);
    }

    if (segments.isEmpty() || totalLen <= 0.0f) {
      return result;
    }

    for (int k = 0; k < count; k++) {
      float t = (count == 1) ? 0.5f : (k / (float) (count - 1));
      float dist = t * totalLen;

      float pos = segments.get(segments.size() - 1)[1];
      float remaining = dist;
      for (int i = 0; i < segments.size(); i++) {
        float segStart = segments.get(i)[0];
        float segEnd = segments.get(i)[1];
        float segLen = segEnd - segStart;
        if (remaining <= segLen) {
          pos = segStart + remaining;
          break;
        }
        remaining -= segLen;
      }

      float x = horizontal ? pos : fixedCoord;
      float y = horizontal ? fixedCoord : pos;
      int[] pt = applyRotation(x, y, centerX, centerY, angleRad);
      result.add(pt);
    }

    return result;
  }

  /**
   * Apply rotation transform to a point around a center.
   */
  private int[] applyRotation(float x, float y, float cx, float cy, float angle) {
    if (Math.abs(angle) < 0.001f) {
      return new int[] { Math.round(x), Math.round(y) };
    }
    
    float cos = (float) Math.cos(angle);
    float sin = (float) Math.sin(angle);
    float dx = x - cx;
    float dy = y - cy;
    
    float rx = cx + dx * cos - dy * sin;
    float ry = cy + dx * sin + dy * cos;
    
    return new int[] { Math.round(rx), Math.round(ry) };
  }

  /**
   * Rotate a point around a center (float precision, no rounding).
   */
  private float[] rotatePointF(float x, float y, float cx, float cy, float angle) {
    if (Math.abs(angle) < 0.001f) {
      return new float[] { x, y };
    }

    float cos = (float) Math.cos(angle);
    float sin = (float) Math.sin(angle);
    float dx = x - cx;
    float dy = y - cy;

    float rx = cx + dx * cos - dy * sin;
    float ry = cy + dx * sin + dy * cos;

    return new float[] { rx, ry };
  }

  /**
   * Check if a point is inside a polygon (for validation/debugging).
   */
  public boolean pointInPolygon(float px, float py, float[] xVerts, float[] yVerts) {
    boolean inside = false;
    int numVerts = xVerts.length;
    
    for (int i = 0, j = numVerts - 1; i < numVerts; j = i++) {
      if (((yVerts[i] > py) != (yVerts[j] > py)) &&
          (px < (xVerts[j] - xVerts[i]) * (py - yVerts[i]) / (yVerts[j] - yVerts[i]) + xVerts[i])) {
        inside = !inside;
      }
    }
    
    return inside;
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
      if (loc >= 0) {
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

    int dmxIndex = startAt;
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

    int idx = startAt;
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

  /**
   * Return the LED's mapped position in canvas coordinates.
   * Returns null if the index is out of range or unmapped.
   */
  public PVector getLedPosition(int index) {
    if (pixelLocations == null || index < 0 || index >= pixelLocations.length)
      return null;
    int loc = pixelLocations[index];
    if (loc < 0)
      return null;
    int w = getCanvasWidth();
    int x = loc % w;
    int y = loc / w;
    return new PVector(x, y);
  }

  /**
   * Return an array of LED positions in canvas coordinates.
   * Unmapped LEDs are returned as null entries.
   */
  public PVector[] getLedPositions() {
    if (pixelLocations == null)
      return new PVector[0];
    PVector[] positions = new PVector[pixelLocations.length];
    int w = getCanvasWidth();
    for (int i = 0; i < pixelLocations.length; i++) {
      int loc = pixelLocations[i];
      if (loc >= 0) {
        int x = loc % w;
        int y = loc / w;
        positions[i] = new PVector(x, y);
      } else {
        positions[i] = null;
      }
    }
    return positions;
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
  public interface DMXControl {
    void sendValue(int channelIndex, int value);
  }
  
} // End of Canvas2DMX class
