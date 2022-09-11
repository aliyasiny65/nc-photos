package com.nkming.nc_photos.plugin

import android.annotation.SuppressLint
import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.os.AsyncTask
import android.os.Bundle
import android.os.IBinder
import android.os.PowerManager
import android.webkit.MimeTypeMap
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.exifinterface.media.ExifInterface
import com.nkming.nc_photos.plugin.image_processor.*
import java.io.File
import java.io.Serializable
import java.net.HttpURLConnection
import java.net.URL

class ImageProcessorService : Service() {
	companion object {
		const val EXTRA_METHOD = "method"
		const val METHOD_ZERO_DCE = "zero-dce"
		const val METHOD_DEEP_LAP_PORTRAIT = "DeepLab3Portrait"
		const val METHOD_ESRGAN = "Esrgan"
		const val METHOD_ARBITRARY_STYLE_TRANSFER = "ArbitraryStyleTransfer"
		const val METHOD_DEEP_LAP_COLOR_POP = "DeepLab3ColorPop"
		const val METHOD_FILTER = "Filter"
		const val EXTRA_FILE_URL = "fileUrl"
		const val EXTRA_HEADERS = "headers"
		const val EXTRA_FILENAME = "filename"
		const val EXTRA_MAX_WIDTH = "maxWidth"
		const val EXTRA_MAX_HEIGHT = "maxHeight"
		const val EXTRA_IS_SAVE_TO_SERVER = "isSaveToServer"
		const val EXTRA_RADIUS = "radius"
		const val EXTRA_ITERATION = "iteration"
		const val EXTRA_STYLE_URI = "styleUri"
		const val EXTRA_WEIGHT = "weight"
		const val EXTRA_FILTERS = "filters"

		val ENHANCE_METHODS = listOf(
			METHOD_ZERO_DCE,
			METHOD_DEEP_LAP_PORTRAIT,
			METHOD_ESRGAN,
			METHOD_ARBITRARY_STYLE_TRANSFER,
			METHOD_DEEP_LAP_COLOR_POP,
		)
		val EDIT_METHODS = listOf(
			METHOD_FILTER,
		)

		private const val ACTION_CANCEL = "cancel"

		private const val NOTIFICATION_ID =
			K.IMAGE_PROCESSOR_SERVICE_NOTIFICATION_ID
		private const val RESULT_NOTIFICATION_ID =
			K.IMAGE_PROCESSOR_SERVICE_RESULT_NOTIFICATION_ID
		private const val RESULT_FAILED_NOTIFICATION_ID =
			K.IMAGE_PROCESSOR_SERVICE_RESULT_FAILED_NOTIFICATION_ID
		private const val CHANNEL_ID = "ImageProcessorService"

		const val TAG = "ImageProcessorService"
	}

	override fun onBind(intent: Intent?): IBinder? = null

	@SuppressLint("WakelockTimeout")
	override fun onCreate() {
		logI(TAG, "[onCreate] Service created")
		super.onCreate()
		wakeLock.acquire()
		createNotificationChannel()
		cleanUp()
	}

	override fun onDestroy() {
		logI(TAG, "[onDestroy] Service destroyed")
		wakeLock.release()
		super.onDestroy()
	}

	override fun onStartCommand(intent: Intent, flags: Int, startId: Int): Int {
		if (!isForeground) {
			try {
				startForeground(NOTIFICATION_ID, buildNotification())
				isForeground = true
			} catch (e: Throwable) {
				// ???
				logE(TAG, "[onStartCommand] Failed while startForeground", e)
			}
		}

		if ((flags and START_FLAG_REDELIVERY) != 0) {
			logW(TAG, "[onStartCommand] Redelivered intent, service crashed?")
			// add a short grace period to let user cancel the queue
			addCommand(ImageProcessorGracePeriodCommand())
		}

		when (intent.action) {
			ACTION_CANCEL -> onCancel(startId)
			else -> onNewImage(intent, startId)
		}
		return START_REDELIVER_INTENT
	}

	private fun onCancel(startId: Int) {
		logI(TAG, "[onCancel] Cancel requested")
		cmdTask?.cancel(false)
		stopSelf(startId)
	}

