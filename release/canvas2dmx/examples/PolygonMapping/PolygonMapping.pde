/**
 * PolygonMapping.pde
 * 
 * Demonstrates the mapLedPolygon() function for filling arbitrary shapes
 * with LEDs. Shows different orientation options (start corner, serpentine,
 * horizontal vs vertical fill).
 * 
 * Controls:
 *   1-4  : Change start corner (1=TL, 2=TR, 3=BR, 4=BL)
 *   S    : Toggle serpentine (zigzag) mode
 *   H    : Toggle horizontal/vertical fill
 *   +/-  : Adjust LED spacing
 *   [/]  : Adjust row spacing
 *   SPACE: Cycle through shape presets
 */

import com.studiojordanshaw.canvas2dmx.*;
import com.jaysonh.dmx4artists.*;

Canvas2DMX c2d;
DMXControl dmxController;

// Current polygon vertices
PVector[] currentShape;
String shapeName = "Triangle";

// Fill configuration
int startCorner = 0;      // 0=TL, 1=TR, 2=BR, 3=BL
boolean serpentine = true;
boolean horizontal = true;
float ledSpacing = 20;
float rowSpacing = 22;
float margin = 5;

// Shape presets
int shapeIndex = 0;

// LED count from last mapping
int mappedLedCount = 0;

void settings() {
  size(600, 500);
  pixelDensity(1);
}

void setup() {
  c2d = new Canvas2DMX(this);
  
  // Set up color correction
  c2d.setResponse(1.2);
  c2d.setTemperature(0.1);
  
  // Initialize with first shape
  cycleShape();
  remapPolygon();
  
  // Initialize DMX (optional)
  try {
    dmxController = new DMXControl(0, 512);
    println("DMX controller initialized");
  } catch (Exception e) {
    println("DMX init failed (running without hardware): " + e.getMessage());
    dmxController = null;
  }
  
  println("\n=== Polygon Mapping Demo ===");
  printControls();
}

void draw() {
  // Animated gradient background
  background(20);
  noStroke();
  for (int y = 0; y < height; y++) {
    float hue = (y * 0.5 + frameCount * 0.5) % 255;
    fill(hue, 180, 200);
    rect(0, y, width, 1);
  }
  
  // Draw the polygon outline
  drawPolygonOutline();
  
  // Sample colors and visualize LEDs
  int[] colors = c2d.getLedColors();
  c2d.visualize(colors);
  c2d.showLedLocations();
  
  // Draw info panel
  drawInfoPanel();
  
  // Send to DMX if available
  if (dmxController != null) {
    c2d.sendToDmx((ch, val) -> dmxController.sendValue(ch, val));
  }
}

// ============================================================================
// POLYGON MAPPING
// ============================================================================

void remapPolygon() {
  // Clear existing LED mappings to avoid stale markers
  c2d.clearLeds();
  
  // Create fill configuration
  Canvas2DMX.PolygonFillConfig config = new Canvas2DMX.PolygonFillConfig(ledSpacing, rowSpacing)
    .startAt(startCorner)
    .serpentine(serpentine)
    .horizontal(horizontal)
    .margin(margin);
  
  // Map the polygon - returns number of LEDs mapped
  mappedLedCount = c2d.mapLedPolygon(0, currentShape, config);
  
  println("Remapped: " + mappedLedCount + " LEDs");
}

// ============================================================================
// SHAPE PRESETS
// ============================================================================

void cycleShape() {
  shapeIndex = (shapeIndex + 1) % 5;
  
  float cx = width / 2;
  float cy = height / 2;
  
  switch (shapeIndex) {
    case 0: // Triangle
      shapeName = "Triangle";
      currentShape = new PVector[] {
        new PVector(cx, cy - 120),      // top
        new PVector(cx - 140, cy + 100), // bottom-left
        new PVector(cx + 140, cy + 100)  // bottom-right
      };
      break;
      
    case 1: // Rectangle
      shapeName = "Rectangle";
      currentShape = new PVector[] {
        new PVector(cx - 150, cy - 80),
        new PVector(cx + 150, cy - 80),
        new PVector(cx + 150, cy + 80),
        new PVector(cx - 150, cy + 80)
      };
      break;
      
    case 2: // Pentagon
      shapeName = "Pentagon";
      currentShape = createRegularPolygon(cx, cy, 120, 5, -HALF_PI);
      break;
      
    case 3: // Hexagon
      shapeName = "Hexagon";
      currentShape = createRegularPolygon(cx, cy, 110, 6, 0);
      break;
      
    case 4: // Diamond/Rhombus
      shapeName = "Diamond";
      currentShape = new PVector[] {
        new PVector(cx, cy - 140),       // top
        new PVector(cx + 100, cy),       // right
        new PVector(cx, cy + 140),       // bottom
        new PVector(cx - 100, cy)        // left
      };
      break;
  }
}

PVector[] createRegularPolygon(float cx, float cy, float radius, int sides, float startAngle) {
  PVector[] verts = new PVector[sides];
  for (int i = 0; i < sides; i++) {
    float angle = startAngle + TWO_PI * i / sides;
    verts[i] = new PVector(
      cx + cos(angle) * radius,
      cy + sin(angle) * radius
    );
  }
  return verts;
}

