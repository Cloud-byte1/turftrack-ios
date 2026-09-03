import { parseGmradarLine } from './radarPacket.js'

/**
 * Web Serial client for a dedicated radar ESP32 streaming GMRADAR lines.
 * Use a different COM port than the mat ESP.
 */
export class RadarSerialClient {
  constructor() {
    this.port = null
    this.reader = null
    this._readLoop = null
    this._listeners = new Set()
    this._statusListeners = new Set()
    this._lineBuffer = ''
    this.latest = null
    this.status = {
      supported: typeof navigator !== 'undefined' && Boolean(navigator.serial),
      state: 'disconnected',
      deviceName: null,
      transport: 'radar-usb',
      error: null,
      sampleCount: 0,
    }
  }

  onRadar(listener) {
    this._listeners.add(listener)
    return () => this._listeners.delete(listener)
  }

  onStatus(listener) {
    this._statusListeners.add(listener)
    listener(this.status)
    return () => this._statusListeners.delete(listener)
  }

  _setStatus(patch) {
    this.status = { ...this.status, ...patch, transport: 'radar-usb' }
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

    this._setStatus({ state: 'connecting', error: null, sampleCount: 0 })

    try {
      const port = await navigator.serial.requestPort()
      await port.open({ baudRate: 115200 })
      this.port = port
      this._lineBuffer = ''
      this.latest = null
      this._setStatus({
        state: 'connected',
        deviceName: 'Radar ESP USB',
        error: null,
        sampleCount: 0,
      })
      this._readLoop = this._pump()
      return port
    } catch (error) {
      let message = error?.message || 'Failed to open radar serial port'
      if (error?.name === 'NotFoundError') {
        message = 'No COM port selected for the radar ESP.'
      } else if (/already|busy|access|failed to open/i.test(message)) {
        message = 'Radar COM port busy. Close Serial Monitor / idf_monitor, then retry.'
      }
      this._setStatus({ state: 'disconnected', error: message, deviceName: null })
      throw error
    }
  }

  async disconnect() {
    try {
      if (this.reader) {
        try { await this.reader.cancel() } catch { /* ignore */ }
        this.reader = null
      }
      if (this._readLoop) {
        try { await this._readLoop } catch { /* ignore */ }
        this._readLoop = null
      }
      if (this.port) {
        try { await this.port.close() } catch { /* ignore */ }
      }
    } finally {
      this.port = null
      this._lineBuffer = ''
      this._setStatus({ state: 'disconnected', deviceName: null, error: null, sampleCount: 0 })
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
          error: error?.message || 'Radar USB disconnected',
        })
      }
    } finally {
      try { this.reader?.releaseLock() } catch { /* ignore */ }
      this.reader = null
    }
  }

  _ingest(chunk) {
    this._lineBuffer += chunk
    const lines = this._lineBuffer.split(/\r?\n/)
    this._lineBuffer = lines.pop() ?? ''

    for (const line of lines) {
      if (!line.includes('GMRADAR')) continue
      const sample = parseGmradarLine(line)
      if (!sample) continue
      this.latest = sample
      this._setStatus({
        ...this.status,
        sampleCount: (this.status.sampleCount || 0) + 1,
        error: null,
      })
      for (const listener of this._listeners) {
        listener(sample)
      }
    }
  }
}

export const radarSerialClient = new RadarSerialClient()