	private fun onNewImage(intent: Intent, startId: Int) {
		assert(intent.hasExtra(EXTRA_METHOD))
		assert(intent.hasExtra(EXTRA_FILE_URL))

		val method = intent.getStringExtra(EXTRA_METHOD)
		when (method) {
			METHOD_ZERO_DCE -> onZeroDce(startId, intent.extras!!)
			METHOD_DEEP_LAP_PORTRAIT -> onDeepLapPortrait(
				startId, intent.extras!!
			)
			METHOD_ESRGAN -> onEsrgan(startId, intent.extras!!)
			METHOD_ARBITRARY_STYLE_TRANSFER -> onArbitraryStyleTransfer(
				startId, intent.extras!!
			)
			METHOD_DEEP_LAP_COLOR_POP -> onDeepLapColorPop(
				startId, intent.extras!!
			)
			METHOD_FILTER -> onFilter(startId, intent.extras!!)
			else -> {
				logE(TAG, "Unknown method: $method")
				// we can't call stopSelf here as it'll stop the service even if
				// there are commands running in the bg
				addCommand(
					ImageProcessorEnhanceCommand(
						startId, "null", "", null, "", 0, 0, false
					)
				)
			}
		}
	}

	private fun onZeroDce(startId: Int, extras: Bundle) {
		return onMethod(
			startId, extras, METHOD_ZERO_DCE, args = mapOf(
				"iteration" to extras.getIntOrNull(EXTRA_ITERATION)
			)
		)
	}

	private fun onDeepLapPortrait(startId: Int, extras: Bundle) {
		return onMethod(
			startId, extras, METHOD_DEEP_LAP_PORTRAIT, args = mapOf(
				"radius" to extras.getIntOrNull(EXTRA_RADIUS)
			)
		)
	}

	private fun onEsrgan(startId: Int, extras: Bundle) {
		return onMethod(startId, extras, METHOD_ESRGAN)
	}

	private fun onArbitraryStyleTransfer(startId: Int, extras: Bundle) {
		return onMethod(
			startId, extras, METHOD_ARBITRARY_STYLE_TRANSFER,
			args = mapOf(
				"styleUri" to extras.getParcelable<Uri>(EXTRA_STYLE_URI),
				"weight" to extras.getFloat(EXTRA_WEIGHT),
			)
		)
	}

	private fun onDeepLapColorPop(startId: Int, extras: Bundle) {
		return onMethod(
			startId, extras, METHOD_DEEP_LAP_COLOR_POP, args = mapOf(
				"weight" to extras.getFloat(EXTRA_WEIGHT)
			)
		)
	}

	private fun onFilter(startId: Int, extras: Bundle) {
		val filters = extras.getSerializable(EXTRA_FILTERS)!!
			.asType<ArrayList<Serializable>>()
			.map { ImageFilter.fromJson(it.asType<HashMap<String, Any>>()) }

		val fileUrl = extras.getString(EXTRA_FILE_URL)!!

		@Suppress("Unchecked_cast")
		val headers =
			extras.getSerializable(EXTRA_HEADERS) as HashMap<String, String>?
		val filename = extras.getString(EXTRA_FILENAME)!!
		val maxWidth = extras.getInt(EXTRA_MAX_WIDTH)
		val maxHeight = extras.getInt(EXTRA_MAX_HEIGHT)
		val isSaveToServer = extras.getBoolean(EXTRA_IS_SAVE_TO_SERVER)
		addCommand(
			ImageProcessorFilterCommand(
				startId, fileUrl, headers, filename, maxWidth,
				maxHeight, isSaveToServer, filters
			)
		)
	}

	/**
	 * Handle methods without arguments
	 *
	 * @param startId
	 * @param extras
	 * @param method
	 */
	private fun onMethod(
		startId: Int, extras: Bundle, method: String,
		args: Map<String, Any?> = mapOf()
	) {
		val fileUrl = extras.getString(EXTRA_FILE_URL)!!

		@Suppress("Unchecked_cast")
		val headers =
			extras.getSerializable(EXTRA_HEADERS) as HashMap<String, String>?
		val filename = extras.getString(EXTRA_FILENAME)!!
		val maxWidth = extras.getInt(EXTRA_MAX_WIDTH)
		val maxHeight = extras.getInt(EXTRA_MAX_HEIGHT)
		val isSaveToServer = extras.getBoolean(EXTRA_IS_SAVE_TO_SERVER)
		addCommand(
			ImageProcessorEnhanceCommand(
				startId, method, fileUrl, headers, filename, maxWidth,
				maxHeight, isSaveToServer, args = args
			)
		)
	}

