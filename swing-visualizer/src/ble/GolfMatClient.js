import {
  GOLFMAT_DEVICE_NAME,
  GOLFMAT_SERVICE_UUID,
  GOLFMAT_SWING_UUID,
  decodeSwingNotification,
} from './packet.js'

/** Canonical 16-bit UUID form expected by Chrome Web Bluetooth. */
export function toBluetoothUuid(uuid16) {
  const hex = Number(uuid16).toString(16).padStart(4, '0')
  return `0000${hex}-0000-1000-8000-00805f9b34fb`
}

const SERVICE_UUID = toBluetoothUuid(GOLFMAT_SERVICE_UUID)
const SWING_UUID = toBluetoothUuid(GOLFMAT_SWING_UUID)

/**
 * Web Bluetooth client for the GolfMat peripheral.
 * Requires Chromium (Chrome/Edge) on localhost or HTTPS, plus a PC Bluetooth radio.
 */
export class GolfMatClient {
  constructor() {
    this.device = null
    this.server = null
    this.characteristic = null
    this._listeners = new Set()
    this._statusListeners = new Set()
    this._onDisconnected = this._handleDisconnect.bind(this)
    this._onNotification = this._handleNotification.bind(this)
    this.status = {
      supported: typeof navigator !== 'undefined' && Boolean(navigator.bluetooth),
      state: 'disconnected',
      deviceName: null,
      error: null,
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
    this.status = { ...this.status, ...patch }
    for (const listener of this._statusListeners) {
      listener(this.status)
    }
  }

  get connected() {
    return Boolean(this.device?.gatt?.connected)
  }

  async _requestDevice() {
    // Prefer devices advertising our service / name.
    try {
      return await navigator.bluetooth.requestDevice({
        filters: [
          { name: GOLFMAT_DEVICE_NAME },
          { namePrefix: 'Golf' },
          { services: [SERVICE_UUID] },
        ],
        optionalServices: [SERVICE_UUID],
      })
    } catch (error) {
      // Empty chooser / cancel → offer an "all devices" fallback once.
      if (error?.name !== 'NotFoundError') throw error
    }

    return navigator.bluetooth.requestDevice({
      acceptAllDevices: true,
      optionalServices: [SERVICE_UUID],
    })
  }

  async connect() {
    if (!this.status.supported) {
      const error = 'Web Bluetooth is not available. Use Chrome or Edge on http://localhost:5173.'
      this._setStatus({ state: 'error', error })
      throw new Error(error)
    }

    if (!window.isSecureContext) {
      const error = 'Open the app on http://localhost:5173 (secure context required for Bluetooth).'
      this._setStatus({ state: 'error', error })
      throw new Error(error)
    }

    this._setStatus({ state: 'connecting', error: null })

    try {
      const availability = await navigator.bluetooth.getAvailability?.()
      if (availability === false) {
        const error = 'PC Bluetooth is off or unavailable. Turn Bluetooth on and retry.'
        this._setStatus({ state: 'error', error })
        throw new Error(error)
      }

      const device = await this._requestDevice()
      device.addEventListener('gattserverdisconnected', this._onDisconnected)

      const server = await device.gatt.connect()
      const service = await server.getPrimaryService(SERVICE_UUID)
      const characteristic = await service.getCharacteristic(SWING_UUID)
      characteristic.addEventListener('characteristicvaluechanged', this._onNotification)
      await characteristic.startNotifications()

      this.device = device
      this.server = server
      this.characteristic = characteristic
      this._setStatus({
        state: 'connected',
        deviceName: device.name || GOLFMAT_DEVICE_NAME,
        error: null,
      })
      return device
    } catch (error) {
      let message = error?.message || 'Failed to connect to GolfMat'
      if (error?.name === 'NotFoundError') {
        message = 'No device selected. Make sure the mat is powered and advertising, then try again.'
      } else if (error?.name === 'SecurityError') {
        message = 'Bluetooth permission blocked. Allow Bluetooth for this site in Chrome/Edge.'
      } else if (error?.name === 'NetworkError') {
        message = 'GATT connect failed. Reset the ESP, wait 2s, then Connect again.'
      } else if (/not.*found|no services|UUID/i.test(message)) {
        message = 'Connected, but GolfMat service 0xAB12 was missing. Reflash the latest firmware.'
      }
      this._setStatus({ state: 'disconnected', error: message, deviceName: null })
      throw error
    }
  }

  async disconnect() {
    try {
      if (this.characteristic) {
        this.characteristic.removeEventListener(
          'characteristicvaluechanged',
          this._onNotification,
        )
        try {
          await this.characteristic.stopNotifications()
        } catch {
          // Device may already be gone.
        }
      }
      if (this.device) {
        this.device.removeEventListener('gattserverdisconnected', this._onDisconnected)
        if (this.device.gatt?.connected) {
          this.device.gatt.disconnect()
        }
      }
    } finally {
      this.device = null
      this.server = null
      this.characteristic = null
      this._setStatus({ state: 'disconnected', deviceName: null, error: null })
    }
  }

  _handleDisconnect() {
    this.characteristic = null
    this.server = null
    this._setStatus({
      state: 'disconnected',
      deviceName: null,
      error: 'GolfMat disconnected',
    })
  }

  _handleNotification(event) {
    try {
      const swing = decodeSwingNotification(event.target.value)
      if (!swing) return
      // Ignore weak / noise packets — same floor as USB serial path.
      if ((swing.impact_quality ?? 0) < 35) return
      for (const listener of this._listeners) {
        listener(swing)
      }
    } catch (error) {
      this._setStatus({
        ...this.status,
        error: error?.message || 'Failed to decode swing packet',
      })
    }
  }
}

export const golfMatClient = new GolfMatClient()
