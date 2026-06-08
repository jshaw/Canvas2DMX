/**
 * HardwareOLA
 *
 * For any DMX dongle using OLA (Open Lighting Architecture) as middleware.
 * OLA handles the raw DMX output; Processing sends Art-Net UDP to localhost.
 *
 * Works with: FT232RL dongles, ENTTEC Open DMX USB, ENTTEC USB Pro, and most others.
 * OLA is the lowest-friction path on macOS for cheap/clone dongles.
 *
 * Setup:
 *   1. brew install ola
 *   2. olad -l 3   (start OLA daemon)
 *   3. Open http://localhost:9090 in a browser
 *   4. Add a Universe (ID 0), patch your dongle output to it
 *   5. Run this sketch — Art-Net flows from Processing → OLA → your dongle → fixture
 *
 * No extra Processing libraries required; uses standard Java UDP sockets.
 */

import com.studiojordanshaw.canvas2dmx.*;
import java.net.*;

// ── Configure these for your setup ──────────────────────────────────────────
int    ART_NET_UNIVERSE    = 1;       // must match the universe ID you created in OLA (http://localhost:9090)

// DMX_CHANNEL_PATTERN — must match your fixture's channel map (check its manual).
//   Each letter is one DMX channel in order:
//     d = dimmer (master brightness)   r = red    g = green   b = blue
//     w = white                        s = strobe  c = color change macro
//
//   SP201E / raw WS2812/WS2815 strips: use "grb" or "rgb" (3 ch per LED, NO dimmer).
//   The SP201E maps DMX channels directly to LED colour data 3 at a time — adding a
//   dimmer or strobe channel will shift the colour data and leave LEDs black or wrong.
//
//   Traditional DMX fixture with dimmer: "drgb", "drgbsc", etc.
//   Common patterns: "rgb"  "grb"  "drgb"  "drgbsc"  "rgbw"
String DMX_CHANNEL_PATTERN = "drgbsc";  // ← change to match your fixture

// Response / gamma correction — tune this for your LED type:
//   WS2812 / WS2815 via SP201E : ~2.2–2.6  (linear LEDs need gamma to avoid washed-out look)
//   Traditional DMX fixture    : 1.0–1.3    (fixture has its own curve; less correction needed)
// WS2812 / WS2815 via SP201E : 2.2–2.6  (linear LEDs need gamma to avoid washed-out look)
// Traditional DMX fixture    : 1.0–1.3
float  DMX_RESPONSE        = 2.6;

static final int ART_NET_PORT = 6454;
// ────────────────────────────────────────────────────────────────────────────

Canvas2DMX c2d;
DatagramSocket artNetSocket;
InetAddress olaHost;

void settings() {
  size(360, 260);
  pixelDensity(1);
}

void setup() {
  try {
    artNetSocket = new DatagramSocket();
    olaHost = InetAddress.getByName("127.0.0.1");
    println("Art-Net socket ready → OLA at 127.0.0.1:" + ART_NET_PORT);
  } catch (Exception e) {
    println("Could not open Art-Net socket: " + e.getMessage());
    artNetSocket = null;
  }

  c2d = new Canvas2DMX(this);
  c2d.setChannelPattern(DMX_CHANNEL_PATTERN);
  c2d.setDefaultValue('d', 255);
  c2d.setStartAt(1);
  c2d.setResponse(DMX_RESPONSE);

  // Map 8 LEDs in a ring so the visualize strip at the bottom shows
  // multiple live colour swatches — makes channel updates easy to spot
  // in the OLA dashboard (http://localhost:9090) as the orb orbits.
  c2d.mapLedRing(0, 8, width / 2f, height / 2f - 10, 70, 0);

  // Boot sequence: clear any LEDs left on from a previous sketch, then
  // flash white so you can confirm the strip is alive before the loop starts.
  if (artNetSocket != null) bootSequence();
}