	private fun createNotificationChannel() {
		val channel = NotificationChannelCompat.Builder(
			CHANNEL_ID, NotificationManagerCompat.IMPORTANCE_LOW
		).run {
			setName("Image processing")
			setDescription("Enhance images in the background")
			build()
		}
		notificationManager.createNotificationChannel(channel)
	}

	private fun buildNotification(content: String? = null): Notification {
		val cancelIntent =
			Intent(this, ImageProcessorService::class.java).apply {
				action = ACTION_CANCEL
			}
		val cancelPendingIntent = PendingIntent.getService(
			this, 0, cancelIntent, getPendingIntentFlagImmutable()
		)
		return NotificationCompat.Builder(this, CHANNEL_ID).run {
			setSmallIcon(R.drawable.outline_auto_fix_high_white_24)
			setContentTitle("Processing image")
			if (content != null) setContentText(content)
			addAction(
				0, getString(android.R.string.cancel), cancelPendingIntent
			)
			build()
		}
	}

	private fun buildResultNotification(result: Uri): Notification {
		val intent = Intent().apply {
			`package` = packageName
			component = ComponentName(
				packageName, "com.nkming.nc_photos.MainActivity"
			)
			action = K.ACTION_SHOW_IMAGE_PROCESSOR_RESULT
			putExtra(K.EXTRA_IMAGE_RESULT_URI, result)
		}
		val pi = PendingIntent.getActivity(
			this, 0, intent,
			PendingIntent.FLAG_UPDATE_CURRENT or getPendingIntentFlagImmutable()
		)
		return NotificationCompat.Builder(this, CHANNEL_ID).run {
			setSmallIcon(R.drawable.outline_image_white_24)
			setContentTitle("Successfully processed image")
			setContentText("Tap to view the result")
			setContentIntent(pi)
			setAutoCancel(true)
			build()
		}
	}

	private fun buildResultFailedNotification(
		exception: Throwable
	): Notification {
		return NotificationCompat.Builder(this, CHANNEL_ID).run {
			setSmallIcon(R.drawable.outline_error_outline_white_24)
			setContentTitle("Failed processing image")
			setContentText(exception.message)
			build()
		}
	}

	private fun buildGracePeriodNotification(): Notification {
		val cancelIntent =
			Intent(this, ImageProcessorService::class.java).apply {
				action = ACTION_CANCEL
			}
		val cancelPendingIntent = PendingIntent.getService(
			this, 0, cancelIntent, getPendingIntentFlagImmutable()
		)
		return NotificationCompat.Builder(this, CHANNEL_ID).run {
			setSmallIcon(R.drawable.outline_auto_fix_high_white_24)
			setContentTitle("Preparing to restart photo processing")
			addAction(
				0, getString(android.R.string.cancel), cancelPendingIntent
			)
			build()
		}
	}

	private fun addCommand(cmd: ImageProcessorCommand) {
		cmds.add(cmd)
		if (cmdTask == null) {
			runCommand()
		}
	}

	private fun runCommand() {
		val cmd = cmds.first()
		if (cmd is ImageProcessorImageCommand) {
			runCommand(cmd)
		} else if (cmd is ImageProcessorGracePeriodCommand) {
			runCommand(cmd)
		}
	}

