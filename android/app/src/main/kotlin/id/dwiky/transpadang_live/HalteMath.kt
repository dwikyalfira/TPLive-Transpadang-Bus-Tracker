package id.dwiky.transpadang_live

import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Port dari logika pelacakan halte di Dart (`halte_tracker.dart` + `geo_utils.dart`)
 * agar sama persis logikanya dengan yang dipakai aplikasi. Hanya menerima daftar
 * halte satu arah (urutan perjalanan) + posisi bus, lalu menghitung indeks halte
 * sekarang / berikutnya serta progres sepanjang rute.
 */
object HalteMath {

    const val DEFAULT_SPEED_KMH = 20.0
    const val MIN_MOVING_SPEED_KMH = 5.0
    private const val EPS_KM = 0.03 // 30 m

    data class Point(val lat: Double, val lng: Double)

    /** Hasil perhitungan posisi bus di sepanjang lintasan halte. */
    data class Progress(
        /** Indeks halte yang baru saja dilewati; -1 bila belum melewati halte awal. */
        val currentIndex: Int,
        /** Indeks halte berikutnya yang dituju (0-based). */
        val nextIndex: Int,
        /** Progres kumulatif sepanjang rute, 0..1. */
        val fraction: Double,
        /** Jarak garis lurus dari bus ke halte berikutnya (km). */
        val distanceToNextKm: Double,
    )

    /** Bearing kompas (derajat, 0 = utara) dari [from] ke [to]. */
    fun bearingDegrees(from: Point, to: Point): Double {
        val lat1 = Math.toRadians(from.lat)
        val lat2 = Math.toRadians(to.lat)
        val dLng = Math.toRadians(to.lng - from.lng)
        val y = sin(dLng) * cos(lat2)
        val x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)
        val deg = Math.toDegrees(atan2(y, x))
        return (deg + 360.0) % 360.0
    }

    /** Selisih sudut terkecil antara dua arah (0..180). */
    fun angularDifference(a: Double, b: Double): Double {
        val d = abs(a - b) % 360.0
        return if (d > 180.0) 360.0 - d else d
    }

    /** Jarak garis lurus (Haversine) dalam kilometer. */
    fun distanceKm(a: Point, b: Point): Double {
        val r = 6371.0
        val dLat = Math.toRadians(b.lat - a.lat)
        val dLng = Math.toRadians(b.lng - a.lng)
        val h = sin(dLat / 2) * sin(dLat / 2) +
            cos(Math.toRadians(a.lat)) * cos(Math.toRadians(b.lat)) *
            sin(dLng / 2) * sin(dLng / 2)
        return 2 * r * kotlin.math.asin(sqrt(h))
    }

    /** Proyeksi titik [p] ke segmen [a]-[b] (aproksimasi equirectangular). */
    fun projectOnSegment(p: Point, a: Point, b: Point): Pair<Double, Double> {
        val latRad = Math.toRadians(a.lat)
        val kx = cos(latRad) * 111.32
        val ky = 111.32
        val x = { q: Point -> (q.lng - a.lng) * kx }
        val y = { q: Point -> (q.lat - a.lat) * ky }
        val bx = x(b); val by = y(b)
        val px = x(p); val py = y(p)
        val seg2 = bx * bx + by * by
        var t = if (seg2 > 0) (px * bx + py * by) / seg2 else 0.0
        t = t.coerceIn(0.0, 1.0)
        val dx = px - t * bx
        val dy = py - t * by
        return Pair(sqrt(dx * dx + dy * dy), t)
    }

    fun nearestIndex(stops: List<Point>, p: Point): Int {
        var best = 0
        var bestD = Double.POSITIVE_INFINITY
        for (i in stops.indices) {
            val d = distanceKm(p, stops[i])
            if (d < bestD) {
                bestD = d
                best = i
            }
        }
        return best
    }

    /** Arah segmen lokal di sekitar index [idx] (rata-rata prev->next). */
    fun localBearing(stops: List<Point>, idx: Int): Double {
        if (stops.size < 2) return 0.0
        if (idx <= 0) return bearingDegrees(stops[0], stops[1])
        if (idx >= stops.size - 1) {
            return bearingDegrees(stops[stops.size - 2], stops[stops.size - 1])
        }
        return bearingDegrees(stops[idx - 1], stops[idx + 1])
    }

    /** Estimasi ETA (menit) berdasarkan jarak dan kecepatan bus. */
    fun etaMinutes(distanceKm: Double, speedKmh: Double?): Int? {
        val speed = if (speedKmh == null || speedKmh < MIN_MOVING_SPEED_KMH) {
            DEFAULT_SPEED_KMH
        } else speedKmh
        if (speed <= 0 || distanceKm <= 0) return null
        val minutes = (distanceKm / speed) * 60
        if (!minutes.isFinite()) return null
        return minutes.roundToInt()
    }

    fun isValidHeading(v: Double?) =
        v != null && v.isFinite() && v >= 0 && v < 360

    /**
     * Menghitung posisi bus di sepanjang urutan halte [stops] (satu arah).
     * Port langsung dari dart `HalteTracker._build`.
     */
    fun computeProgress(stops: List<Point>, pos: Point, heading: Double?): Progress? {
        if (stops.size < 2) return null

        val cum = DoubleArray(stops.size)
        for (i in 1 until stops.size) {
            cum[i] = cum[i - 1] + distanceKm(stops[i - 1], stops[i])
        }

        val near = nearestIndex(stops, pos)
        var progress = cum[near]
        var bestPerp = Double.POSITIVE_INFINITY
        for (i in 0 until stops.size - 1) {
            val (perp, t) = projectOnSegment(pos, stops[i], stops[i + 1])
            if (perp < bestPerp) {
                bestPerp = perp
                progress = cum[i] + t * (cum[i + 1] - cum[i])
            }
        }

        var currentIndex: Int
        var nextIndex: Int
        if (progress < cum[near] - EPS_KM) {
            currentIndex = near - 1
            nextIndex = near
        } else {
            currentIndex = near
            nextIndex = near + 1
        }
        currentIndex = currentIndex.coerceIn(-1, stops.size - 1)
        nextIndex = nextIndex.coerceIn(0, stops.size - 1)
        if (currentIndex >= nextIndex) currentIndex = nextIndex - 1

        val total = cum.last()
        val fraction = if (total > 0) (progress / total).coerceIn(0.0, 1.0) else 0.0

        return Progress(
            currentIndex = currentIndex,
            nextIndex = nextIndex,
            fraction = fraction,
            distanceToNextKm = distanceKm(pos, stops[nextIndex]),
        )
    }
}