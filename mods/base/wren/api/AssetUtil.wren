import "base/native/DB_001" for DBManager
import "base/native/Utils_001" for Utils
import "base/native" for Logger

class AssetUtil {
    /**
     * Hook the specified asset to be loaded from the bundle database, even if the package has
     * not been loaded.
     *
     * This is equivilent to hooking the file and calling set_direct_bundle, but if multiple
     * mods do that to a single file the game will crash.
     */
    static load_asset(name, type) {
        // Init the static field
        if (__loaded_assets == null) __loaded_assets = {}

        // Process the asset identifiers low how register_asset_hook works, so they're all comparable even
        // if some mods used different cases in their hashes, some mods used hashes and others used paths, or
        // anything like that.
        name = Utils.normalise_hash(name)
        type = Utils.normalise_hash(type)

        // At this point, name and type are in @0123456789abcdef notation

        var key = "%(name).%(type)"
        if (__loaded_assets.containsKey(key)) return
        __loaded_assets[key] = true

        var hook = DBManager.register_asset_hook(name, type)
        hook.fallback = true
        hook.set_direct_bundle(name, type)
    }
}
