package id.dwiky.transpadang_live

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class BoardingDetectorTest {

    private fun BoardingDetector.near(n: Int) {
        repeat(n) { onSample(15.0, 20.0, 18.0, 10f) }
    }

    @Test
    fun boardsAfterThreeNearMovingSamples() {
        val d = BoardingDetector()
        assertNull(d.onSample(15.0, 20.0, 18.0, 10f))
        assertNull(d.onSample(15.0, 20.0, 18.0, 10f))
        assertEquals(BoardingDetector.State.ONBOARD, d.onSample(15.0, 20.0, 18.0, 10f))
    }

    @Test
    fun notBoardedWhenBusStopped() {
        val d = BoardingDetector()
        repeat(10) { assertNull(d.onSample(10.0, 0.0, 0.0, 10f)) }
        assertEquals(BoardingDetector.State.FOLLOWING, d.state)
    }

    @Test
    fun nearCounterResetsOnFarSample() {
        val d = BoardingDetector()
        d.onSample(15.0, 20.0, 18.0, 10f)
        d.onSample(15.0, 20.0, 18.0, 10f)
        d.onSample(300.0, 20.0, 18.0, 10f)
        assertNull(d.onSample(15.0, 20.0, 18.0, 10f))
        assertEquals(BoardingDetector.State.FOLLOWING, d.state)
    }

    @Test
    fun poorAccuracyIsIgnored() {
        val d = BoardingDetector()
        repeat(10) { assertNull(d.onSample(15.0, 20.0, 18.0, 200f)) }
        assertEquals(BoardingDetector.State.FOLLOWING, d.state)
    }

    @Test
    fun alightsAfterThreeFarSamples() {
        val d = BoardingDetector()
        d.near(3)
        assertNull(d.onSample(200.0, 20.0, 1.0, 10f))
        assertNull(d.onSample(200.0, 20.0, 1.0, 10f))
        assertEquals(BoardingDetector.State.ALIGHTED, d.onSample(200.0, 20.0, 1.0, 10f))
        assertNull(d.onSample(15.0, 20.0, 18.0, 10f))
    }

    @Test
    fun resetReturnsToFollowing() {
        val d = BoardingDetector()
        d.near(3)
        d.reset()
        assertEquals(BoardingDetector.State.FOLLOWING, d.state)
    }
}