	@SuppressLint("StaticFieldLeak")
	private fun runCommand(cmd: ImageProcessorImageCommand) {
		notificationManager.notify(
			NOTIFICATION_ID, buildNotification(cmd.filename)
		)
		cmdTask = object : ImageProcessorCommandTask(applicationContext) {
			override fun onPostExecute(result: MessageEvent) {
				notifyResult(result)
				cmds.removeFirst()
				stopSelf(cmd.startId)
				cmdTask = null
				@Suppress("Deprecation")
				if (cmds.isNotEmpty() && !isCancelled) {
					runCommand()
				}
			}
		}.apply {
			@Suppress("Deprecation")
			executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR, cmd)
		}
	}

	@SuppressLint("StaticFieldLeak")
	private fun runCommand(
		@Suppress("UNUSED_PARAMETER") cmd: ImageProcessorGracePeriodCommand
	) {
		notificationManager.notify(
			NOTIFICATION_ID, buildGracePeriodNotification()
		)
		@Suppress("Deprecation")
		cmdTask = object : AsyncTask<Unit, Unit, Unit>(), AsyncTaskCancellable {
			override fun doInBackground(vararg params: Unit?) {
				// 10 seconds
				for (i in 0 until 20) {
					if (isCancelled) {
						return
					}
					Thread.sleep(500)
				}
			}

			override fun onPostExecute(result: Unit?) {
				cmdTask = null
				cmds.removeFirst()
				if (cmds.isNotEmpty() && !isCancelled) {
					runCommand()
				}
			}
		}.apply {
			executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR)
		}
	}

	private fun notifyResult(event: MessageEvent) {
		if (event is ImageProcessorCompletedEvent) {
			NativeEventChannelHandler.fire(ImageProcessorUploadSuccessEvent())
			notificationManager.notify(
				RESULT_NOTIFICATION_ID, buildResultNotification(event.result)
			)
		} else if (event is ImageProcessorFailedEvent) {
			notificationManager.notify(
				RESULT_FAILED_NOTIFICATION_ID,
				buildResultFailedNotification(event.exception)
			)
		}
	}

	/**
	 * Clean up temp files in case the service ended prematurely last time
	 */
	private fun cleanUp() {
		try {
			getTempDir(this).deleteRecursively()
		} catch (e: Throwable) {
			logE(TAG, "[cleanUp] Failed while cleanUp", e)
		}
	}

	private var isForeground = false
	private val cmds = mutableListOf<ImageProcessorCommand>()
	private var cmdTask: AsyncTaskCancellable? = null

	private val notificationManager by lazy {
		NotificationManagerCompat.from(this)
	}
	private val wakeLock: PowerManager.WakeLock by lazy {
		(getSystemService(Context.POWER_SERVICE) as PowerManager).newWakeLock(
			PowerManager.PARTIAL_WAKE_LOCK, "nc-photos:ImageProcessorService"
		).apply {
			setReferenceCounted(false)
		}
	}
}

private interface ImageProcessorCommand

private abstract class ImageProcessorImageCommand(
	val startId: Int,
	val method: String,
	val fileUrl: String,
	val headers: Map<String, String>?,
	val filename: String,
	val maxWidth: Int,
	val maxHeight: Int,
	val isSaveToServer: Boolean,
) : ImageProcessorCommand {
	abstract fun apply(context: Context, fileUri: Uri): Bitmap
}

private class ImageProcessorEnhanceCommand(
	startId: Int,
	method: String,
	fileUrl: String,
	headers: Map<String, String>?,
	filename: String,
	maxWidth: Int,
	maxHeight: Int,
	isSaveToServer: Boolean,
	val args: Map<String, Any?> = mapOf(),
) : ImageProcessorImageCommand(
	startId, method, fileUrl, headers, filename, maxWidth, maxHeight,
	isSaveToServer
) {
	override fun apply(context: Context, fileUri: Uri): Bitmap {
		return when (method) {
			ImageProcessorService.METHOD_ZERO_DCE -> ZeroDce(
				context, maxWidth, maxHeight,
				args["iteration"] as? Int ?: 8
			).infer(fileUri)

			ImageProcessorService.METHOD_DEEP_LAP_PORTRAIT -> DeepLab3Portrait(
				context, maxWidth, maxHeight,
				args["radius"] as? Int ?: 16
			).infer(fileUri)

			ImageProcessorService.METHOD_ESRGAN -> Esrgan(
				context, maxWidth, maxHeight
			).infer(fileUri)

			ImageProcessorService.METHOD_ARBITRARY_STYLE_TRANSFER -> ArbitraryStyleTransfer(
				context, maxWidth, maxHeight,
				args["styleUri"] as Uri,
				args["weight"] as Float
			).infer(fileUri)

			ImageProcessorService.METHOD_DEEP_LAP_COLOR_POP -> DeepLab3ColorPop(
				context, maxWidth, maxHeight, args["weight"] as Float
			).infer(fileUri)

			else -> throw IllegalArgumentException("Unknown method: $method")
		}
	}
}

