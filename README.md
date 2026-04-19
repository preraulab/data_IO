# data_io

Data I/O helpers for MATLAB — read/write EDF/EDF+, BrainVision (`.eeg`/`.vmrk`), Grass scoring, MBF, bytestreams, and general log-file utilities. Bundles `xml2struct` for inline XML parsing.

Part of the Prerau Lab [`preraulab_utilities`](https://github.com/preraulab/preraulab_utilities) meta-repository. Can also be used standalone.

## Layout

| Sub-folder | Purpose |
|---|---|
| `EDF/` | `blockEdfLoad`, `blockEdfWrite` — block-wise EDF/EDF+ reader/writer; plus `EDF de-identify/` helpers |
| `BrainVision/` | `bvaloader`, `import_vmrk`, `load_vmrk_scoring` — BrainVision data and marker-file loaders |
| `grass/` | `readgrassstaging`, `convert_grass_scoring` — Grass Twin scoring file readers |
| `MBF/` | `MBFread`, `MBFwrite`, `intrange2num`, `num2intrange` — MBF binary format |
| `bytestream/` | `bytestream_save`, `bytestream_load`, `isIOdatatype` — MATLAB bytestream round-trip |
| `logfiles/` | `create_log`, `generate_run_log` — simple run-log helpers |
| `xml2struct/` | Vendored Wouter Falkena XML reader (BSD) |

See the [published API reference](https://preraulab.github.io/data_IO/) for full per-function documentation.

## Quick start

```matlab
addpath(genpath('/path/to/data_io'));

% Read an EDF file
[hdr, sigHdr, sigs] = blockEdfLoad('study.edf');

% Read a BrainVision marker file into a table
markers = import_vmrk('study.vmrk');
```

## Install

```matlab
addpath(genpath('/path/to/data_io'));
```

`genpath` is recommended so all sub-folders (EDF, BrainVision, grass, MBF, etc.) are on the path.

## Dependencies

MATLAB R2020a+. No required toolboxes. A few readers use native MEX entry points for speed; source is included.

## Citation

See [`CITATION.cff`](CITATION.cff). If you use the BrainVision/EDF readers in a publication, please also credit the original format specifications.

## License

BSD 3-Clause. See [`LICENSE`](LICENSE).
