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
unpin jbig2 --version                 # version banner
unpin jbig2 input.png > out.jb2       # encode to a JBIG2 stream
unpin jbig2 -s -p page1.png page2.png # symbol-coded, PDF-ready output
```

To install it onto your PATH:

```bash
unpin install jbig2
```

JBIG2 is the bilevel-image codec used inside PDF and fax workflows; `jbig2`
reads the usual raster formats (PNG/TIFF/JPEG/…, via leptonica) and emits the
compressed JBIG2 data.

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

- **Encoder only.** Upstream's `jbig2topdf.py` is dropped (see above), and with
  it the `python3` input — it was present only so the install could patch that
  script's shebang. The output is just `bin/jbig2`; the static library, headers,
  and the `nix-support` metadata that would otherwise pin store paths are all
  trimmed, so the binary and its whole closure carry no `/nix/store` reference.

- **leptonica + the image-codec stack, statically.** `jbig2` links leptonica,
  which pulls giflib / libjpeg-turbo / libpng / libtiff / libwebp / openjpeg /
  zlib. jbig2enc's `configure` probes leptonica with a bare `-lleptonica`, which
  can't resolve against a static `libleptonica.a`'s transitive closure; we feed
  the full closure via `pkg-config --static --libs lept` so both the probe and
  the final link succeed.

- **Windows (mingw) cross.** The mingw image stack needs four extra touches to
  link fully static: libtiff's auto-detected libjpeg 8/12-bit *dual mode* is
  turned off (its cmake probe is a false positive — the mingw libjpeg-turbo `.a`
  has no `jpeg12_*` symbols); leptonica is built library-only and with
  `-DOPJ_STATIC` (so its openjpeg calls don't expect a DLL import lib);
  `libsharpyuv` is added to the link (libwebp splits it out); and the libtool
  link uses `-all-static` so the single `jbig2.exe` ships with no companion
  DLLs.

- **Portable on every target.** Linux/Windows binaries are fully static (`file`
  reports `statically linked`; the `.exe` imports only Windows system DLLs);
  macOS links only `/usr/lib/libSystem` and `/usr/lib/libc++` (`otool -L`).
