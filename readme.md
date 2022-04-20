# I/D Machine

An implimentation of both the 2-instruction and OISC versions of
<https://esolangs.org/wiki/I/D_machine>.

## Building

`zig build -Drelease-fast`

### Build Dependencies
- Zig
  - Tested on version `0.10.0-dev.1888+e3cbea934`

## Usage

```
./zig-out/bin/id-machine <code file> <output file>
```

### Header Byte

The first byte of the code file must be a header byte in the following format:
```
aaaabbbc
```
Where `a` is control the amount of cells (a value of 0 creates 0x10000 cells,
a value of 1 creates 0x20000, etc.). `b` controls the ammount of bits ignored
at the end of 2-instruction mode. If `c` is 0, then the code is interpreted in
OISC mode, otherwise it is interpreted in 2-instruction mode.

### OISC Mode

Aside from the header byte the length of the code must be a multiple of the
number of bytes in your machine's word size (ex. 8 bytes on a 64-bit machine).

### 2-Instruction Mode

Each instruction is a bit, 0 is Increment, 1 is Dereference.
