const std = @import("std");
const heap = std.heap;
const proc = std.process;
const mem = std.mem;
const fs = std.fs;
const log = std.log;
const math = std.math;

pub fn main() !void {
    var ignored: u3 = undefined;
    var mode: u1 = undefined;
    var memdump_len: usize = undefined;

    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    // set up command line arguments
    const args = try proc.argsAlloc(allocator);
    defer proc.argsFree(allocator, args);

    if (args.len == 3) {
        var code_file = try fs.cwd().openFile(args[1], .{});
        defer code_file.close();

        const code_meta = try code_file.metadata();
        var code: []u8 = try allocator.alloc(u8, code_meta.size());
        defer allocator.free(code);

        _ = try code_file.readAll(code);

        if (code.len < 2) {
            log.err("There must be at least a header byte and and some code\n", .{});
            return error.TooFewBytes;
        }

        ignored = @truncate(u3, code[0] >> 1);
        mode = @truncate(u1, code[0]);

        const memory_size: usize = 0x10000 * (1 + @intCast(usize, code[0] >> 4));

        var memory: []usize = try allocator.alloc(usize, memory_size);
        defer allocator.free(memory);
        mem.set(usize, memory, 0);

        if (mode == 1) {
            memdump_len = execute_bits(code[1..], memory, ignored);
        } else if (ignored == 0) {
            memdump_len = try execute_oisc(code[1..], memory);
        } else {
            log.err("OISC mode must not have any 'ignore' header bits set\n", .{});
            return error.BadHeaderByte;
        }
        var mem_file = try fs.cwd().createFile(args[2], .{});
        defer mem_file.close();

        var memdump_writer = mem_file.writer();
        for (memory[0 .. memdump_len]) |current_integer| {
            try memdump_writer.writeIntNative(usize, current_integer);
        }
    } else {
        log.err("This program requires 2 arguments of the form <code file> <memdump file>\n", .{});
        return error.WrongNumberOfArguments;
    }
}

// I/D machine https://esolangs.org/wiki/I/D_machine
// 0 is Increment
// 1 is Dereference
// Halts when the data pointer is dereferenced out of bounds

// Mode 0 is bits, mode 1 is OISC

// Returns largest in-bounds cell that was changed
fn execute_bits(code: []u8, memory: []usize, ignored_bits: u3) usize {
    var data_pointer: usize = 0;
    var max_accessed: usize = 0;

    var pc_byte: usize = 0;
    while (true) : (pc_byte += 1) {
        if (pc_byte == code.len) {
            pc_byte = 0;
        }

        var pc_bit: u4 = 0;

        while (pc_bit < 8) : (pc_bit += 1) {
            if (pc_byte == code.len - 1 and pc_bit + ignored_bits == 7) {
                break;
            }

            var op = extractBit(code[pc_byte], @truncate(u3, pc_bit));

            if (op == 0) {
                memory[data_pointer] += 1;

                max_accessed = math.max(data_pointer, max_accessed);
            } else {
                data_pointer = memory[data_pointer];

                if (data_pointer >= memory.len) {
                    return max_accessed;
                }
            }
        }
    }

}

fn execute_oisc(code: []u8, memory: []usize) !usize {
    var data_pointer: usize = 0;
    var max_accessed: usize = 0;

    if (code.len % @sizeOf(usize) != 0) {
        log.err("The code of an OISC mode program must be of some multiple of usize in length\n", .{});
        return error.badCode;
    }

    var pc: usize = 0;

    while (true) : (pc += @sizeOf(usize)) {
        if (pc == code.len) {
            pc = 0;
        }

        memory[data_pointer] += mem.bytesToValue(usize, code[pc..][0..@sizeOf(usize)]);
        data_pointer = memory[data_pointer];

        if (data_pointer >= memory.len) {
            return max_accessed;
        }
        max_accessed = math.max(data_pointer, max_accessed);
    }
}

fn extractBit(byte: u8, bit_num: u3) u1 {
    return @truncate(u1, (byte >> bit_num));
}
