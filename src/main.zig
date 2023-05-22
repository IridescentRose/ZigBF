const std = @import("std");

const Operator = enum(u8) {
    END = 0,
    INC_PTR = 1,
    DEC_PTR = 2,
    INC_VAL = 3,
    DEC_VAL = 4,
    OUT = 5,
    IN = 6,
    JMP_FWD = 7,
    JMP_BCK = 8,
};

const Program = struct {
    operator: Operator,
    operand: u16,
};

const PROGRAM_SIZE: u16 = 4096;
const STACK_SIZE: u16 = 512;
const DATA_SIZE: u16 = 65535;

var PROGRAM: [PROGRAM_SIZE]Program = undefined;
var STACK_POINTER: usize = 0;
var STACK: [STACK_SIZE]u16 = undefined;
var SP: u16 = 0;

fn compile_bf(file: std.fs.File.Reader) !void {
    var pc: u16 = 0;
    var jmp_pc: u16 = 0;
    while (pc < PROGRAM_SIZE) {
        const c = file.readByte() catch return;
        switch (c) {
            '>' => PROGRAM[pc].operator = Operator.INC_PTR,
            '<' => PROGRAM[pc].operator = Operator.DEC_PTR,
            '+' => PROGRAM[pc].operator = Operator.INC_VAL,
            '-' => PROGRAM[pc].operator = Operator.DEC_VAL,
            '.' => PROGRAM[pc].operator = Operator.OUT,
            ',' => PROGRAM[pc].operator = Operator.IN,
            '[' => {
                PROGRAM[pc].operator = Operator.JMP_FWD;
                STACK[STACK_POINTER] = pc;
                STACK_POINTER += 1;
            },
            ']' => {
                STACK_POINTER -= 1;
                jmp_pc = STACK[STACK_POINTER];
                PROGRAM[pc].operator = Operator.JMP_BCK;
                PROGRAM[pc].operand = jmp_pc;
                PROGRAM[jmp_pc].operand = pc;
            },
            else => pc -= 1,
        }
        pc += 1;
    }
    if (SP != 0 or pc == PROGRAM_SIZE) {
        return error.CompileFailure;
    }
    PROGRAM[pc].operator = Operator.END;
}

fn execute_bf() !void {
    var data: [DATA_SIZE]u8 = [_]u8{0} ** DATA_SIZE;

    var pc: u16 = 0;
    var ptr: usize = 0;
    while (PROGRAM[pc].operator != Operator.END and ptr < DATA_SIZE) {
        switch (PROGRAM[pc].operator) {
            Operator.INC_PTR => ptr += 1,
            Operator.DEC_PTR => ptr -= 1,
            Operator.INC_VAL => data[ptr] += 1,
            Operator.DEC_VAL => data[ptr] -= 1,
            Operator.OUT => try std.io.getStdOut().writer().writeByte(data[ptr]),
            Operator.IN => data[ptr] = try std.io.getStdIn().reader().readByte(),
            Operator.JMP_FWD => if (data[ptr] == 0) {
                pc = PROGRAM[pc].operand;
            },
            Operator.JMP_BCK => if (data[ptr] != 0) {
                pc = PROGRAM[pc].operand;
            },
            else => return error.ExecutionFailure,
        }
        pc += 1;
    }
    if (ptr == DATA_SIZE) {
        return error.ExecutionFailure;
    }
}

pub fn main() !void {
    var args = try std.process.argsWithAllocator(std.heap.page_allocator);
    _ = args.next();
    const filename = args.next() orelse return error.MissingArgument;

    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    try compile_bf(file.reader());
    try execute_bf();
}