// ============================================================================
// DRAWING HELPERS
// ============================================================================

void drawPolygonOutline() {
  stroke(255, 100);
  strokeWeight(2);
  noFill();
  
  beginShape();
  for (PVector v : currentShape) {
    vertex(v.x, v.y);
  }
  endShape(CLOSE);
  
  // Draw vertices
  fill(255);
  noStroke();
  for (int i = 0; i < currentShape.length; i++) {
    PVector v = currentShape[i];
    ellipse(v.x, v.y, 8, 8);
    
    // Label first vertex
    if (i == 0) {
      textSize(10);
      text("v0", v.x + 10, v.y);
    }
  }
}

void drawInfoPanel() {
  // Semi-transparent panel
  fill(0, 180);
  noStroke();
  rect(10, 10, 200, 190, 8);
  
  fill(255);
  textSize(14);
  textAlign(LEFT, TOP);
  
  int y = 20;
  int lineHeight = 18;
  
  text("Shape: " + shapeName, 20, y); y += lineHeight;
  text("LEDs: " + mappedLedCount, 20, y); y += lineHeight;
  y += 5;
  
  text("Start Corner: " + cornerName(startCorner), 20, y); y += lineHeight;
  text("Serpentine: " + (serpentine ? "ON" : "OFF"), 20, y); y += lineHeight;
  text("Fill: " + (horizontal ? "Horizontal" : "Vertical"), 20, y); y += lineHeight;
  text("LED Spacing: " + nf(ledSpacing, 0, 1), 20, y); y += lineHeight;
  text("Row Spacing: " + nf(rowSpacing, 0, 1), 20, y); y += lineHeight;
  
  // Draw start corner indicator
  drawCornerIndicator(160, 140, startCorner);
}

String cornerName(int corner) {
  switch (corner) {
    case 0: return "Top-Left";
    case 1: return "Top-Right";
    case 2: return "Bottom-Right";
    case 3: return "Bottom-Left";
    default: return "?";
  }
}

void drawCornerIndicator(float x, float y, int corner) {
  float size = 30;
  
  // Draw box
  stroke(100);
  strokeWeight(1);
  noFill();
  rect(x - size/2, y - size/2, size, size);
  
  // Draw corner indicator
  fill(0, 255, 100);
  noStroke();
  float cx = x - size/2;
  float cy = y - size/2;
  
  switch (corner) {
    case 0: ellipse(cx, cy, 10, 10); break;           // TL
    case 1: ellipse(cx + size, cy, 10, 10); break;    // TR
    case 2: ellipse(cx + size, cy + size, 10, 10); break; // BR
    case 3: ellipse(cx, cy + size, 10, 10); break;    // BL
  }
  
  // Draw direction arrow
  stroke(0, 255, 100);
  strokeWeight(2);
  if (horizontal) {
    float arrowY = y;
    float arrowX1 = (corner == 0 || corner == 3) ? x - 10 : x + 10;
    float arrowX2 = (corner == 0 || corner == 3) ? x + 10 : x - 10;
    line(arrowX1, arrowY, arrowX2, arrowY);
  } else {
    float arrowX = x;
    float arrowY1 = (corner == 0 || corner == 1) ? y - 10 : y + 10;
    float arrowY2 = (corner == 0 || corner == 1) ? y + 10 : y - 10;
    line(arrowX, arrowY1, arrowX, arrowY2);
  }
}

// ============================================================================
// INPUT HANDLING
// ============================================================================

void keyPressed() {
  boolean needsRemap = false;
  
  switch (key) {
    case '1': startCorner = 0; needsRemap = true; break;
    case '2': startCorner = 1; needsRemap = true; break;
    case '3': startCorner = 2; needsRemap = true; break;
    case '4': startCorner = 3; needsRemap = true; break;
    
    case 's':
    case 'S':
      serpentine = !serpentine;
      needsRemap = true;
      break;
      
    case 'h':
    case 'H':
      horizontal = !horizontal;
      needsRemap = true;
      break;
      
    case '+':
    case '=':
      ledSpacing = min(50, ledSpacing + 2);
      needsRemap = true;
      break;
      
    case '-':
    case '_':
      ledSpacing = max(5, ledSpacing - 2);
      needsRemap = true;
      break;
      
    case ']':
      rowSpacing = min(50, rowSpacing + 2);
      needsRemap = true;
      break;
      
    case '[':
      rowSpacing = max(5, rowSpacing - 2);
      needsRemap = true;
      break;
      
    case ' ':
      cycleShape();
      needsRemap = true;
      break;
  }
  
  if (needsRemap) {
    remapPolygon();
  }
}

void printControls() {
  println("Controls:");
  println("  1-4   : Set start corner (1=TL, 2=TR, 3=BR, 4=BL)");
  println("  S     : Toggle serpentine mode");
  println("  H     : Toggle horizontal/vertical fill");
  println("  +/-   : Adjust LED spacing");
  println("  [/]   : Adjust row spacing");
  println("  SPACE : Cycle through shapes");
  println("");
}
