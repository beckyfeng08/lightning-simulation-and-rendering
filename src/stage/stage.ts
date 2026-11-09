import { Camera } from "./camera";

export class Stage {
    //TODO: add clouds lightning and sound here eventualy
    camera: Camera;

    constructor(camera: Camera) {
        this.camera = camera;
    }
}
