# cpgen

`cpgen` is a small generator tool that converts official Unicode code page
mapping files into C3 modules for single‑byte code page to UTF‑8 conversion.

It produces:

- A shared engine module (`std::encoding::codepage`) with generic encode/decode logic
- One module per code page (e.g. `std::encoding::codepage::cp437`) containing the mapping tables and thin wrappers

The generated code is intended for inclusion in the C3 standard library or for reuse in user projects needing legacy code page support.

## Mapping sources

The `resources/` directory contains the original mapping files from the Unicode Consortium’s public “MAPPINGS” area and, optionally, other vendors.

Typical layout:

```
resources/
  vendors/
    micsft/
      pc/
        CP437.TXT
        CP850.TXT
        CP852.TXT
        CP863.TXT
        CP864.TXT
        CP866.TXT
      windows/
        CP1252.TXT
        ...
    iso8859/
      8859-1.TXT
      8859-2.TXT
      ...
```

Each `.TXT` file maps one legacy code page to Unicode:

- Column 1: code page byte value in hex (`0xXX`)
- Column 2: Unicode code point in hex (`0xYYYY`)
- Rest of line: comment (character name, etc.)

`cpgen` reads these files and generates:

- A 256‑entry forward table: code-page byte  UTF‑8 bytes
- A 256‑entry packed reverse table: a `uint` with `(byte << 24) | codepoint`, sorted by `codepoint`

The generator never hard‑codes mappings; everything comes from these source
files so updating to a newer Unicode release is just a matter of refreshing
`resources/` and rerunning `cpgen`.

## Data structures and encoding approach

The shared engine module (typically `std::encoding::codepage`) defines two structures:

```c3
struct CodePoint
{
    char[4] bytes; // UTF‑8 bytes for a single Unicode scalar
    usz     len;   // number of valid bytes (1–4)
}

struct CodePageTable
{
    CodePoint[256] to_codepoint;
    uint[256]      from_codepoint; // packed reverse mapping
}
```

### Packed reverse mapping (`from_codepoint`)

Each `uint` entry in `from_utf8` encodes:

- High 8 bits: code page byte value (`0x00`–`0xFF`)
- Low 24 bits: Unicode code point

```c3
const uint MASK = (1u << 24) - 1;

// Extractors
uint  codepoint = entry & MASK;
char  byte      = (char)(entry >> 24);
```

The array is sorted by `codepoint` (low 24 bits). To map UTF‑8 to code page:

1. Decode one Unicode scalar from UTF‑8.
2. Binary‑search `from_codepoint` table for a matching `codepoint`.
3. If found, emit the stored byte.
4. If not found, emit a caller‑provided replacement byte (typically `0x1A` / SUB).

This avoids a 64‑KiB reverse lookup table per code page while still being efficient.

## cpgen usage

### Basic invocation

```bash
cpgen ./resources
```

This would scan all supported `.TXT` files under the input directory and
generate one C3 module per code page and writes it to stdout.

### Common flags

Below is a suggested flag set; adjust names to your actual implementation:

- `-s`  
  Generate separate files for each code-page mapping.  Write the shared core
  module to `./output/codepage.c3` and each codepage C3 module to
  (`./output/codepages/`).

- `-p <namespace>`  
  Module prefix for generated files (defaults to `std::encoding`).  
  Example: `-p myproj::encoding`. Not implemented yet.

## Using generated code pages in user code

### Importing a code page

```c3
import std::encoding::codepage::cp437;
```

### Decode: CP437 → UTF‑8

```c3
fn void example_decode_cp437()
{
    // CP437 bytes (e.g. from a ZIP filename)
    char[] raw = x"C9CDCDCDCDCDCDCDCDCDCDCDCDCDCDCD"; // truncated

    @pool()
    {
        char[] utf8 = cp437::decode(tmem, raw)!!;

        // utf8 now holds a UTF‑8 string with proper box‑drawing characters.
        io::printn(utf8);
    }
}
```

### Encode: UTF‑8 → CP437

```c3
fn void example_encode_cp437()
{
    @pool()
    {
        char[] banner = "╔════ C3 CP437 Test ════╗";

        char[] encoded = cp437::encode(tmem, banner)!!;

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
