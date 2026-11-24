export var audioContext: AudioContext;
import { WaveFile } from 'wavefile';
import { writeFile } from 'node:fs/promises';


export async function initWebAudio() {
    audioContext = new AudioContext();
    // add master control volume?

}
export async function resumeAudio() {
    if (audioContext.state === 'suspended') await audioContext.resume();
}

async function play(buffer: AudioBuffer, volume: number = 1.0)
{
    await resumeAudio();

    const src = audioContext.createBufferSource();
    const gain = audioContext.createGain();
    gain.gain.value = volume;

    src.buffer = buffer;
    src.connect(gain).connect(audioContext.destination);

    src.start();
}

// float32array[] -> AudioBuffer
function bufferFromSamples(
        channels: Float32Array<ArrayBuffer>[],
        sampleRate = audioContext.sampleRate
    ): AudioBuffer 
{
    // assume channels have the same length
    const buf = audioContext.createBuffer(2, channels[0].length, sampleRate); // we may use more channels for purposes of cacheing
        channels.forEach((samples, i) => buf.copyToChannel(samples, i));

    return buf;
}

// placeholder debug sound: 1s decaying 440 Hz tone, returned as 2 channels (stereo)
export function generateDefaultSound()
{
    const frames = Math.floor(audioContext.sampleRate * 1.0);
    const samples = new Float32Array(frames);
    for (let i = 0; i < frames; i++) {
        const t = i / audioContext.sampleRate;
        samples[i] = Math.sin(2 * Math.PI * 440 * t) * Math.exp(-6 * t);
    }
    return [samples, samples];
}

  // read from wav file
export async function bufferFromWAV(
    url: string,
    seconds: number = 3
): Promise<Float32Array<ArrayBuffer>> 
{
    const res = await fetch(url);
if (!res.ok) throw new Error(`failed to load ${url}: ${res.status}`);

const data = await res.arrayBuffer();
const magic = new TextDecoder().decode(data.slice(0, 4));
console.log(url, res.headers.get('content-type'), data.byteLength, 'bytes, starts with:', magic);

if (magic !== 'RIFF') {
    throw new Error(`${url} is not a WAV file (got "${magic}", content-type ${res.headers.get('content-type')})`);
}
const decoded = await audioContext.decodeAudioData(data);

    // const decoded = await audioContext.decodeAudioData(await res.arrayBuffer());
    const frames = seconds === undefined
        ? decoded.length
        : Math.min(decoded.length, Math.floor(seconds * decoded.sampleRate));

    const out = new Float32Array(frames);
    for (let c = 0; c < decoded.numberOfChannels; c++) {
        const ch = decoded.getChannelData(c);
        for (let i = 0; i < frames; i++) out[i] += ch[i] / decoded.numberOfChannels;
    }
    return out;
}

export class AudioHandler {
    private recording: Float32Array;
    private dt: number;

    constructor(dtime: number, size: number) {
        this.recording = new Float64Array(size);
        this.dt = dtime;
        console.log("recording for ", this.dt * size, "seconds");
    }

    // getters
    get recording_buffer(): Float32Array
    {
        return this.recording;
    }

    get recording_size(): number
    {
        return this.recording.length;
    }

    public record(data: Float32Array, offset: number = 0): void {
        if (offset < 0 || offset + data.length > this.recording_size) {
            throw new Error(
                `recording out of bounds: writing ${data.length} samples at ${offset}, size is ${this.recording_size}`
            );
        }
        this.recording.set(data, offset);
    }

    public record_sample(index: number, value: number): void {
        if (index < 0 || index >= this.recording_size) {
            throw new Error(`index out of bounds while recording ${index} with size ${this.recording_size}`);
        }
        this.recording[index] = value;
    }

    public save_recording(name: string = "recording", normalize: boolean = true): void {
        
        const sampleRate = Math.round(1 / this.dt); // integer rate for wav
        const n = this.recording_size;
        const data = this.recording;

        // scale so the loudest sample hits full scale (raw pressures are usually tiny)
        let peak = 1;
        if (normalize) {
            peak = 0;
            for (let i = 0; i < n; i++) {
                peak = Math.max(peak, Math.abs(data[i]));
            }
            if (peak == 0) peak = 1;  // all silence, avoid dividing by 0
        }


        const dataBytes = n * 2;                      // 16-bit mono
        const buf = new ArrayBuffer(44 + dataBytes);
        const v = new DataView(buf);
        const str = (off: number, s: string) => {
            for (let i = 0; i < s.length; i++) v.setUint8(off + i, s.charCodeAt(i));
        };

        str(0, "RIFF");  v.setUint32(4, 36 + dataBytes, true);  str(8, "WAVE");
        str(12, "fmt "); v.setUint32(16, 16, true);
        v.setUint16(20, 1, true);  
        v.setUint16(22, 1, true);
        v.setUint32(24, sampleRate, true);
        v.setUint32(28, sampleRate * 2, true);
        v.setUint16(32, 2, true); 
        v.setUint16(34, 16, true);
        str(36, "data"); v.setUint32(40, dataBytes, true);

        for (let i = 0; i < n; i++) {
            const s = Math.max(-1, Math.min(1, data[i] / peak));
            v.setInt16(44 + i * 2, s < 0 ? s * 0x8000 : s * 0x7fff, true);
        }

        // trigger download, delete later
        const url = URL.createObjectURL(new Blob([buf], { type: "audio/wav" }));
        const a = document.createElement("a");
        a.href = url;
        a.download = name.endsWith(".wav") ? name : `${name}.wav`;
        document.body.appendChild(a);
        a.click();
        a.remove();
        URL.revokeObjectURL(url);
    }

    public print_recording()
    {
        // print time based data to the console
        console.log(this.recording);
    }

}

// WE MAY NOT USE THIS??? keep around for now, this is just prerecorded sound for now. May need to store attributes like pressures and positions here in the future

export class ThunderSound {
    private gainValue = 1.0; // linear gain after distance attenuation
    public channels: Float32Array<ArrayBuffer>[]; // there are 2 channels
    protected time_until_play: number; // seconds
    public dist = 1.0; // how far it is, meters
    public finished = false;

    private static SPEEDOFSOUND = 343; // m/s
    private static REFDIST = 100; // distance which sound plays at its source volume, otherwise gain falls off

    // check https://pubs.aip.org/aip/jpr/article/54/4/043101/3373738/Speed-of-sound-in-humid-air-Accurate-thermodynamic for speed of sound with humidity, delays are ~ 0.01 seconds on oom
    constructor(ch: Float32Array<ArrayBuffer>[], distance: number, volume: number) {
        this.channels = ch;
        this.dist = distance;
        this.gainValue = volume - Math.min(1, ThunderSound.REFDIST / distance);
        this.time_until_play = distance / ThunderSound.SPEEDOFSOUND;
    }
    
    public use_gpu = false;
    public getVolume()
    {
        return this.gainValue; // TODO: attenuate as we are further
    }

    frame(dt: number)
    {
        if (this.finished) return;

        this.time_until_play -= dt;
        if (this.time_until_play  <= 0.)
        {
            const buffer: AudioBuffer = bufferFromSamples(this.channels);
            play(buffer, this.gainValue);
            this.finished = true; // tells renderer to remove this object
        }
    }
}