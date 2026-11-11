import './style.css'
import { Pane } from 'tweakpane';
import { initWebGPU, Renderer, createPane } from './renderer';
import { initWebAudio } from './sound/sound';
import { allRenderer } from './renderers/alltogether_renderer'; // TODO: add more renderers as we see git
// import { cloudRenderer } from './renderers/cloud_renderer'; 
// import { lightningRenderer } from './renderers/lightning_renderer'; 
import { soundRenderer } from './renderers/sound_renderer'; 

import { Camera } from './stage/camera';
import { Stage } from './stage/stage';


await initWebGPU(); // in renderer.ts
await initWebAudio(); // sound fx, gpu based sound

const camera = new Camera();
const stage = new Stage(camera);

var renderer: Renderer | undefined;

const renderModes = { all: 'all', sound: 'sound', 
    // cloud: 'cloud', lightning: 'lightning', 
};

function setRenderer(mode: string) {
    renderer?.stop();

    switch (mode) {
        // case renderModes.cloud:
        //     renderer = new CloudRenderer(stage);
        //     break;
        // case renderModes.lightning:
        //     renderer = new LightningRenderer(stage);
        //     break;
        case renderModes.sound:
            renderer = new soundRenderer(stage);
            break;
        case renderModes.all:
            renderer = new allRenderer(stage);
    }
}


// Tweakpane: easily adding tweak control for parameters.

// see alltogether_renderer for what to do to add your own ui controls
const renderParams = {mode: renderModes.all};
const selectorPane = createPane('Renderer');
selectorPane.addInput(renderParams, 'mode', {options: renderModes}).on('change', (ev) => setRenderer(ev.value));

setRenderer(renderParams.mode);