void draw() {
  background(14, 18, 28);

  float orbitX = width / 2f + cos(frameCount * 0.04f) * 70f;
  float orbitY = height / 2f - 10 + sin(frameCount * 0.06f) * 40f;

  // Background stays visible between orb passes — dark navy but not black,
  // so LEDs always have some colour to sample rather than going fully dark.
  noStroke();
  fill(20, 60, 140);
  rect(0, 0, width, height);

  // Large orb so it sweeps across more of the LED ring positions at once
  fill(255, 180, 40);
  ellipse(orbitX, orbitY, 140, 140);

  int[] colors = c2d.getLedColors();
  c2d.visualize(colors);
  c2d.showLedLocations();
  drawHud(colors);

  if (artNetSocket != null) {
    int[] frame = c2d.buildDmxFrame(512);
    sendArtNet(frame, ART_NET_UNIVERSE);
  } else if (frameCount % 30 == 0) {
    c2d.sendToDmx((ch, val) -> { if (ch <= 4) println("ch " + ch + " = " + val); });
  }
}

void sendArtNet(int[] dmxValues, int universe) {
  // Art-Net ArtDmx packet — https://art-net.org.uk/resources/art-net-specification/
  byte[] packet = new byte[18 + dmxValues.length];

  // ID: "Art-Net\0"
  packet[0]='A'; packet[1]='r'; packet[2]='t'; packet[3]='-';
  packet[4]='N'; packet[5]='e'; packet[6]='t'; packet[7]=0;

  // OpCode: ArtDmx = 0x5000 (little-endian)
  packet[8] = 0x00; packet[9] = 0x50;

  // Protocol version 14 (big-endian)
  packet[10] = 0; packet[11] = 14;

  // Sequence (0 = disabled), Physical (0)
  packet[12] = 0; packet[13] = 0;

  // Universe (little-endian 15-bit)
  packet[14] = (byte)(universe & 0xFF);
  packet[15] = (byte)((universe >> 8) & 0x7F);

  // Length (big-endian)
  packet[16] = (byte)(dmxValues.length >> 8);
  packet[17] = (byte)(dmxValues.length & 0xFF);

  // DMX channel data
  for (int i = 0; i < dmxValues.length; i++) {
    packet[18 + i] = (byte)(dmxValues[i] & 0xFF);
  }

  try {
    artNetSocket.send(new DatagramPacket(packet, packet.length, olaHost, ART_NET_PORT));
  } catch (Exception e) {
    println("Art-Net send error: " + e.getMessage());
  }
}

// Clears any LEDs left on from a previous sketch, flashes white to confirm
// the strip is alive, then blacks out ready for the draw loop.
// SP201E holds its last state when a sketch stops — this resets it cleanly.
void bootSequence() {
  int[] frame = new int[512];

  // 1. Black — clear residual state from previous sketch
  sendArtNet(frame, ART_NET_UNIVERSE);
  delay(100);

  // 2. White flash at brightness 170 across all 170 LEDs (170 × 3ch = 510)
  for (int i = 0; i < 510; i++) frame[i] = 170;
  sendArtNet(frame, ART_NET_UNIVERSE);
  delay(300);

  // 3. Black again — ready for draw loop
  java.util.Arrays.fill(frame, 0);
  sendArtNet(frame, ART_NET_UNIVERSE);
  delay(100);

  println("Boot sequence complete — strip cleared and confirmed.");
}

void dispose() {
  if (artNetSocket != null) artNetSocket.close();
}

void drawHud(int[] colors) {
  fill(255);
  textSize(12);
  textAlign(LEFT, TOP);
  String status = (artNetSocket != null) ? "Art-Net → OLA" : "Socket error";
  text("HardwareOLA: " + status, 12, 10);
  text("Pattern: " + DMX_CHANNEL_PATTERN + "  |  universe: " + ART_NET_UNIVERSE, 12, 28);

  // Show the first few LED values so you can watch channels change in real time
  int show = min(colors.length, 4);
  for (int i = 0; i < show; i++) {
    int s = colors[i];
    text(
      "LED " + i + "  R=" + int(red(s)) + "  G=" + int(green(s)) + "  B=" + int(blue(s)),
      12, height - 48 - (show - 1 - i) * 14
    );
  }
}
