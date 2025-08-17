# Canvas2DMX

**Canvas2DMX** is a Processing library that maps pixels from your sketch to DMX fixtures in real time.  
Define LED mappings (strips, grids, rings, corners), apply color correction, and send output to any DMX backend using a simple callback.

![Canvas2DMX demo image](_img/canvas2DMX_screenshot.jpg)

> Inspired by [FadeCandy](https://github.com/scanlime/fadecandy) and [Open Pixel Control](https://github.com/scanlime/fadecandy/tree/master/examples/Processing) by Micah Elizabeth Scott.

---

## ✨ Features

- Real-time color sampling from the Processing canvas  
- Flexible LED mapping: strips, rings, grids, single points, square corners  
- Custom DMX channel patterns (e.g. `"rgb"`, `"drgb"`, `"drgbsc"`)  
- Default channel values for dimmer, strobe, color wheel, etc.  
- Gamma / temperature correction and custom response curves  
- Built-in visualization: color swatches + LED location markers  
- DMX-agnostic API: works with DMX4Artists, ENTTEC, SP201E, or your own sender  
- Examples included: **Basics**, **StripMapping**, **InteractiveDemo**  

---

## 🚀 Quick Start Example

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
  c2d.setStartAt(1);

  try {
    dmx = new DMXControl(0, 512);
  } catch (Exception e) {
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
````

---

## 🎥 Demo Video

<iframe width="560" height="315" 
  src="https://www.youtube.com/embed/-gsM0a_rsXs?si=uhUCL9uekq10hPyp" 
  title="Canvas2DMX demo video" 
  frameborder="0" 
  allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" 
  referrerpolicy="strict-origin-when-cross-origin" 
  allowfullscreen>
</iframe>

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