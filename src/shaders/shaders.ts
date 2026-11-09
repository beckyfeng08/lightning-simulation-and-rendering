import triangleVertRaw from './triangle.vert.wgsl';
import fragRaw from './red.frag.wgsl';

export const constants = {
    bindGroup_uniforms: 0,
    bindGroup_model: 1,
    bindGroup_material: 2,

    workgroupSize: 128,

    clusterDimX: 32,
    clusterDimY: 18,
    clusterDimZ: 24
};

// replaces ${name} in WGSL with matching value from constants (above)
function evalShaderRaw(raw: string) {
    const generator = new Function('constants', 'return `' + raw.replaceAll('${', '${constants.') + '`');   
    return generator(constants);
}

export const triangleVertWGSL: string = evalShaderRaw(triangleVertRaw);
export const fragWGSL: string = evalShaderRaw(fragRaw);