private class ImageProcessorFilterCommand(
	startId: Int,
	fileUrl: String,
	headers: Map<String, String>?,
	filename: String,
	maxWidth: Int,
	maxHeight: Int,
	isSaveToServer: Boolean,
	val filters: List<ImageFilter>,
) : ImageProcessorImageCommand(
	startId, ImageProcessorService.METHOD_FILTER, fileUrl, headers, filename,
	maxWidth, maxHeight, isSaveToServer
) {
	override fun apply(context: Context, fileUri: Uri): Bitmap {
		return ImageFilterProcessor(
			context, maxWidth, maxHeight, filters
		).apply(fileUri)
	}
}

private class ImageProcessorGracePeriodCommand : ImageProcessorCommand

@Suppress("Deprecation")
private open class ImageProcessorCommandTask(context: Context) :
	AsyncTask<ImageProcessorImageCommand, Unit, MessageEvent>(),
	AsyncTaskCancellable {
	companion object {
		private val exifTagOfInterests = listOf(
			ExifInterface.TAG_IMAGE_DESCRIPTION,
			ExifInterface.TAG_MAKE,
			ExifInterface.TAG_MODEL,
			ExifInterface.TAG_ORIENTATION,
			ExifInterface.TAG_X_RESOLUTION,
			ExifInterface.TAG_Y_RESOLUTION,
			ExifInterface.TAG_DATETIME,
			ExifInterface.TAG_ARTIST,
			ExifInterface.TAG_COPYRIGHT,
			ExifInterface.TAG_EXPOSURE_TIME,
			ExifInterface.TAG_F_NUMBER,
			ExifInterface.TAG_EXPOSURE_PROGRAM,
			ExifInterface.TAG_SPECTRAL_SENSITIVITY,
			ExifInterface.TAG_PHOTOGRAPHIC_SENSITIVITY,
			ExifInterface.TAG_OECF,
			ExifInterface.TAG_SENSITIVITY_TYPE,
			ExifInterface.TAG_STANDARD_OUTPUT_SENSITIVITY,
			ExifInterface.TAG_RECOMMENDED_EXPOSURE_INDEX,
			ExifInterface.TAG_ISO_SPEED,
			ExifInterface.TAG_ISO_SPEED_LATITUDE_YYY,
			ExifInterface.TAG_ISO_SPEED_LATITUDE_ZZZ,
			ExifInterface.TAG_EXIF_VERSION,
			ExifInterface.TAG_DATETIME_ORIGINAL,
			ExifInterface.TAG_DATETIME_DIGITIZED,
			ExifInterface.TAG_OFFSET_TIME,
			ExifInterface.TAG_OFFSET_TIME_ORIGINAL,
			ExifInterface.TAG_OFFSET_TIME_DIGITIZED,
			ExifInterface.TAG_SHUTTER_SPEED_VALUE,
			ExifInterface.TAG_APERTURE_VALUE,
			ExifInterface.TAG_BRIGHTNESS_VALUE,
			ExifInterface.TAG_EXPOSURE_BIAS_VALUE,
			ExifInterface.TAG_MAX_APERTURE_VALUE,
			ExifInterface.TAG_SUBJECT_DISTANCE,
			ExifInterface.TAG_METERING_MODE,
			ExifInterface.TAG_LIGHT_SOURCE,
			ExifInterface.TAG_FLASH,
			ExifInterface.TAG_FOCAL_LENGTH,
			ExifInterface.TAG_SUBJECT_AREA,
			ExifInterface.TAG_MAKER_NOTE,
			ExifInterface.TAG_USER_COMMENT,
			ExifInterface.TAG_SUBSEC_TIME,
			ExifInterface.TAG_SUBSEC_TIME_ORIGINAL,
			ExifInterface.TAG_SUBSEC_TIME_DIGITIZED,
			ExifInterface.TAG_FLASHPIX_VERSION,
			ExifInterface.TAG_FLASH_ENERGY,
			ExifInterface.TAG_SPATIAL_FREQUENCY_RESPONSE,
			ExifInterface.TAG_FOCAL_PLANE_X_RESOLUTION,
			ExifInterface.TAG_FOCAL_PLANE_Y_RESOLUTION,
			ExifInterface.TAG_FOCAL_PLANE_RESOLUTION_UNIT,
			ExifInterface.TAG_SUBJECT_LOCATION,
			ExifInterface.TAG_EXPOSURE_INDEX,
			ExifInterface.TAG_SENSING_METHOD,
			ExifInterface.TAG_FILE_SOURCE,
			ExifInterface.TAG_SCENE_TYPE,
			ExifInterface.TAG_CFA_PATTERN,
			ExifInterface.TAG_CUSTOM_RENDERED,
			ExifInterface.TAG_EXPOSURE_MODE,
			ExifInterface.TAG_WHITE_BALANCE,
			ExifInterface.TAG_DIGITAL_ZOOM_RATIO,
			ExifInterface.TAG_FOCAL_LENGTH_IN_35MM_FILM,
			ExifInterface.TAG_SCENE_CAPTURE_TYPE,
			ExifInterface.TAG_GAIN_CONTROL,
			ExifInterface.TAG_CONTRAST,
			ExifInterface.TAG_SATURATION,
			ExifInterface.TAG_SHARPNESS,
			ExifInterface.TAG_DEVICE_SETTING_DESCRIPTION,
			ExifInterface.TAG_SUBJECT_DISTANCE_RANGE,
			ExifInterface.TAG_IMAGE_UNIQUE_ID,
			ExifInterface.TAG_CAMERA_OWNER_NAME,
			ExifInterface.TAG_BODY_SERIAL_NUMBER,
			ExifInterface.TAG_LENS_SPECIFICATION,
			ExifInterface.TAG_LENS_MAKE,
			ExifInterface.TAG_LENS_MODEL,
			ExifInterface.TAG_GAMMA,
			ExifInterface.TAG_GPS_VERSION_ID,
			ExifInterface.TAG_GPS_LATITUDE_REF,
			ExifInterface.TAG_GPS_LATITUDE,
			ExifInterface.TAG_GPS_LONGITUDE_REF,
			ExifInterface.TAG_GPS_LONGITUDE,
			ExifInterface.TAG_GPS_ALTITUDE_REF,
			ExifInterface.TAG_GPS_ALTITUDE,
			ExifInterface.TAG_GPS_TIMESTAMP,
			ExifInterface.TAG_GPS_SATELLITES,
			ExifInterface.TAG_GPS_STATUS,
			ExifInterface.TAG_GPS_MEASURE_MODE,
			ExifInterface.TAG_GPS_DOP,
			ExifInterface.TAG_GPS_SPEED_REF,
			ExifInterface.TAG_GPS_SPEED,
			ExifInterface.TAG_GPS_TRACK_REF,
			ExifInterface.TAG_GPS_TRACK,
			ExifInterface.TAG_GPS_IMG_DIRECTION_REF,
			ExifInterface.TAG_GPS_IMG_DIRECTION,
			ExifInterface.TAG_GPS_MAP_DATUM,
			ExifInterface.TAG_GPS_DEST_LATITUDE_REF,
			ExifInterface.TAG_GPS_DEST_LATITUDE,
			ExifInterface.TAG_GPS_DEST_LONGITUDE_REF,
			ExifInterface.TAG_GPS_DEST_LONGITUDE,
			ExifInterface.TAG_GPS_DEST_BEARING_REF,
			ExifInterface.TAG_GPS_DEST_BEARING,
			ExifInterface.TAG_GPS_DEST_DISTANCE_REF,
			ExifInterface.TAG_GPS_DEST_DISTANCE,
			ExifInterface.TAG_GPS_PROCESSING_METHOD,
			ExifInterface.TAG_GPS_AREA_INFORMATION,
			ExifInterface.TAG_GPS_DATESTAMP,
			ExifInterface.TAG_GPS_DIFFERENTIAL,
			ExifInterface.TAG_GPS_H_POSITIONING_ERROR,
		)

		private const val TAG = "ImageProcessorCommandTask"
	}

	override fun doInBackground(
		vararg params: ImageProcessorImageCommand?
	): MessageEvent {
		val cmd = params[0]!!
		return try {
			val outUri = handleCommand(cmd)
			System.gc()
			ImageProcessorCompletedEvent(outUri)
		} catch (e: Throwable) {
			logE(TAG, "[doInBackground] Failed while handleCommand", e)
			ImageProcessorFailedEvent(e)
		}
	}

	private fun handleCommand(cmd: ImageProcessorImageCommand): Uri {
		val file = downloadFile(cmd.fileUrl, cmd.headers)
		handleCancel()

		// special case for lossless rotation
		if (cmd is ImageProcessorFilterCommand) {
			if (shouldTryLosslessRotate(cmd, cmd.filename)) {
				val filter = cmd.filters.first() as Orientation
				try {
					return loselessRotate(
						filter.degree, file, cmd.filename, cmd
					)
				} catch (e: Throwable) {
					logE(
						TAG,
						"[handleCommand] Lossless rotation has failed, fallback to lossy",
						e
					)
				}
			}
		}

		return try {
			val fileUri = Uri.fromFile(file)
			val output = measureTime(TAG, "[handleCommand] Elapsed time", {
				cmd.apply(context, fileUri)
			})
			handleCancel()
			saveBitmap(output, cmd.filename, file, cmd)
		} finally {
			file.delete()
		}
	}

	private fun shouldTryLosslessRotate(
		cmd: ImageProcessorFilterCommand, srcFilename: String
	): Boolean {
		try {
			if (cmd.filters.size != 1) {
				return false
			}
			if (cmd.filters.first() !is Orientation) {
				return false
			}
			// we can't use the content resolver here because the file we just
			// downloaded does not exist in the media store
			val ext = srcFilename.split('.').last()
			val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
			logD(TAG, "[shouldTryLosslessRotate] ext: $ext -> mime: $mime")
			return mime == "image/jpeg"
		} catch (e: Throwable) {
			logE(TAG, "[shouldTryLosslessRotate] Uncaught exception", e)
			return false
		}
	}

	private fun loselessRotate(
		degree: Int, srcFile: File, outFilename: String,
		cmd: ImageProcessorImageCommand
	): Uri {
		logI(TAG, "[loselessRotate] $outFilename")
		val outFile = File.createTempFile("out", null, getTempDir(context))
		try {
			srcFile.copyTo(outFile, overwrite = true)
			val iExif = ExifInterface(srcFile)
			val oExif = ExifInterface(outFile)
			copyExif(iExif, oExif)
			LosslessRotator()(degree, iExif, oExif)
			oExif.saveAttributes()

			handleCancel()
			val persister = getPersister(cmd.isSaveToServer)
			return persister.persist(cmd, outFile)
		} finally {
			outFile.delete()
		}
	}

	private fun downloadFile(
		fileUrl: String, headers: Map<String, String>?
	): File {
		logI(TAG, "[downloadFile] $fileUrl")
		return (URL(fileUrl).openConnection() as HttpURLConnection).apply {
			requestMethod = "GET"
			instanceFollowRedirects = true
			connectTimeout = 8000
			readTimeout = 15000
			for (entry in (headers ?: mapOf()).entries) {
				setRequestProperty(entry.key, entry.value)
			}
		}.use {
			val responseCode = it.responseCode
			if (responseCode / 100 == 2) {
				val file =
					File.createTempFile("img", null, getTempDir(context))
				file.outputStream().use { oStream ->
					it.inputStream.copyTo(oStream)
				}
				file
			} else {
				logE(
					TAG,
					"[downloadFile] Failed downloading file: HTTP$responseCode"
				)
				throw HttpException(
					responseCode, "Failed downloading file (HTTP$responseCode)"
				)
			}
		}
	}

	private fun saveBitmap(
		bitmap: Bitmap, filename: String, srcFile: File,
		cmd: ImageProcessorImageCommand
	): Uri {
		logI(TAG, "[saveBitmap] $filename")
		val outFile = File.createTempFile("out", null, getTempDir(context))
		try {
			outFile.outputStream().use {
				bitmap.compress(Bitmap.CompressFormat.JPEG, 85, it)
			}

			// then copy the EXIF tags
			try {
				val iExif = ExifInterface(srcFile)
				val oExif = ExifInterface(outFile)
				copyExif(iExif, oExif)
				oExif.saveAttributes()
			} catch (e: Throwable) {
				logE(TAG, "[copyExif] Failed while saving EXIF", e)
			}

			val persister = getPersister(cmd.isSaveToServer)
			return persister.persist(cmd, outFile)
		} finally {
			outFile.delete()
		}
	}

	private fun copyExif(from: ExifInterface, to: ExifInterface) {
		// only a subset will be copied over
		for (t in exifTagOfInterests) {
			try {
				from.getAttribute(t)?.let { to.setAttribute(t, it) }
			} catch (e: Throwable) {
				logE(TAG, "[copyExif] Failed while copying tag: $t", e)
			}
		}
	}

	private fun handleCancel() {
		if (isCancelled) {
			logI(TAG, "[handleCancel] Canceled")
			throw InterruptedException()
		}
	}

	private fun getPersister(isSaveToServer: Boolean): EnhancedFilePersister {
		return if (isSaveToServer) {
			EnhancedFileServerPersisterWithFallback(context)
		} else {
			EnhancedFileDevicePersister(context)
		}
	}

	@SuppressLint("StaticFieldLeak")
	private val context = context
}

