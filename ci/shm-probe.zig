// Temporary: how large can a NetBSD shared-memory fd grow?
const std = @import("std");

extern "c" fn shm_open(name: [*:0]const u8, flags: c_int, mode: std.c.mode_t) c_int;
extern "c" fn shm_unlink(name: [*:0]const u8) c_int;
extern "c" fn ftruncate(fd: c_int, len: i64) c_int;
extern "c" fn open(path: [*:0]const u8, flags: c_int, ...) c_int;
extern "c" fn unlink(path: [*:0]const u8) c_int;
extern "c" fn close(fd: c_int) c_int;
extern "c" fn __errno() *c_int;

const o_rdwr_creat_excl: c_int = 0x2 | 0x200 | 0x800;

fn probe(label: []const u8, fd: c_int) void {
    if (fd < 0) {
        std.debug.print("{s}: open failed errno={}\n", .{ label, __errno().* });
        return;
    }
    defer _ = close(fd);
    var size: i64 = 256 << 20;
    while (size <= 2 << 40) : (size *= 2) {
        if (ftruncate(fd, size) != 0) {
            std.debug.print("{s}: ftruncate {} MiB failed errno={}\n", .{ label, size >> 20, __errno().* });
            return;
        }
    }
    std.debug.print("{s}: ftruncate 2 TiB ok\n", .{label});
}

pub fn main() void {
    const shm = shm_open("/roc_probe", o_rdwr_creat_excl, 0o600);
    _ = shm_unlink("/roc_probe");
    probe("shm_open", shm);
    const memfd_create = @extern(?*const fn ([*:0]const u8, c_uint) callconv(.c) c_int, .{ .name = "memfd_create", .linkage = .weak });
    if (memfd_create) |create| probe("memfd_create", create("roc_probe", 0)) else std.debug.print("memfd_create: not in libc\n", .{});
    const tmp = open("/tmp/roc_probe", o_rdwr_creat_excl, @as(c_int, 0o600));
    _ = unlink("/tmp/roc_probe");
    probe("/tmp file", tmp);
}
