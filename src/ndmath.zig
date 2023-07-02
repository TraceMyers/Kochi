
pub const fVec2 = Vec(2, f32);
pub const fVec3 = Vec(3, f32);
pub const fVec4 = Vec(4, f32);

pub const dVec2 = Vec(2, f64);
pub const dVec3 = Vec(3, f64);
pub const dVec4 = Vec(4, f64);

pub const iVec2 = Vec(2, i32);
pub const iVec3 = Vec(3, i32);
pub const iVec4 = Vec(4, i32);

pub const ilVec2 = Vec(2, i64);
pub const ilVec3 = Vec(3, i64);
pub const ilVec4 = Vec(4, i64);

pub const uVec2 = Vec(2, u32);
pub const uVec3 = Vec(3, u32);
pub const uVec4 = Vec(4, u32);

pub const ulVec2 = Vec(2, u64);
pub const ulVec3 = Vec(3, u64);
pub const ulVec4 = Vec(4, u64);

// TODO: comptime-optimized scalar div possible?
// TODO: is there a way to cast scalar types such that same-bitwidth vector types could do arithmetic with each other?
// TODO: ... or just make it easy to convert between them.
// TODO: test @setFloatMode() (a per-scope thing that allows ffast-math optimizations)

pub fn Vec(comptime length: comptime_int, comptime ScalarType: type) type {
    return struct {
        const Self = @This();

        val: @Vector(length, ScalarType) = undefined,

    // -------------------------------------------------------------------------------------------------------- new init

        pub inline fn new() Self {
            return Self{ .val = std.mem.zeroes([length]ScalarType) };
        }

        pub inline fn init(scalars: [length]ScalarType) Self {
            var self = Self{};
            @memcpy(@ptrCast([*]ScalarType, &self.val[0])[0..length], &scalars);
            return self;
        }

        pub inline fn initScalar(scalar: ScalarType) Self {
            var self = Self{};
            self.val = @splat(length, scalar);
            return self;
        }

        pub inline fn initVec(vec: anytype) Self {
            const copy_len = std.math.min(vec.len(), length);
            var self = Self{};
            @memcpy(self.val[0..copy_len], vec.val[0..copy_len]);
            return self;
        }

    // ------------------------------------------------------------------------------------------------------ conversion

        pub inline fn toIntVec(self: *const Self, comptime IntType: type) Vec(length, IntType) {
            var int_vec: Vec(length, IntType) = undefined;
            inline for(0..length) |i| {
                int_vec.val[i] = @floatToInt(IntType, self.val[i]);
            }
            return int_vec;
        }

        pub inline fn toFloatVec(self: *const Self, comptime FloatType: type) Vec(length, FloatType) {
            var float_vec: Vec(length, FloatType) = undefined;
            inline for(0..length) |i| {
                float_vec.val[i] = @intToFloat(FloatType, self.val[i]);
            }
            return float_vec;
        }

    // --------------------------------------------------------------------------------------------------------- re-init

        pub inline fn fill(self: *Self, scalar: ScalarType) Self {
            @memset(&self.val, scalar);
        }

    // ------------------------------------------------------------------------------------------------------- component

        pub inline fn x(self: *const Self) ScalarType {
            return self.val[0];
        }

        pub inline fn y(self: *const Self) ScalarType {
            return self.val[1];
        }

        pub inline fn z(self: *const Self) ScalarType {
            return self.val[2];
        }

        pub inline fn w(self: *const Self) ScalarType {
            return self.val[3];
        }

        pub inline fn setX(self: *Self, in_x: f32) void {
            self.val[0] = in_x;
        }

        pub inline fn setY(self: *Self, in_y: f32) void {
            self.val[1] = in_y;
        }

        pub inline fn setZ(self: *Self, in_z: f32) void {
            self.val[2] = in_z;
        }

        pub inline fn setW(self: *Self, in_w: f32) void {
            self.val[3] = in_w;
        }

    // --------------------------------------------------------------------------------------------------------- statics

        // get the compoment length of this vector. important for use anytime a function can have its branches removed
        // with comptime information.
        pub inline fn componentLenStatic() comptime_int {
            return length;
        }

        pub inline fn epsilonStatic() comptime_float {
            switch(ScalarType) {
                f32 => return 1e-5,
                f64 => return 1e-15,         
                else => unreachable
            }
        }
    // ---------------------------------------------------------------------------------------------------------- length

        pub inline fn componentLen(self: *const Self) usize {
            _ = self;
            return length;
        }

    // ----------------------------------------------------------------------------------------------- vector arithmetic
    // compile time information throughout these function allows for them to be reduced to branchless execution
    // according to compiler explorer. for example, vAddc() with two vectors of the same length will simply be
    // return Self{ .val = self.val + other.val };

        // add two vectors of same or differing lengths with copy for assignment
        pub inline fn vAddc(self: Self, other: anytype) Self {
            return switch(length) {
                0, 1 => unreachable,
                2, 3 => vAddcLoop(self, other),
                else => blk: {
                    if (@TypeOf(other).componentLenStatic() != length) {
                        break :blk vAddcLoop(self, other);
                    }
                    else {
                        return Self{ .val = self.val + other.val };
                    }
                },
            };
        }

        // add two vectors of same or differing lengths inline
        pub inline fn vAdd(self: *Self, other: anytype) void {
            switch(length) {
                0, 1 => unreachable,
                2, 3 => vAddcLoop(self, other),
                else => blk: {
                    if (@TypeOf(other).componentLenStatic() != length) {
                        break :blk vAddLoop(self, other);
                    }
                    else {
                        self.val += other.val;
                    }
                },
            }
        }

        // subtract two vectors of same or differing lengths with copy for assignment
        pub inline fn vSubc(self: Self, other: anytype) Self {
            return switch(length) {
                0, 1 => unreachable,
                2, 3 => vSubcLoop(self, other),
                else => blk: {
                    if (@TypeOf(other).componentLenStatic() != length) {
                        break :blk vSubcLoop(self, other);
                    }
                    else {
                        return Self{ .val = self.val - other.val };
                    }
                },
            };
        }

        // add two vectors of same or differing lengths inline
        pub inline fn vSub(self: *Self, other: anytype) void {
            switch(length) {
                0, 1 => unreachable,
                2, 3 => vSubLoop(self, other),
                else => blk: {
                    if (@TypeOf(other).componentLenStatic() != length) {
                        break :blk vSubLoop(self, other);
                    }
                    else {
                        self.val += other.val;
                    }
                },
            }
        }

        // add two vectors of same or differing lengths with copy for assignment
        pub inline fn vMulc(self: Self, other: anytype) Self {
            return switch(length) {
                0, 1 => unreachable,
                2, 3 => vMulcLoop(self, other),
                else => blk: {
                    if (@TypeOf(other).componentLenStatic() != length) {
                        break :blk vMulcLoop(self, other);
                    }
                    else {
                        return Self{ .val = self.val + other.val };
                    }
                },
            };
        }

        // add two vectors of same or differing lengths inline
        pub inline fn vMul(self: *Self, other: anytype) void {
            switch(length) {
                0, 1 => unreachable,
                2, 3 => vMulLoop(self, other),
                else => blk: {
                    if (@TypeOf(other).componentLenStatic() != length) {
                        break :blk vMulLoop(self, other);
                    }
                    else {
                        self.val += other.val;
                    }
                },
            }
        }

        // add two vectors of same or differing lengths with copy for assignment
        pub inline fn vDivc(self: Self, other: anytype) Self {
            return switch(length) {
                0, 1 => unreachable,
                2, 3 => vDivcLoop(self, other),
                else => blk: {
                    if (@TypeOf(other).componentLenStatic() != length) {
                        break :blk vDivcLoop(self, other);
                    }
                    else {
                        return Self{ .val = self.val + other.val };
                    }
                },
            };
        }

        // add two vectors of same or differing lengths inline
        pub inline fn vDiv(self: *Self, other: anytype) void {
            switch(length) {
                0, 1 => unreachable,
                2, 3 => vDivLoop(self, other),
                else => blk: {
                    if (@TypeOf(other).componentLenStatic() != length) {
                        break :blk vDivLoop(self, other);
                    }
                    else {
                        self.val += other.val;
                    }
                },
            }
        }

    // ------------------------------------------------------------------------------- explicit length vector arithmetic

        pub inline fn vAdd2dc(self: Self, other: anytype) Self {
            var add_vec: Self = undefined;
            add_vec.val[0] = self.val[0] + other.val[0];
            add_vec.val[1] = self.val[1] + other.val[1];
            if (length > 2) {
                @memcpy(@ptrCast([*]ScalarType, &add_vec.val[2])[0..length - 2], @ptrCast([*]ScalarType, &self.val[2])[0..length - 2]);
            }
            return add_vec;
        }

        pub inline fn vAdd2d(self: *Self, other: anytype) void {
            self.val[0] += other.val[0];
            self.val[1] += other.val[1];
        }

        pub inline fn vSub2dc(self: Self, other: anytype) Self {
            var sub_vec: Self = undefined;
            sub_vec.val[0] = self.val[0] - other.val[0];
            sub_vec.val[1] = self.val[1] - other.val[1];
            if (length > 2) {
                @memcpy(@ptrCast([*]ScalarType, &sub_vec.val[2])[0..length - 2], @ptrCast([*]ScalarType, &self.val[2])[0..length - 2]);
            }
            return sub_vec;
        }

        pub inline fn vSub2d(self: *Self, other: anytype) void {
            self.val[0] -= other.val[0];
            self.val[1] -= other.val[1];
        }

        pub inline fn vMul2dc(self: Self, other: anytype) Self {
            var mul_vec: Self = undefined;
            mul_vec.val[0] = self.val[0] * other.val[0];
            mul_vec.val[1] = self.val[1] * other.val[1];
            if (length > 2) {
                @memcpy(@ptrCast([*]ScalarType, &mul_vec.val[2])[0..length - 2], @ptrCast([*]ScalarType, &self.val[2])[0..length - 2]);
            }
            return mul_vec;
        }

        pub inline fn vMul2d(self: *Self, other: anytype) void {
            self.val[0] *= other.val[0];
            self.val[1] *= other.val[1];
        }

        pub inline fn vDiv2dc(self: Self, other: anytype) Self {
            var div_vec: Self = undefined;
            div_vec.val[0] = self.val[0] / other.val[0];
            div_vec.val[1] = self.val[1] / other.val[1];
            if (length > 2) {
                @memcpy(@ptrCast([*]ScalarType, &div_vec.val[2])[0..length - 2], @ptrCast([*]ScalarType, &self.val[2])[0..length - 2]);
            }
            return div_vec;
        }

        pub inline fn vDiv2d(self: *Self, other: anytype) void {
            self.val[0] /= other.val[0];
            self.val[1] /= other.val[1];
        }

        pub inline fn vAdd3dc(self: Self, other: anytype) Self {
            var add_vec: Self = undefined;
            add_vec.val[0] = self.val[0] + other.val[0];
            add_vec.val[1] = self.val[1] + other.val[1];
            add_vec.val[2] = self.val[2] + other.val[2];
            if (length > 3) {
                @memcpy(@ptrCast([*]ScalarType, &add_vec.val[3])[0..length - 3], @ptrCast([*]ScalarType, &self.val[3])[0..length - 3]);
            }
            return add_vec;
        }

        pub inline fn vAdd3d(self: *Self, other: anytype) void {
            self.val[0] += other.val[0];
            self.val[1] += other.val[1];
            self.val[2] += other.val[2];
        }

        pub inline fn vSub3dc(self: Self, other: anytype) Self {
            var sub_vec: Self = undefined;
            sub_vec.val[0] = self.val[0] - other.val[0];
            sub_vec.val[1] = self.val[1] - other.val[1];
            sub_vec.val[2] = self.val[2] - other.val[2];
            if (length > 3) {
                @memcpy(@ptrCast([*]ScalarType, &sub_vec.val[3])[0..length - 3], @ptrCast([*]ScalarType, &self.val[3])[0..length - 3]);
            }
            return sub_vec;
        }

        pub inline fn vSub3d(self: *Self, other: anytype) void {
            self.val[0] -= other.val[0];
            self.val[1] -= other.val[1];
            self.val[2] -= other.val[2];
        }

        pub inline fn vMul3dc(self: Self, other: anytype) Self {
            var mul_vec: Self = undefined;
            mul_vec.val[0] = self.val[0] * other.val[0];
            mul_vec.val[1] = self.val[1] * other.val[1];
            mul_vec.val[2] = self.val[2] * other.val[2];
            if (length > 3) {
                @memcpy(@ptrCast([*]ScalarType, &mul_vec.val[3])[0..length - 3], @ptrCast([*]ScalarType, &self.val[3])[0..length - 3]);
            }
            return mul_vec;
        }

        pub inline fn vMul3d(self: *Self, other: anytype) void {
            self.val[0] *= other.val[0];
            self.val[1] *= other.val[1];
            self.val[2] *= other.val[2];
        }

        pub inline fn vDiv3dc(self: Self, other: anytype) Self {
            var div_vec: Self = undefined;
            div_vec.val[0] = self.val[0] / other.val[0];
            div_vec.val[1] = self.val[1] / other.val[1];
            div_vec.val[2] = self.val[2] / other.val[2];
            if (length > 3) {
                @memcpy(@ptrCast([*]ScalarType, &div_vec.val[3])[0..length - 3], @ptrCast([*]ScalarType, &self.val[3])[0..length - 3]);
            }
            return div_vec;
        }

        pub inline fn vDiv3d(self: *Self, other: anytype) void {
            self.val[0] /= other.val[0];
            self.val[1] /= other.val[1];
            self.val[2] /= other.val[2];
        }

    // ----------------------------------------------------------------------------------------------- scalar arithmetic

        pub inline fn sAddc(self: Self, other: ScalarType) Self {
            const add_vec = @splat(length, other);
            return self + add_vec;
        }

        pub inline fn sAdd(self: *Self, other: ScalarType) void {
            const add_vec = @splat(length, other);
            self.val += add_vec;
        }

        pub inline fn sSubc(self: Self, other: ScalarType) Self {
            const add_vec = @splat(length, other);
            return self - add_vec;
        }

        pub inline fn sSub(self: *Self, other: ScalarType) void {
            const add_vec = @splat(length, other);
            self.val -= add_vec;
        }

        pub inline fn sMulc(self: Self, other: ScalarType) Self {
            const add_vec = @splat(length, other);
            return self * add_vec;
        }

        pub inline fn sMul(self: *Self, other: ScalarType) void {
            const add_vec = @splat(length, other);
            self.val *= add_vec;
        }

        pub inline fn sDivc(self: Self, other: ScalarType) Self {
            const mul_scalar = 1.0 / other;
            return self.sMulc(mul_scalar);
        }

        pub inline fn sDiv(self: Self, other: ScalarType) void {
            const mul_scalar = 1.0 / other;
            self.sMul(mul_scalar);
        }

    // -------------------------------------------------------------------------------------------------- linear algebra

        pub inline fn dot(self: Self, other: Self) ScalarType {
            return @reduce(.Add, self.val * other.val);
        }

        pub inline fn dot2d(self: Self, other: anytype) ScalarType {
            return self.val[0] * other.val[0] + self.val[1] * other.val[1];
        }

        pub inline fn dot3d(self: Self, other: anytype) ScalarType {
            return self.val[0] * other.val[0] + self.val[1] * other.val[1] + self.val[2] * other.val[2];
        }

        pub inline fn determinant2d(self: Self, other: Self) ScalarType {
            return self.val[0] * other.val[1] - other.val[0] * self.val[1];
        }

        pub inline fn cross(self: Self, other: Self) Self {
            return Self { .val = @Vector(length, ScalarType){
                self.val[1] * other.val[2] - self.val[2] * other.val[1],
                self.val[2] * other.val[0] - self.val[0] * other.val[2],
                self.val[0] * other.val[1] - self.val[1] * other.val[0]
            }};
        }

    // ------------------------------------------------------------------------------------------------------------ size

        pub inline fn size(self: Self) ScalarType {
            return @sqrt(@reduce(.Add, self.val * self.val));
        }

        pub inline fn sizeSq(self: Self) ScalarType {
            return @reduce(.Add, self.val * self.val);
        }

        pub inline fn size2d(self: Self) ScalarType {
            return @sqrt(self.val[0] * self.val[0] + self.val[1] * self.val[1]);
        }

        pub inline fn sizeSq2d(self: Self) ScalarType {
            return self.val[0] * self.val[0] + self.val[1] * self.val[1];
        }

        pub inline fn size3d(self: Self) ScalarType {
            return @sqrt(self.val[0] * self.val[0] + self.val[1] * self.val[1] + self.val[2] * self.val[2]);
        }

        pub inline fn sizeSq3d(self: Self) ScalarType {
            return self.val[0] * self.val[0] + self.val[1] * self.val[1] + self.val[2] * self.val[2];
        }

    // -------------------------------------------------------------------------------------------------------- distance

        pub inline fn dist(self: Self, other: Self) ScalarType {
            const diff = self.val - other.val;
            return @sqrt(@reduce(.Add, diff * diff));
        }

        pub inline fn distSq(self: Self, other: Self) ScalarType {
            const diff = self.val - other.val;
            return @reduce(.Add, diff * diff);
        }

        pub inline fn dist2d(self: Self, other: anytype) ScalarType {
            const diff = @Vector(2, ScalarType){self.val[0] - other.val[0], self.val[1] - other.val[1]};
            return @sqrt(@reduce(.Add, diff * diff));
        }

        pub inline fn distSq2d(self: Self, other: anytype) ScalarType {
            const diff = @Vector(2, ScalarType){self.val[0] - other.val[0], self.val[1] - other.val[1]};
            return @reduce(.Add, diff * diff);
        }

        pub inline fn dist3d(self: Self, other: anytype) ScalarType {
            const diff = @Vector(3, ScalarType){self.val[0] - other.val[0], self.val[1] - other.val[1], self.val[2] - other.val[2]};
            return @sqrt(@reduce(.Add, diff * diff));
        }

        pub inline fn distSq3d(self: Self, other: anytype) ScalarType {
            const diff = @Vector(3, ScalarType){self.val[0] - other.val[0], self.val[1] - other.val[1], self.val[2] - other.val[2]};
            return @reduce(.Add, diff * diff);
        }

    // ---------------------------------------------------------------------------------------------------------- normal

        pub inline fn normSafe(self: Self) Self {
            const size_sq = self.sizeSq();
            if (size_sq < @TypeOf(self).epsilonStatic()) {
                return Self.new();
            }
            return self.sMulc(1.0 / @sqrt(size_sq));
        }

        pub inline fn normUnsafe(self: Self) Self {
            return self.sMulc(1.0 / self.size());
        }

        pub inline fn isNorm(self: Self) bool {
            return @fabs(1.0 - self.sizeSq()) < @TypeOf(self).epsilonStatic();
        }

    // -------------------------------------------------------------------------------------------------------- internal

        inline fn vAddcLoop(vec_a: Self, vec_b: anytype) Self {
            var add_vec = vec_a;
            inline for(0..@min(@TypeOf(vec_b).componentLenStatic(), length)) |i| {
                add_vec.val[i] = vec_a.val[i] + vec_b.val[i];
            }
            return add_vec;
        }


        inline fn vAddLoop(vec_a: *Self, vec_b: anytype) void {
            inline for(0..@min(@TypeOf(vec_b).componentLenStatic(), length)) |i| {
                vec_a.val[i] += vec_b.val[i];
            }
        }

        inline fn vSubcLoop(vec_a: Self, vec_b: anytype) Self {
            var add_vec = vec_a;
            inline for(0..@min(@TypeOf(vec_b).componentLenStatic(), length)) |i| {
                add_vec.val[i] = vec_a.val[i] - vec_b.val[i];
            }
            return add_vec;
        }

        inline fn vSubLoop(vec_a: *Self, vec_b: anytype) void {
            inline for(0..@min(@TypeOf(vec_b).componentLenStatic(), length)) |i| {
                vec_a.val[i] -= vec_b.val[i];
            }
        }

        inline fn vMulcLoop(vec_a: Self, vec_b: anytype) Self {
            var add_vec = vec_a;
            inline for(0..@min(@TypeOf(vec_b).componentLenStatic(), length)) |i| {
                add_vec.val[i] = vec_a.val[i] * vec_b.val[i];
            }
            return add_vec;
        }


        inline fn vMulLoop(vec_a: *Self, vec_b: anytype) void {
            inline for(0..@min(@TypeOf(vec_b).componentLenStatic(), length)) |i| {
                vec_a.val[i] *= vec_b.val[i];
            }
        }


        inline fn vDivcLoop(vec_a: Self, vec_b: anytype) Self {
            var add_vec = vec_a;
            inline for(0..@min(@TypeOf(vec_b).componentLenStatic(), length)) |i| {
                add_vec.val[i] = vec_a.val[i] / vec_b.val[i];
            }
            return add_vec;
        }


        inline fn vDivLoop(vec_a: *Self, vec_b: anytype) void {
            inline for(0..@min(@TypeOf(vec_b).componentLenStatic(), length)) |i| {
                vec_a.val[i] /= vec_b.val[i];
            }
        }

    };
}

