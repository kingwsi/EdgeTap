import Foundation

enum Localization: Sendable {
    static var currentLanguage: String {
        get { 
            let langs = UserDefaults.standard.stringArray(forKey: "AppleLanguages") ?? []
            return (langs.first?.hasPrefix("zh") == true) ? "zh-hans" : "en"
        }
        set { 
            UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
            // Also keep our custom key for simplicity in other parts of the app
            UserDefaults.standard.set(newValue, forKey: "language")
            UserDefaults.standard.synchronize()
        }
    }
    
    static func get(_ key: String, bundle: Bundle = .module, comment: String = "") -> String {
        let lang = currentLanguage
        
        // Search for the .lproj path directly
        let folderName = lang == "zh-hans" ? "zh-hans.lproj" : "en.lproj"
        
        if let path = bundle.path(forResource: lang, ofType: "lproj") ?? 
                      bundle.path(forResource: lang.lowercased(), ofType: "lproj") ??
                      bundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: lang)?.deletingLastPathComponent().path {
            if let resourceBundle = Bundle(path: path) {
                return NSLocalizedString(key, bundle: resourceBundle, comment: comment)
            }
        }
        
        // Fallback for Chinese specifically
        if lang == "zh-hans" {
            if let path = bundle.path(forResource: "zh-Hans", ofType: "lproj") ??
                          bundle.path(forResource: "zh_Hans", ofType: "lproj") ??
                          bundle.path(forResource: "zh_hans", ofType: "lproj") {
                if let resourceBundle = Bundle(path: path) {
                    return NSLocalizedString(key, bundle: resourceBundle, comment: comment)
                }
            }
        }
        
        return NSLocalizedString(key, bundle: bundle, comment: comment)
    }
}

extension String {
    var localized: String {
        Localization.get(self)
    }
}
