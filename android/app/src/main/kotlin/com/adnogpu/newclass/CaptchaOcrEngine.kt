package com.adnogpu.newclass

import android.graphics.Bitmap
import android.graphics.BitmapFactory
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
        try {
            val source = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                ?: throw IllegalArgumentException("decode failed")
            val bitmaps = listOf(
                preprocess(source, contrast = 1.6f),
                preprocess(source, threshold = 160),
            )
            source.recycle()

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
            onError(error)
        }
    }

    fun close() {
        recognizer?.close()
        recognizer = null
    }

    private fun preprocess(
        source: Bitmap,
        contrast: Float = 1f,
        threshold: Int? = null,
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
            val luminance =
                0.299 * Color.red(color) +
                    0.587 * Color.green(color) +
                    0.114 * Color.blue(color)
            val value = if (threshold != null) {
                if (luminance < threshold) 0 else 255
            } else {
                ((luminance - 128) * contrast + 128)
                    .coerceIn(0.0, 255.0)
                    .toInt()
            }
            pixels[index] = Color.rgb(value, value, value)
        }
        val output = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        output.setPixels(pixels, 0, width, 0, 0, width, height)
        scaled.recycle()
        return output
    }
}
