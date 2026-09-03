import { SWING_PRESETS, generateRandomSwing } from '../engine/SwingSimulator'
import { REFERENCE_SWINGS } from '../data/referenceSwings'

const PRESET_KEYS = ['perfect', 'heel_strike', 'toe_strike', 'thin_hit']

const baseButtonClasses =
  'rounded-lg text-sm transition-colors duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-green-400 focus-visible:ring-offset-2 focus-visible:ring-offset-slate-800 disabled:cursor-not-allowed disabled:opacity-50'

export default function ControlPanel({
  onSelectSwing,
  selectedClub,
  onSelectClub,
  bleStatus,
  usbStatus,
  xiaoStatus,
  onConnectBle,
  onConnectUsb,
  onConnectXiao,
  onDisconnectLive,
  onCalibrate,
  connectingBle,
  connectingUsb,
  connectingXiao,
  calibrating,
  armed,
}) {
  const bleConnected = bleStatus?.state === 'connected'
  const usbConnected = usbStatus?.state === 'connected'
  const xiaoConnected = xiaoStatus?.state === 'connected'
  const anyConnected = bleConnected || usbConnected || xiaoConnected
  const serialUnsupported = usbStatus && !usbStatus.supported
  const bleUnsupported = bleStatus && !bleStatus.supported
  const activeError = xiaoStatus?.error || usbStatus?.error || bleStatus?.error
  const canCalibrate = anyConnected && !calibrating

  return (
    <section
      className="rounded-xl bg-slate-800 p-4 shadow-lg shadow-slate-950/20"
      aria-labelledby="test-controls-heading"
    >
      <h2 id="test-controls-heading" className="sr-only">
        Swing test controls
      </h2>

      <fieldset className="mb-4">
        <legend className="mb-2 text-xs font-medium uppercase tracking-wider text-slate-500">
          Live hardware
        </legend>
        <div className="space-y-3">
          <div className="flex flex-wrap items-center gap-2">
            {anyConnected ? (
              <>
                <button
                  type="button"
                  onClick={onDisconnectLive}
                  className={`${baseButtonClasses} bg-slate-700 px-4 py-2 text-slate-200 hover:bg-slate-600`}
                >
                  Disconnect
                </button>
                <button
                  type="button"
                  onClick={onCalibrate}
                  disabled={!canCalibrate}
                  className={`${baseButtonClasses} bg-amber-500 px-4 py-2 font-semibold text-slate-950 hover:bg-amber-400`}
                  title={
                    usbConnected
                      ? 'Zero grass baseline on the ESP (~2s, keep mat still)'
                      : 'Arm tracking and zero the display (ESP USB needed for hardware tare)'
                  }
                >
                  {calibrating ? 'Zeroing…' : 'Calibrate / Zero'}
                </button>
              </>
            ) : (
              <>
                <button
                  type="button"
                  onClick={onConnectXiao}
                  disabled={serialUnsupported || connectingXiao}
                  className={`${baseButtonClasses} bg-emerald-600 px-4 py-2 font-semibold text-white hover:bg-emerald-500`}
                >
                  {connectingXiao ? 'Opening XIAO…' : 'Connect XIAO'}
                </button>
                <button
                  type="button"
                  onClick={onConnectUsb}
                  disabled={serialUnsupported || connectingUsb}
                  className={`${baseButtonClasses} bg-teal-700 px-4 py-2 font-semibold text-white hover:bg-teal-600`}
                >
                  {connectingUsb ? 'Opening ESP…' : 'Connect ESP USB'}
                </button>
                <button
                  type="button"
                  onClick={onConnectBle}
                  disabled={bleUnsupported || connectingBle}
                  className={`${baseButtonClasses} bg-sky-700 px-4 py-2 font-semibold text-white hover:bg-sky-600`}
                >
                  {connectingBle ? 'Pairing…' : 'Connect ESP BLE'}
                </button>
              </>
            )}
            <StatusPill
              bleStatus={bleStatus}
              usbStatus={usbStatus}
              xiaoStatus={xiaoStatus}
              connectingBle={connectingBle}
              connectingUsb={connectingUsb}
              connectingXiao={connectingXiao}
            />
          </div>
          {activeError ? (
            <p className="text-xs leading-5 text-amber-300/90">{activeError}</p>
          ) : (
            <p className="text-xs leading-5 text-slate-400">
              {serialUnsupported && bleUnsupported
                ? 'Use Chrome or Edge — Web Serial / Web Bluetooth required.'
                : anyConnected
                  ? calibrating
                    ? 'Keep the mat still for ~2s while grass load is zeroed…'
                    : armed
                      ? 'Armed at 0. Pads stay dark until a full strike is detected.'
                      : usbConnected
                        ? 'Connected. Press Calibrate / Zero (mat at rest) before swinging.'
                        : xiaoConnected
                          ? (xiaoStatus?.receiving
                            ? `XIAO streaming (${xiaoStatus.sampleCount || 0} samples).`
                            : 'XIAO linked — waiting for IMU data.')
                          : 'ESP BLE linked — waiting for swing notifies…'
                  : 'Connect ESP USB, press Calibrate / Zero, then swing. Pads stay at 0 until impact.'}
            </p>
          )}
        </div>
      </fieldset>

      <fieldset className="mb-4">
        <legend className="mb-2 text-xs font-medium uppercase tracking-wider text-slate-500">
          Club
        </legend>
        <div className="flex flex-wrap gap-2">
          {Object.entries(REFERENCE_SWINGS).map(([clubKey, club]) => {
            const isSelected = selectedClub === clubKey

            return (
              <button
                key={clubKey}
                type="button"
                onClick={() => onSelectClub(clubKey)}
                aria-pressed={isSelected}
                className={`${baseButtonClasses} px-3.5 py-2 ${
                  isSelected
                    ? 'bg-green-500 font-bold text-slate-950 hover:bg-green-400'
                    : 'bg-slate-700 font-normal text-slate-300 hover:bg-slate-600 hover:text-white'
                }`}
              >
                {club.name}
              </button>
            )
          })}
        </div>
      </fieldset>

      <fieldset>
        <legend className="mb-2 text-xs font-medium uppercase tracking-wider text-slate-500">
          Swing presets
        </legend>
        <div className="flex flex-wrap gap-2">
          {PRESET_KEYS.map((presetKey) => {
            const preset = SWING_PRESETS[presetKey]

            return (
              <button
                key={presetKey}
                type="button"
                onClick={() => onSelectSwing(preset)}
                className={`${baseButtonClasses} bg-slate-700 px-4 py-2 text-slate-200 hover:bg-slate-600 hover:text-white`}
              >
                {preset.label}
              </button>
            )
          })}

          <button
            type="button"
            onClick={() => onSelectSwing(generateRandomSwing())}
            className={`${baseButtonClasses} bg-blue-700 px-4 py-2 font-semibold text-white hover:bg-blue-600`}
          >
            Random Swing
          </button>
        </div>
      </fieldset>
    </section>
  )
}

