//
//  UserConfigurationTests.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Nimble
import Quick
import SwiftyJSON

fileprivate final class TestConfigurationStorage: ConfigurationStorage {
    var storage: [ConfigurationKey: Any] = [:]

    func object(forKey key: ConfigurationKey) -> Any? {
        return storage[key]
    }

    func array(forKey key: ConfigurationKey) -> [Any]? {
        return storage[key] as? [Any]
    }

    func bool(forKey key: ConfigurationKey) -> Bool {
        return (storage[key] as? Bool) ?? false
    }

    func float(forKey key: ConfigurationKey) -> Float {
        return (storage[key] as? Float) ?? 0
    }

    func stringArray(forKey key: ConfigurationKey) -> [String]? {
        return storage[key] as? [String]
    }
    
    func set(_ value: Any?, forKey key: ConfigurationKey) {
        storage[key] = value
    }

    func set(_ value: Bool, forKey key: ConfigurationKey) {
        storage[key] = value
    }
}

final class UserConfigurationTests: QuickSpec {
    private class TestHotKeyRegistrar: HotKeyRegistrar {
        private(set) var keyString: String?
        private(set) var modifiers: AMModifierFlags?
        private(set) var handler: (() -> ())?
        private(set) var defaultsKey: String?
        private(set) var override: Bool?

        init() {}

        func registerHotKey(with string: String?, modifiers: AMModifierFlags?, handler: @escaping () -> Void, defaultsKey: String, override: Bool) {
            keyString = string
            self.modifiers = modifiers
            self.handler = handler
            self.defaultsKey = defaultsKey
            self.override = override
        }
    }

    private class TestBundleIdentifiable: BundleIdentifiable {
        var bundleIdentifier: String?
    }

