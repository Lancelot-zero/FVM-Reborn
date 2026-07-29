/// 

function NativeUtil() constructor {

    
    /// @param {String} _path 
    /// @returns {String}
    static get_path_in_local_appdata = function(_path) {
        var _user_profile = environment_get_variable("LOCALAPPDATA")
        return self.transfer_path_to_windows(_user_profile + _path)
    }

    /// @param {String} _path 
    /// @returns {String}
    static transfer_path_to_windows = function(_path) {
        return string_replace(_path, "/", "\\")
    }

    /// @param {Real} _code 
    /// @param {String} _msg 
    static show_error = function(_code, _msg) {
        show_message_async(_msg + "code: " + string(_code))
    }

}