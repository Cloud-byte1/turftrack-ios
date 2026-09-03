import { decodeGmswingLine } from '../ble/packet.js'

/**
 * Web Serial client for GolfMat over USB-C (COM port).
 * Requires Chrome/Edge. Close idf_monitor first — only one app can own the port.
 */
export class GolfMatSerialClient {
  constructor() {
    this.port = null
    this.reader = null
    this._readLoop = null
    this._listeners = new Set()
    this._statusListeners = new Set()
    this._lineBuffer = ''
    this._ignoreUntil = 0
    this.status = {
      supported: typeof navigator !== 'undefined' && Boolean(navigator.serial),
      state: 'disconnected',
      deviceName: null,
      transport: 'usb',
      error: null,
      calibrating: false,
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
    this.status = { ...this.status, ...patch, transport: 'usb' }
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

    this._setStatus({ state: 'connecting', error: null })

    try {
      const port = await navigator.serial.requestPort()
      await port.open({ baudRate: 115200 })

      this.port = port
      this._lineBuffer = ''
      this._setStatus({
        state: 'connected',
        deviceName: 'USB serial',
        error: null,
      })

      this._readLoop = this._pump()
      return port
    } catch (error) {
      let message = error?.message || 'Failed to open USB serial port'
      if (error?.name === 'NotFoundError') {
        message = 'No serial port selected.'
      } else if (/already|busy|access|failed to open/i.test(message)) {
        message = 'COM port busy. Quit idf_monitor (Ctrl+]) and close Arduino Serial Monitor, then retry.'
      }
      this._setStatus({ state: 'disconnected', error: message, deviceName: null })
      throw error
    }
  }

  async calibrate() {
    if (!this.port?.writable) {
      throw new Error('Connect ESP USB before calibrating')
    }
    const writer = this.port.writable.getWriter()
    try {
      await writer.write(new TextEncoder().encode('CAL\n'))
    } finally {
      writer.releaseLock()
    }
    this._ignoreUntil = Date.now() + 2600
    this._setStatus({
      ...this.status,
      error: null,
      calibrating: true,
    })
    window.setTimeout(() => {
      if (this.status.state === 'connected') {
        this._setStatus({ ...this.status, calibrating: false })
      }
    }, 2600)
  }

  async disconnect() {
    try {
      if (this.reader) {
        try {
          await this.reader.cancel()
        } catch {
          // Reader may already be closed.
        }
        this.reader = null
      }
      if (this._readLoop) {
        try {
          await this._readLoop
        } catch {
          // Ignore pump errors during shutdown.
        }
        this._readLoop = null
      }
      if (this.port) {
        try {
          await this.port.close()
        } catch {
          // Port may already be closed.
        }
      }
    } finally {
      this.port = null
      this._lineBuffer = ''
      this._setStatus({ state: 'disconnected', deviceName: null, error: null })
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
          error: error?.message || 'USB serial disconnected',
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

  _ingest(chunk) {
    this._lineBuffer += chunk
    const lines = this._lineBuffer.split(/\r?\n/)
    this._lineBuffer = lines.pop() ?? ''

    for (const line of lines) {
      if (!line.includes('GMSWING')) continue
      try {
        const swing = decodeGmswingLine(line, { source: 'usb' })
        if (!swing) continue
        if (Date.now() < this._ignoreUntil) continue
        // Only forward real strikes (firmware may still emit weak noise).
        if ((swing.impact_quality ?? 0) < 35) continue
        for (const listener of this._listeners) {
          listener(swing)
        }
      } catch (error) {
        this._setStatus({
          ...this.status,
          error: error?.message || 'Failed to decode USB swing line',
        })
      }
    }
  }
}

export const golfMatSerialClient = new GolfMatSerialClient()