private interface AsyncTaskCancellable {
	fun cancel(a: Boolean): Boolean
}

private fun getTempDir(context: Context): File {
	val f = File(context.cacheDir, "imageProcessor")
	if (!f.exists()) {
		f.mkdirs()
	} else if (!f.isDirectory) {
		f.delete()
		f.mkdirs()
	}
	return f
}

private interface EnhancedFilePersister {
	fun persist(cmd: ImageProcessorImageCommand, file: File): Uri
}

private class EnhancedFileDevicePersister(context: Context) :
	EnhancedFilePersister {
	override fun persist(cmd: ImageProcessorImageCommand, file: File): Uri {
		val uri = MediaStoreUtil.copyFileToDownload(
			context, Uri.fromFile(file), cmd.filename,
			"Photos (for Nextcloud)/${getSubDir(cmd)}"
		)
		return uri
	}

	private fun getSubDir(cmd: ImageProcessorImageCommand): String {
		return if (cmd.method in ImageProcessorService.EDIT_METHODS) {
			"Edited Photos"
		} else {
			"Enhanced Photos"
		}
	}

	val context = context
}

private class EnhancedFileServerPersister :
	EnhancedFilePersister {
	companion object {
		const val TAG = "EnhancedFileServerPersister"
	}

	override fun persist(cmd: ImageProcessorImageCommand, file: File): Uri {
		val ext = cmd.fileUrl.substringAfterLast('.', "")
		val url = if (ext.contains('/')) {
			// no ext
			"${cmd.fileUrl}_${getSuffix(cmd)}.jpg"
		} else {
			"${cmd.fileUrl.substringBeforeLast('.', "")}_${getSuffix(cmd)}.jpg"
		}
		logI(TAG, "[persist] Persist file to server: $url")
		(URL(url).openConnection() as HttpURLConnection).apply {
			requestMethod = "PUT"
			instanceFollowRedirects = true
			connectTimeout = 8000
			for (entry in (cmd.headers ?: mapOf()).entries) {
				setRequestProperty(entry.key, entry.value)
			}
		}.use {
			file.inputStream()
				.use { iStream -> iStream.copyTo(it.outputStream) }
			val responseCode = it.responseCode
			if (responseCode / 100 != 2) {
				logE(TAG, "[persist] Failed uploading file: HTTP$responseCode")
				throw HttpException(
					responseCode, "Failed uploading file (HTTP$responseCode)"
				)
			}
		}
		return Uri.parse(url)
	}

	private fun getSuffix(cmd: ImageProcessorImageCommand): String {
		val epoch = System.currentTimeMillis() / 1000
		return if (cmd.method in ImageProcessorService.EDIT_METHODS) {
			"edited_$epoch"
		} else {
			"enhanced_$epoch"
		}
	}
}

private class EnhancedFileServerPersisterWithFallback(context: Context) :
	EnhancedFilePersister {
	companion object {
		const val TAG = "EnhancedFileServerPersisterWithFallback"
	}

	override fun persist(cmd: ImageProcessorImageCommand, file: File): Uri {
		try {
			return server.persist(cmd, file)
		} catch (e: Throwable) {
			logW(
				TAG,
				"[persist] Failed while persisting to server, switch to fallback",
				e
			)
		}
		return fallback.persist(cmd, file)
	}

	private val server = EnhancedFileServerPersister()
	private val fallback = EnhancedFileDevicePersister(context)
}
