// This import will cause an error on older versions of the DLL
import "base/native/DB_001" for DBManager, DBForeignFile
import "base/native/internal_001" for Internal
import "base/private/xml_loader" for Tweaker, ModErrorHandler
import "base/native" for Logger, XML

// Disable the old tweaking system so we don't double-up on tweaks
Internal.tweaker_enabled = false

class TweakLoader {
	construct new(){}
	load_file(name, ext) {
		Logger.log("XML-Tweaking (DB) Bundle File %(name).%(ext)")

		var orig = DBManager.load_asset_contents("@" + name, "@" + ext)
		if (orig == null) {
			Fiber.abort("Failed to tweak file %(name).%(ext): original file could not be found!")
		}

		var xml = XML.new(orig)
		Tweaker.tweak_xml(name, ext, xml)
		var tweaked = xml.string
		xml.delete()

		return DBForeignFile.from_string(tweaked)
	}
}
var loader = TweakLoader.new()

for (tweak in Tweaker.tweaked_files) {
	var parts = tweak.split(".")
	var name = parts[0]
	var ext = parts[1]
	Logger.log("Register tweak: %(name).%(ext)")

	var hook = DBManager.register_asset_hook("@" + name, "@" + ext)
	hook.wren_loader = loader
}

// Try using the hook's mod warning to show a popup (on Windows at least), and if that
// fails fall back to the previous handler
var prev_err_handler = ModErrorHandler.func
ModErrorHandler.func = Fn.new { | file_name, err |
	var err2 = (Fiber.new {
		Internal.warn_bad_mod(file_name, err)
	}).try()

	// Basemod doesn't support it?
	if (err2 != null) {
		prev_err_handler.call(file_name, err)
	}
}

// Set a mod-loading error handler, and load all the mod metadata into the runtime
var load_mod_meta_err = (Fiber.new {
	for (mod in Tweaker.mods_data.values) {
		Internal.register_mod_v1(mod.name, mod.scripts_root)
	}
}).try()

if (load_mod_meta_err != null) {
	Logger.log("Failed to mod metadata. This should only occur on some pre-release builds of the DLL. Please update your DLL.")
	Logger.log("Error for the above: %(load_mod_meta_err)")
}
