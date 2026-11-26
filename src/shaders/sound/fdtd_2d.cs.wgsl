struct Uniforms {
    // populate uniform data here
    micpos: vec2<i32>,
    dims: vec2<i32>,
    kv: f32,
    kp: f32,
    numiters: u32,
    numsources: u32,
};

struct Source {
    pos: vec2<i32>,
    pressure: f32,
    time: i32,
};


@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var<storage, read_write> sources: array<Source>;
@group(0) @binding(2) var<storage, read_write> pressures: array<vec4<f32>>; // px, py, p _
@group(0) @binding(3) var<storage, read_write> velocities: array<vec2<f32>>; // vx, vy
@group(0) @binding(4) var<storage, read_write> solids: array<f32>;
@group(0) @binding(5) var<storage, read_write> recording: array<f32>;
@group(0) @binding(6) var<storage, read_write> stepcounter: vec4<u32>;
@group(0) @binding(7) var<storage, read_write> pml: array<f32>;

// get pml things
fn a_vx(x: i32) -> f32 { return pml[x]; }
fn b_vx(x: i32) -> f32 { return pml[uniforms.dims.x + x]; }
fn a_px(x: i32) -> f32 { return pml[2 * uniforms.dims.x + x]; }
fn b_px(x: i32) -> f32 { return pml[3 * uniforms.dims.x + x]; }
fn a_vy(y: i32) -> f32 { return pml[4 * uniforms.dims.x + y]; }
fn b_vy(y: i32) -> f32 { return pml[4 * uniforms.dims.x + uniforms.dims.y + y]; }
fn a_py(y: i32) -> f32 { return pml[4 * uniforms.dims.x + 2 * uniforms.dims.y + y]; }
fn b_py(y: i32) -> f32 { return pml[4 * uniforms.dims.x + 3 * uniforms.dims.y + y]; }

fn get_2d_idx(x:i32, y:i32)->u32
{
    return u32(x + y * uniforms.dims.x);
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
    if (source.pos.x < 0 || source.pos.x >= uniforms.dims.x || source.pos.y < 0 || source.pos.y >= uniforms.dims.y) {return;}

    // if it is rn, then inject the sound by adding the pressure into pressures
    let p_idx = get_2d_idx(source.pos.x, source.pos.y);
    var pressure = pressures[p_idx];

    pressure.x += source.pressure * 0.5; // divide pressure up into 2 per axis
    pressure.y += source.pressure * 0.5;
    pressure.z += source.pressure; // total pressure

    pressures[p_idx] = pressure;
}

@compute @workgroup_size(32, 32)
fn update_velocities(@builtin(global_invocation_id) g: vec3<u32>)
{
    let x = i32(g.x);
    let y = i32(g.y);
    // check to see if idx in bounds
    if ( x >= uniforms.dims.x || y >= uniforms.dims.y) {return;}

    // velocity update

    let xy = get_2d_idx(x, y);
    var v = velocities[xy];
    // todo: integrate with pml later
    if (x > 0) {
        let xm1y = get_2d_idx(x - 1, y);
        let dpdx = pressures[xy].z - pressures[xm1y].z;
        let bx = max(solids[xy], solids[xm1y]);
        v.x = (1.0 - bx) * (a_vx(x) * v.x - b_vx(x) * dpdx * uniforms.kv);
    }

    if (y > 0)
    {
        let xym1 = get_2d_idx(x, y - 1);
        let dpdy = pressures[xy].z - pressures[xym1].z;
        let by = max(solids[xy], solids[xym1]);
        v.y = (1.0 - by) * (a_vy(y) * v.y - b_vy(y) * dpdy * uniforms.kv);
    }

    // write
    velocities[xy] = v;
}

@compute @workgroup_size(32, 32)
fn update_pressures(@builtin(global_invocation_id) g: vec3<u32>)
{
    let x = i32(g.x);
    let y = i32(g.y);
    if (x >= uniforms.dims.x || y >= uniforms.dims.y) { return; }

    let xy = get_2d_idx(x, y);
    let v = velocities[xy];  // cell's left (x) and bottom (y) faces
    var p = pressures[xy];

    // right and top faces live in the next cell; the domain edge is a wall, so 0
    var vr = 0.0;
    var vu = 0.0;
    if (x + 1 < uniforms.dims.x) { vr = velocities[get_2d_idx(x + 1, y)].x; }
    if (y + 1 < uniforms.dims.y) { vu = velocities[get_2d_idx(x, y + 1)].y; }

    p.x = a_px(x) * p.x - b_px(x) * uniforms.kp * (vr - v.x);
    p.y = a_py(y) * p.y - b_py(y) * uniforms.kp * (vu - v.y);
    p.z = p.x + p.y;
    pressures[xy] = p;
}

@compute @workgroup_size(1)
fn record(@builtin(global_invocation_id) g: vec3<u32>)
{
    let step = stepcounter[0];
    var xy_idx = get_2d_idx(uniforms.micpos.x, uniforms.micpos.y);
    if (step < uniforms.numiters) {
        recording[step] = pressures[xy_idx].z;
    }
    stepcounter[0] += 1;
}