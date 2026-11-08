package id.dwiky.transpadang_live

import android.content.Context
import android.util.Log
import io.github.muntashirakon.adb.AbsAdbConnectionManager
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import org.bouncycastle.asn1.x500.X500Name
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder
import java.io.ByteArrayInputStream
import java.io.File
import java.math.BigInteger
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.PrivateKey
import java.security.cert.Certificate
import java.security.cert.CertificateFactory
import java.security.spec.PKCS8EncodedKeySpec
import java.util.Date
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Memasang APK app Wear OS (di-bundle di assets/wear/tplive-wear.apk) ke jam
 * lewat Wireless debugging: pairing (kode 6 digit) lalu koneksi ADB over TLS
 * dan `cmd package install`. Seluruhnya memakai library libadb-android; tidak
 * butuh PC.
 */
class WearInstaller(private val context: Context) {

    companion object {
        private const val TAG = "WearInstaller"
        const val APK_ASSET = "wear/tplive-wear.apk"
        private const val WEAR_PACKAGE = "id.dwiky.transpadang_live"
        private const val KEY_FILE = "adb_key.pk8"
        private const val CERT_FILE = "adb_cert.der"
    }

    data class Result(val ok: Boolean, val message: String)

    /** Dipanggil tiap tahap dimulai: discover_pair, pairing, discover_connect, connecting, installing. */
    var onStage: ((String) -> Unit)? = null

    private fun stage(name: String) {
        Log.d(TAG, "Tahap: $name")
        onStage?.invoke(name)
    }

    fun isApkBundled(): Boolean = try {
        context.assets.open(APK_ASSET).close()
        true
    } catch (e: Exception) {
        false
    }

    private val manager = object : AbsAdbConnectionManager() {
        private val privateKey: PrivateKey
        private val certificate: Certificate

        init {
            val keyFile = File(context.filesDir, KEY_FILE)
            val certFile = File(context.filesDir, CERT_FILE)
            if (!keyFile.exists() || !certFile.exists()) {
                generateKeys(keyFile, certFile)
            }
            privateKey = KeyFactory.getInstance("RSA")
                .generatePrivate(PKCS8EncodedKeySpec(keyFile.readBytes()))
            certificate = CertificateFactory.getInstance("X.509")
                .generateCertificate(ByteArrayInputStream(certFile.readBytes()))
            api = android.os.Build.VERSION.SDK_INT
            setTimeout(15, TimeUnit.SECONDS)
        }

        override fun getPrivateKey(): PrivateKey = privateKey
        override fun getCertificate(): Certificate = certificate
        override fun getDeviceName(): String = "TPLive"
    }

    private fun generateKeys(keyFile: File, certFile: File) {
        val kpg = KeyPairGenerator.getInstance("RSA")
        kpg.initialize(2048)
        val pair = kpg.generateKeyPair()
        val subject = X500Name("CN=TPLive")
        val notBefore = Date(System.currentTimeMillis() - TimeUnit.DAYS.toMillis(1))
        val notAfter = Date(System.currentTimeMillis() + TimeUnit.DAYS.toMillis(3650))
        val holder = JcaX509v3CertificateBuilder(
            subject,
            BigInteger.valueOf(System.currentTimeMillis()),
            notBefore,
            notAfter,
            subject,
            pair.public,
        ).build(JcaContentSignerBuilder("SHA512withRSA").build(pair.private))
        val cert = JcaX509CertificateConverter().getCertificate(holder)
        keyFile.writeBytes(pair.private.encoded)
        certFile.writeBytes(cert.encoded)
    }

    /**
     * Mencari layanan ADB TLS di jaringan lewat mDNS (NsdManager). Dibuat
     * sendiri karena AdbMdns bawaan library hanya melaporkan layanan di
     * perangkat lokal (untuk pairing ke diri sendiri), bukan jam di jaringan.
     * [preferHost] bila diisi hanya menerima layanan dari host itu.
     */
    @Suppress("DEPRECATION")
    private fun discover(
        type: String,
        timeoutMs: Long,
        preferHost: String? = null,
    ): Pair<String, Int>? {
        val nsd = context.getSystemService(Context.NSD_SERVICE) as NsdManager
        val latch = CountDownLatch(1)
        val found = java.util.concurrent.atomic.AtomicReference<Pair<String, Int>?>(null)

        val discovery = object : NsdManager.DiscoveryListener {
            override fun onStartDiscoveryFailed(serviceType: String?, errorCode: Int) {
                Log.d(TAG, "Discovery gagal: $errorCode")
                latch.countDown()
            }

            override fun onStopDiscoveryFailed(serviceType: String?, errorCode: Int) {}
            override fun onDiscoveryStarted(serviceType: String?) {
                Log.d(TAG, "Discovery dimulai: $serviceType")
            }

            override fun onDiscoveryStopped(serviceType: String?) {}
            override fun onServiceLost(serviceInfo: NsdServiceInfo?) {}

            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                Log.d(TAG, "Layanan ditemukan: ${serviceInfo.serviceName}")
                try {
                    nsd.resolveService(serviceInfo, object : NsdManager.ResolveListener {
                        override fun onResolveFailed(info: NsdServiceInfo?, errorCode: Int) {
                            Log.d(TAG, "Resolve gagal: $errorCode")
                        }

                        override fun onServiceResolved(info: NsdServiceInfo) {
                            val host = info.host?.hostAddress
                            Log.d(TAG, "Resolved: $host:${info.port}")
                            if (host == null || info.port <= 0) return
                            if (preferHost != null && host != preferHost) return
                            if (found.compareAndSet(null, Pair(host, info.port))) {
                                latch.countDown()
                            }
                        }
                    })
                } catch (e: Exception) {
                    Log.d(TAG, "resolveService error: ${e.message}")
                }
            }
        }

