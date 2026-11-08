package id.dwiky.transpadang_live

/**
 * Mesin status murni (tanpa dependensi Android) yang mendeteksi otomatis
 * apakah pengguna sudah NAIK atau sudah TURUN dari bus yang diikuti, hanya dari
 * jarak pengguna–bus + kecepatan keduanya. Tidak ada input dari pengguna.
 *
 * - NAIK  : pengguna berada ≤ [BOARD_DISTANCE_M] dari bus, keduanya bergerak,
 *           selama [REQUIRED_SAMPLES] sampel berturut-turut.
 * - TURUN : saat sudah naik, jarak > [ALIGHT_DISTANCE_M] selama
 *           [REQUIRED_SAMPLES] sampel berturut-turut.
 *
 * Sampel dengan akurasi GPS buruk ([MAX_ACCURACY_M]) diabaikan agar sinyal
 * yang melompat tidak memicu transisi palsu.
 */
class BoardingDetector {

    enum class State { FOLLOWING, ONBOARD, ALIGHTED }

    companion object {
        const val BOARD_DISTANCE_M = 40.0
        const val ALIGHT_DISTANCE_M = 120.0
        const val MAX_ACCURACY_M = 50f
        const val MIN_MOVING_KMH = 5.0
        const val REQUIRED_SAMPLES = 3
    }

    var state: State = State.FOLLOWING
        private set

    private var nearCount = 0
    private var farCount = 0

    fun reset() {
        state = State.FOLLOWING
        nearCount = 0
        farCount = 0
    }

    /**
     * Memproses satu sampel. Mengembalikan status baru bila terjadi transisi,
     * atau null bila status tidak berubah.
     *
     * @param distanceM jarak garis lurus pengguna ke bus (meter)
     * @param busSpeedKmh kecepatan bus dari server (null = tidak diketahui)
     * @param userSpeedKmh kecepatan pengguna dari GPS (null = tidak diketahui)
     * @param accuracyM akurasi horizontal GPS pengguna (meter)
     */
    fun onSample(
        distanceM: Double,
        busSpeedKmh: Double?,
        userSpeedKmh: Double?,
        accuracyM: Float,
    ): State? {
        if (state == State.ALIGHTED) return null
        if (accuracyM > MAX_ACCURACY_M) return null

        when (state) {
            State.FOLLOWING -> {
                val busMoving = busSpeedKmh == null || busSpeedKmh >= MIN_MOVING_KMH
                val userMoving = userSpeedKmh == null || userSpeedKmh >= MIN_MOVING_KMH
                if (distanceM <= BOARD_DISTANCE_M && busMoving && userMoving) {
                    nearCount++
                } else {
                    nearCount = 0
                }
                if (nearCount >= REQUIRED_SAMPLES) {
                    state = State.ONBOARD
                    farCount = 0
                    return state
                }
            }
            State.ONBOARD -> {
                if (distanceM > ALIGHT_DISTANCE_M) farCount++ else farCount = 0
                if (farCount >= REQUIRED_SAMPLES) {
                    state = State.ALIGHTED
                    return state
                }
            }
            State.ALIGHTED -> Unit
        }
        return null
    }
}