pub const fRay = struct {
    origin: fVec3 = undefined,
    normal: fVec3 = undefined,

    pub inline fn new() fRay {
        return fRay{
            .origin = fVec3.new(),
            .normal = fVec3.init(.{1.0, 0.0, 0.0})
        };
    }

    pub inline fn fromNorm(in_normal: fVec3) !fRay {
        if (!in_normal.isNorm()) {
            return NDMathError.RayNormalNotNormalized;
        }
        return fRay {
            .origin = fVec3.new(),
            .normal = in_normal
        };
    }

    pub inline fn fromComponents(in_origin: fVec3, in_normal: fVec3) !fRay {
        if (!in_normal.isNorm()) {
            return NDMathError.RayNormalNotNormalized;
        }
        return fRay {
            .origin = in_origin,
            .normal = in_normal
        };
    }
};

pub const fPlane = struct {

    normal: fVec3 = undefined,
    w: f32 = undefined,

    pub inline fn new() fPlane {
        return fPlane{
            .normal = fVec3.init(.{1.0, 0.0, 0.0}),
            .w = 0.0
        };
    }

    pub inline fn fromNorm(norm: fVec3) !fPlane {
        if (!norm.isNorm()) {
            return NDMathError.PlaneNormalNotNormalized;
        }
        return fPlane {
            .normal = norm,
            .w = 0.0
        };
    }

    pub inline fn fromComponents(norm: fVec3, origin_distance: f32) !fPlane {
        if (!norm.isNorm()) {
            return NDMathError.PlaneNormalNotNormalized;
        }
        return fPlane {
            .normal = norm,
            .w = origin_distance
        };
    }

    pub inline fn setNormFromVec(self: *fPlane, vec: fVec3) !void {
        const norm_vec = vec.normSafe();
        // vec could have components that are too small to normalize
        if (!norm_vec.isNorm()) {
            return NDMathError.PlaneNormalNotNormalized;
        }
        self.normal = norm_vec;
    }

    pub inline fn setOriginDistance(self: *fPlane, origin_distance: f32) void {
        self.w = origin_distance;
    }

    pub inline fn setComponents(self: *fPlane, norm: fVec3, origin_distance: f32) !void {
        if (!norm.isNorm()) {
            return NDMathError.PlaneNormalNotNormalized;
        }
        self.normal = norm;
        self.w = origin_distance;
    }

    pub inline fn normX(self: *const fPlane) f32 {
        return self.normal.val[0];
    }

    pub inline fn normY(self: *const fPlane) f32 {
        return self.normal.val[1];
    }

    pub inline fn normZ(self: *const fPlane) f32 {
        return self.normal.val[2];
    }

    pub inline fn originDistance(self: *const fPlane) f32 {
        return self.w;
    }

    // -------------------------------------------------------------------------------------------------- linear algebra

    pub inline fn pNormalDot(self: fPlane, other: fPlane) f32 {
        return self.normal.dot(other.normal);
    }

    pub inline fn vNormalDot(self: fPlane, other: fVec3) f32 {
        return self.normal.dot(other);
    }

    // ---------------------------------------------------------------------------------------------- vector interaction

    pub inline fn pointDistSigned(self: fPlane, point: fVec3) f32 {
        return -(self.normal.dot(point) - self.w);
    }

    pub inline fn pointDist(self: fPlane, point: fVec3) f32 {
        return @fabs(self.pointDistSigned(point));
    }

    pub inline fn pointDiff(self: fPlane, point: fVec3) f32 {
        const dist = self.pointDistSigned(point);
        return fVec3.init(.{
            self.normal.val[0] * dist,
            self.normal.val[1] * dist,
            self.normal.val[2] * dist,
        });
    }

    pub inline fn pointProject(self: fPlane, point: fVec3) f32 {
        const dist = self.pointDistSigned(point);
        return fVec3.init(.{
            point.val[0] + self.normal.val[0] * dist,
            point.val[1] + self.normal.val[1] * dist,
            point.val[2] + self.normal.val[2] * dist,
        });
    }

    pub inline fn pointMirror(self: fPlane, point: fVec3) f32 {
        const double_diff = self.pointDiff(point).sMulc(2.0);
        return point.vAddc(double_diff);
    }

    pub inline fn reflect(self: fPlane, vec: fVec3) f32 {
        const reflect_dist = self.vNormalDot(vec) * -2.0;
        const reflect_diff = self.normal.sMulc(reflect_dist);
        return vec.vAddc(reflect_diff);
    }

    pub fn rayIntersect(self: fPlane, ray: fRay, distance: *f32) ?fVec3 {
        const normal_direction_product = self.vNormalDot(ray.normal);
        if (normal_direction_product >= -F32_EPSILON) {
            return null;
        }

        const normal_origin_product = self.vNormalDot(ray.origin);
        distance.* = normal_origin_product - self.w;

        if (distance.* < 0.0) {
            return null;
        }

        distance.* = distance.* / -normal_direction_product;
        const diff = ray.normal.sMulc(distance.*);
        return ray.origin.vAddc(diff);
    }

    pub fn rayIntersectEitherFace(self: fPlane, ray: fRay, distance: *f32) ?fVec3 {
        const normal_origin_product = self.vNormalDot(ray.origin);
        const normal_direction_product = self.vNormalDot(ray.normal);
        distance.* = (normal_origin_product - self.w) / -normal_direction_product;

        if (distance.* < 0.0) {
            return null;
        }

        const diff = ray.normal.sMulc(distance.*);
        return ray.origin.vAddc(diff);
    }
};
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------- Vec2
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const Vec2 = struct {

    x: f32 = 0.0,
    y: f32 = 0.0,

    pub inline fn new() Vec2 {
        return Vec2 {};
    }

    pub inline fn fill(val: f32) Vec2 {
        return Vec2 { .x = val, .y = val };
    }

    pub inline fn fromVec3(vec: Vec3) Vec2 {
        return Vec2 { .x = vec.x, .y = vec.y };
    }

    pub inline fn init(in_x: f32, in_y: f32) Vec2 {
        return Vec2 { .x = in_x, .y = in_y };
    }

    pub inline fn set(self: *Vec2, x: f32, y: f32) void {
        self.x = x;
        self.y = y;
    }

    pub inline fn len(self: *const Vec2) usize {
        _ = self;
        return 2;
    }

    // ------------------------------------------------------------------------------------------------------ arithmetic

    pub inline fn fAdd(self: Vec2, val: f32) Vec2 {
        return Vec2 { .x = self.x + val, .y = self.y + val };
    }

    pub inline fn fSub(self: Vec2, val: f32) Vec2 {
        return Vec2 { .x = self.x - val, .y = self.y - val };
    }

    pub inline fn fMul(self: Vec2, val: f32) Vec2 {
        return Vec2 { .x = self.x * val, .y = self.y * val };
    }

    pub inline fn fDiv(self: Vec2, val: f32) Vec2 {
        const inv_val = 1.0 / val; 
        return Vec2 { .x = self.x * inv_val, .y = self.y * inv_val };
    }

    pub inline fn add(self: Vec2, other: Vec2) Vec2 {
        return Vec2 { .x = self.x + other.x, .y = self.y + other.y };
    }

    pub inline fn sub(self: Vec2, other: Vec2) Vec2 {
        return Vec2 { .x = self.x - other.x, .y = self.y - other.y };
    }

    pub inline fn mul(self: Vec2, other: Vec2) Vec2 {
        return Vec2 { .x = self.x * other.x, .y = self.y * other.y };
    }

    pub inline fn div(self: Vec2, other: Vec2) Vec2 {
        return Vec2 { .x = self.x / other.x, .y = self.y / other.y };
    }

    pub inline fn add2d(self: Vec2, other: Vec3) Vec2 {
        return Vec2 { .x = self.x + other.x, .y = self.y + other.y };
    }

    pub inline fn sub2d(self: Vec2, other: Vec3) Vec2 {
        return Vec2 { .x = self.x - other.x, .y = self.y - other.y };
    }

    pub inline fn mul2d(self: Vec2, other: Vec3) Vec2 {
        return Vec2 { .x = self.x * other.x, .y = self.y * other.y };
    }

    pub inline fn div2d(self: Vec2, other: Vec3) Vec2 {
        return Vec2 { .x = self.x / other.x, .y = self.y / other.y };
    }

    pub inline fn fAddx(self: *Vec2, val: f32) void {
        self.x += val;
        self.y += val;
    }

    pub inline fn fSubx(self: *Vec2, val: f32) void {
        self.x -= val;
        self.y -= val;
    }

    pub inline fn fMulx(self: *Vec2, val: f32) void {
        self.x *= val;
        self.y *= val;
    }

    pub inline fn fDivx(self: *Vec2, val: f32) void {
        const inv_val = 1.0 / val; 
        self.x *= inv_val;
        self.y *= inv_val;
    }

    pub inline fn addx(self: *Vec2, other: Vec2) void {
        self.x += other.x;
        self.y += other.y;
    }

    pub inline fn subx(self: *Vec2, other: Vec2) void {
        self.x -= other.x;
        self.y -= other.y;
    }

    pub inline fn mulx(self: *Vec2, other: Vec2) void {
        self.x *= other.x;
        self.y *= other.y;
    }

    pub inline fn divx(self: *Vec2, other: Vec2) void {
        self.x /= other.x;
        self.y /= other.y;
    }

    pub inline fn addx2d(self: *Vec2, other: Vec3) void {
        self.x += other.x;
        self.y += other.y;
    }

    pub inline fn subx2d(self: *Vec2, other: Vec3) void {
        self.x -= other.x;
        self.y -= other.y;
    }

    pub inline fn mulx2d(self: *Vec2, other: Vec3) void {
        self.x *= other.x;
        self.y *= other.y;
    }

    pub inline fn divx2d(self: *Vec2, other: Vec3) void {
        self.x /= other.x;
        self.y /= other.y;
    }

    // ---------------------------------------------------------------------------------------------------------- linalg

    pub inline fn dot(self: Vec2, other: Vec2) f32 {
        return self.x * other.x + self.y * other.y;
    }

    pub inline fn dot2d(self: Vec2, other: Vec3) f32 {
        return self.x * other.x + self.y * other.y;
    }

    pub inline fn determinant(self: Vec2, other: Vec2) f32 {
        return self.x * other.y - other.x * self.y;
    }

    // ------------------------------------------------------------------------------------------------------------ size

    pub inline fn size(self: Vec2) f32 {
        return @sqrt(self.x * self.x + self.y * self.y);
    }

    pub inline fn sizeSq(self: Vec2) f32 {
        return self.x * self.x + self.y * self.y;
    }

    // -------------------------------------------------------------------------------------------------------- distance

    pub inline fn dist(self: Vec2, other: Vec2) f32 {
        const diff = Vec2 {.x = self.x - other.x, .y = self.y - other.y };
        return @sqrt(diff.x * diff.x + diff.y * diff.y);
    }

    pub inline fn distSq(self: Vec2, other: Vec2) f32 {
        const diff = Vec2 {.x = self.x - other.x, .y = self.y - other.y };
        return diff.x * diff.x + diff.y * diff.y;
    }

    pub inline fn dist2d(self: Vec2, other: Vec3) f32 {
        const diff = Vec2 {.x = self.x - other.x, .y = self.y - other.y };
        return @sqrt(diff.x * diff.x + diff.y * diff.y);
    }

    pub inline fn distSq2d(self: Vec2, other: Vec3) f32 {
        const diff = Vec2 {.x = self.x - other.x, .y = self.y - other.y };
        return diff.x * diff.x + diff.y * diff.y;
    }

    // --------------------------------------------------------------------------------------------------------- max/min

    pub inline fn maxComponent(self: Vec2) f32 {
        return if (self.x > self.y) self.x else self.y;
    }

    pub fn maxVec(self: Vec2, other: Vec2) Vec2 {
        if (self.x > other.x) {
            if (self.y > other.y) {
                return Vec2 { .x = self.x, .y = self.y };
            }
            return Vec2 { .x = self.x , .y = other.y };
        }
        else if (self.y > other.y) {
            return Vec2 { .x = other.x, .y = self.y };
        }
        return Vec2 { .x = other.x, .y = other.y };
    }

    pub inline fn minComponent(self: Vec2) f32 {
        return if (self.x < self.y) self.x else self.y;
    }
    
    pub fn minVec(self: Vec2, other: Vec2) Vec2 {
        if (self.x < other.x) {
            if (self.y < other.y) {
                return Vec2 { .x = self.x, .y = self.y };
            }
            return Vec2 { .x = self.x , .y = other.y };
        }
        else if (self.y < other.y) {
            return Vec2 { .x = other.x, .y = self.y };
        }
        return Vec2 { .x = other.x, .y = other.y };
    }

    // -------------------------------------------------------------------------------------------------------- equality

    pub inline fn exactlyEqual(self: Vec2, other: Vec2) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub inline fn nearlyEqual(self: Vec2, other: Vec2) bool {
        return self.distSq(other) < F32_EPSILON;
    }

    // ------------------------------------------------------------------------------------------------------------ sign

    pub inline fn abs(self: Vec2) Vec2 {
        return Vec2 { .x = @fabs(self.x), .y = @fabs(self.y) };
    }

    pub inline fn flip(self: Vec2) Vec2 {
        return Vec2 {.x = -self.x, .y = -self.y };
    }

    pub inline fn absx(self: *Vec2) void {
        self.x = @fabs(self.x);
        self.y = @fabs(self.y);
    }

    pub inline fn flipx(self: *Vec2) void {
        self.x = -self.x;
        self.y = -self.y;
    }

    // ---------------------------------------------------------------------------------------------------------- normal

    pub inline fn normSafe(self: Vec2) Vec2 {
        const sq_sz = self.sizeSq();
        if (sq_sz < F32_EPSILON) {
            return Vec2{};
        }
        return self.fDiv(@sqrt(sq_sz));
    }

    pub inline fn normUnsafe(self: Vec2) Vec2 {
        return self.fDiv(self.size());
    }

    pub inline fn isNorm(self: Vec2) bool {
        return @fabs(1.0 - self.sizeSq()) < F32_EPSILON;
    }

    // ----------------------------------------------------------------------------------------------------------- clamp

    pub inline fn clamp(self: Vec2, min: f32, max: f32) Vec2 {
        return Vec2 {
            .x = math.clamp(self.x, min, max),
            .y = math.clamp(self.y, min, max)
        };
    }

    pub fn clampSize(self: Vec2, max_size: f32) Vec2 {
        const max_size_sq = max_size * max_size;
        const cur_size_sq = self.sizeSq();
        if (cur_size_sq > max_size_sq + F32_EPSILON) {
            const cur_size = @sqrt(cur_size_sq);
            return self.fMul(max_size / cur_size);
        }
        return self;
    }

    pub inline fn clampx(self: *Vec2, min: f32, max: f32) Vec2 {
        self.x = math.clamp(self.x, min, max);
        self.y = math.clamp(self.y, min, max);
    }

    pub fn clampSizex(self: *Vec2, max_size: f32) void {
        const max_size_sq = max_size * max_size;
        const cur_size_sq = self.sizeSq();
        if (cur_size_sq > max_size_sq + F32_EPSILON) {
            const cur_size = @sqrt(cur_size_sq);
            self.fMulx(max_size / cur_size);
        }
    }

    // ---------------------------------------------------------------------------------------------------- trigonometry

    pub inline fn cosAngle(self: Vec2, other: Vec2) f32 {
        const size_product = self.size() * other.size();
        return self.dot(other) / size_product;
    }

    pub inline fn angle(self: Vec2, other: Vec2) f32 {
        const size_product = self.size() * other.size();
        return math.acos(self.dot(other) / size_product);
    }

    // ------------------------------------------------------------------------------------------------------ projection

    pub inline fn projectOnto(self: Vec2, onto_vec: Vec2) Vec2 {
        const inner_product = self.dot(onto_vec);
        const other_size_sq = onto_vec.sizeSq();
        return onto_vec.fMul(inner_product / other_size_sq);
    }

    pub inline fn projectOntoNorm(self: Vec2, onto_normalized_vec: Vec2) Vec2 {
        const inner_product = self.dot(onto_normalized_vec);
        return onto_normalized_vec.fMul(inner_product);
    }

    // ------------------------------------------------------------------------------------------------------- direction

    pub inline fn nearlyParallelNorm(self: Vec2, other: Vec2) bool {
        return self.dot(other) > (1.0 - F32_EPSILON);
    }

    pub inline fn nearlyParallel(self: Vec2, other: Vec2) bool {
        const self_norm = self.normSafe();
        const other_norm = other.normSafe();
        return self_norm.dot(other_norm) > (1.0 - F32_EPSILON);
    }

    pub inline fn similarDir(self: Vec2, other: Vec2) bool {
        return self.dot(other) > F32_EPSILON;
    }

    pub inline fn similarDirByTolerance(self: Vec2, other: Vec2, tolerance: f32) bool {
        return self.dot(other) > (1.0 - tolerance);
    }

    // normalizes self and other, then checks if the two are at least nearly orthogonal. note that the zero vector
    // is orthogonal to all vectors including itself.
    pub inline fn nearlyOrthogonal(self: Vec2, other: Vec2) bool {
        const self_norm = self.normSafe();
        const other_norm = other.normSafe();
        return @fabs(self_norm.dot(other_norm)) < F32_EPSILON;
    }

    // assumes normality and checks if the two vectors are at least nearly orthogonal. note that the zero vector is
    // orthogonal to all vectors including itself.
    pub inline fn nearlyOrthogonalNorm(self: Vec2, other: Vec2) bool {
        return @fabs(self.dot(other)) < F32_EPSILON;
    }

    // ----------------------------------------------------------------------------------------- array.zig functionality

    pub inline fn matches(self: Vec2, other: Vec2) bool {
        return self.exactlyEqual(other);
    }

};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------- Vec3
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const Vec3 = struct {

    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,

    pub inline fn new() Vec3 {
        return Vec3 {};
    }

    pub inline fn fill(val: f32) Vec3 {
        return Vec3 { .x = val, .y = val, .z = val };
    }

    pub inline fn fromVec2(vec: Vec2) Vec3 {
        return Vec3 { .x = vec.x, .y = vec.y };
    }

    pub inline fn init(in_x: f32, in_y: f32, in_z: f32) Vec3 {
        return Vec3 { .x = in_x, .y = in_y, .z = in_z};
    }

    pub inline fn set(self: *Vec3, x: f32, y: f32, z: f32) void {
        self.x = x;
        self.y = y;
        self.z = z;
    }

    pub inline fn len(self: *const Vec3) usize {
        _ = self;
        return 3;
    }

    // ------------------------------------------------------------------------------------------------------ arithmetic

    pub inline fn fAdd(self: Vec3, val: f32) Vec3 {
        return Vec3 { .x = self.x + val, .y = self.y + val, .z = self.z + val };
    }

    pub inline fn fSub(self: Vec3, val: f32) Vec3 {
        return Vec3 { .x = self.x - val, .y = self.y - val, .z = self.z - val };
    }

    pub inline fn fMul(self: Vec3, val: f32) Vec3 {
        return Vec3 { .x = self.x * val, .y = self.y * val, .z = self.z * val };
    }

    pub inline fn fDiv(self: Vec3, val: f32) Vec3 {
        const inv_val = 1.0 / val; 
        return Vec3 { .x = self.x * inv_val, .y = self.y * inv_val, .z = self.z * inv_val };
    }

    pub inline fn add(self: Vec3, other: Vec3) Vec3 {
        return Vec3 { .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
    }

    pub inline fn sub(self: Vec3, other: Vec3) Vec3 {
        return Vec3 { .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
    }

    pub inline fn mul(self: Vec3, other: Vec3) Vec3 {
        return Vec3 { .x = self.x * other.x, .y = self.y * other.y, .z = self.z * other.z };
    }

    pub inline fn div(self: Vec3, other: Vec3) Vec3 {
        return Vec3 { .x = self.x / other.x, .y = self.y / other.y, .z = self.z / other.z };
    }

    pub inline fn add2d(self: Vec3, other: anytype) Vec3 {
        return Vec3 { .x = self.x + other.x, .y = self.y + other.y, .z = self.z };
    }

    pub inline fn sub2d(self: Vec3, other: anytype) Vec3 {
        return Vec3 { .x = self.x - other.x, .y = self.y - other.y, .z = self.z };
    }

    pub inline fn mul2d(self: Vec3, other: anytype) Vec3 {
        return Vec3 { .x = self.x * other.x, .y = self.y * other.y, .z = self.z };
    }

    pub inline fn div2d(self: Vec3, other: anytype) Vec3 {
        return Vec3 { .x = self.x / other.x, .y = self.y / other.y, .z = self.z };
    }

    pub inline fn fAddx(self: *Vec3, val: f32) void {
        self.x += val;
        self.y += val;
        self.z += val;
    }

    pub inline fn fSubx(self: *Vec3, val: f32) void {
        self.x -= val;
        self.y -= val;
        self.z -= val;
    }

    pub inline fn fMulx(self: *Vec3, val: f32) void {
        self.x *= val;
        self.y *= val;
        self.z *= val;
    }

    pub inline fn fDivx(self: *Vec3, val: f32) void {
        const inv_val = 1.0 / val; 
        self.x *= inv_val;
        self.y *= inv_val;
        self.z *= inv_val;
    }

    pub inline fn addx(self: *Vec3, other: Vec3) void {
        self.x += other.x;
        self.y += other.y;
        self.z += other.z;
    }

    pub inline fn subx(self: *Vec3, other: Vec3) void {
        self.x -= other.x;
        self.y -= other.y;
        self.z -= other.z;
    }

    pub inline fn mulx(self: *Vec3, other: Vec3) void {
        self.x *= other.x;
        self.y *= other.y;
        self.z *= other.z;
    }

    pub inline fn divx(self: *Vec3, other: Vec3) void {
        self.x /= other.x;
        self.y /= other.y;
        self.z /= other.z;
    }

    pub inline fn addx2d(self: *Vec3, other: anytype) void {
        self.x += other.x;
        self.y += other.y;
    }

    pub inline fn subx2d(self: *Vec3, other: anytype) void {
        self.x -= other.x;
        self.y -= other.y;
    }

    pub inline fn mulx2d(self: *Vec3, other: anytype) void {
        self.x *= other.x;
        self.y *= other.y;
    }

    pub inline fn divx2d(self: *Vec3, other: anytype) void {
        self.x /= other.x;
        self.y /= other.y;
    }

    // ---------------------------------------------------------------------------------------------------------- linalg

    pub inline fn dot(self: Vec3, other: Vec3) f32 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub inline fn dot2d(self: Vec3, other: anytype) f32 {
        return self.x * other.x + self.y * other.y;
    }

    pub inline fn cross(self: Vec3, other: Vec3) Vec3 {
        return Vec3{ 
            .x = self.y * other.z - self.z * other.y,
            .y = self.z * other.x - self.x * other.z,
            .z = self.x * other.y - self.y * other.x
        };
    }

    // ------------------------------------------------------------------------------------------------------------ size

    pub inline fn size(self: Vec3) f32 {
        return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    pub inline fn sizeSq(self: Vec3) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub inline fn size2d(self: Vec3) f32 {
        return @sqrt(self.x * self.x + self.y * self.y);
    }

    pub inline fn sizeSq2d(self: Vec3) f32 {
        return self.x * self.x + self.y * self.y;
    }


    // -------------------------------------------------------------------------------------------------------- distance

    pub inline fn dist(self: Vec3, other: Vec3) f32 {
        const diff = Vec3 {.x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
        return @sqrt(diff.x * diff.x + diff.y * diff.y + diff.z * diff.z );
    }

    pub inline fn distSq(self: Vec3, other: Vec3) f32 {
        const diff = Vec3 {.x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
        return diff.x * diff.x + diff.y * diff.y + diff.z * diff.z;
    }

    pub inline fn dist2d(self: Vec3, other: anytype) f32 {
        const diff = Vec2 {.x = self.x - other.x, .y = self.y - other.y };
        return @sqrt(diff.x * diff.x + diff.y * diff.y);
    }

    pub inline fn distSq2d(self: Vec3, other: anytype) f32 {
        const diff = Vec2 {.x = self.x - other.x, .y = self.y - other.y };
        return diff.x * diff.x + diff.y * diff.y;
    }

    // --------------------------------------------------------------------------------------------------------- max/min

    pub fn maxComponent(self: Vec3) f32 {
        if (self.x > self.y) {
            if (self.x > self.z) {
                return self.x;
            }
            return self.z;
        }
        else if (self.y > self.z) {
            return self.y;
        }
        return self.z;
    }

    pub fn minComponent(self: Vec3) f32 {
        if (self.x < self.y) {
            if (self.x < self.z) {
                return self.x;
            }
            return self.z;
        }
        else if (self.y < self.z) {
            return self.y;
        }
        return self.z;
    }

    // -------------------------------------------------------------------------------------------------------- equality

    pub inline fn exactlyEqual(self: Vec3, other: Vec3) bool {
        return self.x == other.x and self.y == other.y and self.z == other.z;
    }

    pub inline fn nearlyEqual(self: Vec3, other: Vec3) bool {
        return self.distSq(other) < F32_EPSILON;
    }

    // ------------------------------------------------------------------------------------------------------------ sign

    pub inline fn abs(self: Vec3) Vec3 {
        return Vec3 { .x = @fabs(self.x), .y = @fabs(self.y), .z = @fabs(self.z) };
    }

    pub inline fn flip(self: Vec3) Vec3 {
        return Vec3 {.x = -self.x, .y = -self.y, .z = -self.z };
    }

    pub inline fn absx(self: *Vec3) void {
        self.x = @fabs(self.x);
        self.y = @fabs(self.y);
        self.z = @fabs(self.z);
    }

    pub inline fn flipx(self: *Vec3) void {
        self.x = -self.x;
        self.y = -self.y;
        self.z = -self.z;
    }

    // ---------------------------------------------------------------------------------------------------------- normal

    pub inline fn normSafe(self: Vec3) Vec3 {
        const sq_sz = self.sizeSq();
        if (sq_sz < F32_EPSILON) {
            return Vec3{};
        }
        return self.fDiv(@sqrt(sq_sz));
    }

    pub inline fn normUnsafe(self: Vec3) Vec3 {
        return self.fDiv(self.size());
    }

    pub inline fn isNorm(self: Vec3) bool {
        return @fabs(1.0 - self.sizeSq()) < F32_EPSILON;
    }

    // ----------------------------------------------------------------------------------------------------------- clamp

    pub inline fn clamp(self: Vec3, min: f32, max: f32) Vec3 {
        return Vec3 {
            .x = math.clamp(self.x, min, max),
            .y = math.clamp(self.y, min, max),
            .z = math.clamp(self.z, min, max)
        };
    }

    pub fn clampSize(self: Vec3, max_size: f32) Vec3 {
        const max_size_sq = max_size * max_size;
        const cur_size_sq = self.sizeSq();
        if (cur_size_sq > max_size_sq) {
            const cur_size = @sqrt(cur_size_sq);
            return self.fMul(max_size / cur_size);
        }
        return self;
    }

    pub inline fn clampx(self: *Vec2, min: f32, max: f32) void {
        self.x = math.clamp(self.x, min, max);
        self.y = math.clamp(self.y, min, max);
        self.z = math.clamp(self.z, min, max);
    }

    pub fn clampSizex(self: *Vec2, max_size: f32) void {
        const max_size_sq = max_size * max_size;
        const cur_size_sq = self.sizeSq();
        if (cur_size_sq > max_size_sq + F32_EPSILON) {
            const cur_size = @sqrt(cur_size_sq);
            self.fMulx(max_size / cur_size);
        }
    }

    // ---------------------------------------------------------------------------------------------------- trigonometry

    pub inline fn cosAngle(self: Vec3, other: Vec3) f32 {
        const size_product = self.size() * other.size();
        return self.dot(other) / size_product;
    }

    pub inline fn angle(self: Vec3, other: Vec3) f32 {
        const size_product = self.size() * other.size();
        return math.acos(self.dot(other) / size_product);
    }

    // ------------------------------------------------------------------------------------------------------ projection

    pub inline fn projectOnto(self: Vec3, onto_vec: Vec3) Vec3 {
        const inner_product = self.dot(onto_vec);
        const other_size_sq = onto_vec.sizeSq();
        return onto_vec.fMul(inner_product / other_size_sq);
    }

    pub inline fn projectOntoNorm(self: Vec3, onto_normalized_vec: Vec3) Vec3 {
        const inner_product = self.dot(onto_normalized_vec);
        return onto_normalized_vec.fMul(inner_product);
    }

    // ------------------------------------------------------------------------------------------------------- direction

    pub inline fn nearlyParallelNorm(self: Vec3, other: Vec3) bool {
        return self.dot(other) > (1.0 - F32_EPSILON);
    }

    pub inline fn nearlyParallel(self: Vec3, other: Vec3) bool {
        const self_norm = self.normSafe();
        const other_norm = other.normSafe();
        return self_norm.dot(other_norm) > (1.0 - F32_EPSILON);
    }

    pub inline fn similarDir(self: Vec3, other: Vec3) bool {
        return self.dot(other) > F32_EPSILON;
    }

    pub inline fn similarDirByTolerance(self: Vec3, other: Vec3, tolerance: f32) bool {
        return self.dot(other) > (1.0 - tolerance);
    }

    pub inline fn nearlyOrthogonal(self: Vec3, other: Vec3) bool {
        const self_norm = self.normSafe();
        const other_norm = other.normSafe();
        return @fabs(self_norm.dot(other_norm)) < F32_EPSILON;
    }

    pub inline fn nearlyOrthogonalNorm(self: Vec3, other: Vec3) bool {
        return @fabs(self.dot(other)) < F32_EPSILON;
    }

    // ----------------------------------------------------------------------------------------- array.zig functionality

    pub inline fn matches(self: Vec3, other: Vec3) bool {
        return self.exactlyEqual(other);
    }

};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------- Vec4
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const Vec4 = struct {

    values: [4]f32 = .{ 0.0, 0.0, 0.0, 0.0 },

    pub inline fn new() Vec4 {
        return Vec4 {};
    }

    pub inline fn fill(val: f32) Vec4 {
        return Vec4 {.values = .{ val, val, val, val }};
    }

    pub inline fn fromVec2(vec: Vec2) Vec4 {
        return Vec4 {.values = .{ vec.x, vec.y, 0.0, 0.0 }};
    }

    pub inline fn fromVec3(vec: Vec3) Vec4 {
        return Vec4 {.values = .{ vec.x, vec.y, vec.z, 0.0 }};
    }

    pub inline fn init(in_x: f32, in_y: f32, in_z: f32, in_w: f32) Vec4 {
        return Vec4 {.values = .{ in_x, in_y, in_z, in_w }};
    }

    pub inline fn set(self: *Vec4, in_x: f32, in_y: f32, in_z: f32, in_w: f32) void {
        self.values[0] = in_x;
        self.values[1] = in_y;
        self.values[2] = in_z;
        self.values[3] = in_w;
    }

    pub inline fn len(self: *const Vec4) usize {
        _ = self;
        return 4;
    }

    // --------------------------------------------------------------------------------------------------------- getters

    pub inline fn x(self: *Vec4) f32 {
        return self.values[0];
    }

    pub inline fn y(self: *Vec4) f32 {
        return self.values[1];
    }

    pub inline fn z(self: *Vec4) f32 {
        return self.values[2];
    }

    pub inline fn w(self: *Vec4) f32 {
        return self.values[3];
    }

    // ------------------------------------------------------------------------------------------------------ arithmetic

    pub inline fn fAdd(self: Vec4, val: f32) Vec4 {
        const vself : @Vector(4, f32) = self.values;
        const vvals : @Vector(4, f32) = @splat(4, val);
        return Vec4{ .values = vself + vvals };
    }

    pub inline fn fSub(self: Vec4, val: f32) Vec4 {
        const vself : @Vector(4, f32) = self.values;
        const vvals : @Vector(4, f32) = @splat(4, val);
        return Vec4{ .values = vself - vvals };
    }

    pub inline fn fMul(self: Vec4, val: f32) Vec4 {
        const vself : @Vector(4, f32) = self.values;
        const vvals : @Vector(4, f32) = @splat(4, val);
        return Vec4{ .values = vself * vvals };
    }

    pub inline fn fDiv(self: Vec4, val: f32) Vec4 {
        const inv_val = 1.0 / val; 
        const vself : @Vector(4, f32) = self.values;
        const vvals : @Vector(4, f32) = @splat(4, inv_val);
        return Vec4{ .values = vself * vvals };
    }

    pub inline fn add(self: Vec4, other: Vec4) Vec4 {
        const vself : @Vector(4, f32) = self.values;
        const vother : @Vector(4, f32) = other.values;
        return Vec4{ .values = vself + vother };
    }

    pub inline fn sub(self: Vec4, other: Vec4) Vec4 {
        const vself : @Vector(4, f32) = self.values;
        const vother : @Vector(4, f32) = other.values;
        return Vec4{ .values = vself - vother };
    }

    pub inline fn mul(self: Vec4, other: Vec4) Vec4 {
        const vself : @Vector(4, f32) = self.values;
        const vother : @Vector(4, f32) = other.values;
        return Vec4{ .values = vself * vother };
    }

    pub inline fn div(self: Vec4, other: Vec4) Vec4 {
        const vself : @Vector(4, f32) = self.values;
        const vother : @Vector(4, f32) = other.values;
        return Vec4{ .values = vself / vother };
    }

    // pub inline fn add2d(self: Vec4, other: anytype) Vec4 {
    //     return Vec4 { .x = self.x + other.x, .y = self.y + other.y, .z = self.z, .w = self.w };
    // }

    // pub inline fn sub2d(self: Vec4, other: anytype) Vec4 {
    //     return Vec4 { .x = self.x - other.x, .y = self.y - other.y, .z = self.z, .w = self.w };
    // }

    // pub inline fn mul2d(self: Vec4, other: anytype) Vec4 {
    //     return Vec4 { .x = self.x * other.x, .y = self.y * other.y, .z = self.z, .w = self.w };
    // }

    // pub inline fn div2d(self: Vec4, other: anytype) Vec4 {
    //     return Vec4 { .x = self.x / other.x, .y = self.y / other.y, .z = self.z, .w = self.w };
    // }

    // pub inline fn add3d(self: Vec4, other: anytype) Vec4 {
    //     return Vec4 { .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z, .w = self.w };
    // }

    // pub inline fn sub3d(self: Vec4, other: anytype) Vec4 {
    //     return Vec4 { .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z, .w = self.w };
    // }

    // pub inline fn mul3d(self: Vec4, other: anytype) Vec4 {
    //     return Vec4 { .x = self.x * other.x, .y = self.y * other.y, .z = self.z * other.z, .w = self.w };
    // }

    // pub inline fn div3d(self: Vec4, other: anytype) Vec4 {
    //     return Vec4 { .x = self.x / other.x, .y = self.y / other.y, .z = self.z / other.z, .w = self.w };
    // }

    // pub inline fn fAddx(self: *Vec4, val: f32) void {
    //     const 
    //     self.x += val;
    //     self.y += val;
    //     self.z += val;
    //     self.w += val;
    // }

    // pub inline fn fSubx(self: *Vec4, val: f32) void {
    //     self.x -= val;
    //     self.y -= val;
    //     self.z -= val;
    //     self.w -= val;
    // }

    // pub inline fn fMulx(self: *Vec4, val: f32) void {
    //     self.x *= val;
    //     self.y *= val;
    //     self.z *= val;
    //     self.w *= val;
    // }

    // pub inline fn fDivx(self: *Vec4, val: f32) void {
    //     const inv_val = 1.0 / val; 
    //     self.x *= inv_val;
    //     self.y *= inv_val;
    //     self.z *= inv_val;
    //     self.w *= inv_val;
    // }

    // pub inline fn addx(self: *Vec4, other: Vec4) void {
    //     self.x += other.x;
    //     self.y += other.y;
    //     self.z += other.z;
    //     self.w += other.w;
    // }

    // pub inline fn subx(self: *Vec4, other: Vec4) void {
    //     self.x -= other.x;
    //     self.y -= other.y;
    //     self.z -= other.z;
    //     self.w -= other.w;
    // }

    // pub inline fn mulx(self: *Vec4, other: Vec4) void {
    //     self.x *= other.x;
    //     self.y *= other.y;
    //     self.z *= other.z;
    //     self.w *= other.w;
    // }

    // pub inline fn divx(self: *Vec4, other: Vec4) void {
    //     self.x /= other.x;
    //     self.y /= other.y;
    //     self.z /= other.z;
    //     self.w /= other.w;
    // }

    // pub inline fn addx2d(self: *Vec4, other: anytype) void {
    //     self.x += other.x;
    //     self.y += other.y;
    // }

    // pub inline fn subx2d(self: *Vec4, other: anytype) void {
    //     self.x -= other.x;
    //     self.y -= other.y;
    // }

    // pub inline fn mulx2d(self: *Vec4, other: anytype) void {
    //     self.x *= other.x;
    //     self.y *= other.y;
    // }

    // pub inline fn divx2d(self: *Vec4, other: anytype) void {
    //     self.x /= other.x;
    //     self.y /= other.y;
    // }

    // pub inline fn addx3d(self: *Vec4, other: anytype) void {
    //     self.x += other.x;
    //     self.y += other.y;
    //     self.z += other.z;
    // }

    // pub inline fn subx3d(self: *Vec4, other: anytype) void {
    //     self.x -= other.x;
    //     self.y -= other.y;
    //     self.z -= other.z;
    // }

    // pub inline fn mulx3d(self: *Vec4, other: anytype) void {
    //     self.x *= other.x;
    //     self.y *= other.y;
    //     self.z *= other.z;
    // }

    // pub inline fn divx3d(self: *Vec4, other: anytype) void {
    //     self.x /= other.x;
    //     self.y /= other.y;
    //     self.z *= other.z;
    // }

    // // ---------------------------------------------------------------------------------------------------------- linalg

    // pub inline fn dot(self: Vec4, other: Vec4) f32 {
    //     return self.x * other.x + self.y * other.y + self.z * other.z;
    // }

    // pub inline fn dot2d(self: Vec4, other: anytype) f32 {
    //     return self.x * other.x + self.y * other.y;
    // }

    // pub inline fn cross(self: Vec4, other: Vec4) Vec4 {
    //     return Vec4{ 
    //         .x = self.y * other.z - self.z * other.y,
    //         .y = self.z * other.x - self.x * other.z,
    //         .z = self.x * other.y - self.y * other.x
    //     };
    // }

    // // ------------------------------------------------------------------------------------------------------------ size

    // pub inline fn size(self: Vec4) f32 {
    //     return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    // }

    // pub inline fn sizeSq(self: Vec4) f32 {
    //     return self.x * self.x + self.y * self.y + self.z * self.z;
    // }

    // pub inline fn size2d(self: Vec4) f32 {
    //     return @sqrt(self.x * self.x + self.y * self.y);
    // }

    // pub inline fn sizeSq2d(self: Vec4) f32 {
    //     return self.x * self.x + self.y * self.y;
    // }


    // // -------------------------------------------------------------------------------------------------------- distance

    // pub inline fn dist(self: Vec4, other: Vec4) f32 {
    //     const diff = Vec4 {.x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
    //     return @sqrt(diff.x * diff.x + diff.y * diff.y + diff.z * diff.z );
    // }

    // pub inline fn distSq(self: Vec4, other: Vec4) f32 {
    //     const diff = Vec4 {.x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
    //     return diff.x * diff.x + diff.y * diff.y + diff.z * diff.z;
    // }

    // pub inline fn dist2d(self: Vec4, other: anytype) f32 {
    //     const diff = Vec2 {.x = self.x - other.x, .y = self.y - other.y };
    //     return @sqrt(diff.x * diff.x + diff.y * diff.y);
    // }

    // pub inline fn distSq2d(self: Vec4, other: anytype) f32 {
    //     const diff = Vec2 {.x = self.x - other.x, .y = self.y - other.y };
    //     return diff.x * diff.x + diff.y * diff.y;
    // }

    // // --------------------------------------------------------------------------------------------------------- max/min

    // pub fn maxComponent(self: Vec4) f32 {
    //     if (self.x > self.y) {
    //         if (self.x > self.z) {
    //             return self.x;
    //         }
    //         return self.z;
    //     }
    //     else if (self.y > self.z) {
    //         return self.y;
    //     }
    //     return self.z;
    // }

    // pub fn minComponent(self: Vec4) f32 {
    //     if (self.x < self.y) {
    //         if (self.x < self.z) {
    //             return self.x;
    //         }
    //         return self.z;
    //     }
    //     else if (self.y < self.z) {
    //         return self.y;
    //     }
    //     return self.z;
    // }

    // // -------------------------------------------------------------------------------------------------------- equality

    // pub inline fn exactlyEqual(self: Vec4, other: Vec4) bool {
    //     return self.x == other.x and self.y == other.y and self.z == other.z;
    // }

    // pub inline fn nearlyEqual(self: Vec4, other: Vec4) bool {
    //     return self.distSq(other) < F32_EPSILON;
    // }

    // // ------------------------------------------------------------------------------------------------------------ sign

    // pub inline fn abs(self: Vec4) Vec4 {
    //     return Vec4 { .x = @fabs(self.x), .y = @fabs(self.y), .z = @fabs(self.z) };
    // }

    // pub inline fn flip(self: Vec4) Vec4 {
    //     return Vec4 {.x = -self.x, .y = -self.y, .z = -self.z };
    // }

    // pub inline fn absx(self: *Vec4) void {
    //     self.x = @fabs(self.x);
    //     self.y = @fabs(self.y);
    //     self.z = @fabs(self.z);
    // }

    // pub inline fn flipx(self: *Vec4) void {
    //     self.x = -self.x;
    //     self.y = -self.y;
    //     self.z = -self.z;
    // }

    // // ---------------------------------------------------------------------------------------------------------- normal

    // pub inline fn normSafe(self: Vec4) Vec4 {
    //     const sq_sz = self.sizeSq();
    //     if (sq_sz < F32_EPSILON) {
    //         return Vec4{};
    //     }
    //     return self.fDiv(@sqrt(sq_sz));
    // }

    // pub inline fn normUnsafe(self: Vec4) Vec4 {
    //     return self.fDiv(self.size());
    // }

    // pub inline fn isNorm(self: Vec4) bool {
    //     return @fabs(1.0 - self.sizeSq()) < F32_EPSILON;
    // }

    // // ----------------------------------------------------------------------------------------------------------- clamp

    // pub inline fn clamp(self: Vec4, min: f32, max: f32) Vec4 {
    //     return Vec4 {
    //         .x = math.clamp(self.x, min, max),
    //         .y = math.clamp(self.y, min, max),
    //         .z = math.clamp(self.z, min, max)
    //     };
    // }

    // pub fn clampSize(self: Vec4, max_size: f32) Vec4 {
    //     const max_size_sq = max_size * max_size;
    //     const cur_size_sq = self.sizeSq();
    //     if (cur_size_sq > max_size_sq) {
    //         const cur_size = @sqrt(cur_size_sq);
    //         return self.fMul(max_size / cur_size);
    //     }
    //     return self;
    // }

    // pub inline fn clampx(self: *Vec2, min: f32, max: f32) void {
    //     self.x = math.clamp(self.x, min, max);
    //     self.y = math.clamp(self.y, min, max);
    //     self.z = math.clamp(self.z, min, max);
    // }

    // pub fn clampSizex(self: *Vec2, max_size: f32) void {
    //     const max_size_sq = max_size * max_size;
    //     const cur_size_sq = self.sizeSq();
    //     if (cur_size_sq > max_size_sq + F32_EPSILON) {
    //         const cur_size = @sqrt(cur_size_sq);
    //         self.fMulx(max_size / cur_size);
    //     }
    // }

    // // ---------------------------------------------------------------------------------------------------- trigonometry

    // pub inline fn cosAngle(self: Vec4, other: Vec4) f32 {
    //     const size_product = self.size() * other.size();
    //     return self.dot(other) / size_product;
    // }

    // pub inline fn angle(self: Vec4, other: Vec4) f32 {
    //     const size_product = self.size() * other.size();
    //     return math.acos(self.dot(other) / size_product);
    // }

    // // ------------------------------------------------------------------------------------------------------ projection

    // pub inline fn projectOnto(self: Vec4, onto_vec: Vec4) Vec4 {
    //     const inner_product = self.dot(onto_vec);
    //     const other_size_sq = onto_vec.sizeSq();
    //     return onto_vec.fMul(inner_product / other_size_sq);
    // }

    // pub inline fn projectOntoNorm(self: Vec4, onto_normalized_vec: Vec4) Vec4 {
    //     const inner_product = self.dot(onto_normalized_vec);
    //     return onto_normalized_vec.fMul(inner_product);
    // }

    // // ------------------------------------------------------------------------------------------------------- direction

    // pub inline fn nearlyParallelNorm(self: Vec4, other: Vec4) bool {
    //     return self.dot(other) > (1.0 - F32_EPSILON);
    // }

    // pub inline fn nearlyParallel(self: Vec4, other: Vec4) bool {
    //     const self_norm = self.normSafe();
    //     const other_norm = other.normSafe();
    //     return self_norm.dot(other_norm) > (1.0 - F32_EPSILON);
    // }

    // pub inline fn similarDir(self: Vec4, other: Vec4) bool {
    //     return self.dot(other) > F32_EPSILON;
    // }

    // pub inline fn similarDirByTolerance(self: Vec4, other: Vec4, tolerance: f32) bool {
    //     return self.dot(other) > (1.0 - tolerance);
    // }

    // pub inline fn nearlyOrthogonal(self: Vec4, other: Vec4) bool {
    //     const self_norm = self.normSafe();
    //     const other_norm = other.normSafe();
    //     return @fabs(self_norm.dot(other_norm)) < F32_EPSILON;
    // }

    // pub inline fn nearlyOrthogonalNorm(self: Vec4, other: Vec4) bool {
    //     return @fabs(self.dot(other)) < F32_EPSILON;
    // }

    // // ----------------------------------------------------------------------------------------- array.zig functionality

    // pub inline fn matches(self: Vec4, other: Vec4) bool {
    //     return self.exactlyEqual(other);
    // }

};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------- Quaternion
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const Quaternion = struct {

    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    w: f32 = 1.0,

    pub fn new() Quaternion {
        return Quaternion{};
    }

    

};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------------------------------- Square Matrix
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const Identity2x2: [2][2]f32 = .{
    .{1.0, 0.0},
    .{0.0, 1.0},
};

const Identity3x3: [3][3]f32 = .{
    .{1.0, 0.0, 0.0},
    .{0.0, 1.0, 0.0},
    .{0.0, 0.0, 1.0}
};

const Identity4x4: [3][3]f32 = .{
    .{1.0, 0.0, 0.0, 0.0},
    .{0.0, 1.0, 0.0, 0.0},
    .{0.0, 0.0, 1.0, 0.0},
    .{0.0, 0.0, 0.0, 1.0}
};

const Identity5x5: [5][5]f32 = .{
    .{1.0, 0.0, 0.0, 0.0, 0.0},
    .{0.0, 1.0, 0.0, 0.0, 0.0},
    .{0.0, 0.0, 1.0, 0.0, 0.0},
    .{0.0, 0.0, 0.0, 1.0, 0.0},
    .{0.0, 0.0, 0.0, 0.0, 1.0}
};

pub fn SquareMatrix(comptime size: u32) type {

    std.debug.assert(size >= 2);

    return struct {
        const Self = @This();

        values : [size][size]f32 = undefined,

        pub fn new() Self {
            return Self{.values = std.mem.zeroes(Self)};
        }

        pub fn identity() Self {
            if (size <= 5) {
                return Self{ .values = 
                    switch(size) {
                        2 => Identity2x2,
                        3 => Identity3x3,
                        4 => Identity4x4,
                        5 => Identity5x5,
                        else => unreachable
                    }
                };
            }
            else {
                var self: Self = std.mem.zeroes(Self);
                for (0..size) |i| {
                    self.values[i][i] = 1.0;
                }
                return self;
            }
        }

        pub fn fromScaleVec(vec: anytype) Self {
            std.debug.assert(size >= vec.len());
            var self: Self = std.mem.zeroes(Self);
            switch(@TypeOf(vec)) {
                Vec2 => {
                    self.values[0][0] = vec.x;
                    self.values[1][1] = vec.y;
                    inline for (2..size) |i| {
                        self.values[i][i] = 1.0;
                    }
                },
                Vec3 => {
                    self.values[0][0] = vec.x;
                    self.values[1][1] = vec.y;
                    self.values[2][2] = vec.z;
                    inline for (3..size) |i| {
                        self.values[i][i] = 1.0;
                    }
                },
                Vec4 => {
                    self.values[0][0] = vec.values[0];
                    self.values[1][1] = vec.values[1];
                    self.values[2][2] = vec.values[2];
                    self.values[3][3] = vec.values[3];
                    inline for (4..size) |i| {
                        self.values[i][i] = 1.0;
                    }
                },
                else => unreachable
            }
            return self;
        }

        pub fn fromScalar(scalar: f32) Self {
            var self: Self = std.mem.zeroes(Self);
            inline for (0..size) |i| {
                self.values[i][i] = scalar;
            }
            return self;
        }

    };
}

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// --------------------------------------------------------------------------------------------------------------- Plane
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// A plane in three dimensions, using Ax + By + Cz - D = 0, where x, y, z are the *normalized* components corresponding
// to A, B, C, and w is the absolute value of D. In other words, x, y, z are the plane normal and w is the shortest
// distance between the plane and the origin. **Many plane operations assume x, y, z are normalized** so please make
// note of those functions if you intend on using this struct with non-normalized x, y, z.
pub const Plane = struct {

    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    w: f32 = 0.0,

    pub inline fn new() Plane {
        return Plane {};
    }

    pub inline fn fill(val: f32) Plane {
        return Plane { .x = val, .y = val, .z = val, .w = val };
    }

    pub inline fn fromVec2(vec: Vec2) Plane {
        return Plane { .x = vec.x, .y = vec.y };
    }

    pub inline fn fromVec3(vec: Vec3) Plane {
        return Plane { .x = vec.x, .y = vec.y, .z = vec.z };
    }

    pub inline fn init(in_x: f32, in_y: f32, in_z: f32, in_w: f32) Plane {
        return Plane { .x = in_x, .y = in_y, .z = in_z, .w = in_w };
    }

    pub inline fn constructWithNorm(point: Vec3, norm_dir: Vec3) Plane {
        const plane_dist = @fabs(norm_dir.dot(point));
        return Plane { .x = norm_dir.x, .y = norm_dir.y, .z = norm_dir.z, .w = plane_dist };
    }

    pub inline fn constructNormalize(point: Vec3, scaled_dir: Vec3) Plane {
        const dir = scaled_dir.normSafe();
        const plane_dist = @fabs(dir.dot(point));
        return Plane { .x = dir.x, .y = dir.y, .z = dir.z, .w = plane_dist };
    }

    pub inline fn copy(self: Plane) Plane {
        return Plane { .x = self.x, .y = self.y, .z = self.z, .w = self.w };
    }

    // ---------------------------------------------------------------------------------------------------------- linalg

    pub inline fn normalDot(self: Plane, other: Plane) f32 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub inline fn vNormalDot(self: Plane, other: Vec3) f32 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub inline fn vNormalDot2d(self: Plane, other: anytype) f32 {
        return self.x * other.x + self.y * other.y;
    }

    // ------------------------------------------------------------------------------------------------------------ size

    pub inline fn normalSize(self: Plane) f32 {
        return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    pub inline fn normalSizeSq(self: Plane) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    // --------------------------------------------------------------------------------------------------------- max/min

    pub fn normalMaxComponent(self: Plane) f32 {
        if (self.x > self.y) {
            if (self.x > self.z) {
                return self.x;
            }
            return self.z;
        }
        else if (self.y > self.z) {
            return self.y;
        }
        return self.z;
    }

    pub fn normalMinComponent(self: Plane) f32 {
        if (self.x < self.y) {
            if (self.x < self.z) {
                return self.x;
            }
            return self.z;
        }
        else if (self.y < self.z) {
            return self.y;
        }
        return self.z;
    }

    // -------------------------------------------------------------------------------------------------------- equality

    pub inline fn exactlyEqual(self: Plane, other: Plane) bool {
        return self.x == other.x and self.y == other.y and self.z == other.z and self.w == other.w;
    }

    pub inline fn nearlyEqual(self: Plane, other: Plane) bool {
        const diff = Plane {.x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z, .w = self.w - other.w };
        const size_sq = diff.x * diff.x + diff.y * diff.y + diff.z * diff.z + diff.w * diff.w;
        return size_sq < F32_EPSILON;
    }

    pub inline fn closeByTolerance(self: Plane, other: Plane, tolerance: f32) bool {
        const diff = Plane {.x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z, .w = self.w - other.w };
        const size_sq = diff.x * diff.x + diff.y * diff.y + diff.z * diff.z + diff.w * diff.w;
        return size_sq < tolerance;
    }

    // ------------------------------------------------------------------------------------------------------------ sign

    pub inline fn normalFlip(self: Plane) Plane {
        return Plane {.x = -self.x, .y = -self.y, .z = -self.z, .w = self.w };
    }

    // ---------------------------------------------------------------------------------------------------------- normal

    pub inline fn normSafe(self: Plane) Plane {
        const sq_sz = self.normalSizeSq();
        if (sq_sz < F32_EPSILON) {
            return Plane{ .w = self.w };
        }
        const inv_size = 1.0 / @sqrt(sq_sz);
        return Plane {.x = self.x * inv_size, .y = self.y * inv_size, .z = self.z * inv_size, .w = self.w };
    }

    pub inline fn normUnsafe(self: Plane) Plane {
        const inv_size = 1.0 / self.normalSize();
        return Plane {.x = self.x * inv_size, .y = self.y * inv_size, .z = self.z * inv_size, .w = self.w };
    }

    pub inline fn isNorm(self: Plane) bool {
        return @fabs(1.0 - self.normalSizeSq()) < F32_EPSILON;
    }

    // ---------------------------------------------------------------------------------------------------- trigonometry

    pub inline fn normalAngle(self: Plane, other: Plane) f32 {
        return math.acos(self.normalDot(other));
    }

    pub inline fn vNormalAngle(self: Plane, other: Vec3) f32 {
        return math.acos(self.vNormalDot(other.normSafe()));
    }

    pub inline fn vNormalAngleNorm(self: Plane, other: Vec3) f32 {
        return math.acos(self.vNormalDot(other));
    }

    // ---------------------------------------------------------------------------------------------- vector interaction

    pub inline fn pointDistSigned(self: Plane, point: Vec3) f32 {
        return -(self.x * point.x + self.y * point.y + self.z * point.z - self.w);
    }

    pub inline fn pointDist(self: Plane, point: Vec3) f32 {
        return @fabs(self.x * point.x + self.y * point.y + self.z * point.z - self.w);
    }

    pub inline fn pointDiff(self: Plane, point: Vec3) Vec3 {
        const dist = self.pointDistSigned(point);
        return Vec3 { 
            .x = self.x * dist,
            .y = self.y * dist,
            .z = self.z * dist
        };
    }

    pub inline fn pointProject(self: Plane, point: Vec3) Vec3 {
        const dist = self.pointDistSigned(point);
        return Vec3 { 
            .x = point.x + self.x * dist,
            .y = point.y + self.y * dist,
            .z = point.z + self.z * dist
        };
    }

    pub inline fn pointMirror(self: Plane, point: Vec3) Vec3 {
        const double_diff = self.pointDiff(point).fMul(2.0);
        return point.add(double_diff);
    }

    pub inline fn reflect(self: Plane, vec: Vec3) Vec3 {
        const reflect_dist = self.vNormalDot(vec) * -2.0;
        const reflect_diff = Vec3 { .x = self.x * reflect_dist, .y = self.y * reflect_dist, .z = self.z * reflect_dist };
        return vec.add(reflect_diff);
    }

    pub fn rayIntersect(self: Plane, ray: Ray, distance: *f32) ?Vec3 {
        const normal_direction_product = self.vNormalDot(ray.direction);
        if (normal_direction_product >= -F32_EPSILON) {
            return null;
        }

        const normal_origin_product = self.vNormalDot(ray.origin);
        distance.* = normal_origin_product - self.w;

        if (distance.* < 0.0) {
            return null;
        }

        distance.* = distance.* / -normal_direction_product;
        const diff = ray.direction.fMul(distance.*);
        return ray.origin.add(diff);
    }

    pub fn rayIntersectTwoFaced(self: Plane, ray: Ray, distance: *f32) ?Vec3 {
        const normal_origin_product = self.vNormalDot(ray.origin);
        distance.* = normal_origin_product - self.w;

        const normal_direction_product = self.vNormalDot(ray.direction);
        distance.* = distance.* / -normal_direction_product;

        if (distance.* < 0.0) {
            return null;
        }

        const diff = ray.direction.fMul(distance.*);
        return ray.origin.add(diff);
    }

    // ------------------------------------------------------------------------------------------------------- direction

    pub inline fn nearlyParallel(self: Plane, other: Plane) bool {
        return self.normalDot(other) > (1.0 - F32_EPSILON);
    }

    pub inline fn similarDir(self: Plane, other: Plane) bool {
        return self.normalDot(other) > F32_EPSILON;
    }

    pub inline fn similarDirByTolerance(self: Plane, other: Plane, tolerance: f32) bool {
        return self.normalDot(other) > (1.0 - tolerance);
    }

    pub inline fn nearlyOrthogonal(self: Plane, other: Plane) bool {
        return @fabs(self.normalDot(other)) < F32_EPSILON;
    }

    // ----------------------------------------------------------------------------------------- array.zig functionality

    pub inline fn matches(self: Plane, other: Plane) bool {
        return self.exactlyEqual(other);
    }

};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------------- Ray
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const Ray = struct {

    origin: Vec3 = Vec3 {},
    direction: Vec3 = Vec3 {},

    pub fn new() Ray {
        return Ray {};
    }

    pub fn constructWithNorm(origin: Vec3, norm_dir: Vec3) Ray {
        return Ray {
            .origin = origin,
            .direction = norm_dir
        };
    }

    pub fn constructNormalize(origin: Vec3, scaled_dir: Vec3) Ray {
        return Ray {
            .origin = origin,
            .direction = scaled_dir.normSafe()
        };
    }

    pub fn flip(self: *Ray) Ray {
        return Ray {
            .origin = self.origin,
            .direction = self.direction.flip()
        };
    }

    pub fn flipx(self: *Ray) void {
        self.direction.flipx();
    }

    // ----------------------------------------------------------------------------------------- array.zig functionality

    pub inline fn matches(self: Ray, other: Ray) bool {
        return self.origin.exactlyEqual(other.origin) and self.direction.exactlyEqual(other.direction);
    }

};

pub const PointIntersection = struct {
    point: Vec3 = undefined,
    distance: f32 = undefined,
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------------------------------------------------------- constants
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pub const vec2_zero = Vec2 {};
pub const vec3_zero = Vec3 {};
pub const plane_zero = Plane {};
pub const ray_zero = Ray {};
pub const quaternion_zero = Quaternion{.w = 0.0};
pub const quaternion_identity = Quaternion{};

const F32_EPSILON: f32 = 1e-5;
const F64_EPSILON: f64 = 1e-15;

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- errors
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const NDMathError = error{
    PlaneNormalNotNormalized,
    RayNormalNotNormalized,
};

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------------------------------------- import
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const std = @import("std");
const math = std.math;
const expect = std.testing.expect;
const print = std.debug.print;

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ---------------------------------------------------------------------------------------------------------------- test
// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

test "Vec2" {
    var v1 = Vec2.fill(30.0);
    var v2 = Vec2.fill(500000.0);
    try expect(v1.nearlyParallel(v2));

    v1 = v1.normUnsafe();
    v2 = v2.normSafe();
    try expect(v2.nearlyEqual(v2));
    try expect(v1.isNorm());
    try expect(v2.isNorm());

    v1.set(1.0, 0.0);
    v2.set(0.0, 0.999999);
    try expect(v1.isNorm());
    try expect(v2.isNorm());
    try expect(v1.nearlyOrthogonalNorm(v2));

    var v3 = Vec2.init(0.1, 1.1);
    v3 = v3.projectOntoNorm(v1);
    try expect(v3.nearlyParallel(v1));

    var v4 = Vec2.init(0.001, 20.0);
    try expect(v4.similarDir(v1));

    v4.x = -0.0001;
    try expect (!v4.similarDir(v1));
}

test "Vec3" {
    var v1 = Vec3.fill(30.0);
    var v2 = Vec3.fill(500000.0);
    try expect(v1.nearlyParallel(v2));

    v1 = v1.normUnsafe();
    v2 = v2.normSafe();
    try expect(v2.nearlyEqual(v2));
    try expect(v1.isNorm());
    try expect(v2.isNorm());

    v1.set(1.0, 0.0, 1.0);
    v1 = v1.normUnsafe();
    v2.set(-0.999999, 0.0, 1.0);
    v2 = v2.normUnsafe();
    try expect(v1.isNorm());
    try expect(v2.isNorm());
    try expect(v1.nearlyOrthogonalNorm(v2));

    var v3 = Vec3.init(0.1, 1.1, 0.2);
    v3 = v3.projectOntoNorm(v1);
    try expect(v3.nearlyParallel(v1));

    var v4 = Vec3.init(0.001, 20.0, 0.1);
    try expect(v4.similarDir(v1));

    v4.x = -2.0001;
    try expect (!v4.similarDir(v1));
}

test "Vec4" {
    var v1 = Vec4.new();
    _ = v1;
    var v2 = Vec4.init(0.0, 1.0, 2.0, 3.0);
    var v3 = v2.fAdd(4);
    print("\n{},{},{},{}\n", .{v3.x(), v3.y(), v3.z(), v3.w()});
}

test "SquareMatrix" {
    var m1 = SquareMatrix(3).identity();
    _ = m1;
    var m2 = SquareMatrix(4).fromScaleVec(Vec3.fill(2.0));
    print("\nmatrix 4x4: {any}\n", .{m2});
}

test "fVec" {
    var j = fVec3.init(.{0.0, 1.0, 2.0});
    var k = fVec3.initScalar(3.0);
    print("\nVec(3): {any}\n", .{j});
    print("x: {}, y: {}\n", .{j.x(), j.y()});
    var i = j.vAddc(k);
    print("{any}\n", .{i});
}

test "Plane" {
    var p1dir = Vec3.init(20.0, 31.0, -5.0);
    var p1pos = Vec3.new();
    var p1 = Plane.constructNormalize(p1pos, p1dir);
    try expect(p1.isNorm());

    var p2dir = p1dir.flip();
    var p2pos = Vec3.init(-10.0, -10.0, -20.0);
    var p2 = Plane.constructNormalize(p2pos, p2dir);
    try expect(p2.isNorm());

    var p3dir = p1dir.fMul(2.0);
    var p3pos = Vec3.init(50000.0, -20000.0, 30343.0);
    var p3 = Plane.constructNormalize(p3pos, p3dir);
    try expect(p3.isNorm());
    try expect(p1.nearlyParallel(p3));

    var p4dir = Vec3.init(1.0, 0.0, 0.0);
    var p4pos = Vec3.new();
    var p4 = Plane.constructWithNorm(p4pos, p4dir);
    try expect(p4.isNorm());

    var v5 = Vec3.init(2.0, 1.0, 0.0);
    var v5distp4 = p4.pointDist(v5);
    try expect(@fabs(v5distp4 - 2.0) <= F32_EPSILON);

    var v5diffp4 = p4.pointDiff(v5);
    var expected_diff = Vec3.init(-2.0, 0.0, 0.0);
    try expect(expected_diff.dist(v5diffp4) <= F32_EPSILON);

    var v6 = Vec3.init(5303.328, -3838383.3, 9999.0);
    v6 = p4.pointProject(v6);
    try expect(p4.pointDist(v6) <= F32_EPSILON);

    var r1pos = Vec3.init(20.0, 20.0, 20.0);
    var r1dir = Vec3.init(-50.0, 32.0, 0.0);
    var r1 = Ray.constructNormalize(r1pos, r1dir);
    var dist: f32 = undefined;
    var result = p4.rayIntersect(r1, &dist);
    try expect(result != null);

    var v7 = result.?;
    try expect(p4.pointDist(v7) <= F32_EPSILON);

    r1.flipx();
    r1.origin = p4.pointMirror(r1.origin);
    try expect(p4.rayIntersect(r1, &dist) == null);

    result = p4.rayIntersectTwoFaced(r1, &dist);
    try expect(result != null);

    var v8 = result.?;
    try expect(p4.pointDist(v8) <= F32_EPSILON);
    
    var v9 = Vec3.init(20.9, 30.2, 15.0);
    var v9distp2 = p2.pointDist(v9);
    var v10 = p2.pointMirror(v9);
    var v10distp2 = p2.pointDist(v10);
    try expect(@fabs(v9distp2 - v10distp2) <= 0.0001);

    var v11 = p2.reflect(v9);
    var v9angle = p2.vNormalAngle(v9);
    var v11angle = p2.vNormalAngle(v11);
    try expect(@fabs(v9angle + v11angle - math.pi) <= F32_EPSILON);

}