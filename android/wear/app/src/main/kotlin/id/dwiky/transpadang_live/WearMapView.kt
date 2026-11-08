package id.dwiky.transpadang_live

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.os.Handler
import android.os.Looper
import android.util.LruCache
import android.view.GestureDetector
import android.view.InputDevice
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.View
import android.view.ViewConfiguration
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.tan
import kotlin.math.cos

/**
 * Peta ringkas khusus bus yang di-pin: tile peta jalan (OpenStreetMap, ditampilkan
 * gelap) + garis rute arah yang ditempuh + posisi bus.
 *
 * Interaksi seperti peta di Wear OS: geser, cubit (pinch) untuk zoom, ketuk dua
 * kali untuk kembali ke tampilan awal, dan putar crown/bezel untuk zoom.
 */
class WearMapView(context: Context) : View(context) {

    companion object {
        private const val TILE = 256.0
        private const val MIN_USER_SCALE = 1f
        private const val MAX_USER_SCALE = 16f
        private const val MAX_TILE_ZOOM = 19
        private const val RETRY_AFTER_MS = 30_000L
        private const val USER_AGENT =
            "TPLive-Wear/1.0 (+https://github.com/dwiky/transpadang-live)"
    }

    private var stops: List<DoubleArray> = emptyList() // [lat, lng]
    private var bus: DoubleArray? = null // posisi bus yang DIGAMBAR (dianimasikan)
    private var busTarget: DoubleArray? = null
    private var busAnimator: ValueAnimator? = null
    private var nextIndex = 0

    /** Bila true kamera selalu memusatkan bus (seperti mode "ikuti"). */
    var followBus = false
        private set
    var onFollowChanged: ((Boolean) -> Unit)? = null

    // Transformasi pengguna: skala (kelipatan) + geser (px) relatif terhadap tampilan "fit".
    private var userScale = 1f
    private var panX = 0f
    private var panY = 0f

    private val dp = resources.displayMetrics.density
    private val main = Handler(Looper.getMainLooper())

    // ---- Tile ----
    private val tileCache = object : LruCache<String, Bitmap>(48) {}
    private val loading = HashSet<String>()
    private val failedAt = HashMap<String, Long>()
    private val executor = Executors.newFixedThreadPool(3)

    /**
     * Gaya gelap ala "invert + hue-rotate 180°": terang jadi gelap tetapi rona
     * tetap (hijau tetap hijau, air tetap kebiruan), lalu sedikit diredupkan.
     */
    private val tilePaint = Paint(Paint.FILTER_BITMAP_FLAG).apply {
        val dim = 0.9f
        colorFilter = ColorMatrixColorFilter(
            ColorMatrix(
                floatArrayOf(
                    0.574f * dim, -1.430f * dim, -0.144f * dim, 0f, 255f * dim - 40f,
                    -0.426f * dim, -0.430f * dim, -0.144f * dim, 0f, 255f * dim - 40f,
                    -0.426f * dim, -1.430f * dim, 0.856f * dim, 0f, 255f * dim - 40f,
                    0f, 0f, 0f, 1f, 0f,
                ),
            ),
        )
    }

