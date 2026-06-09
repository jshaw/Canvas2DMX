# Release

How to cut a **Canvas2DMX** release, package it for Processing, publish it, and update the docs.

---

## 1) Bump versions

- `release.properties`
  ```properties
  version=1
  prettyVersion = 0.0.1
  ```

- Re-generate `library.properties` during the release build.

Notes:
- `version` is the Processing Library Manager update counter and must be an integer.
- `prettyVersion` is the human-readable release version.
- Refresh `sentence`, `paragraph`, and `url` in `release.properties` when needed.

---

## 2) Build & package

From repo root:

```bash
./gradlew clean buildReleaseArtifacts packageRelease
```

This produces:

- `release/canvas2dmx.zip` — the library package Processing expects
- `release/canvas2dmx.txt` — a hosted copy of `library.properties` for Processing's aggregator
- `release/canvas2dmx.pdex` — optional duplicate artifact

To stage the hosted Processing submission files into GitHub Pages:

```bash
./gradlew stageContributionArtifactsToDocs
```

That copies the latest `canvas2dmx.zip` and `canvas2dmx.txt` into `docs/download/`.

Quick local install for testing:

```bash
./gradlew deployToProcessingSketchbook
```

---

## 3) Smoke test

1. Restart Processing.
2. Run **Basics**, **StripMapping**, **OffscreenBuffer**, **PolygonMapping**, and **InteractiveDemo** from
   *File → Examples → Contributed Libraries → Canvas2DMX*.
3. With hardware: confirm DMX output. Without hardware: confirm console preview.

---

## 4) Publish on GitHub

```bash
git tag v0.0.1
git push origin v0.0.1
```

* Create a **GitHub Release** for `v0.0.1`.
* Attach the built **zip** (the one that contains `library/`, `examples/`, `library.properties`).
* If you want GitHub Pages to host the Processing submission files, run:

  ```bash
  ./gradlew stageContributionArtifactsToDocs
  ```

  and commit the updated `docs/download/` assets.

---

## 5) Submit to Processing Library Manager

Processing's current library submission flow is based on hosting a `.zip` and matching `.txt` file at stable URLs, then emailing the Processing librarian.

Checklist:

- Ensure `library.properties` is complete:
  - `name`
  - `authors`
  - `url`
  - `categories`
  - `sentence`
  - `version`
- Build the release package.
- Host these two files at stable public URLs:
  - `https://jshaw.github.io/Canvas2DMX/download/canvas2dmx.zip`
  - `https://jshaw.github.io/Canvas2DMX/download/canvas2dmx.txt`
- Email the `.txt` URL to `contributions@processing.org`.

Suggested email:

```text
Subject: Processing library submission: Canvas2DMX

Hi Processing team,

I'd like to submit Canvas2DMX for the Processing Library Manager.

Project URL:
https://github.com/jshaw/Canvas2DMX

Hosted library.properties (.txt):
https://jshaw.github.io/Canvas2DMX/download/canvas2dmx.txt

Hosted release zip:
https://jshaw.github.io/Canvas2DMX/download/canvas2dmx.zip

Thanks,
Jordan Shaw
```

---

## 6) Update the docs (GitHub Pages)

Your site is served from `/docs`.

* **Edit docs** under `docs/` (Markdown + images in `docs/_img/`).
* **Commit & push** to `main` — Pages updates automatically.
* You do **not** need to deploy from `gh-pages` for the current repo setup.

First-time only (repo → *Settings → Pages*): set **Source** = `Deploy from a branch`, **Branch** = `main`, **Folder** = `/docs`.

**Embedding media**

* Image: `![Canvas2DMX demo](_img/hero.png)`
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
* [ ] `docs/download/canvas2dmx.zip` updated
* [ ] `docs/download/canvas2dmx.txt` updated
* [ ] Submission email sent to `contributions@processing.org`

---

## 📚 Learn More

* **[Canvas2DMX](https://github.com/jshaw/Canvas2DMX)** — repo link
* [Getting Started](getting-started.md) — installation and first sketch
* [Troubleshooting](troubleshooting.md) — common issues and fixes
* [Develop](develop.md) — contributing and building from source
* [Release](release.md) — packaging and Processing Library Manager submission

---

## 📜 License

MIT License © 2025 [Studio Jordan Shaw](https://www.jordanshaw.com/)
