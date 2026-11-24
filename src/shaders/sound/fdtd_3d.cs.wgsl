struct Uniforms {
    micpos: vec3<i32>,
    dims: vec3<i32>,
    kv: f32,
    kp: f32,
    numiters: u32,
    numsources: u32,
};

struct Source { 
    x: i32, 
    y: i32, 
    z: i32, 
    pressure: f32, 
    time: i32 
};


@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var<storage, read_write> sources: array<Source>;
@group(0) @binding(2) var<storage, read_write> pressures: array<vec4<f32>>; // px, py, pz, p
@group(0) @binding(3) var<storage, read_write> velocities: array<vec4<f32>>; // vx, vy, vz, _
@group(0) @binding(4) var<storage, read_write> solids: array<f32>;
@group(0) @binding(5) var<storage, read_write> recording: array<f32>;
@group(0) @binding(6) var<storage, read_write> stepcounter: vec4<u32>;
@group(0) @binding(7) var<storage, read_write> pml: array<f32>;

// get pml things

//offsets for x y and z
fn offsetx() -> i32 { return 0; }
fn offsety() -> i32 { return 4 * uniforms.dims.x; }
fn offsetz() -> i32 { return 4 * (uniforms.dims.x + uniforms.dims.y); }

fn a_vx(x: i32) -> f32 { return pml[offsetx() + x]; }
fn b_vx(x: i32) -> f32 { return pml[offsetx() + uniforms.dims.x + x]; }
fn a_px(x: i32) -> f32 { return pml[offsetx() + 2 * uniforms.dims.x + x]; }
fn b_px(x: i32) -> f32 { return pml[offsetx() + 3 * uniforms.dims.x + x]; }

fn a_vy(y: i32) -> f32 { return pml[offsety() + y]; }
fn b_vy(y: i32) -> f32 { return pml[offsety() + uniforms.dims.y + y]; }
fn a_py(y: i32) -> f32 { return pml[offsety() + 2 * uniforms.dims.y + y]; }
fn b_py(y: i32) -> f32 { return pml[offsety() + 3 * uniforms.dims.y + y]; }

fn a_vz(z: i32) -> f32 { return pml[offsetz() + z]; }
fn b_vz(z: i32) -> f32 { return pml[offsetz() + uniforms.dims.z + z]; }
fn a_pz(z: i32) -> f32 { return pml[offsetz() + 2 * uniforms.dims.z + z]; }
fn b_pz(z: i32) -> f32 { return pml[offsetz() + 3 * uniforms.dims.z + z]; }

// helper
fn get_3d_idx(x:i32, y:i32, z: i32)->u32
{
    return u32(x + y * uniforms.dims.x + z * uniforms.dims.x * uniforms.dims.y);
}

@compute @workgroup_size(64)
fn inject_sound_in_grid(@builtin(global_invocation_id) g: vec3<u32>)
{
    let i = u32(g.x);

    // see if we are in the range
    if (i >= uniforms.numsources) {return;}
    let source = sources[i];

    // check the time, if the time is not rn, then return.
    if (u32(source.time) != stepcounter[0]) {return;}

    // check to see if the source is within bounds
    if (source.x < 0 || source.x >= uniforms.dims.x 
    || source.y < 0 || source.y >= uniforms.dims.y
    || source.z < 0 || source.z >= uniforms.dims.z) {return;}

    // if it is rn, then inject the sound by adding the pressure into pressures
    let p_idx = get_3d_idx(source.x, source.y, source.z);
    var pressure = pressures[p_idx];

    pressure.x += source.pressure * 0.34; // divide pressure up into 2 per axis
    pressure.y += source.pressure * 0.33;
    pressure.z += source.pressure * 0.33;
    pressure.w += source.pressure; // total pressure

    pressures[p_idx] = pressure;
}

@compute @workgroup_size(16, 4, 4) 
fn update_velocities(@builtin(global_invocation_id) g: vec3<u32>)
{
    let x = i32(g.x);
    let y = i32(g.y);
    let z = i32(g.z);

    // check to see if idx in bounds
    if ( x >= uniforms.dims.x || y >= uniforms.dims.y || z >= uniforms.dims.z) {return;}

    // velocity update

    let xyz = get_3d_idx(x, y, z);
    var v = velocities[xyz];
    // todo: integrate with pml later
    if (x > 0) {
        let xm1yz = get_3d_idx(x - 1, y, z);
        let dpdx = pressures[xyz].w - pressures[xm1yz].w;
        let bx = max(solids[xyz], solids[xm1yz]);
        v.x = (1.0 - bx) * (a_vx(x) * v.x - b_vx(x) * dpdx * uniforms.kv);
    }

    if (y > 0)
    {
        let xym1z = get_3d_idx(x, y - 1, z);
        let dpdy = pressures[xyz].w - pressures[xym1z].w;
        let by = max(solids[xyz], solids[xym1z]);
        v.y = (1.0 - by) * (a_vy(y) * v.y - b_vy(y) * dpdy * uniforms.kv);
    }

    if (z > 0)
    {
        let xyzm1 = get_3d_idx(x, y, z - 1);
        let dpdz = pressures[xyz].w - pressures[xyzm1].w;
        let bz = max(solids[xyz], solids[xyzm1]);
        v.z = (1.0 - bz) * (a_vz(z) * v.z - b_vz(z) * dpdz * uniforms.kv);
    }

    // write
    velocities[xyz] = v;
}

@compute @workgroup_size(16, 4, 4) 
fn update_pressures(@builtin(global_invocation_id) g: vec3<u32>)
{
    let x = i32(g.x);
    let y = i32(g.y);
    let z = i32(g.z);

    if ( x >= uniforms.dims.x || y >= uniforms.dims.y || z >= uniforms.dims.z) {return;}

    let xyz = get_3d_idx(x, y, z);
    let v = velocities[xyz];  // cell's left (x) and bottom (y) faces
    var p = pressures[xyz];

    // right top front faces live in the next cell; the domain edge is a wall, so 0
    var vr = 0.0;
    var vu = 0.0;
    var vf = 0.0;

    if (x + 1 < uniforms.dims.x) { vr = velocities[get_3d_idx(x + 1, y, z)].x; }
    if (y + 1 < uniforms.dims.y) { vu = velocities[get_3d_idx(x, y + 1, z)].y; }
    if (z + 1 < uniforms.dims.z) { vf = velocities[get_3d_idx(x, y, z + 1)].z; }

    p.x = a_px(x) * p.x - b_px(x) * uniforms.kp * (vr - v.x);
    p.y = a_py(y) * p.y - b_py(y) * uniforms.kp * (vu - v.y);
    p.z = a_pz(z) * p.z - b_pz(z) * uniforms.kp * (vf - v.z);

    p.w = p.x + p.y + p.z;
    pressures[xyz] = p;
}

@compute @workgroup_size(1)
fn record(@builtin(global_invocation_id) g: vec3<u32>)
{
    let step = stepcounter[0];
    var xyz_idx = get_3d_idx(uniforms.micpos.x, uniforms.micpos.y, uniforms.micpos.z);
    if (step < uniforms.numiters) {
        recording[step] = pressures[xyz_idx].w;
    }
    stepcounter[0] += 1;
}