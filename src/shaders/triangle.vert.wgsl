
struct CameraUniforms {
    viewProjMat: mat4x4f,
    viewMat: mat4x4f,
    invProjMat: mat4x4f,
    nClip: f32,
    fClip: f32,
    screenX: f32,
    screenY: f32
}

@group(${bindGroup_uniforms}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;


@vertex
fn main(
  @builtin(vertex_index) VertexIndex : u32
) -> @builtin(position) vec4<f32> {

  // render world space triangle in x = 0 plane

  var pos = array<vec3<f32>, 3>(
    vec3(0.0, 3.0, 0.0),
    vec3(0.0, 1.0, -1.5),
    vec3(0.0, 1.0, 1.5)
  );

  return cameraUniforms.viewProjMat * vec4<f32>(pos[VertexIndex], 1.0);
}