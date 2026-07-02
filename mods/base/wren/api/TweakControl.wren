import "base/private/xml_loader" for Tweaker, ModErrorHandler
import "base/native/Environment_001" for Environment

class TweakControl {
    static set_control_key(name, state) {
        // Use the caller's mod directory
        var mod = Environment.mod_directory_at_depth(1)

        Tweaker.set_control_key(mod, name, state)
    }
}
