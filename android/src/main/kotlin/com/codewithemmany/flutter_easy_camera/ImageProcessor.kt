package com.codewithemmany.flutter_easy_camera

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Turns a raw capture into an upright, optionally mirrored, cropped, resized
 * and re-encoded JPEG.
 */
internal object ImageProcessor {
  data class Output(val file: File, val bytes: ByteArray, val width: Int, val height: Int)

  /** EXIF tags copied over when metadata is kept. Orientation is always reset. */
  private val keptTags =
      listOf(
          ExifInterface.TAG_DATETIME,
          ExifInterface.TAG_DATETIME_ORIGINAL,
          ExifInterface.TAG_DATETIME_DIGITIZED,
          ExifInterface.TAG_OFFSET_TIME,
          ExifInterface.TAG_OFFSET_TIME_ORIGINAL,
          ExifInterface.TAG_MAKE,
          ExifInterface.TAG_MODEL,
          ExifInterface.TAG_EXPOSURE_TIME,
          ExifInterface.TAG_F_NUMBER,
          ExifInterface.TAG_PHOTOGRAPHIC_SENSITIVITY,
          ExifInterface.TAG_FOCAL_LENGTH,
          ExifInterface.TAG_FLASH,
          ExifInterface.TAG_WHITE_BALANCE,
          ExifInterface.TAG_GPS_LATITUDE,
          ExifInterface.TAG_GPS_LATITUDE_REF,
          ExifInterface.TAG_GPS_LONGITUDE,
          ExifInterface.TAG_GPS_LONGITUDE_REF,
          ExifInterface.TAG_GPS_ALTITUDE,
          ExifInterface.TAG_GPS_ALTITUDE_REF,
          ExifInterface.TAG_GPS_TIMESTAMP,
          ExifInterface.TAG_GPS_DATESTAMP,
      )

  fun process(
      input: File,
      output: File,
      options: PlatformCaptureOptions,
      mirror: Boolean,
  ): Output {
    val exif = ExifInterface(input)
    val rotation = exif.rotationDegrees
    val flipped = exif.isFlipped

    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(input.path, bounds)
    val rawW = bounds.outWidth
    val rawH = bounds.outHeight
    require(rawW > 0 && rawH > 0) { "Could not decode captured image." }

    // Size of the image once it is upright.
    val uprightW = if (rotation % 180 == 0) rawW else rawH
    val uprightH = if (rotation % 180 == 0) rawH else rawW
    val crop = cropSize(uprightW, uprightH, options.cropAspectRatio)

    // Decode at the smallest power-of-two sample size that still covers the
    // requested output so large sensors don't blow the heap.
    val maxDimension = options.maxDimension?.toInt()
    val scale =
        if (maxDimension != null) maxDimension.toDouble() / max(crop.first, crop.second) else 1.0
    var sampleSize = 1
    while (scale < 1.0 && sampleSize * 2 * scale <= 1.0) sampleSize *= 2

    val decoded =
        BitmapFactory.decodeFile(input.path, BitmapFactory.Options().apply { inSampleSize = sampleSize })
            ?: error("Could not decode captured image.")

    // ExifInterface defines flipped orientations as "flip horizontally, then
    // rotate". The front-camera mirror is applied last, in upright space.
    val matrix = Matrix()
    if (flipped) matrix.postScale(-1f, 1f)
    matrix.postRotate(rotation.toFloat())
    if (mirror) matrix.postScale(-1f, 1f)
    val upright = Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
    if (upright !== decoded) decoded.recycle()

    val sampledCrop = cropSize(upright.width, upright.height, options.cropAspectRatio)
    val cropped =
        Bitmap.createBitmap(
            upright,
            (upright.width - sampledCrop.first) / 2,
            (upright.height - sampledCrop.second) / 2,
            sampledCrop.first,
            sampledCrop.second,
        )
    if (cropped !== upright) upright.recycle()

    val finalBitmap =
        if (maxDimension != null && max(cropped.width, cropped.height) > maxDimension) {
          val ratio = maxDimension.toDouble() / max(cropped.width, cropped.height)
          Bitmap.createScaledBitmap(
                  cropped,
                  (cropped.width * ratio).roundToInt().coerceAtLeast(1),
                  (cropped.height * ratio).roundToInt().coerceAtLeast(1),
                  true,
              )
              .also { if (it !== cropped) cropped.recycle() }
        } else {
          cropped
        }

    val buffer = ByteArrayOutputStream()
    finalBitmap.compress(
        Bitmap.CompressFormat.JPEG, options.jpegQuality.toInt().coerceIn(1, 100), buffer)
    val width = finalBitmap.width
    val height = finalBitmap.height
    finalBitmap.recycle()

    output.parentFile?.mkdirs()
    output.writeBytes(buffer.toByteArray())

    if (!options.stripMetadata) {
      val outExif = ExifInterface(output)
      for (tag in keptTags) exif.getAttribute(tag)?.let { outExif.setAttribute(tag, it) }
      outExif.setAttribute(
          ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL.toString())
      outExif.saveAttributes()
    }

    val bytes = if (options.stripMetadata) buffer.toByteArray() else output.readBytes()
    return Output(output, bytes, width, height)
  }

  /**
   * Largest centered crop of [width] x [height] with [aspectRatio]. The ratio
   * is flipped to follow the image's orientation, so a 3:4 request on a
   * landscape photo yields a 4:3 crop.
   */
  private fun cropSize(width: Int, height: Int, aspectRatio: Double?): Pair<Int, Int> {
    if (aspectRatio == null || aspectRatio <= 0) return width to height
    var ratio = aspectRatio
    if ((width > height) != (ratio > 1.0) && ratio != 1.0) ratio = 1.0 / ratio
    val current = width.toDouble() / height
    return if (current > ratio) {
      (height * ratio).roundToInt().coerceIn(1, width) to height
    } else {
      width to (width / ratio).roundToInt().coerceIn(1, height)
    }
  }
}