function StatusPill({
  bleStatus,
  usbStatus,
  xiaoStatus,
  connectingBle,
  connectingUsb,
  connectingXiao,
}) {
  const connecting = connectingBle || connectingUsb || connectingXiao
  const xiaoConnected = xiaoStatus?.state === 'connected'
  const usbConnected = usbStatus?.state === 'connected'
  const bleConnected = bleStatus?.state === 'connected'
  const state = connecting
    ? 'connecting'
    : xiaoConnected || usbConnected || bleConnected
      ? 'connected'
      : 'disconnected'

  const styles = {
    connected: 'border-turf-400/30 bg-turf-400/10 text-turf-300',
    connecting: 'border-sky-400/30 bg-sky-400/10 text-sky-300',
    disconnected: 'border-white/10 bg-white/[0.04] text-slate-400',
  }

  const label = connecting
    ? connectingXiao
      ? 'Opening XIAO…'
      : connectingUsb
        ? 'Opening ESP…'
        : 'Pairing BLE…'
    : xiaoConnected
      ? 'Live · XIAO'
      : usbConnected
        ? 'Live · ESP USB'
        : bleConnected
          ? `Live · ${bleStatus?.deviceName || 'BLE'}`
          : 'Offline'

  return (
    <span
      className={`inline-flex items-center gap-2 rounded-full border px-3 py-1.5 text-[11px] font-medium ${styles[state]}`}
    >
      <span
        className={`h-1.5 w-1.5 rounded-full ${
          state === 'connected'
            ? 'bg-turf-400'
            : state === 'connecting'
              ? 'animate-pulse bg-sky-400'
              : 'bg-slate-500'
        }`}
      />
      {label}
    </span>
  )
}
