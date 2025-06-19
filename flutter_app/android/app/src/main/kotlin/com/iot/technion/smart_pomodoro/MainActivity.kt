package com.iot.technion.smart_pomodoro

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.ComponentName
import android.content.pm.PackageManager

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.iot.technion.smart_pomodoro/app_icon"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setAlternateIcon" -> {
                    val iconName = call.argument<String?>("iconName")
                    try {
                        val pm = packageManager
                        val normalIcon = ComponentName(packageName, "$packageName.MainActivity")
                        val gloomyIcon = ComponentName(packageName, "$packageName.MainActivityGloomy")
                        
                        // Disable all icons first
                        pm.setComponentEnabledSetting(normalIcon, 
                            PackageManager.COMPONENT_ENABLED_STATE_DISABLED, 
                            PackageManager.DONT_KILL_APP)
                        pm.setComponentEnabledSetting(gloomyIcon, 
                            PackageManager.COMPONENT_ENABLED_STATE_DISABLED, 
                            PackageManager.DONT_KILL_APP)
                        
                        // Enable the selected icon
                        val selectedIcon = if (iconName == "gloomy") gloomyIcon else normalIcon
                        pm.setComponentEnabledSetting(selectedIcon,
                            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                            PackageManager.DONT_KILL_APP)
                            
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("ICON_CHANGE_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
} 