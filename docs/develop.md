## DMX Backend Integration (Adapter/Proxy Design)

Canvas2DMX is **backend-agnostic**. It doesn’t depend on any specific DMX library (ENTTEC, DMX4Artists, Art-Net, sACN, OLA, etc.).  
Instead, it exposes a tiny callback so you can adapt any sender with one line.

### Minimal contract

```java
@FunctionalInterface
public interface DmxSender {
  void send(int channel, int value);
}
```

Canvas2DMX emits channel/value pairs using your current mapping + channel pattern:

```java
c2d.sendToDmx((ch, val) -> {
  // bridge to your backend here
  dmxController.sendValue(ch, val);
});
```

* **Why this approach?**

  * **No hard dependency** on a specific DMX stack
  * **Plug-and-play** with any backend (USB DMX, Art-Net, sACN)
  * **Testable**: swap in a mock sender for unit/integration tests

---

### Two integration modes

1. **Streaming (per channel/value)** — lowest friction, works with libraries like DMX4Artists:

```java
c2d.sendToDmx((ch, val) -> dmx.sendValue(ch, val));
```

2. **Batch frame** — if your backend prefers a full universe write:

```java
int[] frame = c2d.buildDmxFrame(512);     // 1-based DMX mapped into 0-based array
artnet.writeUniverse(0, frame);           // hypothetical bulk API
```

---

### Examples

**DMX4Artists (ENTTEC / serial)**

```java
import com.jaysonh.dmx4artists.*;

DMXControl dmx = new DMXControl(0, 512);
c2d.sendToDmx((ch, val) -> dmx.sendValue(ch, val));
```

**Mock sender (testing / no hardware)**

```java
c2d.sendToDmx((ch, val) -> {
  if (ch <= 16 && frameCount % 30 == 0) println("ch " + ch + " = " + val);
});
```

**Art-Net / sACN style (batch)**

```java
int[] frame = c2d.buildDmxFrame(512);
// e.g., convert to byte[] and send in one call (pseudo-code)
// byte[] bytes = new byte[frame.length];
// for (int i = 0; i < frame.length; i++) bytes[i] = (byte) (frame[i] & 0xFF);
// artnet.writeUniverse(0, bytes);
```

---

### Design note: why not `BiConsumer<Integer,Integer>`?

We considered an overload that accepted `BiConsumer<Integer,Integer>`.
However, having both `sendToDmx(DmxSender)` and `sendToDmx(BiConsumer<…>)` made lambdas **ambiguous** for the Java compiler.
To keep the API simple and reliable, we **kept only** the `DmxSender` version.
You still get one-line lambda calls, and the library stays backend-agnostic.

---

## 📚 Learn More

* **[Canvas2DMX](https://github.com/jshaw/Canvas2DMX)** — repo link
* [Getting Started](getting-started.md) — installation and first sketch
* [Troubleshooting](troubleshooting.md) — common issues and fixes
* [Develop](develop.md) — contributing and building from source
* [Release](release.md) — packaging and Contribution Manager