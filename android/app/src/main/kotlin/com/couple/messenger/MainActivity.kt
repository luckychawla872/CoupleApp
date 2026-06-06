package com.couple.messenger

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.ComponentName
import android.content.pm.PackageManager

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.chatty/stealth"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "changeAppIcon") {
                val aliasName = call.argument<String>("aliasName") ?: ""
                val aliases = listOf(
                    "com.couple.messenger.MainActivity",
                    "com.couple.messenger.MainActivityCalculator",
                    "com.couple.messenger.MainActivityNotes",
                    "com.couple.messenger.MainActivityWeather",
                    "com.couple.messenger.MainActivityClock"
                )

                if (!aliases.contains(aliasName)) {
                    result.error("INVALID_ALIAS", "The alias $aliasName is not valid.", null)
                    return@setMethodCallHandler
                }

                val pm = packageManager
                
                // First enable the new alias to prevent app killing if we disable the only enabled one
                pm.setComponentEnabledSetting(
                    ComponentName(this, aliasName),
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )

                // Then disable all other aliases
                for (alias in aliases) {
                    if (alias != aliasName) {
                        pm.setComponentEnabledSetting(
                            ComponentName(this, alias),
                            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                            PackageManager.DONT_KILL_APP
                        )
                    }
                }
                
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}
