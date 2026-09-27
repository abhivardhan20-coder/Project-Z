/** Original synthesized ambience. Audio starts only following an explicit interaction. */
export class Ambience {
  private context?: AudioContext;
  private gain?: GainNode;
  private filter?: BiquadFilterNode;
  private volume = 0.3;
  private weather = 'rain';
  private stepBuffer?: AudioBuffer;
  start() {
    try {
      if (!this.context) {
        this.context = new AudioContext();
        const buffer = this.context.createBuffer(1, this.context.sampleRate * 4, this.context.sampleRate);
        const data = buffer.getChannelData(0);
        let brown = 0;
        for (let i=0; i<data.length; i++) { brown = (brown + (Math.random()*2-1)*0.04)/1.02; data[i] = brown * 2; }
        const source = this.context.createBufferSource(); source.buffer = buffer; source.loop = true;
        this.filter = this.context.createBiquadFilter(); this.filter.type = 'lowpass'; this.filter.frequency.value = 1500;
        this.gain = this.context.createGain(); this.gain.gain.value = 0;
        source.connect(this.filter).connect(this.gain).connect(this.context.destination); source.start();
      }
      void this.context.resume().catch(() => {}); this.apply();
    } catch { /* Audio is optional; rendering remains available. */ }
  }
  set(volume: number, weather: string) { this.volume = volume; this.weather = weather; this.apply(); }
  pause(paused: boolean) { if (this.context) { if (paused) void this.context.suspend(); else void this.context.resume().catch(() => {}); } }
  footstep(strength=1,wet=false) {
    const context=this.context;if(!context||context.state!=='running'||this.volume===0)return;
    if(!this.stepBuffer) {
      this.stepBuffer=context.createBuffer(1,Math.floor(context.sampleRate*.14),context.sampleRate);
      const samples=this.stepBuffer.getChannelData(0);
      for(let i=0;i<samples.length;i++)samples[i]=(Math.random()*2-1)*Math.exp(-i/samples.length*6);
    }
    const source=context.createBufferSource();source.buffer=this.stepBuffer;source.playbackRate.value=.85+Math.random()*.25;
    const filter=context.createBiquadFilter();filter.type='lowpass';filter.frequency.value=wet?1400:650;
    const gain=context.createGain();gain.gain.value=this.volume*.6*strength;
    source.connect(filter).connect(gain).connect(context.destination);source.start();
    source.onended=()=>{source.disconnect();filter.disconnect();gain.disconnect();};
  }
  cue(kind:'collect'|'rest'|'door') {
    const context=this.context;if(!context||context.state!=='running'||this.volume===0)return;
    const oscillator=context.createOscillator(),gain=context.createGain();
    oscillator.type=kind==='door'?'triangle':'sine';oscillator.frequency.setValueAtTime(kind==='door'?115:kind==='rest'?330:490,context.currentTime);
    oscillator.frequency.exponentialRampToValueAtTime(kind==='door'?62:kind==='rest'?220:730,context.currentTime+.12);
    gain.gain.setValueAtTime(this.volume*.07,context.currentTime);gain.gain.exponentialRampToValueAtTime(.001,context.currentTime+.23);
    oscillator.connect(gain).connect(context.destination);oscillator.start();oscillator.stop(context.currentTime+.24);
    oscillator.onended=()=>{oscillator.disconnect();gain.disconnect();};
  }
  private apply() {
    if (!this.context || !this.gain || !this.filter) return;
    this.gain.gain.setTargetAtTime(this.volume * (this.weather === 'rain' ? 0.35 : 0.10), this.context.currentTime, 0.5);
    this.filter.frequency.setTargetAtTime(this.weather === 'rain' ? 1600 : 350, this.context.currentTime, 0.8);
  }
}
