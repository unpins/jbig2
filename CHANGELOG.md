# Changelog

## [Unreleased]

### Changed

- The Windows binary is now built by the same compiler as the Linux and macOS
  ones, and is 51% smaller (5.22 MB to 2.54 MB). Checked on Windows 10 against
  the previous binary: same version banner, and PNG, TIFF, JPEG, PBM and BMP
  pages encode to byte-identical output, in both plain and symbol mode.

  It now uses the Universal C Runtime, which is part of Windows 10 and later.
  On Windows 7 or 8.1 that runtime has to be installed first — it comes through
  Windows Update. The previous binary did not need it.

### Fixed

- On Windows, symbol-mode output (`-s`) for a large page could differ by a few
  bytes from what the Linux and macOS binaries produce for the same input. All
  three now agree exactly.
