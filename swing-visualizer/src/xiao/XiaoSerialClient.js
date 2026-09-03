import { XiaoImuBuffer, parseXiaoLine, swingFromXiaoSamples } from './xiaoSwing.js'

/**
 * Web Serial client for Seeed XIAO nRF52840 Sense IMU streamer.
 * Flash xiao/swing_imu_stream.ino first. Close Arduino Serial Monitor before connecting.
 */
export class XiaoSerialClient {
  constructor() {
    this.port = null
    this.reader = null
    this._readLoop = null
    this._listeners = new Set()
    this._statusListeners = new Set()
    this._lineBuffer = ''
    this.buffer = new XiaoImuBuffer()
    this._sampleCount = 0
    this._lastImpactAt = 0
    this._lastLiveEmitAt = 0
    this._watchdog = null
    this.status = {
      supported: typeof navigator !== 'undefined' && Boolean(navigator.serial),
      state: 'disconnected',
      deviceName: null,
      transport: 'xiao',
      error: null,
      sampleCount: 0,
      receiving: false,
    }
  }

  onSwing(listener) {
    this._listeners.add(listener)
    return () => this._listeners.delete(listener)
  }

  onStatus(listener) {
    this._statusListeners.add(listener)
    listener(this.status)
    return () => this._statusListeners.delete(listener)
  }

  _setStatus(patch) {
    this.status = { ...this.status, ...patch, transport: 'xiao' }
    for (const listener of this._statusListeners) {
      listener(this.status)
    }
  }

  get connected() {
    return this.status.state === 'connected'
  }

  async connect() {
    if (!this.status.supported) {
      const error = 'Web Serial is not available. Use Chrome or Edge.'
      this._setStatus({ state: 'error', error })
      throw new Error(error)
    }

    this._setStatus({ state: 'connecting', error: null, sampleCount: 0, receiving: false })

    try {
      // Always ask — auto-picking a single saved port often grabs the ESP by mistake.
      const port = await navigator.serial.requestPort()
      await port.open({ baudRate: 115200 })
      try {
        await port.setSignals({ dataTerminalReady: true, requestToSend: true })
      } catch {
        // Some adapters reject signal control; streaming may still work.
      }

      this.port = port
      this._lineBuffer = ''
      this.buffer.clear()
      this._sampleCount = 0
      this._lastImpactAt = 0
      this._lastLiveEmitAt = 0
      this._setStatus({
        state: 'connected',
        deviceName: 'XIAO Sense',
        error: null,
        sampleCount: 0,
        receiving: false,
      })
      this._readLoop = this._pump()
      this._watchdog = setTimeout(() => {
        if (this.status.state === 'connected' && this._sampleCount === 0) {
          this._setStatus({
            ...this.status,
            error: 'Connected, but no GMIMU data. Pick the XIAO COM port (not the ESP), and make sure swing_imu_stream.ino is flashed.',
          })
        }
      }, 2500)
      return port
    } catch (error) {
      let message = error?.message || 'Failed to open XIAO serial port'
      if (error?.name === 'NotFoundError') {
        message = 'No COM port chosen. Quit Arduino IDE, unplug/replug XIAO, Connect XIAO, then click a port (not Cancel).'
      } else if (/already|busy|access|failed to open|NetworkError/i.test(message)) {
        message = 'COM port busy. Fully quit Arduino IDE / Serial Monitor / idf_monitor, then retry.'
      }
      this._setStatus({ state: 'disconnected', error: message, deviceName: null, receiving: false })
      throw error
    }
  }

  async disconnect() {
    if (this._watchdog) {
      clearTimeout(this._watchdog)
      this._watchdog = null
    }
    try {
      if (this.reader) {
        try {
          await this.reader.cancel()
        } catch {
          // ignore
        }
        this.reader = null
      }
      if (this._readLoop) {
        try {
          await this._readLoop
        } catch {
          // ignore
        }
        this._readLoop = null
      }
      if (this.port) {
        try {
          await this.port.setSignals({ dataTerminalReady: false, requestToSend: false })
        } catch {
          // ignore
        }
        try {
          await this.port.close()
        } catch {
          // ignore
        }
      }
    } finally {
      this.port = null
      this._lineBuffer = ''
      this._setStatus({
        state: 'disconnected',
        deviceName: null,
        error: null,
        sampleCount: 0,
        receiving: false,
      })
    }
  }

  async _pump() {
    if (!this.port?.readable) return
    const decoder = new TextDecoderStream()
    const input = this.port.readable.pipeThrough(decoder)
    this.reader = input.getReader()

    try {
      while (true) {
        const { value, done } = await this.reader.read()
        if (done) break
        if (value) this._ingest(value)
      }
    } catch (error) {
      if (this.status.state === 'connected') {
        this._setStatus({
          state: 'disconnected',
          deviceName: null,
          error: error?.message || 'XIAO serial disconnected',
          receiving: false,
        })
      }
    } finally {
      try {
        this.reader?.releaseLock()
      } catch {
        // ignore
      }
      this.reader = null
    }
  }

  _emitSwing(timestampMs, { force = false, preview = false } = {}) {
    const now = Date.now()
    if (!force && now - this._lastImpactAt < 500) return
    try {
      const window = this.buffer.windowAround(timestampMs)
      const swing = swingFromXiaoSamples(window)
      swing.preview = preview
      if (!preview) this._lastImpactAt = now
      for (const listener of this._listeners) {
        listener(swing)
      }
      if (this.status.error) {
        this._setStatus({ ...this.status, error: null })
      }
    } catch (error) {
      this._setStatus({
        ...this.status,
        error: error?.message || 'Failed to build XIAO swing',
      })
    }
  }

  _ingest(chunk) {
    this._lineBuffer += chunk
    const lines = this._lineBuffer.split(/\r?\n/)
    this._lineBuffer = lines.pop() ?? ''

    for (const line of lines) {
      const parsed = parseXiaoLine(line)
      if (!parsed) continue

      if (parsed.type === 'error') {
        this._setStatus({ ...this.status, error: parsed.message })
        continue
      }

      if (parsed.type === 'ready') {
        this._setStatus({
          ...this.status,
          error: null,
          deviceName: 'XIAO Sense',
        })
        continue
      }

      if (parsed.type === 'imu') {
        this.buffer.push(parsed.sample)
        this._sampleCount += 1
        if (this._sampleCount === 1 || this._sampleCount % 25 === 0) {
          this._setStatus({
            ...this.status,
            sampleCount: this._sampleCount,
            receiving: true,
            error: null,
          })
        }

        const mag = Math.hypot(parsed.sample.ax, parsed.sample.ay, parsed.sample.az)
        const now = Date.now()

        // Hard swing / shake → commit to history.
        if (mag > 3.0 && now - this._lastImpactAt > 900) {
          this._emitSwing(parsed.sample.timestamp_ms, { force: true, preview: false })
        }
        continue
      }

      if (parsed.type === 'impact') {
        this._emitSwing(parsed.timestamp_ms, { force: true, preview: false })
      }
    }
  }
}

export const xiaoSerialClient = new XiaoSerialClient()
