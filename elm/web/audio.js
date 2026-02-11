// audio.js — WebAudio DSP integration for Sound Blocks
// Consumes AudioEvent and MixerCommand messages from Elm ports.
// Material-aware collision sounds + mixer with reverb, delay, and level meter.

(function () {
  "use strict";

  var ctx = null;
  var masterGain = null;
  var initialized = false;

  // Effects chain nodes
  var dryGain = null;       // pre-effects dry signal
  var reverbNode = null;    // ConvolverNode
  var reverbGain = null;    // reverb wet mix
  var reverbDry = null;     // reverb dry mix
  var delayNode = null;     // DelayNode
  var delayFeedback = null; // feedback GainNode
  var delayGain = null;     // delay wet mix
  var delayDry = null;      // delay dry mix
  var analyser = null;      // AnalyserNode for meter

  // Current mixer state
  var mixerState = {
    volume: 0.7,
    muted: false,
    reverbEnabled: false,
    reverbDecay: 0.5,
    reverbMix: 0.3,
    delayEnabled: false,
    delayTime: 0.25,
    delayFeedback: 0.4,
    delayMix: 0.3
  };

  // Material sound profiles (matches Material.elm definitions)
  var materialProfiles = {
    Stone:  { oscType: "sine",     baseFreq: 120, decay: 0.08, noise: 0.5 },
    Wood:   { oscType: "square",   baseFreq: 200, decay: 0.12, noise: 0.3 },
    Metal:  { oscType: "triangle", baseFreq: 440, decay: 0.30, noise: 0.0 },
    Rubber: { oscType: "sine",     baseFreq: 80,  decay: 0.05, noise: 0.0 },
    Glass:  { oscType: "sine",     baseFreq: 800, decay: 0.25, noise: 0.1 },
    Ice:    { oscType: "sine",     baseFreq: 500, decay: 0.15, noise: 0.4 }
  };

  var defaultProfile = materialProfiles.Rubber;

  function getProfile(name) {
    return materialProfiles[name] || defaultProfile;
  }

  // Generate impulse response buffer for convolution reverb
  function createReverbIR(decay) {
    var sampleRate = ctx.sampleRate;
    var length = Math.floor(sampleRate * Math.min(decay, 3.0));
    if (length < 1) length = 1;
    var buffer = ctx.createBuffer(2, length, sampleRate);
    for (var ch = 0; ch < 2; ch++) {
      var data = buffer.getChannelData(ch);
      for (var i = 0; i < length; i++) {
        data[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / length, 2);
      }
    }
    return buffer;
  }

  function initAudio() {
    if (initialized) return true;
    try {
      var AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (!AudioCtx) return false;
      ctx = new AudioCtx();

      // Master output gain
      masterGain = ctx.createGain();
      masterGain.gain.value = mixerState.volume;
      masterGain.connect(ctx.destination);

      // Analyser for level meter
      analyser = ctx.createAnalyser();
      analyser.fftSize = 256;
      masterGain.connect(analyser);

      // Input node — all sounds connect here
      dryGain = ctx.createGain();
      dryGain.gain.value = 1.0;

      // Reverb chain
      reverbNode = ctx.createConvolver();
      reverbNode.buffer = createReverbIR(mixerState.reverbDecay);
      reverbGain = ctx.createGain();
      reverbGain.gain.value = 0;
      reverbDry = ctx.createGain();
      reverbDry.gain.value = 1.0;

      dryGain.connect(reverbNode);
      reverbNode.connect(reverbGain);
      dryGain.connect(reverbDry);

      // Delay chain
      delayNode = ctx.createDelay(2.0);
      delayNode.delayTime.value = mixerState.delayTime;
      delayFeedback = ctx.createGain();
      delayFeedback.gain.value = 0;
      delayGain = ctx.createGain();
      delayGain.gain.value = 0;
      delayDry = ctx.createGain();
      delayDry.gain.value = 1.0;

      // Reverb output -> delay input
      reverbGain.connect(delayNode);
      reverbDry.connect(delayNode);
      delayNode.connect(delayFeedback);
      delayFeedback.connect(delayNode);
      delayNode.connect(delayGain);

      // Dry path bypasses delay
      reverbGain.connect(delayDry);
      reverbDry.connect(delayDry);

      // Final mix to master
      delayGain.connect(masterGain);
      delayDry.connect(masterGain);

      // Apply initial mixer state
      applyMixerState();

      initialized = true;

      // Start meter animation
      requestAnimationFrame(updateMeter);

      return true;
    } catch (e) {
      console.warn("Sound Blocks: WebAudio init failed:", e);
      return false;
    }
  }

  // Apply mixer state to audio nodes
  function applyMixerState() {
    if (!ctx) return;
    var now = ctx.currentTime;

    // Master volume / mute
    var vol = mixerState.muted ? 0 : mixerState.volume;
    masterGain.gain.setTargetAtTime(vol, now, 0.02);

    // Reverb
    if (mixerState.reverbEnabled) {
      reverbGain.gain.setTargetAtTime(mixerState.reverbMix, now, 0.02);
      reverbDry.gain.setTargetAtTime(1.0 - mixerState.reverbMix * 0.5, now, 0.02);
    } else {
      reverbGain.gain.setTargetAtTime(0, now, 0.02);
      reverbDry.gain.setTargetAtTime(1.0, now, 0.02);
    }

    // Delay
    if (mixerState.delayEnabled) {
      delayNode.delayTime.setTargetAtTime(mixerState.delayTime, now, 0.02);
      delayFeedback.gain.setTargetAtTime(mixerState.delayFeedback, now, 0.02);
      delayGain.gain.setTargetAtTime(mixerState.delayMix, now, 0.02);
      delayDry.gain.setTargetAtTime(1.0 - mixerState.delayMix * 0.5, now, 0.02);
    } else {
      delayFeedback.gain.setTargetAtTime(0, now, 0.02);
      delayGain.gain.setTargetAtTime(0, now, 0.02);
      delayDry.gain.setTargetAtTime(1.0, now, 0.02);
    }
  }

  // Update the reverb IR when decay changes
  function updateReverbIR() {
    if (!ctx || !reverbNode) return;
    try {
      reverbNode.buffer = createReverbIR(mixerState.reverbDecay);
    } catch (e) {
      // ConvolverNode may throw if buffer is invalid
    }
  }

  // Level meter: animate #audio-meter-bar width
  function updateMeter() {
    if (!analyser) {
      requestAnimationFrame(updateMeter);
      return;
    }
    var data = new Uint8Array(analyser.frequencyBinCount);
    analyser.getByteTimeDomainData(data);

    var peak = 0;
    for (var i = 0; i < data.length; i++) {
      var sample = Math.abs(data[i] - 128) / 128;
      if (sample > peak) peak = sample;
    }

    var pct = Math.min(100, Math.round(peak * 200));
    var bar = document.getElementById("audio-meter-bar");
    if (bar) {
      bar.style.width = pct + "%";
    }
    requestAnimationFrame(updateMeter);
  }

  // Resume audio context on first user interaction (browser autoplay policy)
  function resumeOnInteraction() {
    if (ctx && ctx.state === "suspended") {
      ctx.resume();
    }
  }
  document.addEventListener("click", resumeOnInteraction, { once: false });
  document.addEventListener("keydown", resumeOnInteraction, { once: false });

  // Play a material-aware collision sound
  function playCollisionSound(event) {
    if (!initAudio()) return;
    if (ctx.state === "suspended") return;

    var energy = event.energy || 1;
    var x = event.x || 0;
    var worldWidth = 800;

    // Get material profiles for both colliders
    var profA = getProfile(event.materialA);
    var profB = getProfile(event.materialB);

    // Blend the two material profiles
    var oscType = profA.baseFreq >= profB.baseFreq ? profA.oscType : profB.oscType;
    var baseFreq = (profA.baseFreq + profB.baseFreq) / 2;
    var decay = (profA.decay + profB.decay) / 2;
    var noiseAmt = Math.max(profA.noise, profB.noise);

    // Scale volume by energy (clamped)
    var volume = Math.min(1.0, Math.max(0.05, energy / 50));

    // Frequency modulated by energy: higher energy = higher pitch
    var freq = baseFreq + Math.min(energy * 4, 300);

    // Stereo panning based on x position (-1 to 1)
    var pan = ((x / worldWidth) * 2) - 1;
    pan = Math.max(-1, Math.min(1, pan));

    var now = ctx.currentTime;

    // Oscillator: short burst with material-specific type
    var osc = ctx.createOscillator();
    osc.type = oscType;
    osc.frequency.setValueAtTime(freq, now);
    osc.frequency.exponentialRampToValueAtTime(Math.max(20, freq * 0.3), now + decay);

    // Envelope with material-specific decay
    var env = ctx.createGain();
    env.gain.setValueAtTime(volume, now);
    env.gain.exponentialRampToValueAtTime(0.001, now + decay);

    // Panner
    var panner = ctx.createStereoPanner();
    panner.pan.setValueAtTime(pan, now);

    // Connect chain: osc -> env -> panner -> dryGain (effects input)
    osc.connect(env);
    env.connect(panner);
    panner.connect(dryGain);

    osc.start(now);
    osc.stop(now + decay + 0.05);

    // Noise burst for materials with noise component or high-energy collisions
    var effectiveNoise = noiseAmt + (energy > 15 ? 0.3 : 0);
    if (effectiveNoise > 0.05) {
      playNoiseBurst(volume * effectiveNoise, pan, now, decay);
    }
  }

  // Short noise burst for impact texture
  function playNoiseBurst(volume, pan, startTime, duration) {
    var dur = Math.min(duration, 0.08);
    var bufferSize = Math.floor(ctx.sampleRate * dur);
    if (bufferSize < 1) return;

    var buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
    var data = buffer.getChannelData(0);
    for (var i = 0; i < bufferSize; i++) {
      data[i] = (Math.random() * 2 - 1) * (1 - i / bufferSize);
    }

    var source = ctx.createBufferSource();
    source.buffer = buffer;

    var env = ctx.createGain();
    env.gain.setValueAtTime(Math.min(volume, 0.5), startTime);
    env.gain.exponentialRampToValueAtTime(0.001, startTime + dur);

    var panner = ctx.createStereoPanner();
    panner.pan.setValueAtTime(pan, startTime);

    source.connect(env);
    env.connect(panner);
    panner.connect(dryGain);

    source.start(startTime);
  }

  // Play selection click
  function playSelectSound() {
    if (!initAudio()) return;
    if (ctx.state === "suspended") return;

    var now = ctx.currentTime;
    var osc = ctx.createOscillator();
    osc.type = "sine";
    osc.frequency.setValueAtTime(600, now);
    osc.frequency.exponentialRampToValueAtTime(400, now + 0.05);

    var env = ctx.createGain();
    env.gain.setValueAtTime(0.15, now);
    env.gain.exponentialRampToValueAtTime(0.001, now + 0.06);

    osc.connect(env);
    env.connect(dryGain);
    osc.start(now);
    osc.stop(now + 0.08);
  }

  // Dispatch audio events from Elm ports
  function handleAudioEvent(event) {
    if (!event || !event.type) return;
    switch (event.type) {
      case "collision":
        playCollisionSound(event);
        break;
      case "select":
        playSelectSound();
        break;
      default:
        break;
    }
  }

  // Handle mixer commands from Elm ports
  function handleMixerCommand(cmd) {
    if (!cmd) return;
    if (!initAudio()) return;

    var prevDecay = mixerState.reverbDecay;

    mixerState.volume = cmd.volume;
    mixerState.muted = cmd.muted;
    mixerState.reverbEnabled = cmd.reverbEnabled;
    mixerState.reverbDecay = cmd.reverbDecay;
    mixerState.reverbMix = cmd.reverbMix;
    mixerState.delayEnabled = cmd.delayEnabled;
    mixerState.delayTime = cmd.delayTime;
    mixerState.delayFeedback = cmd.delayFeedback;
    mixerState.delayMix = cmd.delayMix;

    // Regenerate reverb IR if decay changed significantly
    if (Math.abs(prevDecay - mixerState.reverbDecay) > 0.05) {
      updateReverbIR();
    }

    applyMixerState();
  }

  // Expose for Elm port subscription
  window.ParticleForgeAudio = {
    handleAudioEvent: handleAudioEvent,
    handleMixerCommand: handleMixerCommand,
    initAudio: initAudio
  };
})();
