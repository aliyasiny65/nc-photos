package com.nkming.nc_photos.plugin

import android.app.Activity
import android.content.Context
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class PermissionChannelHandler(context: Context) :
	MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ActivityAware,
	PluginRegistry.RequestPermissionsResultListener {
	companion object {
		const val EVENT_CHANNEL = "${K.LIB_ID}/permission"
		const val METHOD_CHANNEL = "${K.LIB_ID}/permission_method"

		private const val TAG = "PermissionChannelHandler"
	}

	override fun onAttachedToActivity(binding: ActivityPluginBinding) {
		activity = binding.activity
	}

	override fun onReattachedToActivityForConfigChanges(
		binding: ActivityPluginBinding
	) {
		activity = binding.activity
	}

	override fun onDetachedFromActivity() {
		activity = null
	}

	override fun onDetachedFromActivityForConfigChanges() {
		activity = null
	}

	override fun onRequestPermissionsResult(
		requestCode: Int, permissions: Array<String>, grantResults: IntArray
	): Boolean {
		return if (requestCode == K.PERMISSION_REQUEST_CODE) {
			eventSink?.success(buildMap {
				put("event", "RequestPermissionsResult")
				put(
					"grantResults",
					permissions.zip(grantResults.toTypedArray()).toMap()
				)
			})
			true
		} else {
			false
		}
	}

	override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
		eventSink = events
	}

	override fun onCancel(arguments: Any?) {
		eventSink = null
	}

	override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
		when (call.method) {
			"request" -> {
				try {
					request(call.argument("permissions")!!, result)
				} catch (e: Throwable) {
					result.error("systemException", e.toString(), null)
				}
			}

			"hasWriteExternalStorage" -> {
				try {
					result.success(
						PermissionUtil.hasWriteExternalStorage(context)
					)
				} catch (e: Throwable) {
					result.error("systemException", e.toString(), null)
				}
			}

			"hasReadExternalStorage" -> {
				try {
					result.success(
						PermissionUtil.hasReadExternalStorage(context)
					)
				} catch (e: Throwable) {
					result.error("systemException", e.toString(), null)
				}
			}

			else -> result.notImplemented()
		}
	}

	private fun request(
		permissions: List<String>, result: MethodChannel.Result
	) {
		if (activity == null) {
			result.error("systemException", "Activity is not ready", null)
			return
		}
		PermissionUtil.request(activity!!, *permissions.toTypedArray())
		result.success(null)
	}

	private val context = context
	private var activity: Activity? = null
	private var eventSink: EventChannel.EventSink? = null
}
