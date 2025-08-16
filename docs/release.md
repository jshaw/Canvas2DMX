# Release

How to cut a **Canvas2DMX** release, package it for Processing, publish it, and update the docs.

---

## 1) Bump versions

- `build.gradle.kts`
  ```kotlin
  version = "0.0.2"
   ```

* `library.properties`

  ```properties
  version=0.0.2
  prettyVersion=0.0.2
  ```

(Optionally refresh `sentence`, `paragraph`, and `url` in `library.properties`.)

---

## 2) Build & package

From repo root:

```bash
./gradlew clean buildReleaseArtifacts packageRelease
```

Quick local install for testing:

```bash
./gradlew deployToProcessingSketchbook
```

---

## 3) Smoke test

1. Restart Processing.
2. Run **Basics**, **StripMapping**, **InteractiveDemo** from
   *File → Examples → Contributed Libraries → Canvas2DMX*.
3. With hardware: confirm DMX output. Without hardware: confirm console preview.

---

## 4) Publish on GitHub

```bash
git tag v0.0.2
git push origin v0.0.2
```

* Create a **GitHub Release** for `v0.0.2`.
* Attach the built **zip** (the one that contains `library/`, `examples/`, `library.properties`).

---

## 5) Optional: Processing Contribution Manager

Ensure `library.properties` is complete (e.g., `name=canvas2dmx`, `categories=Hardware,I/O`, `authors=...`, `url=...`).
Follow the Processing submission steps to have the zip listed in the Contribution Manager.

---

## 6) Update the docs (GitHub Pages)

Your site is served from `/docs`.

* **Edit docs** under `docs/` (Markdown + images in `docs/img/`).
* **Commit & push** to `main` — Pages updates automatically.

First-time only (repo → *Settings → Pages*): set **Source** = `Deploy from a branch`, **Branch** = `main`, **Folder** = `/docs`.

**Embedding media**

* Image: `![Canvas2DMX demo](img/hero.png)`
* YouTube:

  ```html
  <iframe width="560" height="315"
    src="https://www.youtube.com/embed/VIDEO_ID"
    title="Canvas2DMX demo" frameborder="0" allowfullscreen></iframe>
  ```

---

## 7) Post-release checklist

* [ ] README updated (version, links)
* [ ] Docs updated (if API changed)
* [ ] Examples launch cleanly in Processing
* [ ] GitHub Release has the zip attached
* [ ] Submitted to Contribution Manager

---

## 📚 Learn More

* **[Canvas2DMX](https://github.com/jshaw/Canvas2DMX)** — repo link
* [Getting Started](getting-started.md) — installation and first sketch
* [Troubleshooting](troubleshooting.md) — common issues and fixes
* [Develop](develop.md) — contributing and building from source
* [Release](release.md) — packaging and Contribution Manager