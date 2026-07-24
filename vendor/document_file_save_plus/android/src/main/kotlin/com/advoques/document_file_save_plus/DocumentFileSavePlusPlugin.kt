package com.advoques.document_file_save_plus

import android.Manifest
import android.R.attr
import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.Environment.DIRECTORY_DOWNLOADS
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.io.FileOutputStream

/** DocumentFileSavePlusPlugin */
class DocumentFileSavePlusPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener  {
  private lateinit var context: Context
  private val REQ_CODE = 39285
  private var currentActivity : Activity? = null
  private var call: MethodCall? = null
  private var result: Result? = null

  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "document_file_save_plus")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    this.call = call
    this.result = result

    if (call.method == "getPlatformVersion") {
      result.success("Android ${android.os.Build.VERSION.RELEASE}")
    } else if (call.method == "getBatteryPercentage") {
      val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
      val value = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
      result.success(value)
    } else if (call.method == "saveMultipleFiles") {
      var permissionGranted = true

      if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q && ActivityCompat.checkSelfPermission(currentActivity!!, Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED)
          permissionGranted = false

      if (permissionGranted) {
        val dataList: List<ByteArray> = call.argument("dataList")!!
        val fileNameList: List<String> = call.argument("fileNameList")!!
        val mimeTypeList: List<String> = call.argument("mimeTypeList")!!
        saveMultipleFiles(dataList, fileNameList, mimeTypeList)
        result.success(null)
      } else {
        ActivityCompat.requestPermissions(currentActivity!!, arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), REQ_CODE)
      }

    } else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  private fun saveMultipleFiles(dataList: List<ByteArray>, fileNameList: List<String>, mimeTypeList: List<String>) {
    val length = dataList.count()

    for (i in 0 until length) {
      val data = dataList[i]
      val fileName = fileNameList[i]
      val mimeType = mimeTypeList[i]

      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        Log.i("advoques", "save file using MediaStore")

        val values = ContentValues().apply {
          put(MediaStore.Downloads.DISPLAY_NAME, fileName)
          put(MediaStore.Downloads.MIME_TYPE, mimeType)
          put(MediaStore.Downloads.IS_PENDING, 1)
        }

        val resolver = context.contentResolver

        val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)

        val itemUri = resolver.insert(collection, values)

        if (itemUri != null) {
          resolver.openFileDescriptor(itemUri, "w").use { it ->
            ParcelFileDescriptor.AutoCloseOutputStream(it).write(data)
          }
          values.clear()
          values.put(MediaStore.Downloads.IS_PENDING, 0)
          resolver.update(itemUri, values, null, null)
        }
      } else {
        Log.i("advoques", "save file using getExternalStoragePublicDirectory")
        val file = File(Environment.getExternalStoragePublicDirectory(DIRECTORY_DOWNLOADS), fileName)
        val fos = FileOutputStream(file)
        fos.write(data)
        fos.close()
      }
    }
  }

  override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<out String>,
    grantResults: IntArray
  ): Boolean {
    if (requestCode == this.REQ_CODE) {
      val granted = grantResults[0] == PackageManager.PERMISSION_GRANTED
      if (granted) {
        onMethodCall(call!!, result!!)
      } else {
        result?.error("0", "Permission denied", null)
      }
      return granted
    }

    return false
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    currentActivity = binding.activity
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    currentActivity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    currentActivity = binding.activity
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivity() {
    currentActivity = null
  }
}
