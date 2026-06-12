{
  description = ''
    The jbig2enc JBIG2 encoder (`jbig2`) as a single self-contained binary.

    jbig2enc ships two things in bin/: the C++ encoder `jbig2`, and
    `jbig2topdf.py`, a pure-stdlib Python script that muxes the encoder's
    multipage symbol-coded output (`jbig2 -s -p ...`) into a PDF. We ship ONLY
    the encoder `jbig2` — bundling a whole CPython runtime just to run a
    ~150-line PDF byte-emitter is disproportionate for a single static binary
    (see README). `python3` is therefore dropped (it was an input only so the
    install could patch the script's shebang).

    The binary is named `jbig2` (= upstream mainProgram, the actual command), so
    the flake `name` is `jbig2` too; the nixpkgs attr is `jbig2enc` (pkgsAttr).
  '';

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs.unpins-lib.url = "github:unpins/nix-lib";

  outputs = { self, unpins-lib }:
    let
      ulib = unpins-lib.lib;

      # jbig2enc, static, with the Python script stripped out.
      #
      # The encoder pulls leptonica + the image-codec stack (giflib / libjpeg /
      # libpng / libtiff / libwebp / openjpeg / zlib) — all already proven as
      # static deps across the catalogue. The one per-target wrinkle is the
      # shared riscv64 libjpeg-turbo `simdcoverage` fix (same overlay openjpeg /
      # jpeg-tools / chafa use); identity off riscv so other arches cache-hit.
      mk = scope:
        let
          host = scope.stdenv.hostPlatform;
          s = scope.extend (final: prev:
            (scope.lib.optionalAttrs host.isRiscV {
              libjpeg = ulib.nativeFixes."libjpeg-turbo" prev;
            }) // (scope.lib.optionalAttrs host.isWindows (
              let
                # libtiff auto-enables libjpeg 8/12-bit dual mode via a cmake
                # `check_c_source_compiles` probe (HAVE_JPEGTURBO_DUAL_MODE_8_12)
                # that only *compiles* a `jpeg12_read_scanlines()` call. On
                # mingw the libjpeg-turbo HEADERS declare that API but the `.a`
                # ships no `jpeg12_*` symbols (built without dual mode), so the
                # probe is a false positive: tif_jpeg12.c gets compiled and any
                # full static link of libtiff (leptonica, jbig2) fails with
                # `undefined reference to jpeg12_*`. The `jpeg12` cmake OPTION
                # only governs the *separate-lib* fallback branch, so it can't
                # turn this off — pre-seed the probe's cache var to false
                # instead, which routes libtiff to single-mode (as the musl
                # build already is, which is why native links cleanly).
                # Rebuilds libtiff → leptonica for windows only.
                tiff = prev.libtiff.overrideAttrs (to: {
                  cmakeFlags = (to.cmakeFlags or [ ])
                    ++ [ "-DHAVE_JPEGTURBO_DUAL_MODE_8_12=OFF" "-Djpeg12=OFF" ];
                });
              in
              {
                libtiff = tiff;
                # leptonica against the jpeg12-off libtiff, AND restricted to
                # src/: its autotools build otherwise also compiles the demo
                # programs (prog/converttopdf.exe …), which fail the same mingw
                # static link (they also pull libwebp's SharpYuv, split into a
                # separate libsharpyuv.a). We only need liblept.a.
                leptonica = (prev.leptonica.override { libtiff = tiff; }).overrideAttrs (lo: {
                  makeFlags = (lo.makeFlags or [ ]) ++ [ "SUBDIRS=src" ];
                  installFlags = (lo.installFlags or [ ]) ++ [ "SUBDIRS=src" ];
                  # leptonica's jp2kio.c uses the openjpeg API. Without
                  # -DOPJ_STATIC the mingw openjpeg headers decorate that API
                  # __declspec(dllimport), so jp2kio.o references `__imp_opj_*`
                  # — symbols only a DLL import lib provides, absent from the
                  # static libopenjp2.a. Define it so the calls bind to the
                  # plain `opj_*` in the .a.
                  env = (lo.env or { }) // {
                    NIX_CFLAGS_COMPILE = ((lo.env.NIX_CFLAGS_COMPILE or "") + " -DOPJ_STATIC");
                  };
                });
              }
            )));
          dev = p: p.dev or p;
          # Swap the `python3` INPUT to a non-broken host python. jbig2enc's
          # package.nix takes python3 only so `make install` can patch the
          # jbig2topdf.py shebang — which we drop. But the input must still be
          # *evaluable* to compute `old` in overrideAttrs, and pkgsStatic.python3
          # is marked broken on darwin (eval error). buildPackages.python3 (the
          # native host interpreter) is non-broken everywhere and, since we also
          # drop it from buildInputs below, never enters the build at all.
          base = s.jbig2enc.override { python3 = s.buildPackages.python3; };
        in
        base.overrideAttrs (old: {
          # Set buildInputs explicitly (= upstream list MINUS python3). python3
          # was present only so `make install` could patch the jbig2topdf.py
          # shebang; we ship only the encoder, so we drop it — no static CPython
          # in the build closure. We list the `.dev`s so pkg-config can resolve
          # leptonica's full static closure (Requires.private) below.
          buildInputs = map dev (with s; [
            leptonica zlib libwebp giflib libjpeg libpng libtiff
          ]);
          # Static-link autoconf fix: jbig2enc's configure does
          # `AC_CHECK_LIB(leptonica, findFileFormatStream)`, which links a probe
          # with `-lleptonica` ALONE. Against a static leptonica.a that pulls in
          # giflib/jpeg/png/tiff/webp/openjpeg/zlib, the probe fails to resolve
          # ("Leptonica not detected"). Feed the full static closure via LIBS so
          # both the configure probe and the final `jbig2` link see every
          # transitive `.a` (same shape as poppler-utils' --start-group dodge).
          # On mingw, lept.pc's Libs.private lists `-lwebp -lwebpmux` but NOT
          # `-lsharpyuv` (libwebp ships SharpYuv as a separate libsharpyuv.a),
          # so libwebp.a's `SharpYuv*` refs go unresolved. Append it (the
          # libwebp -L is already on the line from lept.pc). The native musl
          # lept.pc already includes -lsharpyuv, so this is windows-only.
          preConfigure = (old.preConfigure or "") + ''
            export LIBS="$(''${PKG_CONFIG:-pkg-config} --static --libs lept)${scope.lib.optionalString host.isWindows " -lsharpyuv"} -lm $LIBS"
          '';
          # Ship ONLY the `jbig2` encoder binary. Drop:
          #   - the Python PDF muxer (out of scope; see header),
          #   - the static library + headers (libjbig2enc.a/.la, include/) — the
          #     `.la` and nix-support/propagated-build-inputs carry absolute
          #     store paths (leptonica, the image-lib -dev outputs, even
          #     python3-static), the only thing keeping them in the closure,
          #   - share/doc.
          # The binary itself is already store-ref-free; trimming these makes the
          # whole output self-contained.
          postInstall = (old.postInstall or "") + ''
            rm -f "$out/bin/jbig2topdf.py" "$out/bin/pdf.py"
            rm -rf "$out/lib" "$out/include" "$out/share"
          '';
          # `nix-support/propagated-build-inputs` is (re)written during
          # fixupPhase — AFTER postInstall — and is the sole remaining carrier of
          # store paths (leptonica, the image-lib -dev outputs, python3-static).
          # The binary is ref-free, so dropping this file in postFixup (which
          # runs after that writer) makes the closure fully self-contained.
          postFixup = (old.postFixup or "") + ''
            rm -rf "$out/nix-support"
          '';
        });
    in
    ulib.mkStandaloneFlake {
      inherit self;
      name = "jbig2";
      pkgsAttr = "jbig2enc";
      # `jbig2 --version` prints "jbig2enc 0.31\n leptonica… : libjpeg…" and
      # exits 0 — a clean non-interactive smoke. Note jbig2 writes --version (and
      # -h) to STDERR, not stdout, but action-build captures the smoke as `2>&1`,
      # so the smokePattern still matches the combined stream.
      smoke = [ "--version" ];
      smokePattern = "jbig2enc";
      # Upstream ships no man page, so there's nothing to embed; opt out of the
      # withMan graft (it would just warn-and-skip otherwise).
      embedMan = false;

      build = pkgs: mk pkgs.pkgsStatic;
      # C++ over the image stack. `jbig2` is linked through libtool (there's a
      # libjbig2enc.la), so a bare `-static` in NIX_LDFLAGS doesn't reach the
      # final link — libtool picks the `.dll.a` import libs and the DLL-copy
      # hook drops libgcc_s_seh-1.dll / libmcfgthread-2.dll next to the exe.
      # `LDFLAGS=-all-static` is libtool's "fully static" switch (the jq
      # precedent); it folds libstdc++/libgcc/mcfgthread/winpthread so a single
      # self-contained jbig2.exe ships with no companion DLLs.
      windowsBuild = pkgs: (mk (ulib.mingwStaticCross pkgs)).overrideAttrs (old: {
        makeFlags = (old.makeFlags or [ ]) ++ [ "LDFLAGS=-all-static" ];
      });
    };
}
