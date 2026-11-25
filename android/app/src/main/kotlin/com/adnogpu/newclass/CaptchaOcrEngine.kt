package com.adnogpu.newclass

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

object CaptchaOcrEngine {
    private var recognizer: TextRecognizer? = null

    fun recognize(
        bytes: ByteArray,
        onSuccess: (List<String>) -> Unit,
        onError: (Throwable) -> Unit,
    ) {
        val bitmaps = mutableListOf<Bitmap>()
        try {
            val source = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                ?: throw IllegalArgumentException("decode failed")
            try {
                bitmaps.add(
                    preprocess(
                        source,
                        minChannel = true,
                        contrast = 1.5f,
                    ),
                )
                bitmaps.add(
                    preprocess(
                        source,
                        minChannel = true,
                        threshold = 245,
                        denoise = true,
                    ),
                )
                bitmaps.add(preprocess(source, contrast = 1.6f))
                bitmaps.add(
                    preprocess(
                        source,
                        minChannel = true,
                        threshold = 210,
                        denoise = true,
                    ),
                )
                bitmaps.add(paddedUpscale(source))
            } finally {
                source.recycle()
            }

            val client = recognizer ?: TextRecognition.getClient(
                TextRecognizerOptions.DEFAULT_OPTIONS,
            ).also { recognizer = it }
            val tasks = bitmaps.map {
                client.process(InputImage.fromBitmap(it, 0))
            }
            Tasks.whenAllSuccess<Text>(tasks)
                .addOnSuccessListener { texts ->
                    onSuccess(
                        texts.map { it.text.trim() }.filter { it.isNotEmpty() },
                    )
                }
                .addOnFailureListener(onError)
                .addOnCompleteListener {
                    bitmaps.forEach { it.recycle() }
                }
        } catch (error: Throwable) {
            bitmaps.forEach { it.recycle() }
            onError(error)
        }
    }

    fun close() {
        recognizer?.close()
        recognizer = null
    }

    private fun preprocess(
        source: Bitmap,
        minChannel: Boolean = false,
        contrast: Float = 1f,
        threshold: Int? = null,
        denoise: Boolean = false,
    ): Bitmap {
        val scale = 4
        val scaled = Bitmap.createScaledBitmap(
            source,
            source.width * scale,
            source.height * scale,
            true,
        )
        val width = scaled.width
        val height = scaled.height
        val pixels = IntArray(width * height)
        scaled.getPixels(pixels, 0, width, 0, 0, width, height)
        for (index in pixels.indices) {
            val color = pixels[index]
            val r = Color.red(color)
            val g = Color.green(color)
            val b = Color.blue(color)
            val base = if (minChannel) {
                minOf(r, g, b).toDouble()
            } else {
                0.299 * r + 0.587 * g + 0.114 * b
            }
            val value = if (threshold != null) {
                if (base < threshold) 0 else 255
            } else {
                ((base - 128) * contrast + 128)
                    .coerceIn(0.0, 255.0)
                    .toInt()
            }
            pixels[index] = Color.rgb(value, value, value)
        }
        if (threshold != null && denoise) {
            denoise(pixels, width, height)
        }
        val output = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        output.setPixels(pixels, 0, width, 0, 0, width, height)
        scaled.recycle()
        return withPadding(output)
    }

    private fun paddedUpscale(source: Bitmap): Bitmap {
        val scale = 4
        val scaled = Bitmap.createScaledBitmap(
            source,
            source.width * scale,
            source.height * scale,
            true,
        )
        return withPadding(scaled)
    }

    private fun withPadding(source: Bitmap): Bitmap {
        val padding = 32
        val padded = Bitmap.createBitmap(
            source.width + padding * 2,
            source.height + padding * 2,
            Bitmap.Config.ARGB_8888,
        )
        val canvas = Canvas(padded)
        canvas.drawColor(Color.WHITE)
        canvas.drawBitmap(source, padding.toFloat(), padding.toFloat(), null)
        source.recycle()
        return padded
    }

    private fun denoise(pixels: IntArray, width: Int, height: Int) {
        val copy = pixels.copyOf()
        for (y in 1 until height - 1) {
            for (x in 1 until width - 1) {
                var dark = 0
                for (dy in -1..1) {
                    for (dx in -1..1) {
                        val value = copy[(y + dy) * width + (x + dx)]
                        if (Color.red(value) < 128) dark++
                    }
                }
                pixels[y * width + x] = if (dark >= 6) {
                    Color.BLACK
                } else {
                    Color.WHITE
                }
            }
        }
    }
}
