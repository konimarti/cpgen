# cpgen

`cpgen` is a small generator tool that converts official Unicode code page
mapping files into C3 for single‑byte code page to UTF‑8 conversion.

It produces:

- A shared engine module (`std::encoding::codepage`) with generic encode/decode logic
- A set of auto‑generated code page tables (CP437, CP850, CP866, ISO‑8859‑x, Windows‑125x, etc.)

The generated code is intended for inclusion in the C3 standard library or for reuse in user projects needing legacy code page support.

The implementation is table‑driven and inspired in spirit by Go’s `golang.org/x/text/encoding/charmap` package, but generated independently from the Unicode mapping files. [github](https://github.com/golang/text/blob/master/encoding/charmap/charmap.go)

## Mapping sources

The `resources/` directory contains the original mapping files from the Unicode Consortium’s public “MAPPINGS” area and, optionally, other vendors.

Each `.TXT` file maps one legacy code page to Unicode:

- Column 1: code page byte value in hex (`0xXX`)
- Column 2: Unicode code point in hex (`0xYYYY`)
- Rest of line: comment (character name, etc.)

## Data model and design

### Packed code page table

The core type in `std::encoding::codepage` is:

```c
struct CodePageTable
{
    char[1024] to_codepoint;
    char[1024] from_codepoint;
}
```

It represents one single‑byte (8‑bit) code page.

#### Forward table: `to_codepoint`

Maps a code page byte to its UTF‑8 bytes:

- Indexed by the raw byte value `b` (0x00–0xFF).
- Each entry is 4 bytes at offset `b * 4`:

  - Byte 0: length of the UTF‑8 sequence (0–4).
  - Bytes 1..(1+len‑1): the UTF‑8 bytes for the mapped Unicode scalar.

This makes `to_codepoint` a flat `char[256 * 4]` table with one lookup per byte on decode.

#### Reverse table: `from_codepoint`

Maps a Unicode scalar back to a code page byte:

- Stored as 256 packed 4‑byte entries in `from_codepoint`.
- Each 4‑byte chunk is interpreted as a little‑endian `uint`:

  - High 8 bits: code page byte value (0x00–0xFF).
  - Low 24 bits: Unicode scalar (code point).

  In other words:

  ```c
  entry = (byte_value << 24) | codepoint;
  ```

- The 256 entries are sorted by the low 24 bits (`codepoint`).

This allows a binary search over at most 256 entries per code page instead of
maintaining a 64‑KiB Unicode‑to‑byte array, trading a small amount of CPU for a
compact, cache‑friendly table.

## Generator (`cpgen`) usage

`cpgen` itself is a separate tool that:

1. Reads mapping files from `resources/`.
2. Builds `CodePageTable` instances for all selected code pages.
3. Emits C3 code with:
   - The `CodePageTable` constants (packed arrays as base64 literals).
   - The `charset()` switch cases.
   - Optional tests for round‑trip behavior.

Typical invocation:

```bash
cpgen ./resources
```

This would scan all supported `.TXT` files under the input directory and
generate three C3 files (`codepage.c3`, `codepage_private.c3` and `codepage_test.c3`).

## Using generated code pages in user code

### Decode: CP437 to UTF‑8

```c3
fn void example_decode_cp437()
{
    // CP437 bytes (e.g. from a ZIP filename)
    char[] raw = x"C9CDCDCDCDCDCDCDCDCDCDCDCDCDCDCD"; // truncated

    @pool()
    {
        char[] utf8 = codepage::decode(tmem, raw, codepage::charset("cp437"))!!;

        // utf8 now holds a UTF‑8 string with proper box‑drawing characters.
        io::printn(utf8);
    }
}
```

### Encode: UTF‑8 to CP437

```c3
fn void example_encode_cp437()
{
    @pool()
    {
        char[] banner = "╔════ C3 CP437 Test ════╗";

        char[] encoded = codepage::encode(tmem, banner, codepage::charset("cp437"))!!;

        // encoded contains CP437 bytes.
	io::printn(encoded);
    }
}
```

By default, characters not representable in the target code page are replaced
with `0x1A`:


## License

The mapping source files in `resources/` originate from the Unicode
Consortium’s public “MAPPINGS” area and retain their original copyright and
license terms.

This project is licensed under the MIT License.  
See `LICENSE` for details.
