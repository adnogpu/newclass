package com.adnogpu.newclass

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.nio.FloatBuffer
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Arithmetic captcha recognizer for the NUSTTI CAS login.
 *
 * Uses the compact ddddocr CRNN model (MIT licensed) through ONNX Runtime. The
 * model was trained for this family of captchas and is far more reliable here
 * than a general-purpose text recognizer.
 */
object CaptchaOcrEngine {
    private const val TAG = "CaptchaOcr"
    private const val MODEL_ASSET = "captcha/ddddocr.onnx"
    private const val CHARSET_ASSET = "captcha/charset.txt"
    private const val INPUT_NAME = "input1"
    private const val TARGET_HEIGHT = 64

    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "captcha-ocr").apply { isDaemon = true }
    }
    private val mainHandler = Handler(Looper.getMainLooper())

    private var environment: OrtEnvironment? = null
    private var session: OrtSession? = null
    private var charset: CharArray? = null

    fun recognize(
        context: Context,
        bytes: ByteArray,
        onSuccess: (List<String>) -> Unit,
        onError: (Throwable) -> Unit,
    ) {
        val appContext = context.applicationContext
        executor.execute {
            try {
                val text = recognizeBlocking(appContext, bytes)
                mainHandler.post { onSuccess(listOf(text)) }
            } catch (error: Throwable) {
                Log.w(TAG, "captcha OCR failed", error)
                mainHandler.post { onError(error) }
            }
        }
    }

    @Synchronized
    fun close() {
        closeQuietly(session)
        closeQuietly(environment)
        session = null
        environment = null
        charset = null
    }

    @Synchronized
    private fun ensureLoaded(context: Context): Pair<OrtEnvironment, OrtSession> {
        val loadedSession = session
        val loadedEnvironment = environment
        if (loadedSession != null && loadedEnvironment != null) {
            return loadedEnvironment to loadedSession
        }
        val env = OrtEnvironment.getEnvironment()
        val options = OrtSession.SessionOptions().apply {
            setIntraOpNumThreads(2)
            setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
        }
        val modelBytes = context.assets.open(MODEL_ASSET).use { it.readBytes() }
        val loaded = try {
            env.createSession(modelBytes, options)
        } finally {
            options.close()
        }
        val chars = context.assets.open(CHARSET_ASSET)
            .use { it.readBytes().toString(Charsets.UTF_8) }
            .toCharArray()
        require(chars.size > 1) { "captcha charset is empty" }
        environment = env
        session = loaded
        charset = chars
        return env to loaded
    }

    private fun recognizeBlocking(context: Context, bytes: ByteArray): String {
        val (env, ortSession) = ensureLoaded(context)
        val chars = charset ?: throw IllegalStateException("captcha charset missing")
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: throw IllegalArgumentException("captcha image decode failed")
        val scaled = try {
            val width = max(
                8,
                (bitmap.width * TARGET_HEIGHT.toDouble() / bitmap.height).roundToInt(),
            )
            Bitmap.createScaledBitmap(bitmap, width, TARGET_HEIGHT, true)
        } finally {
            bitmap.recycle()
        }

        try {
            val width = scaled.width
            val pixels = IntArray(width * TARGET_HEIGHT)
            scaled.getPixels(pixels, 0, width, 0, 0, width, TARGET_HEIGHT)
            val input = FloatArray(pixels.size)
            for (index in pixels.indices) {
                val color = pixels[index]
                val red = (color shr 16) and 0xff
                val green = (color shr 8) and 0xff
                val blue = color and 0xff
                input[index] = (
                    0.299f * red + 0.587f * green + 0.114f * blue
                    ) / 255f
            }

            val tensor = OnnxTensor.createTensor(
                env,
                FloatBuffer.wrap(input),
                longArrayOf(1, 1, TARGET_HEIGHT.toLong(), width.toLong()),
            )
            tensor.use {
                ortSession.run(mapOf(INPUT_NAME to it)).use { result ->
                    val output = result.get(0) as OnnxTensor
                    return decode(output, chars)
                }
            }
        } finally {
            scaled.recycle()
        }
    }

    private fun decode(output: OnnxTensor, chars: CharArray): String {
        val shape = output.info.shape
        require(shape.size == 3) { "unexpected captcha output shape" }
        val sequence = shape[0].toInt()
        val stride = shape[1].toInt() * shape[2].toInt()
        val classes = shape[2].toInt()
        val buffer = output.floatBuffer
        val values = FloatArray(buffer.remaining())
        buffer.get(values)

        val text = StringBuilder()
        var previous = -1
        for (step in 0 until sequence) {
            val offset = step * stride
            var bestIndex = 0
            var bestScore = -Float.MAX_VALUE
            for (classIndex in 0 until classes) {
                val score = values[offset + classIndex]
                if (score > bestScore) {
                    bestScore = score
                    bestIndex = classIndex
                }
            }
            if (bestIndex != 0 && bestIndex != previous) {
                if (bestIndex < chars.size) {
                    text.append(chars[bestIndex])
                }
            }
            previous = bestIndex
        }
        return text.toString()
    }

    private fun closeQuietly(closeable: AutoCloseable?) {
        try {
            closeable?.close()
        } catch (_: Throwable) {
        }
    }
}