    override func spec() {
        describe("constructing commands") {
            context("overrides") {
                it("when user configuration exists") {
                    let configuration = UserConfiguration(storage: TestConfigurationStorage())
                    let localConfiguration: [String: Any] = [
                        "test": [
                            "mod": "mod1",
                            "key": "1"
                        ]
                    ]
                    configuration.configuration = JSON(localConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                    let registrar = TestHotKeyRegistrar()

                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})

                    expect(registrar.override).to(beTrue())
                }

                it("when custom mod1 is specified") {
                    let configuration = UserConfiguration(storage: TestConfigurationStorage())
                    let localConfiguration: [String: Any] = [
                        "mod1": [
                            "command"
                        ]
                    ]
                    let defaultConfiguration: [String: Any] = [
                        "test": [
                            "mod": "mod1",
                            "key": "1"
                        ]
                    ]
                    configuration.configuration = JSON(localConfiguration)
                    configuration.defaultConfiguration = JSON(defaultConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                    let registrar = TestHotKeyRegistrar()

                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})

                    expect(registrar.override).to(beTrue())
                }

                it("when custom mod2 is specified") {
                    let configuration = UserConfiguration(storage: TestConfigurationStorage())
                    let localConfiguration: [String: Any] = [
                        "mod2": [
                            "command"
                        ]
                    ]
                    let defaultConfiguration: [String: Any] = [
                        "test": [
                            "mod": "mod1",
                            "key": "1"
                        ]
                    ]
                    configuration.configuration = JSON(localConfiguration)
                    configuration.defaultConfiguration = JSON(defaultConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])
                    
                    let registrar = TestHotKeyRegistrar()
                    
                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})
                    
                    expect(registrar.override).to(beTrue())
                }
            }

            context("takes command") {
                it("from local configuration over default") {
                    let configuration = UserConfiguration(storage: TestConfigurationStorage())
                    let localConfiguration: [String: Any] = [
                        "test": [
                            "mod": "mod1",
                            "key": "1"
                        ]
                    ]
                    let defaultConfiguration: [String: Any] = [
                        "test": [
                            "mod": "mod1",
                            "key": "2"
                        ]
                    ]
                    configuration.configuration = JSON(localConfiguration)
                    configuration.defaultConfiguration = JSON(defaultConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                    let registrar = TestHotKeyRegistrar()

                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})

                    expect(registrar.keyString).to(equal("1"))
                }

                it("from default in absence of local configuration") {
                    let configuration = UserConfiguration(storage: TestConfigurationStorage())
                    let defaultConfiguration: [String: Any] = [
                        "test": [
                            "mod": "mod1",
                            "key": "1"
                        ]
                    ]
                    configuration.configuration = JSON([:])
                    configuration.defaultConfiguration = JSON(defaultConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])
                    
                    let registrar = TestHotKeyRegistrar()
                    
                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})

                    expect(configuration.defaultConfiguration?["test"]["key"].string).to(equal("1"))
                    expect(registrar.keyString).to(equal("1"))
                }
            }

            it("does not crash for malformed commands") {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                let localConfiguration: [String: Any] = [
                    "test": [
                        "key": "2"
                    ]
                ]
                let defaultConfiguration: [String: Any] = [
                    "test": [
                        "mod": "mod1",
                        "key": "2"
                    ]
                ]
                configuration.configuration = JSON(localConfiguration)
                configuration.defaultConfiguration = JSON(defaultConfiguration)
                configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])
                
                let registrar = TestHotKeyRegistrar()
                
                expect {
                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})
                }.toNot(throwError())
            }
        }

        describe("floating application") {
            it("is not floating by default") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                storage.set([] as Any?, forKey: .floatingBundleIdentifiers)

                let bundleIdentifiable = TestBundleIdentifiable()
                bundleIdentifiable.bundleIdentifier = "test.test.Test"

                expect(configuration.runningApplicationShouldFloat(bundleIdentifiable)).to(beFalse())
            }

            it("floats for exact matches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                
                storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                storage.set(["test.test.Test"], forKey: .floatingBundleIdentifiers)

                let bundleIdentifiable = TestBundleIdentifiable()
                bundleIdentifiable.bundleIdentifier = "test.test.Test"

                expect(configuration.runningApplicationShouldFloat(bundleIdentifiable)).to(beTrue())
            }

            it("floats for wildcard matches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                
                storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                storage.set(["test.test.*"], forKey: .floatingBundleIdentifiers)
                
                let bundleIdentifiable = TestBundleIdentifiable()
                bundleIdentifiable.bundleIdentifier = "test.test.Test"
                
                expect(configuration.runningApplicationShouldFloat(bundleIdentifiable)).to(beTrue())
            }
            
            it("floats for prefixed wildcard matches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                
                storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                storage.set(["*.Test"], forKey: .floatingBundleIdentifiers)
                
                let bundleIdentifiable = TestBundleIdentifiable()
                bundleIdentifiable.bundleIdentifier = "test.test.Test"
                
                expect(configuration.runningApplicationShouldFloat(bundleIdentifiable)).to(beTrue())
            }
            
            it("floats for inline wildcard matches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                
                storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                storage.set(["test.*.Test"], forKey: .floatingBundleIdentifiers)
                
                let bundleIdentifiable = TestBundleIdentifiable()
                bundleIdentifiable.bundleIdentifier = "test.foo.Test"
                
                expect(configuration.runningApplicationShouldFloat(bundleIdentifiable)).to(beTrue())
            }

            it("does not float for exact mismatches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                
                storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                storage.set(["test.test.Other"], forKey: .floatingBundleIdentifiers)
                
                let bundleIdentifiable = TestBundleIdentifiable()
                bundleIdentifiable.bundleIdentifier = "test.test.Test"
                
                expect(configuration.runningApplicationShouldFloat(bundleIdentifiable)).to(beFalse())
            }

            it("does not float for wildcard mismatches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                
                storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                storage.set(["test.other.*"], forKey: .floatingBundleIdentifiers)
                
                let bundleIdentifiable = TestBundleIdentifiable()
                bundleIdentifiable.bundleIdentifier = "test.test.Test"
                
                expect(configuration.runningApplicationShouldFloat(bundleIdentifiable)).to(beFalse())
            }
        }

        describe("focus follows mouse") {
            it("toggles") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set(true, forKey: .focusFollowsMouse)

                expect(configuration.focusFollowsMouse()).to(beTrue())

                configuration.toggleFocusFollowsMouse()

                expect(configuration.focusFollowsMouse()).to(beFalse())
            }
        }

        describe("load configuration") {
            it("default configuration does not override existing configuration") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                let existingLayouts = ["wide"]
                let defaultConfiguration = [
                    "layouts": [
                        "tall"
                    ]
                ]

                storage.set(existingLayouts, forKey: .layouts)

                expect(configuration.layoutStrings()).to(equal(existingLayouts))
                configuration.defaultConfiguration = JSON(defaultConfiguration)
                configuration.loadConfiguration()
                expect(configuration.layoutStrings()).to(equal(existingLayouts))
            }

            it("local configuration does override existing configuration") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                let existingLayouts = ["wide"]
                let localConfiguration = [
                    "layouts": [
                        "fullscreen"
                    ]
                ]
                let defaultConfiguration = [
                    "layouts": [
                        "tall"
                    ]
                ]
                
                storage.set(existingLayouts, forKey: .layouts)
                
                expect(configuration.layoutStrings()).to(equal(existingLayouts))
                configuration.configuration = JSON(localConfiguration)
                configuration.defaultConfiguration = JSON(defaultConfiguration)
                configuration.loadConfiguration()
                expect(configuration.layoutStrings()).to(equal(localConfiguration["layouts"]))
            }
        }
    }
}
