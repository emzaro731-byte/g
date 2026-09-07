package com.example.iphone_style_launcher

import android.app.role.RoleManager
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.os.Build
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "iphone_launcher/apps"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> result.success(getInstalledApps())
                    "launchApp" -> {
                        val packageName = call.argument<String>("packageName")
                        val className = call.argument<String>("className")
                        result.success(packageName != null && launchPackage(packageName, className))
                    }
                    "isDefaultHome" -> result.success(isDefaultHome())
                    "requestDefaultHome" -> result.success(requestDefaultHome())
                    else -> result.notImplemented()
                }
            }
    }

    private fun getInstalledApps(): List<Map<String, String>> {
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN).apply { addCategory(Intent.CATEGORY_LAUNCHER) }
        return pm.queryIntentActivities(intent, PackageManager.MATCH_ALL)
            .mapNotNull { info ->
                val activity = info.activityInfo ?: return@mapNotNull null
                val packageName = activity.packageName
                if (packageName == this.packageName) return@mapNotNull null
                val label = info.loadLabel(pm)?.toString()?.trim().orEmpty()
                if (label.isEmpty()) return@mapNotNull null
                val icon = info.loadIcon(pm)
                mapOf(
                    "packageName" to packageName,
                    "className" to activity.name,
                    "name" to label,
                    "icon" to drawableToBase64(icon)
                )
            }
            .distinctBy { it["packageName"] }
            .sortedBy { it["name"]?.lowercase() }
    }

    private fun drawableToBase64(drawable: Drawable): String {
        val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 96
        val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 96
        val size = minOf(maxOf(width, height), 192)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(canvas)
        val output = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
        bitmap.recycle()
        return Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)
    }

    private fun launchPackage(packageName: String, className: String?): Boolean {
        val intent = if (!className.isNullOrBlank()) {
            Intent().setClassName(packageName, className)
        } else {
            packageManager.getLaunchIntentForPackage(packageName)
        } ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        return true
    }

    private fun isDefaultHome(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val roleManager = getSystemService(RoleManager::class.java)
        return roleManager?.isRoleHeld(RoleManager.ROLE_HOME) == true
    }

    private fun requestDefaultHome(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val roleManager = getSystemService(RoleManager::class.java) ?: return false
        if (!roleManager.isRoleAvailable(RoleManager.ROLE_HOME)) return false
        if (roleManager.isRoleHeld(RoleManager.ROLE_HOME)) return true
        startActivityForResult(roleManager.createRequestRoleIntent(RoleManager.ROLE_HOME), 9001)
        return true
    }
}