        try {
            nsd.discoverServices("_$type._tcp", NsdManager.PROTOCOL_DNS_SD, discovery)
            latch.await(timeoutMs, TimeUnit.MILLISECONDS)
        } finally {
            try {
                nsd.stopServiceDiscovery(discovery)
            } catch (_: Exception) {
            }
        }
        return found.get()
    }

    /**
     * Mode otomatis: hanya butuh kode pairing. Alamat & port pairing serta port
     * koneksi ditemukan lewat mDNS. Dipanggil di thread latar.
     */
    fun autoPairAndInstall(pairingCode: String): Result {
        if (!isApkBundled()) return Result(false, "apk_missing")
        try {
            stage("discover_pair")
            val pairing = discover("adb-tls-pairing", 20_000)
                ?: return Result(false, "discover_pair_failed")
            val host = pairing.first
            stage("pairing")
            if (!manager.pair(host, pairing.second, pairingCode)) {
                return Result(false, "pair_failed")
            }
            stage("discover_connect")
            val connect = discover("adb-tls-connect", 20_000, preferHost = host)
                ?: return Result(false, "discover_connect_failed")
            stage("connecting")
            if (!manager.connect(host, connect.second)) {
                return Result(false, "connect_failed")
            }
            return install()
        } catch (e: Exception) {
            Log.w(TAG, "Gagal memasang app jam (otomatis)", e)
            return Result(false, e.message ?: e.javaClass.simpleName)
        } finally {
            try {
                manager.disconnect()
            } catch (_: Exception) {
            }
        }
    }

    /** Pairing lalu koneksi lalu pasang APK. Dipanggil di thread latar. */
    fun pairAndInstall(
        host: String,
        pairPort: Int,
        pairingCode: String,
        connectPort: Int,
    ): Result {
        if (!isApkBundled()) {
            return Result(false, "apk_missing")
        }
        try {
            stage("pairing")
            if (!manager.pair(host, pairPort, pairingCode)) {
                return Result(false, "pair_failed")
            }
            stage("connecting")
            if (!manager.connect(host, connectPort)) {
                return Result(false, "connect_failed")
            }
            return install()
        } catch (e: Exception) {
            Log.w(TAG, "Gagal memasang app jam", e)
            return Result(false, e.message ?: e.javaClass.simpleName)
        } finally {
            try {
                manager.disconnect()
            } catch (_: Exception) {
            }
        }
    }

    /** Pasang APK dengan batas waktu agar UI tidak berputar tanpa akhir. */
    private fun install(): Result {
        stage("installing")
        val executor = java.util.concurrent.Executors.newSingleThreadExecutor()
        val future = executor.submit<Result> { doInstall() }
        return try {
            future.get(120, TimeUnit.SECONDS)
        } catch (e: java.util.concurrent.TimeoutException) {
            future.cancel(true)
            try {
                manager.disconnect()
            } catch (_: Exception) {
            }
            Result(false, "install_timeout")
        } catch (e: java.util.concurrent.ExecutionException) {
            Result(false, e.cause?.message ?: "install_failed")
        } finally {
            executor.shutdownNow()
        }
    }

    private fun doInstall(): Result {
        val bytes = context.assets.open(APK_ASSET).use { it.readBytes() }
        val size = bytes.size.toLong()
        manager.openStream("exec:cmd package install -r -S $size").use { stream ->
            val out = stream.openOutputStream()
            out.write(bytes)
            out.flush()
            val output = stream.openInputStream().readBytes().toString(Charsets.UTF_8)
            Log.d(TAG, "Hasil install: $output")
            if (!output.contains("Success")) {
                return Result(false, output.trim().ifEmpty { "install_failed" })
            }
        }
        // Buka app di jam (best-effort).
        try {
            manager.openStream("shell:am start -n $WEAR_PACKAGE/.WearMainActivity").use { s ->
                s.openInputStream().readBytes()
            }
        } catch (e: Exception) {
            Log.d(TAG, "Gagal membuka app jam: ${e.message}")
        }
        return Result(true, "ok")
    }
}
