package com.example.mecab_dart

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * MecabDartPlugin
 *
 * Vendored for shiroikumanojisho (toolchain migration): the upstream
 * class carried the v1-embedding registerWith(Registrar) path, whose
 * API the Flutter engine removed. The channel only ever served the
 * template getPlatformVersion; the real MeCab binding is pure FFI.
 */
class MecabDartPlugin : FlutterPlugin, MethodCallHandler {
  private var channel: MethodChannel? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, "mecab_dart")
    channel?.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    if (call.method == "getPlatformVersion") {
      result.success("Android ${android.os.Build.VERSION.RELEASE}")
    } else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel?.setMethodCallHandler(null)
    channel = null
  }
}
