# Manic Server protocol v1

Manic Server is a small HTTP/HTTPS protocol for user-owned game libraries. The
server provides metadata first; ManicEMU downloads a selected game only when it
needs a local file for an emulator core.

## Catalog

`GET /library.json`

Example:

```json
{
  "version": 1,
  "name": "Galaxy A14",
  "games": [
    {
      "id": "PS2/Fatal Frame.iso",
      "system": "PS2",
      "title": "Fatal Frame",
      "file": "PS2/Fatal Frame.iso",
      "size": 2890000000,
      "download": "games/PS2/Fatal%20Frame.iso"
    }
  ]
}
```

Fields:

- `version`: protocol version. Current version is 1.
- `name`: optional server/library display name.
- `games`: array of game entries.
- `id`: optional stable ID. If omitted, ManicEMU uses `file`.
- `system`: ManicEMU short system name such as `PS2`, `PS1`, `PSP`, `NDS`, `GBA`.
- `title`: optional display title.
- `file`: remote library-relative file path.
- `size`: optional file size in bytes.
- `download`: optional relative or absolute HTTP(S) download path. If omitted,
  ManicEMU requests `games/<file>`.
- `cover`: optional relative or absolute cover-art URL.
- `sha256`: reserved for file-integrity verification.
- `files`: optional array for a multi-file game. Each member can provide
  `name` (the local filename/path relative to the main file), `file`, `size`,
  and `download`. When present, ManicEMU downloads the complete set before launch.

For CUE/BIN discs, the reference server publishes only the `.cue` as the game
entry and places the cue plus every existing `FILE` reference in `files`.
Referenced BIN/audio tracks are suppressed as separate games.

## Game download

`GET /games/<path>`

The v1 reference server supports normal downloads plus HTTP byte ranges. ManicEMU
currently downloads a game into a local cache before passing it to the emulator.

The game server should send every file unchanged. Single-file formats (CHD, ISO,
CSO, RVZ, normal cartridge ROMs, etc.) use the ordinary `download` field.
CUE/BIN track sets use the optional `files` array; ManicEMU preserves the
filenames from the cue set inside one cache directory so the emulator can resolve
the cue's track references.

## Security

The reference Python server is intended for a trusted local network. It does not
open router ports or configure public internet access. Do not expose it directly
to the internet. Remote-away-from-home access should be layered over an encrypted
private network or a future authenticated Manic Server mode.

Optional HTTP Basic authentication is supported by the ManicEMU client when a
username/password is stored with the service.
