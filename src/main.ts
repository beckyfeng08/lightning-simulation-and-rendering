import './style.css'

import { GUI } from 'dat.gui';
import { initWebGPU, Renderer } from './renderer';
import { allRenderer } from './renderers/alltogether_renderer'; // TODO: add more renderers as we see git
// import { cloudRenderer } from './renderers/cloud_renderer'; 
// import { lightningRenderer } from './renderers/lightning_renderer'; 
// import { soundRenderer } from './renderers/sound_renderer'; 

import { Camera } from './stage/camera';
import { Stage } from './stage/stage';


await initWebGPU(); // in renderer.ts

const camera = new Camera();
const gui = new GUI();
const stage = new Stage(camera);

var renderer: Renderer | undefined;

const renderModes = { all: 'all',
    // cloud: 'cloud', lightning: 'lightning', sound: 'sound', 
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
        // case renderModes.sound:
        //     renderer = new SoundRenderer(stage);
        //     break;
        case renderModes.all:
            renderer = new allRenderer(stage);
    }
}


let renderModeController = gui.add({ mode: renderModes.all }, 'mode', renderModes);
renderModeController.onChange(setRenderer);

setRenderer(renderModeController.getValue());