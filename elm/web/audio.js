// audio.js — WebAudio DSP integration for Particle Forge
// Consumes AudioEvent messages from Elm ports and produces collision sounds.
// Tolerant: if AudioContext fails to initialize, the simulation still runs.

(function () {
  "use strict";

  var ctx = null;
  var masterGain = null;
  var initialized = false;

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
      console.warn("Particle Forge: WebAudio init failed:", e);
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

  // Play a short percussive thump for a collision event
  function playCollisionSound(event) {
    if (!initAudio()) return;
    if (ctx.state === "suspended") return;

    var energy = event.energy || 1;
    var x = event.x || 0;
    var worldWidth = 800; // match viewport width

    // Scale volume by energy (clamped)
    var volume = Math.min(1.0, Math.max(0.05, energy / 50));

    // Frequency based on energy: higher energy = higher pitch
    var baseFreq = 80 + Math.min(energy * 8, 400);

    // Stereo panning based on x position (-1 to 1)
    var pan = ((x / worldWidth) * 2) - 1;
    pan = Math.max(-1, Math.min(1, pan));

    var now = ctx.currentTime;

    // Oscillator: short burst
    var osc = ctx.createOscillator();
    osc.type = "triangle";
    osc.frequency.setValueAtTime(baseFreq, now);
    osc.frequency.exponentialRampToValueAtTime(baseFreq * 0.3, now + 0.15);

    // Envelope
    var env = ctx.createGain();
    env.gain.setValueAtTime(volume, now);
    env.gain.exponentialRampToValueAtTime(0.001, now + 0.15);

    // Panner
    var panner = ctx.createStereoPanner();
    panner.pan.setValueAtTime(pan, now);

    // Connect chain: osc -> env -> panner -> master
    osc.connect(env);
    env.connect(panner);
    panner.connect(masterGain);

    osc.start(now);
    osc.stop(now + 0.2);

    // Noise burst for high-energy collisions
    if (energy > 10) {
      playNoiseBurst(volume * 0.4, pan, now);
    }
  }

  // Short noise burst for impact texture
  function playNoiseBurst(volume, pan, startTime) {
    var bufferSize = ctx.sampleRate * 0.05; // 50ms
    var buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
    var data = buffer.getChannelData(0);
    for (var i = 0; i < bufferSize; i++) {
      data[i] = (Math.random() * 2 - 1) * (1 - i / bufferSize);
    }

    var source = ctx.createBufferSource();
    source.buffer = buffer;

    var env = ctx.createGain();
    env.gain.setValueAtTime(volume, startTime);
    env.gain.exponentialRampToValueAtTime(0.001, startTime + 0.05);

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
