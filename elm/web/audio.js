// audio.js — WebAudio DSP integration for Sound Blocks
// Consumes AudioEvent messages from Elm ports and produces collision sounds.
// Material-aware: uses SoundProfile data to vary timbre per material pair.

(function () {
  "use strict";

  var ctx = null;
  var masterGain = null;
  var initialized = false;

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

  function initAudio() {
    if (initialized) return true;
    try {
      var AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (!AudioCtx) return false;
      ctx = new AudioCtx();
      masterGain = ctx.createGain();
      masterGain.gain.value = 0.3;
      masterGain.connect(ctx.destination);
      initialized = true;
      return true;
    } catch (e) {
      console.warn("Sound Blocks: WebAudio init failed:", e);
      return false;
    }
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

    // Connect chain: osc -> env -> panner -> master
    osc.connect(env);
    env.connect(panner);
    panner.connect(masterGain);

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
    panner.connect(masterGain);

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
    env.connect(masterGain);
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

  // Expose for Elm port subscription
  window.ParticleForgeAudio = {
    handleAudioEvent: handleAudioEvent,
    initAudio: initAudio
  };
})();