    // ---- Cat ----
    private val casingPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 7 * dp
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        color = Color.parseColor("#CC000000")
    }
    private val passedPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 4 * dp
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        color = Color.parseColor("#88B0B0B0")
    }
    private val aheadPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 4 * dp
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        color = Color.parseColor("#F47F38")
    }
    private val stopPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = Color.WHITE
    }
    private val stopBorder = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 1.2f * dp
        color = Color.parseColor("#CC000000")
    }
    private val nextRingPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 2.5f * dp
        color = Color.WHITE
    }
    private val busPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = Color.parseColor("#F47F38")
    }
    private val busBorder = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 2.5f * dp
        color = Color.WHITE
    }
    private val attributionPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#99FFFFFF")
        textSize = 8 * dp
        textAlign = Paint.Align.CENTER
    }

    private val scaleDetector = ScaleGestureDetector(
        context,
        object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(detector: ScaleGestureDetector): Boolean {
                zoomAround(detector.scaleFactor, detector.focusX, detector.focusY)
                return true
            }
        },
    )

    private val gestureDetector = GestureDetector(
        context,
        object : GestureDetector.SimpleOnGestureListener() {
            override fun onDown(e: MotionEvent): Boolean = true

            override fun onScroll(
                e1: MotionEvent?,
                e2: MotionEvent,
                distanceX: Float,
                distanceY: Float,
            ): Boolean {
                if (scaleDetector.isInProgress) return false
                setFollow(false)
                panX -= distanceX
                panY -= distanceY
                clampPan()
                invalidate()
                return true
            }

            override fun onDoubleTap(e: MotionEvent): Boolean {
                // Ketuk dua kali = zoom in 2x di titik ketukan; bila sudah
                // mentok zoom maksimum, kembali ke tampilan awal.
                if (userScale * 2f > MAX_USER_SCALE + 0.001f) {
                    resetView()
                } else {
                    animateZoom(2f, e.x, e.y)
                }
                return true
            }
        },
    )

    init {
        setBackgroundColor(Color.parseColor("#121212"))
        isFocusable = true
        isFocusableInTouchMode = true
    }

    private var zoomAnimator: ValueAnimator? = null

    /** Zoom halus sebesar [factor] dengan titik [fx],[fy] tetap diam. */
    private fun animateZoom(factor: Float, fx: Float, fy: Float) {
        zoomAnimator?.cancel()
        var applied = 1f
        zoomAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 220
            addUpdateListener { a ->
                val cumulative = factor.pow(a.animatedValue as Float)
                zoomAround(cumulative / applied, fx, fy)
                applied = cumulative
            }
            start()
        }
    }

    fun setFollow(enabled: Boolean) {
        if (followBus == enabled) return
        followBus = enabled
        if (enabled) {
            // Saat mengikuti, zoom minimal agar pergerakan bus terlihat jelas.
            if (userScale < 4f) userScale = 4f
        }
        onFollowChanged?.invoke(enabled)
        invalidate()
    }

    /** Geser titik bus yang digambar dengan halus ke posisi baru. */
    private var lastBusUpdateAt = 0L

    private fun moveBusTo(target: DoubleArray?) {
        busAnimator?.cancel()
        val nowMs = android.os.SystemClock.elapsedRealtime()
        val gap = if (lastBusUpdateAt == 0L) 1400L else (nowMs - lastBusUpdateAt).coerceIn(700L, 2500L)
        lastBusUpdateAt = nowMs
        val from = bus
        busTarget = target
        if (target == null || from == null ||
            (abs(from[0] - target[0]) < 1e-9 && abs(from[1] - target[1]) < 1e-9)
        ) {
            bus = target
            return
        }
        val start = doubleArrayOf(from[0], from[1])
        busAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            // Durasi = selang antar-data (700-2500 ms) agar gerak terus menerus.
            duration = gap
            interpolator = android.view.animation.LinearInterpolator()
            addUpdateListener { a ->
                val t = (a.animatedValue as Float).toDouble()
                bus = doubleArrayOf(
                    start[0] + (target[0] - start[0]) * t,
                    start[1] + (target[1] - start[1]) * t,
                )
                invalidate()
            }
            start()
        }
    }

    fun resetView() {
        setFollow(false)
        zoomAnimator?.cancel()
        userScale = 1f
        panX = 0f
        panY = 0f
        invalidate()
    }

    fun update(
        stopsEncoded: String?,
        busLat: Double?,
        busLng: Double?,
        nextIdx: Int,
        accentColor: Int,
    ) {
        stops = stopsEncoded.orEmpty().split(';').mapNotNull { pair ->
            val p = pair.split(',')
            val lat = p.getOrNull(0)?.toDoubleOrNull()
            val lng = p.getOrNull(1)?.toDoubleOrNull()
            if (lat != null && lng != null) doubleArrayOf(lat, lng) else null
        }
        moveBusTo(if (busLat != null && busLng != null) doubleArrayOf(busLat, busLng) else null)
        nextIndex = nextIdx
        aheadPaint.color = accentColor
        busPaint.color = accentColor
        invalidate()
    }

    override fun onDetachedFromWindow() {
        busAnimator?.cancel()
        zoomAnimator?.cancel()
        executor.shutdownNow()
        super.onDetachedFromWindow()
    }

    // ---- Interaksi ----

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (event.actionMasked == MotionEvent.ACTION_DOWN) {
            parent?.requestDisallowInterceptTouchEvent(true)
            requestFocus()
        }
        scaleDetector.onTouchEvent(event)
        gestureDetector.onTouchEvent(event)
        return true
    }

    /** Putar crown/bezel = zoom pada pusat layar. */
    override fun onGenericMotionEvent(event: MotionEvent): Boolean {
        if (event.action == MotionEvent.ACTION_SCROLL &&
            event.isFromSource(InputDevice.SOURCE_ROTARY_ENCODER)
        ) {
            val delta = -event.getAxisValue(MotionEvent.AXIS_SCROLL) *
                ViewConfiguration.get(context).scaledVerticalScrollFactor
            val factor = if (delta > 0) 1.15f else 1f / 1.15f
            zoomAround(factor, width / 2f, height / 2f)
            return true
        }
        return super.onGenericMotionEvent(event)
    }

    /** Zoom dengan titik fokus [fx],[fy] tetap diam di layar. */
    private fun zoomAround(factor: Float, fx: Float, fy: Float) {
        val newScale = (userScale * factor).coerceIn(MIN_USER_SCALE, MAX_USER_SCALE)
        val ratio = newScale / userScale
        val cx = width / 2f
        val cy = height / 2f
        panX = fx - cx - (fx - cx - panX) * ratio
        panY = fy - cy - (fy - cy - panY) * ratio
        userScale = newScale
        clampPan()
        invalidate()
    }

    private fun clampPan() {
        val maxX = width * userScale / 2f
        val maxY = height * userScale / 2f
        panX = panX.coerceIn(-maxX, maxX)
        panY = panY.coerceIn(-maxY, maxY)
        if (abs(userScale - 1f) < 0.001f) {
            panX = 0f
            panY = 0f
        }
    }

    // ---- Proyeksi Web Mercator (koordinat dunia ternormalisasi 0..1) ----

    private fun mx(lng: Double) = (lng + 180.0) / 360.0

    private fun my(lat: Double): Double {
        val r = Math.toRadians(lat.coerceIn(-85.05, 85.05))
        return (1.0 - ln(tan(r) + 1.0 / cos(r)) / PI) / 2.0
    }

    // ---- Tile ----

    private fun tileKey(z: Int, x: Int, y: Int) = "$z/$x/$y"

    private fun requestTile(z: Int, x: Int, y: Int) {
        val key = tileKey(z, x, y)
        if (tileCache.get(key) != null) return
        if (loading.contains(key)) return
        val failed = failedAt[key]
        if (failed != null && System.currentTimeMillis() - failed < RETRY_AFTER_MS) return
        loading.add(key)
        try {
            executor.execute {
                var bmp: Bitmap? = null
                try {
                    val conn = URL("https://tile.openstreetmap.org/$key.png")
                        .openConnection() as HttpURLConnection
                    conn.setRequestProperty("User-Agent", USER_AGENT)
                    conn.connectTimeout = 8000
                    conn.readTimeout = 8000
                    conn.inputStream.use { bmp = BitmapFactory.decodeStream(it) }
                    conn.disconnect()
                } catch (_: Exception) {
                }
                main.post {
                    loading.remove(key)
                    val b = bmp
                    if (b != null) {
                        tileCache.put(key, b)
                        failedAt.remove(key)
                        invalidate()
                    } else {
                        failedAt[key] = System.currentTimeMillis()
                    }
                }
            }
        } catch (_: Exception) {
            loading.remove(key)
        }
    }

    // ---- Gambar ----

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (stops.size < 2 || width == 0) return

        // Batas rute (+ bus) dalam koordinat dunia 0..1.
        val pts = ArrayList<DoubleArray>(stops)
        bus?.let { pts.add(it) }
        val minX = pts.minOf { mx(it[1]) }
        val maxX = pts.maxOf { mx(it[1]) }
        val minY = pts.minOf { my(it[0]) }
        val maxY = pts.maxOf { my(it[0]) }
        val dx = max(maxX - minX, 1e-7)
        val dy = max(maxY - minY, 1e-7)
        val centerX = (minX + maxX) / 2
        val centerY = (minY + maxY) / 2

        // Zoom "fit": rute muat dalam area bulat dengan margin.
        val margin = min(width, height) * 0.16
        val availW = width - 2 * margin
        val availH = height - 2 * margin
        val fitZoom = ln(min(availW / (dx * TILE), availH / (dy * TILE))) / ln(2.0)
        val zoomF = (fitZoom + ln(userScale.toDouble()) / ln(2.0)).coerceIn(2.0, MAX_TILE_ZOOM.toDouble())

        val worldPx = TILE * 2.0.pow(zoomF) // lebar dunia dalam px layar pada zoomF
        val cx = width / 2f
        val cy = height / 2f

        // Mode ikuti: pan dihitung agar bus tepat di tengah layar.
        if (followBus) {
            bus?.let {
                panX = (-(mx(it[1]) - centerX) * worldPx).toFloat()
                panY = (-(my(it[0]) - centerY) * worldPx).toFloat()
            }
        }

        fun sx(nx: Double): Float = (cx + (nx - centerX) * worldPx + panX).toFloat()
        fun sy(ny: Double): Float = (cy + (ny - centerY) * worldPx + panY).toFloat()

        // --- Tile ---
        val z = floor(zoomF).toInt().coerceIn(0, MAX_TILE_ZOOM)
        val tiles = 1 shl z
        val tileScreen = (worldPx / tiles).toFloat() // ukuran tile di layar
        val leftN = centerX + (0 - cx - panX) / worldPx
        val rightN = centerX + (width - cx - panX) / worldPx
        val topN = centerY + (0 - cy - panY) / worldPx
        val bottomN = centerY + (height - cy - panY) / worldPx
        val tx0 = floor(leftN * tiles).toInt().coerceAtLeast(0)
        val tx1 = floor(rightN * tiles).toInt().coerceAtMost(tiles - 1)
        val ty0 = floor(topN * tiles).toInt().coerceAtLeast(0)
        val ty1 = floor(bottomN * tiles).toInt().coerceAtMost(tiles - 1)
        // Batasi jumlah tile agar tidak membanjiri jaringan saat zoom keluar jauh.
        if ((tx1 - tx0 + 1) * (ty1 - ty0 + 1) <= 36) {
            val dst = RectF()
            for (ty in ty0..ty1) {
                for (tx in tx0..tx1) {
                    val left = sx(tx.toDouble() / tiles)
                    val top = sy(ty.toDouble() / tiles)
                    val bmp = tileCache.get(tileKey(z, tx, ty))
                    if (bmp != null) {
                        // +0.5px menutup celah antar tile akibat pembulatan.
                        dst.set(left, top, left + tileScreen + 0.5f, top + tileScreen + 0.5f)
                        canvas.drawBitmap(bmp, null, dst, tilePaint)
                    } else {
                        requestTile(z, tx, ty)
                    }
                }
            }
        }

        // --- Rute ---
        val split = max(0, min(nextIndex, stops.size - 1))
        val passed = Path()
        val ahead = Path()
        val sxs = FloatArray(stops.size)
        val sys = FloatArray(stops.size)
        for (i in stops.indices) {
            sxs[i] = sx(mx(stops[i][1]))
            sys[i] = sy(my(stops[i][0]))
            if (i == 0) passed.moveTo(sxs[i], sys[i]) else if (i <= split) passed.lineTo(sxs[i], sys[i])
            if (i == split) ahead.moveTo(sxs[i], sys[i]) else if (i > split) ahead.lineTo(sxs[i], sys[i])
        }
        canvas.drawPath(passed, casingPaint)
        canvas.drawPath(ahead, casingPaint)
        canvas.drawPath(passed, passedPaint)
        canvas.drawPath(ahead, aheadPaint)

        val dotR = (2.4f + min(userScale - 1f, 3f) * 0.6f) * dp
        for (i in stops.indices) {
            val x = sxs[i]
            val y = sys[i]
            if (x < -20 * dp || x > width + 20 * dp || y < -20 * dp || y > height + 20 * dp) continue
            if (i == split) {
                canvas.drawCircle(x, y, 6.5f * dp, nextRingPaint)
            } else {
                canvas.drawCircle(x, y, dotR, stopBorder)
                canvas.drawCircle(x, y, dotR, stopPaint)
            }
        }

        bus?.let {
            val x = sx(mx(it[1]))
            val y = sy(my(it[0]))
            canvas.drawCircle(x, y, 7.5f * dp, busPaint)
            canvas.drawCircle(x, y, 7.5f * dp, busBorder)
        }

        // Atribusi wajib OSM.
        canvas.drawText("© OpenStreetMap", cx, 14 * dp, attributionPaint)
    }
}
