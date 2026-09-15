# jbig2

[jbig2enc](https://github.com/agl/jbig2enc) — an encoder for the **JBIG2** image compression format (the `jbig2` command). A single self-contained binary, built natively for Linux, macOS, and Windows.

[![CI](https://github.com/unpins/jbig2/actions/workflows/jbig2.yml/badge.svg)](https://github.com/unpins/jbig2/actions)
![Linux](https://img.shields.io/badge/Linux-✓-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-✓-success?logo=apple&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-✓-success?logo=windows&logoColor=white)

Part of the [unpins](https://unpins.org) catalog; install it with [`unpin`](https://github.com/unpins/unpin): `unpin install jbig2`.

## Usage

Run the `jbig2` program with [unpin](https://github.com/unpins/unpin):

```bash
unpin jbig2 input.png > out.jb2                 # encode a page to a JBIG2 file
unpin jbig2 -s -p -b output page1.png page2.png # symbol-coded, PDF-ready output
```

To install it onto your PATH:

```bash
unpin install jbig2
```

JBIG2 is the black-and-white image format used inside PDF files and fax
workflows. `jbig2` reads PNG, TIFF, JPEG, GIF, WebP, JPEG 2000, BMP and PNM pages
(color and gray pages are turned to black and white first) and writes JBIG2.

## Scope: encoder only (no `jbig2topdf.py`)

Upstream jbig2enc also ships `jbig2topdf.py`, a small Python helper that stitches
the `-s -p` multipage output (`output.sym` + `output.NNNN`) into a PDF. This
package ships **only the `jbig2` encoder** — bundling a whole CPython runtime
just to run a ~150-line PDF byte-emitter would dwarf the binary it serves and
defeats the single-self-contained-binary model.

If you need the PDF-muxing step, run the encoder here to produce the symbol /
page streams and pass them through upstream's
[`jbig2topdf.py`](https://github.com/agl/jbig2enc/blob/master/jbig2topdf.py)
with any Python 3 you already have:

```bash
jbig2 -s -p -b output page1.png page2.png   # → output.sym, output.0000, …
python3 jbig2topdf.py output > out.pdf
```

## Build locally

```bash
nix build github:unpins/jbig2
./result/bin/jbig2 --version
```

Or run directly:

```bash
nix run github:unpins/jbig2 -- --version
```

The first invocation will offer to add the [unpins.cachix.org](https://unpins.cachix.org) substituter so most pulls come pre-built.

## Manual download

The [Releases](https://github.com/unpins/jbig2/releases) page has standalone binaries for manual download.

## Build notes

- **Encoder only** — the PDF helper `jbig2topdf.py` is not included (see above).
- **Symbol mode (`-s`) is lossy** by design: similar-looking symbols are merged,
  so the decoded page can differ slightly from the input. The default generic
  mode is lossless. Refinement (`-r`), meant to make symbol mode lossless, is
  broken upstream: it prints "Refinement broke in recent releases" and exits.
- **Windows:** a single `.exe`, no companion DLLs.
- **No man pages** — jbig2enc ships none; run `jbig2 -h`.
